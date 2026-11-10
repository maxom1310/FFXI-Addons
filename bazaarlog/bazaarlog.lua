_addon.name = 'BazaarLog'
_addon.author = 'Claude'
_addon.version = '2.3'
_addon.commands = {'bazaarlog', 'bl'}

require('logger')
local config = require('config')
local texts = require('texts')

local defaults = {
    pos = {x = 20, y = 250},
    text = {
        font = 'Consolas', size = 10,
        stroke = {width = 1, alpha = 200, red = 0, green = 0, blue = 0},
    },
    bg = {alpha = 150, red = 0, green = 0, blue = 0},
    flags = {draggable = true},
}
local settings = config.load(defaults)
local hud = texts.new('', settings)
local hud_visible = true

local debug_mode = false
local sales = {}

local recent = {}      -- recent chat lines: {t=, mode=, text=}
local last_gil = nil   -- gil balance at last poll
local pending = nil    -- gil gain waiting for its chat line: {t=, delta=}
local last_poll = 0

local WINDOW = 5       -- seconds of chat history to search for the sale line
local SETTLE = 1.0     -- seconds to wait after a gil gain before resolving

-- Patterns are tried against the chat line with any trailing "for N gil" removed.
-- Gil is NOT taken from the text; it comes from the gil balance change.
-- 'bi' = (buyer, item), 'ib' = (item, buyer)
local patterns = {
    {'^(%S+) bought an? (.+)$',            'bi'},  -- "Name bought a <item>"
    {'^(%S+) purchases your (.+)$',        'bi'},
    {'^(%S+) has purchased your (.+)$',    'bi'},
    {'^(%S+) purchased your (.+)$',        'bi'},
    {'^(%S+) bought your (.+)$',           'bi'},
    {'^(%S+) buys your (.+)$',             'bi'},
    {'^(%S+) purchased (.+) from your bazaar$', 'bi'},
    {'^You sold (.+) to (%S+)$',           'ib'},
    {'^(%S+) bought (.+)$',                'bi'},  -- generic, e.g. "Name bought 3 <item>"
}

local function commas(n)
    local s, k = tostring(n), 0
    repeat s, k = s:gsub('^(-?%d+)(%d%d%d)', '%1,%2') until k == 0
    return s
end

local function update_hud()
    local total = 0
    for _, s in ipairs(sales) do total = total + s.gil end

    local lines = {('BazaarLog: %d sales, %s gil'):format(#sales, commas(total))}
    if #sales == 0 then
        lines[#lines + 1] = '(no sales yet)'
    else
        for i = #sales, math.max(1, #sales - 9), -1 do
            local s = sales[i]
            local item = s.item
            if s.qty > 1 then item = ('%s x%d'):format(item, s.qty) end
            lines[#lines + 1] = ('%s  %-12s %s  %s gil'):format(
                s.time:sub(6, 16), s.buyer, item, commas(s.gil))
        end
    end
    hud:text(table.concat(lines, '\n'))
    if hud_visible then hud:show() else hud:hide() end
end

-- One CSV per character: data/sales_<Name>.csv. Each row also has a
-- "seller" column so the files can be merged later.
local function current_char()
    local player = windower.ffxi.get_player()
    return player and player.name or nil
end

local function csv_path_for(char)
    return windower.addon_path .. 'data/sales_' .. (char or 'Unknown') .. '.csv'
end

local function ensure_file(path)
    path = path or csv_path_for(current_char())
    windower.create_dir(windower.addon_path .. 'data')
    if not windower.file_exists(path) then
        local f = io.open(path, 'w')
        if f then
            f:write('timestamp,seller,buyer,item,quantity,gil,raw\n')
            f:close()
        end
    end
end

local function clean(text)
    text = windower.convert_auto_trans(text)
    -- 0x1E/0x1F + one byte are color codes; 0x7F + one byte is the line-end
    -- marker (shows up as a stray "1" if only the 0x7F is removed).
    text = text:gsub(string.char(0x1E) .. '.', ''):gsub(string.char(0x1F) .. '.', '')
    text = text:gsub(string.char(0x7F) .. '.?', '')
    text = text:gsub('[%c]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    return text
end

local function csv_escape(s)
    return '"' .. tostring(s):gsub('"', '""') .. '"'
end

-- Lines about someone entering/leaving your bazaar are not sale lines.
local function is_presence(line)
    local lower = line:lower()
    return lower:find('bazaar', 1, true) ~= nil
        and (lower:find('leave', 1, true) or lower:find(' left', 1, true)
            or lower:find('enter', 1, true) or lower:find('arriv', 1, true)
            or lower:find('browse', 1, true) or lower:find('view', 1, true)) ~= nil
end

-- Returns buyer, item, kind where kind is 'strict' or 'loose'.
local function parse_line(line)
    if is_presence(line) then return nil end
    local stripped = line:gsub('%s+for [%d,]+ gil%.?$', ''):gsub('%.$', '')
    for _, p in ipairs(patterns) do
        local a, b = stripped:match(p[1])
        if a then
            if p[2] == 'bi' then return a, b, 'strict' else return b, a, 'strict' end
        end
    end
    -- Loose fallback: must contain an actual sale keyword.
    local lower = stripped:lower()
    if lower:find('purchas', 1, true) or lower:find('bought', 1, true)
        or lower:find(' buys ', 1, true) or lower:find(' sold ', 1, true) then
        return stripped:match('^(%S+)') or '?', stripped, 'loose'
    end
    return nil
end

-- Rows waiting to be written to the CSV. If the file can't be opened (for
-- example it is open in Excel), they stay queued and are retried.
local unwritten = {}
local warned = false
local last_flush = 0

-- Each queued entry is {path = <csv file>, line = <row text>}.
local function flush_csv()
    if #unwritten == 0 then return end
    local remaining, failed_path = {}, nil
    local handles = {}
    for _, entry in ipairs(unwritten) do
        local f = handles[entry.path]
        if f == nil then
            ensure_file(entry.path)
            f = io.open(entry.path, 'a') or false
            handles[entry.path] = f
        end
        if f then
            f:write(entry.line)
        else
            failed_path = entry.path
            remaining[#remaining + 1] = entry
        end
    end
    for _, f in pairs(handles) do if f then f:close() end end
    unwritten = remaining

    if failed_path then
        if not warned then
            warned = true
            windower.add_to_chat(167, 'BazaarLog: cannot write ' .. failed_path ..
                ' (is it open in Excel? Close it and the queued sales will be saved.)')
        end
    elseif warned then
        warned = false
        notice('Queued sales saved.')
    end
end

local function record(buyer, item, gil, raw)
    local qty = 1
    local name, n = item:match('^(.-)%s*[x×](%d+)$')
    if name then
        item, qty = name, tonumber(n)
    else
        local q, rest = item:match('^(%d+)%s+(.+)$')
        if q then item, qty = rest, tonumber(q) end
    end

    local row = {
        time = os.date('%Y-%m-%d %H:%M:%S'),
        buyer = buyer, item = item, qty = qty, gil = gil,
    }
    sales[#sales + 1] = row

    local seller = current_char() or 'Unknown'
    row.seller = seller
    unwritten[#unwritten + 1] = {
        path = csv_path_for(seller),
        line = table.concat({row.time, seller, buyer, csv_escape(item), qty, gil,
                             csv_escape(raw)}, ',') .. '\n',
    }
    flush_csv()
    notice(('Sold %s x%d to %s for %d gil'):format(item, qty, buyer, gil))
    update_hud()
end

local function resolve(p)
    -- Search chat lines from just before the gil gain, newest first.
    local candidates = {}
    for i = #recent, 1, -1 do
        local r = recent[i]
        if r.t >= p.t - WINDOW then candidates[#candidates + 1] = r end
    end

    -- Pass 1: exact sale patterns, then pass 2: loose sale-keyword lines.
    local loose
    for _, r in ipairs(candidates) do
        local buyer, item, kind = parse_line(r.text)
        if kind == 'strict' then
            record(buyer, item, p.delta, r.text)
            return
        elseif kind == 'loose' and not loose then
            loose = {buyer = buyer, item = item, raw = r.text}
        end
    end
    if loose then
        record(loose.buyer, loose.item, p.delta, loose.raw)
        return
    end

    -- Pass 3: no sale line found, but someone was in your bazaar. Keep the
    -- gil and buyer, and mark the item unknown so the gain is not lost.
    for _, r in ipairs(candidates) do
        if is_presence(r.text) then
            local who = r.text:match('^(%S+)') or '?'
            record(who, '(unknown item)', p.delta, r.text)
            if debug_mode then
                log('Item line not recognised. Chat lines in the last ' .. WINDOW .. 's:')
                for i = #candidates, 1, -1 do
                    log(('  [mode %d] %s'):format(candidates[i].mode, candidates[i].text))
                end
            end
            return
        end
    end

    if debug_mode then
        log(('Gil +%d with no recognised sale line. Chat lines in the last %ds:'):format(p.delta, WINDOW))
        if #candidates == 0 then log('  (none)') end
        for i = #candidates, 1, -1 do
            log(('  [mode %d] %s'):format(candidates[i].mode, candidates[i].text))
        end
    end
end

windower.register_event('incoming text', function(original, modified, mode)
    local line = clean(original)
    if line == '' then return end
    local t = os.clock()
    recent[#recent + 1] = {t = t, mode = mode, text = line}
    -- Drop lines older than 15 seconds.
    while #recent > 0 and recent[1].t < t - 15 do table.remove(recent, 1) end
end)

windower.register_event('prerender', function()
    local t = os.clock()
    if t - last_poll < 0.25 then return end
    last_poll = t

    if #unwritten > 0 and t - last_flush >= 10 then
        last_flush = t
        flush_csv()
    end

    local info = windower.ffxi.get_info()
    if not info or not info.logged_in then
        last_gil = nil
        pending = nil
        return
    end

    local items = windower.ffxi.get_items()
    if not items or not items.gil then return end
    local gil = items.gil

    if last_gil and gil > last_gil then
        local gained = gil - last_gil
        if pending then
            pending.delta = pending.delta + gained
        else
            pending = {t = t, delta = gained}
        end
    end
    last_gil = gil

    if pending and t - pending.t >= SETTLE then
        local p = pending
        pending = nil
        resolve(p)
    end
end)

windower.register_event('zone change', function()
    -- Avoid counting zone-time balance refreshes as gains.
    last_gil = nil
    pending = nil
end)

windower.register_event('addon command', function(cmd, ...)
    cmd = cmd and cmd:lower() or 'help'

    if cmd == 'debug' then
        debug_mode = not debug_mode
        notice('Debug mode ' .. (debug_mode and 'ON: on every gil gain that is not a recognised sale, the recent chat lines are printed.' or 'OFF'))
    elseif cmd == 'clear' then
        sales = {}
        update_hud()
        notice('Cleared the HUD and session totals. sales.csv was not touched.')
    elseif cmd == 'total' then
        local total = 0
        for _, s in ipairs(sales) do total = total + s.gil end
        notice(('%d sales this session, %d gil total.'):format(#sales, total))
    elseif cmd == 'gil' then
        local items = windower.ffxi.get_items()
        notice(('Current gil: %s, tracking baseline: %s'):format(
            items and tostring(items.gil) or '?', tostring(last_gil)))
    elseif cmd == 'hud' then
        hud_visible = not hud_visible
        update_hud()
        notice('HUD ' .. (hud_visible and 'shown. Drag it with the mouse to move it.' or 'hidden.'))
    elseif cmd == 'lines' then
        local n = tonumber((...)) or 15
        local now = os.clock()
        for i = math.max(1, #recent - n + 1), #recent do
            local r = recent[i]
            log(('  [%.0fs ago, mode %d] %s'):format(now - r.t, r.mode, r.text))
        end
    elseif cmd == 'path' then
        notice('Log file: ' .. csv_path_for(current_char()))
    else
        log('//bl hud       - show/hide the last-10-sales HUD (drag to move)')
        log('//bl lines [n] - dump the last n chat lines the addon saw')
        log('//bl clear     - clear the HUD and session totals (CSV is kept)')
        log('//bl total     - session totals')
        log('//bl gil       - show current gil and the tracked baseline')
        log('//bl path      - where the CSV is saved')
        log('//bl debug     - after a gil gain with no match, print nearby chat lines')
    end
end)

windower.register_event('unload', function()
    -- Remember where the HUD was dragged to.
    local x, y = hud:pos()
    settings.pos.x, settings.pos.y = x, y
    config.save(settings)
end)

windower.register_event('load', function()
    update_hud()
    if current_char() then
        ensure_file()
        notice('Logging sales to ' .. csv_path_for(current_char()))
    end
    local info = windower.ffxi.get_info()
    if info and info.logged_in then
        local items = windower.ffxi.get_items()
        last_gil = items and items.gil or nil
    end
end)

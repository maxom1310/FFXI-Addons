--[[
Entruster
GUI for assigning an Entrust Indi- spell to each party member, then applying them
one by one, resetting the Entrust recast by swapping sub job at a Nomad Moogle.

Job change / Moogle / poke logic adapted from JobChange (Sammeh, Akaden).
Entrust / Indi spell handling adapted from AutoGEO (Ivaar, icy).
]]

_addon.name = 'Entruster'
_addon.author = 'Based on JobChange (Sammeh/Akaden) and AutoGEO (Ivaar/icy)'
_addon.version = '1.1.0'
_addon.commands = {'entruster', 'ent'}

require('luau')
texts = require('texts')
packets = require('packets')
res = require('resources')

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------
defaults = {
    pos = {x = 300, y = 200},
    minimal = false,             -- minimal view (title, Run, Stop, status only)
    assign = {},                 -- [lowercase player name] = 'Indi-Fury'
    cast_range = 20,             -- max yalms to the entrust target
    temp_jobs = 'RDM,WHM,BLM,SCH,NIN,DNC,WAR,MNK,THF', -- preferred swap sub jobs; any other unlocked job is used if none fit
}
settings = config.load(defaults)

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------
local ENTRUST_RECAST = 93
local ENTRUST_BUFF = 584
local INDI_FIRST, INDI_LAST = 768, 797

local mog_zones = S{ 'Selbina', 'Mhaura', 'Tavnazian Safehold', 'Nashmau', 'Rabao', 'Kazham', 'Norg', 'Walk of Echoes [P1]', 'Walk of Echoes [P2]' }
local moogles = S{ 'Moogle', 'Nomad Moogle', 'Green Thumb Moogle', 'Pilgrim Moogle' }
local blocking_debuffs = S{ 'sleep', 'silence', 'petrification', 'stun', 'terror', 'charm', 'amnesia', 'mute', 'omerta', 'impairment' }

-- Indi spell table built from resources
local spells, by_name, by_short = {}, {}, {}
for id = INDI_FIRST, INDI_LAST do
    local s = res.spells[id]
    if s then
        local short = (s.en:gsub('^Indi%-', ''))
        local entry = {id = id, name = s.en, short = short, mp = s.mp_cost or 0}
        spells[#spells + 1] = entry
        by_name[s.en:lower()] = entry
        by_short[short:lower()] = entry
    end
end

local function find_spell(str)
    local key = (str:lower():gsub('^indi[%-%s]*', ''))
    if by_short[key] then return by_short[key] end
    for _, sp in ipairs(spells) do
        if sp.short:lower():sub(1, #key) == key then return sp end
    end
end

----------------------------------------------------------------------
-- State / helpers
----------------------------------------------------------------------
local running = false
local status_text = 'Idle'
local ui_visible = true
local selected = nil          -- lowercase name of the member being edited
local refresh_ui              -- forward declaration
local cast = {}               -- filled by the incoming packet handler
local injected_poke = false

local function log(msg)
    windower.add_to_chat(207, 'Entruster: ' .. msg)
end

local function set_status(msg)
    status_text = msg
    if refresh_ui then refresh_ui() end
end

-- Wait until cond() is true. Returns false on timeout or when stopped,
-- unless force is set (used so a sub job swap always finishes restoring).
local function wait_until(cond, timeout, force)
    local start = os.clock()
    while running or force do
        if cond() then return true end
        if os.clock() - start > timeout then return false end
        coroutine.sleep(0.2)
    end
    return false
end

local function has_buff(id)
    local pl = windower.ffxi.get_player()
    if pl then
        for _, b in ipairs(pl.buffs) do
            if b == id then return true end
        end
    end
    return false
end

local function incapacitated(pl)
    for _, b in ipairs(pl.buffs) do
        local r = res.buffs[b]
        local n = r and (r.en or r.english)
        if n and blocking_debuffs:contains(n:lower()) then return n end
    end
end

local function entrust_ready()
    local rc = windower.ffxi.get_ability_recasts()
    return rc ~= nil and (rc[ENTRUST_RECAST] or 0) <= 0
end

local function get_members()
    local list = {}
    local party = windower.ffxi.get_party()
    if not party then return list end
    for i = 1, 5 do
        local m = party['p' .. i]
        if m and m.name then list[#list + 1] = m end
    end
    return list
end

----------------------------------------------------------------------
-- Job change (adapted from JobChange)
----------------------------------------------------------------------
local function send_job_change(job_id, main)
    local packet = packets.new('outgoing', 0x100, {
        [(main and 'Main' or 'Sub') .. ' Job'] = job_id,
    })
    packets.inject(packet)
end

local function poke(npc)
    local p = packets.new('outgoing', 0x1a, {
        ['Target'] = npc.id,
        ['Target Index'] = npc.index,
    })
    injected_poke = true
    packets.inject(p)
end

local function find_job_change_npc()
    local info = windower.ffxi.get_info()
    if not (info.mog_house or mog_zones:contains(res.zones[info.zone].english)) then
        return nil
    end
    for _, v in pairs(windower.ffxi.get_mob_array()) do
        if v.distance < 36 and v.valid_target and moogles:contains(v.name) then
            return v
        end
    end
end

local orig_main, orig_main_id = nil, nil -- jobs the run started with
local orig_sub, orig_sub_id = nil, nil

-- Any unlocked job that is not the current main or sub.
local function find_other_job(pl)
    local function usable(job)
        return job and job ~= pl.main_job and job ~= pl.sub_job and (pl.jobs[job] or 0) > 0
    end
    for job in settings.temp_jobs:gmatch('%a+') do
        job = job:upper()
        if usable(job) then
            for id, v in pairs(res.jobs) do
                if v.ens == job then return id, job end
            end
        end
    end
    for id, v in pairs(res.jobs) do
        if usable(v.ens) then return id, v.ens end
    end
end

-- One main or sub job change at the Moogle. Always runs to completion once started.
local function change_job(job_id, job, is_main)
    local npc = find_job_change_npc()
    if not npc then
        log('Not close enough to a Moogle (or not in a zone with one).')
        return false
    end
    if npc.name == 'Nomad Moogle' or npc.name == 'Pilgrim Moogle' then
        poke(npc)
        coroutine.sleep(1)
    end
    send_job_change(job_id, is_main)
    local ok = wait_until(function()
        local p = windower.ffxi.get_player()
        return p and ((is_main and p.main_job or p.sub_job) == job)
    end, 10, true)
    if not ok then
        log((is_main and 'Main' or 'Sub') .. ' job did not change to ' .. job .. '.')
        return false
    end
    -- Wait for the Moogle menu / event state to release us.
    wait_until(function()
        local p = windower.ffxi.get_player()
        return p and p.status == 0
    end, 8, true)
    coroutine.sleep(is_main and 2.5 or 1)
    return true
end

local function change_sub(job_id, job)
    return change_job(job_id, job, false)
end

local function get_job_id(ens)
    for id, v in pairs(res.jobs) do
        if v.ens == ens then return id end
    end
end

-- Get to the target main/sub (either may be nil = leave alone), resolving
-- conflicts where the target main is currently the sub job.
local function set_jobs(main_id, main, sub_id, sub)
    local pl = windower.ffxi.get_player()
    if main and pl.main_job ~= main then
        if pl.sub_job == main then
            local tid, tjob = find_other_job(pl)
            if not tid then
                log('No other unlocked job found to clear the sub job conflict.')
                return false
            end
            set_status('Sub job -> ' .. tjob)
            if not change_job(tid, tjob, false) then return false end
        end
        set_status('Main job -> ' .. main)
        if not change_job(main_id, main, true) then return false end
    end
    pl = windower.ffxi.get_player()
    if sub and pl.sub_job ~= sub then
        set_status('Sub job -> ' .. sub)
        if not change_job(sub_id, sub, false) then return false end
    end
    return true
end

-- Change sub to any other job to reset Entrust (no restore here).
local function reset_entrust()
    local pl = windower.ffxi.get_player()
    local id, job = find_other_job(pl)
    if not id then
        log('No other unlocked job found to swap the sub job to.')
        return false
    end
    set_status('Sub job -> ' .. job)
    if not change_sub(id, job) then return false end
    if not wait_until(entrust_ready, 6, true) then
        log('Entrust is still on cooldown after the sub job swap.')
        return false
    end
    return true
end

-- Put main and sub back to what they were when the run started.
local function restore_jobs()
    if not orig_sub_id and not orig_main_id then return true end
    for _ = 1, 3 do
        if set_jobs(orig_main_id, orig_main, orig_sub_id, orig_sub) then return true end
    end
    log('WARNING: could not restore your jobs to ' .. tostring(orig_main or 'current main') .. '/' .. tostring(orig_sub) .. '!')
    return false
end

----------------------------------------------------------------------
-- Entrust engine
----------------------------------------------------------------------
-- Returns 'ok', 'skip' or 'abort'
local function entrust_one(job)
    local pl = windower.ffxi.get_player()
    local sp = job.spell

    local mob = windower.ffxi.get_mob_by_name(job.name)
    if not mob or not mob.valid_target or mob.hpp <= 0 or math.sqrt(mob.distance) > settings.cast_range then
        log(job.name .. ' is out of range or not targetable. Skipping.')
        return 'skip'
    end

    local bad = incapacitated(pl)
    if bad then
        log('Cannot act while under ' .. bad .. '.')
        return 'abort'
    end

    local active = has_buff(ENTRUST_BUFF)

    if not active and not entrust_ready() then
        set_status('Resetting Entrust...')
        if not reset_entrust() then return 'abort' end
    end

    -- Spell recast and MP are checked before burning Entrust.
    if not wait_until(function()
        local rc = windower.ffxi.get_spell_recasts()
        return rc and (rc[sp.id] or 0) <= 0
    end, 30) then
        log(sp.name .. ' is not ready.')
        return 'abort'
    end

    if windower.ffxi.get_player().vitals.mp < sp.mp then
        set_status('Waiting for MP (' .. sp.mp .. ')')
        if not wait_until(function() return windower.ffxi.get_player().vitals.mp >= sp.mp end, 180) then
            log('Not enough MP for ' .. sp.name .. '.')
            return 'abort'
        end
    end

    if not active then
        local got = false
        for _ = 1, 3 do
            set_status('Entrust -> ' .. job.name)
            windower.send_command('input /ja "Entrust" <me>')
            if wait_until(function() return has_buff(ENTRUST_BUFF) end, 4) then
                got = true
                break
            end
            if not running then return 'abort' end
        end
        if not got then
            log('Entrust did not activate.')
            return 'abort'
        end
    end

    for _ = 1, 3 do
        cast.done, cast.failed = nil, nil
        set_status(sp.name .. ' -> ' .. job.name)
        windower.send_command(('input /ma "%s" %s'):format(sp.name, job.name))
        wait_until(function() return cast.done or cast.failed end, 10)
        if not running then return 'abort' end
        if cast.done then return 'ok' end
        if not has_buff(ENTRUST_BUFF) then
            log('Entrust buff is gone with no cast confirmation; assuming ' .. sp.name .. ' landed on ' .. job.name .. '.')
            return 'ok'
        end
        coroutine.sleep(1.5)
    end

    log('Could not cast ' .. sp.name .. ' on ' .. job.name .. '.')
    return 'abort'
end

local function run()
    if running then
        log('Already running. Press Stop first.')
        return
    end
    local pl = windower.ffxi.get_player()
    if not pl or (pl.main_job ~= 'GEO' and (pl.jobs.GEO or 0) <= 0) then
        log('GEO is not unlocked on this character.')
        return
    end
    if not pl.sub_job or not pl.sub_job_id or pl.sub_job_id == 0 then
        log('Set a sub job first so it can be swapped and restored.')
        return
    end

    local queue = {}
    for _, m in ipairs(get_members()) do
        local sname = settings.assign[m.name:lower()]
        local sp = sname and by_name[sname:lower()]
        if sp then queue[#queue + 1] = {name = m.name, spell = sp} end
    end
    if #queue == 0 then
        log('No assignments for current party members.')
        return
    end

    orig_main, orig_main_id = pl.main_job, pl.main_job_id
    orig_sub, orig_sub_id = pl.sub_job, pl.sub_job_id
    running = true
    local done, skipped, aborted = 0, 0, false
    if pl.main_job ~= 'GEO' then
        if not set_jobs(get_job_id('GEO'), 'GEO', nil, nil) then aborted = true end
    end
    for i, job in ipairs(queue) do
        if not running or aborted then break end
        local result = entrust_one(job)
        if result == 'ok' then
            done = done + 1
            if running and i < #queue then
                set_status('Resetting Entrust...')
                if not reset_entrust() then aborted = true break end
            end
        elseif result == 'skip' then
            skipped = skipped + 1
        else
            aborted = true
            break
        end
    end

    local finished = running and not aborted
    restore_jobs()
    running = false
    orig_main, orig_main_id, orig_sub, orig_sub_id = nil, nil, nil, nil

    if aborted then
        set_status('Aborted')
        log('Aborted after ' .. done .. ' of ' .. #queue .. '.')
    elseif finished then
        set_status('Done: ' .. done .. ' cast, ' .. skipped .. ' skipped')
        log('Finished. ' .. done .. ' cast, ' .. skipped .. ' skipped.')
    else
        set_status('Stopped')
    end
end

local function stop_run(reason)
    if running then
        running = false
        log(reason or 'Stopped.')
    end
    set_status(reason or 'Stopped')
end

----------------------------------------------------------------------
-- Packet handling
----------------------------------------------------------------------
windower.register_event('incoming chunk', function(id, data)
    if id == 0x02E and injected_poke then
        injected_poke = false
        return true
    end
    if id == 0x028 and running then
        local pl = windower.ffxi.get_player()
        if not pl then return end
        local p = packets.parse('incoming', data)
        if p.Actor ~= pl.id then return end
        if p.Category == 4 then
            if p.Param >= INDI_FIRST and p.Param <= INDI_LAST then
                cast.done = {spell = p.Param, target = p['Target 1 ID']}
            end
        elseif p.Category == 8 and p.Param == 28787 then
            cast.failed = true
        end
    end
end)

----------------------------------------------------------------------
-- GUI
----------------------------------------------------------------------
local ROW_H, W, PICK_ROWS = 22, 32, 8
local COL = {
    base = {25, 25, 40}, sel = {70, 70, 130}, cur = {40, 90, 90},
    run = {30, 80, 30}, stop = {100, 30, 30}, btn = {45, 45, 60},
}
local ui = {els = {}}
local drag = nil
local swallow_release = false
local last_refresh = 0

local function make_text()
    return texts.new(' ', {
        pos = {x = 0, y = 0},
        text = {font = 'Consolas', size = 10, red = 255, green = 255, blue = 255, alpha = 255,
                stroke = {width = 1, alpha = 255, red = 0, green = 0, blue = 0}},
        bg = {alpha = 215, red = 25, green = 25, blue = 40, visible = true},
        flags = {draggable = false},
        padding = 3,
    })
end

local function new_el(kind, data, color)
    local el = {t = make_text(), kind = kind, data = data, shown = false}
    if color then el.t:bg_color(unpack(color)) end
    ui.els[#ui.els + 1] = el
    return el
end

local function set_shown(el, on)
    if el.shown ~= on then
        el.shown = on
        if on then el.t:show() else el.t:hide() end
    end
end

local function set_text(el, str)
    if el.last ~= str then
        el.last = str
        el.t:text(str)
    end
end

local function pad(s)
    return ' ' .. s .. string.rep(' ', math.max(0, W - #s))
end

local function build_ui()
    ui.title = new_el('title', nil, COL.btn)
    ui.rows = {}
    for i = 1, 5 do ui.rows[i] = new_el('member', i, COL.base) end
    ui.run = new_el('run', nil, COL.run)
    ui.stop = new_el('stop', nil, COL.stop)
    ui.clear = new_el('clear', nil, COL.btn)
    ui.view = new_el('view', nil, COL.btn)
    ui.status = new_el('status', nil, COL.base)
    ui.pick_head = new_el('pick_head', nil, COL.btn)
    ui.picks = {}
    for i, sp in ipairs(spells) do ui.picks[i] = new_el('pick', sp, COL.base) end
    ui.pick_none = new_el('pick_none', nil, COL.stop)

    ui.column = {ui.title}
    for i = 1, 5 do ui.column[#ui.column + 1] = ui.rows[i] end
    for _, el in ipairs({ui.run, ui.stop, ui.clear, ui.view, ui.status}) do
        ui.column[#ui.column + 1] = el
    end

    set_text(ui.run, pad('[ Run ]  Entrust everyone'))
    set_text(ui.stop, pad('[ Stop ]'))
    set_text(ui.clear, pad('[ Clear all assignments ]'))
    ui.mini = {ui.title, ui.run, ui.stop, ui.view, ui.status}
    ui.active = ui.column
    set_text(ui.pick_none, ' None        ')
end

local function layout()
    local x, y = settings.pos.x, settings.pos.y
    for i, el in ipairs(ui.active or ui.column) do
        el.t:pos(x, y + (i - 1) * ROW_H)
    end
    local w = ui.title.t:extents()
    if not w or w < 50 then w = 230 end
    local px = x + w + 8
    ui.pick_head.t:pos(px, y)
    local cw = ui.picks[1].t:extents()
    if not cw or cw < 30 then cw = 90 end
    cw = cw + 2
    for i, el in ipairs(ui.picks) do
        local col = math.floor((i - 1) / PICK_ROWS)
        local row = (i - 1) % PICK_ROWS
        el.t:pos(px + col * cw, y + (row + 1) * ROW_H)
    end
    local n = #ui.picks
    ui.pick_none.t:pos(px + math.floor(n / PICK_ROWS) * cw, y + (n % PICK_ROWS + 1) * ROW_H)
end

refresh_ui = function()
    if not ui.title then return end
    if not ui_visible then
        for _, el in ipairs(ui.els) do set_shown(el, false) end
        return
    end

    local members = get_members()
    ui.members = members

    if settings.minimal then selected = nil end
    local sel_name
    if selected then
        for _, m in ipairs(members) do
            if m.name:lower() == selected then sel_name = m.name end
        end
        if not sel_name then selected = nil end
    end

    set_text(ui.title, pad('Entruster' .. (running and '  [RUNNING]' or '')))
    for i, el in ipairs(ui.rows) do
        local m = members[i]
        if m then
            local key = m.name:lower()
            local sp = settings.assign[key] and by_name[settings.assign[key]:lower()]
            set_text(el, pad(string.format('%-15s %s', m.name, sp and sp.short or '-')))
            el.enabled = true
            el.t:bg_color(unpack(selected == key and COL.sel or COL.base))
        else
            set_text(el, pad('(empty)'))
            el.enabled = false
            el.t:bg_color(unpack(COL.base))
        end
    end
    set_text(ui.status, pad(status_text:sub(1, W)))

    ui.active = settings.minimal and ui.mini or ui.column
    for _, el in ipairs(ui.column) do set_shown(el, false) end
    for _, el in ipairs(ui.active) do set_shown(el, true) end
    set_text(ui.view, pad(settings.minimal and '[ Full window ]' or '[ Minimal view ]'))

    local pick_on = selected ~= nil
    if pick_on then
        set_text(ui.pick_head, ' Indi spell for ' .. sel_name .. ' ')
        local cur = settings.assign[selected]
        for _, el in ipairs(ui.picks) do
            set_text(el, string.format(' %-12s', el.data.short))
            local is_cur = cur and cur:lower() == el.data.name:lower()
            el.t:bg_color(unpack(is_cur and COL.cur or COL.base))
        end
    end
    set_shown(ui.pick_head, pick_on)
    for _, el in ipairs(ui.picks) do set_shown(el, pick_on) end
    set_shown(ui.pick_none, pick_on)

    layout()
end

local function hit_test(x, y)
    for _, el in ipairs(ui.els) do
        if el.shown and el.enabled ~= false and el.kind ~= 'status' and el.kind ~= 'pick_head' and el.t:hover(x, y) then
            return el
        end
    end
end

local function save()
    settings:save()
end

local function handle_click(el, x, y)
    local k = el.kind
    if k == 'title' then
        drag = {dx = x - settings.pos.x, dy = y - settings.pos.y}
    elseif k == 'member' then
        local m = ui.members and ui.members[el.data]
        if m then
            local key = m.name:lower()
            selected = (selected ~= key) and key or nil
        end
    elseif k == 'pick' and selected then
        settings.assign[selected] = el.data.name
        save()
        selected = nil
    elseif k == 'pick_none' and selected then
        settings.assign[selected] = nil
        save()
        selected = nil
    elseif k == 'run' then
        coroutine.schedule(run, 0)
    elseif k == 'stop' then
        stop_run('Stopped by user')
    elseif k == 'clear' then
        settings.assign = {}
        save()
        selected = nil
    elseif k == 'view' then
        settings.minimal = not settings.minimal
        selected = nil
        save()
    end
    refresh_ui()
end

windower.register_event('mouse', function(mtype, x, y, delta, blocked)
    if blocked or not ui_visible or not ui.title then return end

    if drag then
        if mtype == 0 then
            settings.pos.x = x - drag.dx
            settings.pos.y = y - drag.dy
            layout()
            return true
        elseif mtype == 2 then
            drag = nil
            save()
            return true
        end
    end

    if mtype == 1 then
        local el = hit_test(x, y)
        if el then
            swallow_release = true
            handle_click(el, x, y)
            return true
        end
    elseif mtype == 2 and swallow_release then
        swallow_release = false
        return true
    end
end)

windower.register_event('prerender', function()
    local now = os.clock()
    if now - last_refresh >= 1 then
        last_refresh = now
        refresh_ui()
    end
end)

----------------------------------------------------------------------
-- Events and commands
----------------------------------------------------------------------
windower.register_event('zone change', function()
    stop_run('Zone changed')
end)

windower.register_event('status change', function(new, old)
    if new == 2 or new == 3 then stop_run('Player died') end
end)

windower.register_event('logout', function()
    stop_run('Logged out')
end)

windower.register_event('unload', function()
    running = false
    for _, el in ipairs(ui.els) do el.t:destroy() end
end)

local function help()
    log('//ent                  toggle the window')
    log('//ent mini              toggle minimal view / full window')
    log('//ent hide | show       hide or show the window')
    log('//ent run | stop       apply assignments / abort')
    log('//ent set <name> <spell>   e.g. //ent set Bob fury')
    log('//ent clear [name]     clear one or all assignments')
    log('//ent temp <JOBS...>   preferred swap sub jobs, e.g. //ent temp RDM WHM')
    log('//ent range <yalms>    max distance to targets (default 20)')
    log('//ent testreset        test the sub job swap only')
    log('//ent pos <x> <y>      move the window')
end

windower.register_event('addon command', function(cmd, ...)
    local a = {...}
    cmd = cmd and cmd:lower() or 'toggle'

    if cmd == 'toggle' then
        ui_visible = not ui_visible
    elseif cmd == 'mini' then
        settings.minimal = not settings.minimal
        save()
    elseif cmd == 'show' then
        ui_visible = true
    elseif cmd == 'hide' then
        ui_visible = false
    elseif cmd == 'run' then
        coroutine.schedule(run, 0)
    elseif cmd == 'stop' then
        stop_run('Stopped by user')
    elseif cmd == 'set' and a[1] and a[2] then
        local sp = find_spell(a[2])
        if sp then
            settings.assign[a[1]:lower()] = sp.name
            save()
            log(a[1] .. ' -> ' .. sp.name)
        else
            log('Unknown Indi spell: ' .. a[2])
        end
    elseif cmd == 'clear' then
        if a[1] then settings.assign[a[1]:lower()] = nil else settings.assign = {} end
        save()
    elseif cmd == 'temp' and a[1] then
        settings.temp_jobs = table.concat(a, ',')
        save()
        log('Temp sub jobs: ' .. settings.temp_jobs)
    elseif cmd == 'range' and tonumber(a[1]) then
        settings.cast_range = tonumber(a[1])
        save()
    elseif cmd == 'pos' and tonumber(a[1]) and tonumber(a[2]) then
        settings.pos.x, settings.pos.y = tonumber(a[1]), tonumber(a[2])
        save()
    elseif cmd == 'testreset' then
        coroutine.schedule(function()
            if running then return end
            local pl = windower.ffxi.get_player()
            if not pl or not pl.sub_job then log('Set a sub job first.') return end
            orig_main, orig_main_id = nil, nil
            orig_sub, orig_sub_id = pl.sub_job, pl.sub_job_id
            running = true
            local ok = reset_entrust()
            restore_jobs()
            running = false
            orig_sub, orig_sub_id = nil, nil
            set_status(ok and 'Reset OK' or 'Reset failed')
        end, 0)
    else
        help()
        return
    end
    refresh_ui()
end)

build_ui()
refresh_ui()

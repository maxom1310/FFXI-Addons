--[[
    LimbusBar - on-screen progress bar for Temenos and Apollyon floors (Windower 4)

    Reads the floor bar from the 0x075 packet, shows kill gain / kills to full, marks a floor as
    completed once its temp item is in your bag, and can run a command when the bar passes a percentage.
    See README.md for commands and details.
--]]

_addon.name = 'LimbusBar'
_addon.author = 'maxom'
_addon.version = '1.0'
_addon.commands = {'limbusbar', 'lb'}

require('logger')
require('tables')
require('sets')
require('strings')
local config = require('config')
local texts = require('texts')
local res = require('resources')

local defaults = {}
defaults.display = {}
defaults.display.pos = {x = 300, y = 300}
defaults.display.bg = {red = 0, green = 0, blue = 0, alpha = 255}
defaults.display.text = {font = 'Courier New', red = 255, green = 255, blue = 255, alpha = 255, size = 10,
    stroke = {width = 2, alpha = 255, red = 0, green = 0, blue = 0}}
defaults.style = 2
defaults.width = 30

local settings = config.load(defaults)
if settings.style ~= defaults.style then
    -- one-time refresh of the look: an old saved settings file would otherwise keep the see-through background
    settings.display.bg.alpha = 255
    settings.display.text.stroke.width = 2
    settings.display.text.stroke.alpha = 255
    settings.display.text.stroke.red, settings.display.text.stroke.green, settings.display.text.stroke.blue = 0, 0, 0
    settings.style = defaults.style
end
settings:save()

local box = texts.new(settings.display, settings)

local LIMBUS_ZONES = S{37, 38}    -- 37 = Temenos, 38 = Apollyon
local BAR_MAX = 100

-- State
local value = nil                 -- current bar value (0-100), nil until a 0x075 packet is seen
local label = nil                 -- floor name from the packet, e.g. 'North_Tower_F1'
local hidden = false              -- //lb hide
local show_kills = true           -- //lb kills on|off: show last kill gain + kills to full
local prev_value = nil            -- previous bar reading, to measure what a kill granted
local last_gain = nil             -- bar points granted by the last kill (nil until one is seen)
local testing = false             -- //lb test (lets the bar show outside Limbus)
local test_done = false           -- //lb test <n> done (previews the Floor completed look)
local auto = {cmd = nil, armed = true, pct = 50, need_temp = true}
local warned_name = nil
-- //lb complete <command>: run a command when this floor's temp item is gained (the bar filled)
local complete = {cmd = nil, held = nil, pending = false}   -- held = whether the item was held at the last check (nil = not yet known)
local INVENTORY_PACKETS = S{0x01E, 0x01F, 0x020}            -- incoming item add/update packets

-- Temp item ids per floor (from superwarp's limbus.lua)
local temp_items = {
    [37] = { -- Temenos
        N1 = 9956, N2 = 9957, N3 = 9958, N4 = 9959,
        W1 = 9963, W2 = 9964, W3 = 9965, W4 = 9966,
        E1 = 9970, E2 = 9971, E3 = 9972, E4 = 9973,
        C1 = 9977, C2 = 9978, C3 = 9979,
    },
    [38] = { -- Apollyon
        NW1 = 9981, NW2 = 9982, NW3 = 9983, NW4 = 9984, NW5 = 9985,
        SW1 = 9986, SW2 = 9987, SW3 = 9988, SW4 = 9989,
        NE1 = 9990, NE2 = 9991, NE3 = 9992, NE4 = 9993, NE5 = 9994,
        SE1 = 9995, SE2 = 9996, SE3 = 9997, SE4 = 9998,
    },
}

local function current_zone()
    local info = windower.ffxi.get_info()
    return info and info.zone
end

local function in_limbus()
    return LIMBUS_ZONES:contains(current_zone() or 0)
end

local function read_value(data, offset, size)
    local v = 0
    for i = 0, size - 1 do
        v = v + data:byte(offset + i + 1) * (256 ^ i)
    end
    return v
end

local function color_for(pct)
    if pct >= 0.66 then return '\\cs(0,255,0)' end
    if pct >= 0.33 then return '\\cs(255,255,0)' end
    return '\\cs(255,0,0)'
end

-- In-game item name of a floor's temp item, e.g. 'C1' -> 'Tem. C-F1', 'NW1' -> 'Apollyon NW #1'
local function temp_item_name(zone, key)
    if zone == 37 then return string.format('Tem. %s-F%s', key:sub(1, 1), key:sub(2)) end
    if zone == 38 then return string.format('Apollyon %s #%s', key:sub(1, 2), key:sub(3)) end
end

-- Held if the bag has the item by id OR by its name in the game's resources, so one wrong id can't hide it
local function has_temp_item(zone, key)
    local item_id = temp_items[zone] and temp_items[zone][key]
    local name = temp_item_name(zone, key)
    local bag = windower.ffxi.get_items(3)
    if not bag or not name then return false end
    for _, item in ipairs(bag) do
        if type(item) == 'table' and item.id and item.id ~= 0 then
            if item.id == item_id then return true end
            local r = res.items[item.id]
            if r and (r.name == name or r.en == name) then return true end
        end
    end
    return false
end

-- Turn the 0x075 floor string ('North_Tower_F1', 'NW_Floor_#1') into a floor key ('N1', 'NW1')
local function floor_key(zone, name)
    local n = name:lower()
    local num = n:match('_f(%d+)') or n:match('(%d+)$')
    if not num then return nil end
    if zone == 37 then
        -- names start with the tower: North_Tower_F1, Center_Tower_F2 (note: 'Center', not 'Central')
        local letter = ({n = 'N', w = 'W', e = 'E', c = 'C'})[n:sub(1, 1)]
        if letter then return letter .. num end
    elseif zone == 38 then
        for _, p in ipairs({{'northwest', 'NW'}, {'southwest', 'SW'}, {'northeast', 'NE'}, {'southeast', 'SE'}}) do
            if n:find(p[1], 1, true) or n:find('^' .. p[2]:lower() .. '[_%d]') then return p[2] .. num end
        end
    end
    return nil
end

-- true when the temp item for the floor you're on is already in your temp bag (i.e. the bar was filled)
local function temp_item_held()
    local zone = current_zone()
    local ids = temp_items[zone]
    if not ids or not label then return false end
    local key = floor_key(zone, label)
    return key ~= nil and ids[key] ~= nil and has_temp_item(zone, key), key
end

-- Fires when the temp item for the current floor goes from not held to held. The first check on a floor
-- only records the starting state, so an item you already had never triggers it.
local function check_complete()
    if not complete.cmd or not label then return end
    local held, key = temp_item_held()
    if complete.held == nil then
        complete.held = held
        if not key and warned_name ~= label then
            warned_name = label
            warning('complete: unrecognized floor name "' .. label .. '" - please report this floor name so it can be added')
        end
        return
    end
    if held and not complete.held then
        notice(string.format('complete: %s temp item gained, running: %s', key or label, complete.cmd))
        windower.send_command(complete.cmd)
    end
    complete.held = held
end

local function update_bar()
    if value == nil or hidden or not (testing or in_limbus()) then
        box:hide()
        return
    end
    local w = settings.width
    local pct = math.max(0, math.min(1, value / BAR_MAX))
    local filled = math.floor(pct * w + 0.5)
    local held = testing and test_done or ((not testing) and temp_item_held())
    local fill_color = held and '\\cs(0,255,255)' or color_for(pct)    -- cyan once this floor's temp item is held
    local text_color = held and '\\cs(0,255,255)' or '\\cs(255,255,255)'     -- all text goes cyan when the floor is done
    local bar = fill_color .. string.rep('|', filled) ..
                '\\cs(90,90,90)' .. string.rep('|', w - filled) .. text_color
    box:clear()
    local kills_line = ''
    if show_kills then
        if value >= BAR_MAX then
            kills_line = '\n full!'
        elseif last_gain then
            kills_line = string.format('\n last kill: +%d | ~%d kills to full | ~%d per bar',
                last_gain, math.ceil((BAR_MAX - value) / last_gain), math.ceil(BAR_MAX / last_gain))
        else
            kills_line = '\n last kill: -- (kill one to measure)'
        end
    end
    box:append(text_color .. string.format(' %s: %d / %d (%d%%)%s\n [%s] %s',
        label or 'Limbus', value, BAR_MAX, math.floor(pct * 100), held and ' - Floor completed *' or '', bar, kills_line))
    box:show()
end

local function fire_auto(why)
    auto.armed = false      -- fire once per crossing
    notice(string.format('auto: bar %d%%%s, running: %s', math.floor(value / BAR_MAX * 100), why, auto.cmd))
    windower.send_command(auto.cmd)
end

local function check_auto()
    if not auto.cmd or value == nil or not label then return end
    local over = (value / BAR_MAX) * 100 > auto.pct
    if not over then
        auto.armed = true   -- bar emptied / below threshold: ready again
        return
    end
    if not auto.armed then return end

    if not auto.need_temp then
        fire_auto(' (temp check off)')
        return
    end

    local zone = current_zone()
    local ids = temp_items[zone]
    if not ids then return end
    local key = floor_key(zone, label)
    if not key then
        if warned_name ~= label then
            warned_name = label
            warning('auto: unrecognized floor name "' .. label .. '" in zone ' .. tostring(zone) .. ' - please report this floor name so it can be added')
        end
        return
    end
    if ids[key] and has_temp_item(zone, key) then      -- floors without a temp item never fire
        fire_auto(string.format(' and %s temp item held', key))
    end
end

windower.register_event('incoming chunk', function(id, data)
    -- 0x075 "Unity Start": Bar Progress 2 is a 4-byte value at offset 60, name string at offset 64
    if id == 0x075 and #data >= 104 and data:byte(37) == 2 and in_limbus() then
        local v = read_value(data, 60, 4)
        if v <= 1000 then
            local new_label = data:sub(65, 80):match('^[^%z]*') or 'Floor'
            if new_label ~= label then
                -- new floor: kill values differ per floor, so measure again
                prev_value, last_gain = nil, nil
                complete.held = nil             -- re-baseline the temp item check on the new floor
            end
            if prev_value and v > prev_value then
                last_gain = v - prev_value      -- a drop means the bar filled/reset, so keep the last gain
            end
            prev_value = v
            value = v
            label = new_label
            update_bar()
            check_auto()
            if complete.held == nil then check_complete() end    -- record the starting state for this floor
        end
    end
    -- Item packets arriving = your inventory may have changed. Look once, shortly after, so the client has
    -- applied the change (the bag is read from the game's local memory; nothing is sent to the server).
    if complete.cmd and not complete.pending and INVENTORY_PACKETS:contains(id) then
        complete.pending = true
        coroutine.schedule(function()
            coroutine.sleep(0.5)
            complete.pending = false
            if complete.cmd and in_limbus() then check_complete() end
        end, 0)
    end
end)

windower.register_event('addon command', function(cmd, ...)
    cmd = cmd and cmd:lower() or 'help'
    local args = {...}

    if cmd == 'auto' then
        -- //lb auto [pct] [command...]   |   //lb auto off
        local rest = 1
        if tonumber(args[1]) then
            auto.pct = tonumber(args[1])
            rest = 2
        end
        if args[1] == 'off' then
            auto.cmd = nil
            notice('Auto trigger off.')
        elseif args[rest] then
            auto.cmd = table.concat(args, ' ', rest)
            auto.armed = true
            notice(string.format('Auto trigger on: when bar > %d%%%s, run: %s',
                auto.pct, auto.need_temp and " and this floor's temp item is held" or ' (temp item check OFF)', auto.cmd))
        elseif rest == 2 then
            auto.armed = true
            notice('Auto threshold now > ' .. auto.pct .. '%')
        else
            notice('Auto: ' .. (auto.cmd and ('on, runs: ' .. auto.cmd) or 'off') ..
                ' | threshold > ' .. auto.pct .. '% | temp item check ' .. (auto.need_temp and 'ON' or 'OFF'))
        end
    elseif cmd == 'complete' then
        -- //lb complete <command...>   |   //lb complete off
        if args[1] == 'off' then
            complete.cmd = nil
            notice('Floor complete trigger off.')
        elseif args[1] then
            complete.cmd = table.concat(args, ' ')
            complete.held = nil
            check_complete()        -- record whether the item is already held, so that never fires it
            notice('Floor complete trigger on: when the bar fills and this floor\'s temp item is gained, run: ' .. complete.cmd)
        else
            notice('Floor complete: ' .. (complete.cmd and ('on, runs: ' .. complete.cmd) or 'off'))
        end
    elseif cmd == 'floor' then
        -- diagnostic: what floor does the addon think you're on?
        local zone = current_zone()
        if not label then
            notice('floor: no bar data yet (zone ' .. tostring(zone) .. '). The bar reads in Temenos/Apollyon only.')
        else
            local key = floor_key(zone, label)
            local item_id = key and temp_items[zone] and temp_items[zone][key]
            notice(string.format('floor: name "%s" | key %s | temp item %s | held: %s',
                label, key or 'NOT RECOGNIZED',
                item_id and string.format('%s (id %d)', temp_item_name(zone, key), item_id) or 'none for this floor',
                (item_id and has_temp_item(zone, key)) and 'yes' or 'no'))
        end
    elseif cmd == 'autotemp' and (args[1] == 'on' or args[1] == 'off') then
        -- off = ignore temp item (testing); on = require it (default)
        auto.need_temp = (args[1] == 'on')
        auto.armed = true
        notice('Auto temp item check ' .. (auto.need_temp and "ON (default): needs this floor's temp item" or 'OFF: fires on bar % only'))
    elseif cmd == 'kills' and (args[1] == 'on' or args[1] == 'off') then
        show_kills = (args[1] == 'on')
        update_bar()
        notice('Kill tracker ' .. (show_kills and 'ON' or 'OFF'))
    elseif cmd == 'hide' then
        hidden = true
        update_bar()
        notice('Bar hidden. //lb show to bring it back.')
    elseif cmd == 'show' then
        hidden = false
        update_bar()
    elseif cmd == 'width' and tonumber(args[1]) then
        settings.width = tonumber(args[1])
        settings:save()
        update_bar()
    elseif cmd == 'test' and tonumber(args[1]) then
        -- preview the bar anywhere; cleared when you zone
        testing = true
        test_done = (args[2] == 'done')
        local v = tonumber(args[1])
        if prev_value and v > prev_value then last_gain = v - prev_value end   -- repeat test to preview the kill line
        prev_value = v
        value = v
        label = label or 'Test'
        update_bar()
    else
        notice('LimbusBar commands (the bar shows by default in Temenos/Apollyon):')
        notice('  //lb hide | show         hide or show the bar')
        notice('  //lb kills on|off        show last kill gain and kills left to fill (default on)')
        notice('  //lb width <n>           bar length (default 30)')
        notice('  //lb test <n>            preview the bar at value n, even outside Limbus (run twice, e.g. 21 then 42, to see the kill line)')
        notice('  //lb test <n> done       preview the Floor completed look (cyan + *)')
        notice('  //lb auto <command>      run <command> once when bar > 50% AND this floor\'s temp item is held')
        notice('  //lb auto <n> <command>  same, but at n% (e.g. //lb auto 70 input /ma "Cure" <me>)')
        notice('  //lb auto <n>            change the % only, keeping the current command')
        notice('  //lb auto                show status;  //lb auto off  turn it off')
        notice('  //lb complete <command>  run <command> once when this floor\'s temp item is gained (bar filled)')
        notice('  //lb complete            show status;  //lb complete off  turn it off')
        notice('  //lb floor               show the floor name the addon read, which floor it maps to, and the temp item check')
        notice('  //lb autotemp off|on     off = ignore temp item, fire on bar % alone (testing); on = require it (default)')
    end
end)

local function reset_state()
    value, label, warned_name = nil, nil, nil
    prev_value, last_gain = nil, nil
    testing, test_done = false, false
    auto.armed = true
    complete.held = nil
    update_bar()
end

windower.register_event('zone change', reset_state)

windower.register_event('logout', function()
    reset_state()
    box:hide()
end)

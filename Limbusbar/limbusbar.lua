--[[
    LimbusBar - on-screen progress bar for Temenos and Apollyon floors (Windower 4)

    Reads the floor bar from the 0x075 packet, shows kill gain / kills to full, marks a floor as
    completed once its temp item is in your bag, and can run a command when the bar passes a percentage.
    See README.md for commands and details.
--]]

_addon.name = 'LimbusBar'
_addon.author = 'maxom'
_addon.version = '1.1'
_addon.commands = {'limbusbar', 'lb'}

require('logger')
require('tables')
require('sets')
require('strings')
local config = require('config')
local texts = require('texts')
local images = require('images')
local res = require('resources')

local defaults = {}
defaults.display = {}
defaults.display.pos = {x = 300, y = 300}
defaults.display.bg = {red = 0, green = 0, blue = 0, alpha = 0}
defaults.display.text = {font = 'Segoe UI', red = 245, green = 248, blue = 252, alpha = 255, size = 11,
    stroke = {width = 1, alpha = 160, red = 0, green = 0, blue = 0}}
defaults.style = 4
defaults.width = 30
defaults.auto_sound = false
defaults.complete_sound = false
defaults.auto_command = ''
defaults.auto_pct = 50
defaults.auto_need_temp = true
defaults.complete_command = ''
defaults.box_alpha = 215                                    -- 0 (invisible) .. 255 (solid) card opacity
defaults.bar_bg = {red = 45, green = 52, blue = 68}         -- dark slate track (multiplies bg_body.png)

local settings = config.load(defaults)
if settings.style ~= defaults.style then
    settings.display.bg.alpha = 0
    settings.display.bg.visible = false
    settings.display.text.font = defaults.display.text.font
    settings.display.text.size = defaults.display.text.size
    settings.display.text.red = defaults.display.text.red
    settings.display.text.green = defaults.display.text.green
    settings.display.text.blue = defaults.display.text.blue
    settings.display.text.stroke.width = defaults.display.text.stroke.width
    settings.display.text.stroke.alpha = defaults.display.text.stroke.alpha
    settings.display.text.stroke.red = 0
    settings.display.text.stroke.green = 0
    settings.display.text.stroke.blue = 0
    settings.box_alpha = defaults.box_alpha
    settings.bar_bg = table.copy(defaults.bar_bg)
    settings.style = defaults.style
end
settings:save()

-- 1. Card background & 1px border (created FIRST so they render behind the bar and text)
local function new_solid(r, g, b, a)
    return images.new({
        pos = {x = 0, y = 0}, visible = false,
        color = {alpha = a, red = r, green = g, blue = b},
        size = {width = 1, height = 1}, draggable = false
    })
end

local card_border = new_solid(75, 85, 102, 235)
local card_bg     = new_solid(18, 22, 30, settings.box_alpha)

-- 2. Progress bar images (created AFTER card_bg so they render on top of the card)
local graphic_height = 12           -- sleek bar thickness in pixels
local bar_offset = 28               -- vertical offset from top of card
local bar_pad_x = 12                -- horizontal padding inside the card
local bar_pad_y = 9                 -- vertical padding inside the card
local kills_drop = 6                -- gap between bar and bottom stats line
local graphic_w = settings.width * 11

local function new_img(file, w, color)
    return images.new({
        pos = {x = settings.display.pos.x, y = settings.display.pos.y + bar_offset}, visible = false,
        color = color, size = {width = w, height = graphic_height},
        texture = {path = windower.windower_path .. 'addons/limbusbar/' .. file, fit = true},
        repeatable = {x = 1, y = 1}, draggable = false
    })
end

local graphic_cap_l = new_img('bg_cap.png', 1, {alpha = 255, red = 70, green = 78, blue = 95})
local graphic_bg    = new_img('bg_body.png', graphic_w, {alpha = 255, red = settings.bar_bg.red, green = settings.bar_bg.green, blue = settings.bar_bg.blue})
local graphic_fg    = new_img('fg_body.png', 0, {alpha = 255, red = 65, green = 205, blue = 125})
local graphic_cap_r = new_img('bg_cap.png', 1, {alpha = 255, red = 70, green = 78, blue = 95})

-- 25%, 50%, 75% tick dividers drawn over the bar
local ticks = {new_solid(12, 15, 22, 140), new_solid(12, 15, 22, 140), new_solid(12, 15, 22, 140)}

-- 3. Text boxes (Windower always renders texts on top of images)
local box = texts.new(settings.display, settings) -- Top header line (draggable anchor)
box:bg_alpha(0)
box:bg_visible(false)

local box2_display = table.copy(settings.display)
box2_display.text.size = math.max(8, settings.display.text.size - 1)
local box2 = texts.new(box2_display) -- Bottom kill stats line
box2:bg_alpha(0)
box2:bg_visible(false)
box2:draggable(false)

local kills_on = false
local graphic_on = false

local function hide_graphic()
    graphic_on = false
    kills_on = false
    box:hide()
    box2:hide()
    card_border:hide()
    card_bg:hide()
    graphic_cap_l:hide()
    graphic_bg:hide()
    graphic_fg:hide()
    graphic_cap_r:hide()
    graphic_fg:size(0, graphic_height)
    for _, t in ipairs(ticks) do t:hide() end
end

-- Keep all card elements locked to the draggable `box` position
local function place_graphic()
    if not graphic_on then return end
    local bx, by = box:pos_x(), box:pos_y()
    local ew, eh = box:extents()
    if not (bx and by and ew and eh) then return end

    local gw, gh = graphic_w, graphic_height
    local inner_w = gw + 2
    local card_w = inner_w + (bar_pad_x * 2)

    -- Position bar inside the card
    local gx = bx + bar_pad_x
    local gy = by + bar_offset
    graphic_cap_l:pos(gx, gy)
    graphic_bg:pos(gx + 1, gy)
    graphic_fg:pos(gx + 1, gy)
    graphic_cap_r:pos(gx + 1 + gw, gy)

    -- Position 25%, 50%, 75% tick marks
    for i, t in ipairs(ticks) do
        local tx = gx + 1 + math.floor(gw * (i * 0.25))
        t:pos(tx, gy)
        t:size(1, gh)
    end

    -- Position bottom kill stats line and calculate total card height
    local total_h = bar_offset + gh + bar_pad_y
    if kills_on then
        box2:pos(gx, gy + gh + kills_drop)
        local e2w, e2h = box2:extents()
        if e2w and e2h then
            total_h = bar_offset + gh + kills_drop + e2h + bar_pad_y
        end
    end

    -- Size and position the card backdrop and 1px border
    local card_x = bx
    local card_y = by - bar_pad_y + 2
    card_bg:pos(card_x, card_y)
    card_bg:size(card_w, total_h)
    card_border:pos(card_x - 1, card_y - 1)
    card_border:size(card_w + 2, total_h + 2)
end
windower.register_event('prerender', place_graphic)

math.randomseed(os.time())
local LIMBUS_ZONES = S{37, 38}    -- 37 = Temenos, 38 = Apollyon
local BAR_MAX = 100

-- State
local value = nil                 -- current bar value (0-100), nil until a 0x075 packet is seen
local label = nil                 -- floor name from the packet, e.g. 'North_Tower_F1'
local hidden = false              -- //lb hide
local show_kills = true           -- //lb kills on|off: show last kill gain + kills to full
local prev_value = nil            -- previous bar reading, to measure what a kill granted
local last_gain = nil             -- bar points granted by the last kill (nil until one is seen)
local tower_stats = {}            -- points-per-kill cache, keyed by Temenos/Apollyon zone
local testing = false             -- //lb test (lets the bar show outside Limbus)
local test_done = false           -- //lb test <n> done (previews the Floor completed look)
local auto = {cmd = settings.auto_command ~= '' and settings.auto_command or nil, armed = true,
    pct = settings.auto_pct, need_temp = settings.auto_need_temp, sound = settings.auto_sound}
local warned_name = nil
-- //lb complete <command>: run a command when this floor's temp item is gained (the bar filled)
local complete = {cmd = settings.complete_command ~= '' and settings.complete_command or nil, held = nil,
    pending = false, sound = settings.complete_sound}   -- held = whether the item was held at the last check (nil = not yet known)
local INVENTORY_PACKETS = S{0x01E, 0x01F, 0x020}            -- incoming item add/update packets
local CHIME = windower.windower_path .. 'addons/limbusbar/sounds/cursor.wav'

local function chime(enabled)
    if enabled and windower.file_exists(CHIME) then
        windower.play_sound(CHIME)
    end
end

local function save_runtime_settings()
    settings.auto_command = auto.cmd or ''
    settings.auto_pct = auto.pct
    settings.auto_need_temp = auto.need_temp
    settings.auto_sound = auto.sound
    settings.complete_command = complete.cmd or ''
    settings.complete_sound = complete.sound
    settings:save()
end

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
        chime(complete.sound)
        windower.send_command(complete.cmd)
    end
    complete.held = held
end

local function update_bar()
    if value == nil or hidden or not (testing or in_limbus()) then
        hide_graphic()
        return
    end

    local pct = math.max(0, math.min(1, value / BAR_MAX))
    local held = testing and test_done or ((not testing) and temp_item_held())

    local done_color = '\\cs(85,205,250)'

    -- Top header line (percentage stays inline in top middle, all text turns blue when floor is completed)
    box:clear()
    if held then
        box:append(string.format('  %s%s: %d / %d (%d%%) - Floor completed *',
            done_color, label or 'Limbus', value, BAR_MAX, math.floor(pct * 100)))
    else
        box:append(string.format('  \\cs(245,248,252)%s: \\cs(255,255,255)%d / %d (%d%%)',
            label or 'Limbus', value, BAR_MAX, math.floor(pct * 100)))
    end
    box:show()
    box:bg_alpha(0)
    box:bg_visible(false)

    -- Bottom kill tracker (all blue when floor is completed; otherwise dim labels + bright values)
    local kills_text = ''
    if show_kills then
        if value >= BAR_MAX then
            kills_text = done_color .. 'Bar full!'
        elseif last_gain then
            if held then
                kills_text = string.format('%sLast kill: +%d%%  •  ~%d kills to full  •  ~%d per bar',
                    done_color, last_gain, math.ceil((BAR_MAX - value) / last_gain), math.ceil(BAR_MAX / last_gain))
            else
                kills_text = string.format(
                    '\\cs(160,170,185)Last kill: \\cs(245,248,252)+%d%%  \\cs(110,120,135)•  \\cs(245,248,252)~%d \\cs(160,170,185)kills to full  \\cs(110,120,135)•  \\cs(245,248,252)~%d \\cs(160,170,185)per bar',
                    last_gain, math.ceil((BAR_MAX - value) / last_gain), math.ceil(BAR_MAX / last_gain)
                )
            end
        else
            if held then
                kills_text = done_color .. 'Last kill: -- (kill one to measure)'
            else
                kills_text = '\\cs(160,170,185)Last kill: \\cs(245,248,252)-- \\cs(160,170,185)(kill one to measure)'
            end
        end
    end

    box2:clear()
    kills_on = kills_text ~= ''
    if kills_on then
        box2:append(kills_text)
        box2:show()
        box2:bg_alpha(0)
        box2:bg_visible(false)
    else
        box2:hide()
    end

    -- Show and size card + bar graphics
    graphic_w = settings.width * 11
    graphic_on = true
    card_border:show()
    card_border:alpha(math.min(255, settings.box_alpha + 20))
    card_bg:show()
    card_bg:alpha(settings.box_alpha)

    graphic_cap_l:show()
    graphic_bg:show()
    graphic_fg:show()
    graphic_cap_r:show()
    for _, t in ipairs(ticks) do t:show() end

    graphic_cap_l:size(1, graphic_height)
    graphic_bg:size(graphic_w, graphic_height)
    graphic_bg:color(settings.bar_bg.red, settings.bar_bg.green, settings.bar_bg.blue)
    graphic_fg:size(math.floor(graphic_w * pct), graphic_height)
    graphic_cap_r:size(1, graphic_height)

    place_graphic()

    -- Softened, modern color palette (multiplies the gradient in fg_body.png)
    if held then
        graphic_fg:color(75, 195, 245)          -- sky blue: temp item obtained
    elseif pct >= 0.66 then
        graphic_fg:color(65, 205, 125)          -- emerald green
    elseif pct >= 0.33 then
        graphic_fg:color(235, 185, 65)          -- warm gold
    else
        graphic_fg:color(225, 80, 80)           -- soft crimson
    end
end

local function fire_auto(why)
    auto.armed = false      -- fire once per crossing
    notice(string.format('auto: bar %d%%%s, running: %s', math.floor(value / BAR_MAX * 100), why, auto.cmd))
    chime(auto.sound)
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
                -- Keep the measured gain while moving between floors in the same tower.
                prev_value = nil
                last_gain = tower_stats[current_zone()]
                complete.held = nil             -- re-baseline the temp item check on the new floor
            end
            if prev_value and v > prev_value then
                last_gain = v - prev_value      -- a drop means the bar filled/reset, so keep the last gain
                tower_stats[current_zone()] = last_gain
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

    if cmd == 'save' then
        save_runtime_settings()
        notice('LimbusBar settings saved.')
    elseif cmd == 'auto' then
        -- //lb auto [pct] [command...]   |   //lb auto off
        if args[1] == 'sound' and (args[2] == 'on' or args[2] == 'off') then
            auto.sound = args[2] == 'on'
            settings.auto_sound = auto.sound
            settings:save()
            notice('Auto chime ' .. (auto.sound and 'ON' or 'OFF'))
            return
        end
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
                ' | threshold > ' .. auto.pct .. '% | temp item check ' .. (auto.need_temp and 'ON' or 'OFF') ..
                ' | chime ' .. (auto.sound and 'ON' or 'OFF'))
        end
    elseif cmd == 'complete' then
        -- //lb complete <command...>   |   //lb complete off
        if args[1] == 'sound' and (args[2] == 'on' or args[2] == 'off') then
            complete.sound = args[2] == 'on'
            settings.complete_sound = complete.sound
            settings:save()
            notice('Complete chime ' .. (complete.sound and 'ON' or 'OFF'))
            return
        end
        if args[1] == 'off' then
            complete.cmd = nil
            notice('Floor complete trigger off.')
        elseif args[1] then
            complete.cmd = table.concat(args, ' ')
            complete.held = nil
            check_complete()        -- record whether the item is already held, so that never fires it
            notice("Floor complete trigger on: when the bar fills and this floor's temp item is gained, run: " .. complete.cmd)
        else
            notice('Floor complete: ' .. (complete.cmd and ('on, runs: ' .. complete.cmd) or 'off') ..
                ' | chime ' .. (complete.sound and 'ON' or 'OFF'))
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
    elseif cmd == 'baroffset' and tonumber(args[1]) then
        bar_offset = tonumber(args[1])
        update_bar()
        notice('Bar offset set to ' .. bar_offset)
    elseif cmd == 'debug' then
        local function f(v) return tostring(v) end
        local ew, eh = box:extents()
        notice(string.format('box: pos=%s,%s size=%s x %s  bg_visible=%s bg_alpha=%s',
            f(box:pos_x()), f(box:pos_y()), f(ew), f(eh), f(box:bg_visible()), f(box:bg_alpha())))
        notice(string.format('bar: on=%s offset=%s w=%s  bg img visible=%s pos=%s,%s size=%s x %s',
            f(graphic_on), f(bar_offset), f(graphic_w), f(graphic_bg:visible()),
            f(graphic_bg:pos_x()), f(graphic_bg:pos_y()), f(graphic_bg:width()), f(graphic_bg:height())))
        notice(string.format('fg img visible=%s size=%s x %s  card visible=%s size=%s x %s',
            f(graphic_fg:visible()), f(graphic_fg:width()), f(graphic_fg:height()),
            f(card_bg:visible()), f(card_bg:width()), f(card_bg:height())))
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
    elseif cmd == 'font' and args[1] then
        local name = table.concat(args, ' ')
        settings.display.text.font = name
        box:font(name)
        box2:font(name)
        settings:save()
        update_bar()
        notice('Font set to ' .. name .. ' (must be installed on your PC; //lb font Segoe UI to go back)')
    elseif cmd == 'fontsize' and tonumber(args[1]) then
        local n = math.max(6, math.min(40, math.floor(tonumber(args[1]))))
        settings.display.text.size = n
        box:size(n)
        box2:size(math.max(8, n - 1))
        settings:save()
        update_bar()
        notice('Font size set to ' .. n .. ' (adjust the bar with //lb baroffset if needed)')
    elseif cmd == 'reset' then
        -- put the box back at its default spot (use this if it ever ends up off screen)
        settings.display.pos.x, settings.display.pos.y = defaults.display.pos.x, defaults.display.pos.y
        box:pos(defaults.display.pos.x, defaults.display.pos.y)
        settings:save()
        update_bar()
        notice('Position reset to ' .. defaults.display.pos.x .. ',' .. defaults.display.pos.y)
    elseif cmd == 'barheight' and tonumber(args[1]) then
        local n = math.max(6, math.min(40, math.floor(tonumber(args[1]))))
        graphic_height = n
        update_bar()
        notice('Bar thickness set to ' .. n .. ' px')
    elseif cmd == 'killsdrop' and tonumber(args[1]) then
        kills_drop = tonumber(args[1])
        update_bar()
        notice('Kill line pushed down ' .. kills_drop .. ' px')
    elseif cmd == 'boxalpha' and tonumber(args[1]) then
        settings.box_alpha = math.max(0, math.min(255, math.floor(tonumber(args[1]))))
        settings:save()
        update_bar()
        notice('Card transparency set to ' .. settings.box_alpha .. ' (0 = invisible, 255 = solid)')
    elseif cmd == 'barbg' and tonumber(args[1]) and tonumber(args[2]) and tonumber(args[3]) then
        local function c(v) return math.max(0, math.min(255, math.floor(tonumber(v)))) end
        settings.bar_bg.red, settings.bar_bg.green, settings.bar_bg.blue = c(args[1]), c(args[2]), c(args[3])
        settings:save()
        update_bar()
        notice(string.format('Bar background color set to %d,%d,%d', settings.bar_bg.red, settings.bar_bg.green, settings.bar_bg.blue))
    elseif cmd == 'test' and (tonumber(args[1]) or args[1] == 'random') then
        -- preview the bar anywhere; cleared when you zone
        testing = true
        local v
        if args[1] == 'random' then
            v = math.random(0, 100)
            test_done = math.random() < 0.25                  -- sometimes preview the Floor completed look
        else
            v = math.max(0, math.min(BAR_MAX, tonumber(args[1])))
            test_done = (args[2] == 'done')
        end
        last_gain = math.random(2, 20)                        -- random kill gain so the Last kill line varies every run
        prev_value = v
        value = v
        label = label or 'Test'
        update_bar()
    else
        notice('LimbusBar commands (the bar shows by default in Temenos/Apollyon):')
        notice('  //lb hide | show         hide or show the bar')
        notice('  //lb kills on|off        show last kill gain and kills left to fill (default on)')
        notice('  //lb width <n>           bar length (default 30)')
        notice('  //lb baroffset <n>       move the bar up/down inside the card (default 28)')
        notice('  //lb font <name>         text font, e.g. Segoe UI, Consolas, Arial (default Segoe UI)')
        notice('  //lb fontsize <n>        text size (default 11)')
        notice('  //lb reset               put the box back at its default screen position')
        notice('  //lb barheight <n>       bar thickness in pixels (default 12)')
        notice('  //lb killsdrop <n>       push the Last kill line down n pixels (default 6)')
        notice('  //lb boxalpha <0-255>    card background opacity (0 = invisible, default 215)')
        notice('  //lb barbg <r> <g> <b>   color of the empty part of the bar (default 45 52 68)')
        notice('  //lb debug               print bar/box positions for troubleshooting')
        notice('  //lb test <n>            preview the bar at value n with a random kill gain, even outside Limbus')
        notice('  //lb test random        random value, random kill gain, sometimes Floor completed')
        notice('  //lb test <n> done       preview the Floor completed look (sky blue)')
        notice("  //lb auto <command>      run <command> once when bar > 50% AND this floor's temp item is held")
        notice('  //lb auto <n> <command>  same, but at n% (e.g. //lb auto 70 input /ma "Cure" <me>)')
        notice('  //lb auto <n>            change the % only, keeping the current command')
        notice('  //lb auto                show status;  //lb auto off  turn it off')
        notice('  //lb auto sound on|off  play a chime when the auto trigger fires')
        notice("  //lb complete <command>  run <command> once when this floor's temp item is gained (bar filled)")
        notice('  //lb complete            show status;  //lb complete off  turn it off')
        notice('  //lb complete sound on|off  play a chime when the floor completes')
        notice('  //lb save                save auto/complete commands and options')
        notice('  //lb floor               show the floor name the addon read, which floor it maps to, and the temp item check')
        notice('  //lb autotemp off|on     off = ignore temp item, fire on bar % alone (testing); on = require it (default)')
    end
end)

local function reset_state()
    value, label, warned_name = nil, nil, nil
    prev_value, last_gain = nil, tower_stats[current_zone()]
    testing, test_done = false, false
    auto.armed = true
    complete.held = nil
    update_bar()
end

windower.register_event('zone change', reset_state)

windower.register_event('logout', function()
    reset_state()
    hide_graphic()
end)

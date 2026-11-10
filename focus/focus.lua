_addon.name = 'focus'
_addon.author = 'Max (Claude AI)'
_addon.version = '3.1'
_addon.commands = {'focus', 'foc'}

-- Focus target + "act on focus without changing your target", GearSwap-friendly,
-- with an on-screen HP bar for the focus.
--
-- Setting the focus (same matching logic as enemybar2's //eb ft):
--   //foc <name>     exact name, then name starting with <name>, then name containing <name>
--   //foc <id>       by mob id (number)
--   //foc            use your current target
--   //foc clear      clear the focus
--
-- Acting on the focus: use <ft> as the target in any command or macro line:
--   /ws "Savage Blade" <ft>
--   /ma "Stun" <ft>
--   /ja "Provoke" <ft>
-- or from the console / a macro:
--   //foc ws Savage Blade      (/console foc ws Savage Blade)
--
-- HP bar:
--   //foc bar               toggle the bar on/off
--   //foc bar on|off
--   //foc bar pos <x> <y>   move it (screen pixels)
--   //foc bar width <n>
--   //foc bar height <n>
--   //foc bar color <r> <g> <b>
--   //foc bar font <name>
--   //foc bar fontsize <n>
--   //foc bar unlock        make the bar draggable (shows it even with no focus)
--   //foc bar lock          stop dragging and save the position
-- Settings are saved between sessions. The bar is always locked after a reload.
--
-- How <ft> works: GearSwap understands a numeric mob id as the target of a
-- typed command and runs your precast/midcast/aftercast for it. So <ft> is
-- replaced with the focus's mob id and the command is re-sent. Because the
-- command is re-sent, this works no matter which of focus/gearswap loaded
-- first. GearSwap must be loaded for the id form to work.

require('strings')
require('tables')
local config = require('config')
local images = require('images')
local texts = require('texts')

local focus_id = nil

local defaults = {
    bar = {
        show = true,
        pos = {x = 680, y = 670},
        width = 250,
        height = 14,
        color = {red = 93, green = 0, blue = 255},
        font = 'Arial',
        font_size = 11,
    },
}
local settings = config.load(defaults)

local function say(msg)    windower.add_to_chat(207, 'Focus: ' .. msg) end
local function warn(msg)   windower.add_to_chat(123, 'Focus: ' .. msg) end

---------------------------------------------------------------------------
-- Focus selection
---------------------------------------------------------------------------

-- Mirrors enemybar2's get_mob_by_name: exact > prefix > substring.
local function get_mob_by_name(n)
    n = n:lower()
    local worse, worser = nil, nil
    for _, mob in pairs(windower.ffxi.get_mob_array()) do
        if mob and mob.name and mob.name ~= '' then
            local mobname = mob.name:lower()
            if n == mobname then
                return mob
            elseif not worse and mobname:sub(1, #n) == n then
                worse = mob
            elseif not worser and mobname:find(n, 1, true) then
                worser = mob
            end
        end
    end
    return worse or worser
end

local function get_focus()
    if not focus_id then return nil end
    local mob = windower.ffxi.get_mob_by_id(focus_id)
    if mob and mob.valid_target then return mob end
    return nil
end

local function set_focus(args)
    if args[1] and args[1]:lower() == 'clear' then
        focus_id = nil
        say('focus cleared.')
        return
    end

    local mob
    if #args == 0 then
        mob = windower.ffxi.get_mob_by_target('t')
        if not mob then warn('no target selected.') return end
    elseif #args == 1 and tonumber(args[1]) then
        mob = windower.ffxi.get_mob_by_id(tonumber(args[1]))
        if not mob then warn('no mob with that id.') return end
    else
        mob = get_mob_by_name(table.concat(args, ' '))
        if not mob then warn('no target found with that name.') return end
    end

    focus_id = mob.id
    say('focus is now ' .. mob.name .. ' (id ' .. mob.id .. ').')
end

---------------------------------------------------------------------------
-- HP bar
---------------------------------------------------------------------------

local bg, fg, label

-- The bar always starts locked after a (re)load. Unlock it to drag it.
local unlocked = false
local dragging = nil

local function destroy_bar()
    if bg then bg:destroy() bg = nil end
    if fg then fg:destroy() fg = nil end
    if label then label:destroy() label = nil end
end

local function hide_bar()
    if bg then bg:hide() end
    if fg then fg:hide() end
    if label then label:hide() end
end

local function build_bar()
    destroy_bar()
    local b = settings.bar

    bg = images.new({
        pos = {x = b.pos.x, y = b.pos.y},
        size = {width = b.width, height = b.height},
        color = {alpha = 190, red = 0, green = 0, blue = 0},
        visible = false,
        draggable = false,
    })

    fg = images.new({
        pos = {x = b.pos.x, y = b.pos.y},
        size = {width = b.width, height = b.height},
        color = {alpha = 255, red = b.color.red, green = b.color.green, blue = b.color.blue},
        visible = false,
        draggable = false,
    })

    label = texts.new('', {
        pos = {x = b.pos.x, y = b.pos.y - b.font_size - 8},
        text = {
            font = b.font,
            size = b.font_size,
            stroke = {width = 2, alpha = 255, red = 0, green = 0, blue = 0},
        },
        flags = {bold = true, draggable = false},
        bg = {alpha = 0, visible = false},
    })
end

local function update_bar()
    if not bg then return end

    -- While unlocked the bar is always shown so there is something to grab.
    if not (settings.bar.show or unlocked) then
        hide_bar()
        return
    end

    local info = windower.ffxi.get_info()
    if not info or not info.logged_in then
        hide_bar()
        return
    end

    -- Use the raw lookup (not get_focus) so a dead focus still shows 0%.
    local mob = focus_id and windower.ffxi.get_mob_by_id(focus_id) or nil

    local name, hpp
    if mob then
        name = mob.name
        hpp = math.max(0, math.min(100, mob.hpp or 0))
    elseif unlocked then
        name, hpp = 'Focus target (drag me)', 100
    else
        hide_bar()
        return
    end

    local w = math.floor(settings.bar.width * hpp / 100)

    bg:show()
    if w >= 1 then
        fg:size(w, settings.bar.height)
        fg:show()
    else
        fg:hide()
    end

    label:text(name .. '  ' .. hpp .. '%')
    label:show()
end

local function bar_command(args)
    local sub = args[1] and args[1]:lower()
    local b = settings.bar

    if sub == 'unlock' then
        unlocked = true
        say('HP bar unlocked. Drag it with the left mouse button, then run //foc bar lock.')
        return
    elseif sub == 'lock' then
        unlocked = false
        dragging = nil
        settings:save()
        say('HP bar locked, position saved.')
        return
    end

    if not sub or sub == 'toggle' then
        b.show = not b.show
    elseif sub == 'on' then
        b.show = true
    elseif sub == 'off' then
        b.show = false
    elseif sub == 'pos' then
        local x, y = tonumber(args[2]), tonumber(args[3])
        if not x or not y then warn('usage: //foc bar pos <x> <y>') return end
        b.pos = {x = x, y = y}
    elseif sub == 'width' then
        local n = tonumber(args[2])
        if not n or n < 1 then warn('usage: //foc bar width <number>') return end
        b.width = n
    elseif sub == 'height' then
        local n = tonumber(args[2])
        if not n or n < 1 then warn('usage: //foc bar height <number>') return end
        b.height = n
    elseif sub == 'color' then
        local r, g, bl = tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
        if not r or not g or not bl then warn('usage: //foc bar color <r> <g> <b>  (0-255)') return end
        b.color = {red = r, green = g, blue = bl}
    elseif sub == 'font' then
        if not args[2] then warn('usage: //foc bar font <name>') return end
        table.remove(args, 1)
        b.font = table.concat(args, ' ')
    elseif sub == 'fontsize' then
        local n = tonumber(args[2])
        if not n or n < 1 then warn('usage: //foc bar fontsize <number>') return end
        b.font_size = n
    else
        warn('unknown bar option. Try: on, off, pos, width, height, color, font, fontsize')
        return
    end

    settings:save()
    build_bar()
    say('HP bar is ' .. (b.show and 'on' or 'off') .. '.')
end

---------------------------------------------------------------------------
-- Commands and <ft>
---------------------------------------------------------------------------

windower.register_event('addon command', function(cmd, ...)
    local args = {...}
    local c = cmd and cmd:lower()

    if c == 'bar' then
        bar_command(args)
        return
    end

    if c == 'ws' or c == 'ja' or c == 'ma' then
        if #args == 0 then warn('usage: //foc ' .. c .. ' <name>') return end
        windower.chat.input('/' .. c .. ' "' .. table.concat(args, ' ') .. '" <ft>')
        return
    end

    -- Anything else sets the focus (cmd is the first word of the name/id).
    local all = {}
    if cmd then all[1] = cmd end
    for _, a in ipairs(args) do all[#all + 1] = a end
    set_focus(all)
end)

-- Replace <ft> with the focus's mob id and re-send the command so every
-- addon (GearSwap included) sees the final text. The original is blocked.
-- With no valid focus, the command is blocked rather than falling back to
-- your current target.
windower.register_event('outgoing text', function(original, modified, blocked)
    if blocked or not modified or not modified:lower():find('<ft>', 1, true) then
        return
    end

    local mob = get_focus()
    if not mob then
        warn('<ft> used but no valid focus is set. Command blocked.')
        return true
    end

    local text = modified:gsub('<[fF][tT]>', tostring(mob.id))
    coroutine.schedule(function() windower.chat.input(text) end, 0)
    return true
end)

-- Drag handling (only active while the bar is unlocked).
-- Mouse event types: 0 = move, 1 = left button down, 2 = left button up.
windower.register_event('mouse', function(type, x, y, delta, blocked)
    if blocked or not unlocked or not bg then return false end

    if type == 1 then
        if bg:hover(x, y) then
            dragging = {x = x, y = y, ox = settings.bar.pos.x, oy = settings.bar.pos.y}
            return true
        end
    elseif type == 0 then
        if dragging then
            local nx = dragging.ox + (x - dragging.x)
            local ny = dragging.oy + (y - dragging.y)
            settings.bar.pos = {x = nx, y = ny}
            bg:pos(nx, ny)
            fg:pos(nx, ny)
            label:pos(nx, ny - settings.bar.font_size - 8)
            return true
        end
    elseif type == 2 then
        if dragging then
            dragging = nil
            settings:save()
            return true
        end
    end

    return false
end)

windower.register_event('prerender', update_bar)

windower.register_event('logout', function()
    focus_id = nil
    hide_bar()
end)

windower.register_event('zone change', function() focus_id = nil end)

windower.register_event('unload', destroy_bar)

build_bar()

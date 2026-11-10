--[[
Copyright © 2016, Omnys of Valefor
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
    * Neither the name of Pouches nor the
    names of its contributors may be used to endorse or promote products
    derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL OMNYS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.name = 'Pouches'
_addon.version = '2'
_addon.author = 'Omnys@Valefor'
_addon.command = 'pouches'

-- Libraries (saved in addons/libs)
require('logger')
require('tables')
require('strings')
config = require('config')
texts = require('texts')
res = require('resources')

------------------------------------------------------------
-- Settings
------------------------------------------------------------
defaults = {
    pos = {x = 400, y = 300},
}
settings = config.load(defaults)

------------------------------------------------------------
-- State
------------------------------------------------------------
inverted = {}

state = {
    active = false,
    paused = false,
    run_id = 0,      -- bumped on every start/stop so stale timers die off
    name = '',
    id = 0,
    delay = 0,
    total = 0,
    used = 0,
}

------------------------------------------------------------
-- HUD
------------------------------------------------------------
local function make_box(txt, x, y, r, g, b)
    return texts.new(txt, {
        pos = {x = x, y = y},
        text = {size = 11, font = 'Arial', stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0}},
        bg = {alpha = 220, red = r, green = g, blue = b},
        flags = {draggable = false},
        padding = 4,
    })
end

hud       = make_box('${title}\n${line}\n${left}\n${slots}\n${status}', settings.pos.x, settings.pos.y, 20, 20, 20)
btn_pause = make_box(' Pause ', settings.pos.x, settings.pos.y + 60, 40, 90, 160)
btn_stop  = make_box(' Stop ',  settings.pos.x + 70, settings.pos.y + 60, 160, 40, 40)

local HUD_LINES   = 5    -- title, item, left, slots, status
local LINE_HEIGHT = 18   -- approx px per line at font size 11
local PADDING     = 4
local GAP         = 6

function layout()
    local x, y = settings.pos.x, settings.pos.y
    hud:pos(x, y)

    -- extents() returns 0 until the text has actually rendered, so fall back
    -- to an estimate based on line count.
    local _, h = hud:extents()
    if not h or h < LINE_HEIGHT then
        h = HUD_LINES * LINE_HEIGHT + PADDING * 2
    end

    local by = y + h + GAP
    btn_pause:pos(x, by)

    local w = btn_pause:extents()
    if not w or w < 20 then w = 70 end
    btn_stop:pos(x + w + GAP, by)
end

local function show_hud()
    hud:show(); btn_pause:show(); btn_stop:show()
    layout()
    -- re-layout once the text has rendered and real sizes are known
    layout:schedule(0.2)
end

local function hide_hud()
    hud:hide(); btn_pause:hide(); btn_stop:hide()
end

local function refresh_hud()
    hud.title  = 'Pouches'
    local inv = windower.ffxi.get_items(0)
    local free = inv and (inv.max - inv.count) or 0
    local max = inv and inv.max or 0
    hud.line   = string.format('%s (used %d)', state.name, state.used)
    hud.left   = string.format('Left: %d', count_items())
    hud.slots  = string.format('Free slots: %d / %d', free, max)
    if state.paused then
        hud.status = state.reason and ('PAUSED (' .. state.reason .. ')') or 'PAUSED'
    else
        hud.status = 'Running'
    end
    btn_pause:text(state.paused and ' Resume ' or ' Pause ')
    if state.paused then
        btn_pause:bg_color(40, 140, 70)
    else
        btn_pause:bg_color(40, 90, 160)
    end
    hud:update()
    layout()
end

------------------------------------------------------------
-- Core logic
------------------------------------------------------------
function count_items()
    local inv = windower.ffxi.get_items(0) -- main inventory
    local n = 0
    if inv then
        for _, v in ipairs(inv) do
            if v.id == state.id then
                n = n + v.count
            end
        end
    end
    return n
end

function stop_run(reason)
    if state.active then
        log(reason or 'Stopped.')
    end
    state.active = false
    state.paused = false
    state.run_id = state.run_id + 1
    hide_hud()
end

function tick(id)
    if id ~= state.run_id or not state.active then return end

    -- Auto-pause when the bag is full
    local inv = windower.ffxi.get_items(0)
    if not state.paused and inv and (inv.max - inv.count) <= 0 then
        state.paused = true
        state.reason = 'inventory full'
        log('Inventory full. Paused; free up a slot, then press Resume.')
    end

    refresh_hud() -- keep Left / Free slots current

    if state.paused then
        tick:schedule(0.5, id)
        return
    end

    local player = windower.ffxi.get_player()
    if not player or player.status ~= 0 then
        stop_run('Stopped (no longer idle).')
        return
    end

    local remaining = count_items()
    if remaining <= 0 then
        stop_run('Finished. Used ' .. state.used .. ' ' .. state.name .. '.')
        return
    end

    windower.chat.input('/item "' .. state.name .. '" <me>')
    state.used = state.used + 1
    refresh_hud()
    tick:schedule(state.delay, id)
end

function start_run(name)
    local entry = inverted[name]
    if entry == nil then
        log('Item, "' .. name .. '", does not exist.')
        return
    end

    stop_run() -- cancel any run already in progress
    state.name = name
    state.id = entry.id
    state.delay = (entry.cast or 0) + 2

    if entry.targets.Self ~= true then
        log('Item, ' .. name .. ', is not the type of item that can be used on yourself.')
        return
    end

    local n = count_items()
    if n <= 0 then
        log('Item, ' .. name .. ', not found in main inventory.')
        return
    end

    state.total = n
    state.used = 0
    state.paused = false
    state.reason = nil
    state.active = true
    state.run_id = state.run_id + 1

    log('Found ' .. n .. ' ' .. name .. '. Commencing Use.')
    log('Use the HUD buttons, //pouches pause|resume|stop, or /heal to stop.')
    refresh_hud()
    show_hud()
    tick(state.run_id)
end

function set_paused(p)
    if not state.active then return end
    state.paused = p
    state.reason = nil
    log(p and 'Paused.' or 'Resumed.')
    refresh_hud()
end

------------------------------------------------------------
-- Mouse handling (button clicks)
------------------------------------------------------------
local pressed = nil -- which button the left mouse press started on

windower.register_event('mouse', function(type, x, y, delta, blocked)
    -- Left button released: always swallow it if we swallowed the press,
    -- even if the HUD is already gone, so it never reaches the game.
    if type == 2 then
        if pressed then
            local which = pressed
            pressed = nil
            if state.active then
                if which == 'pause' and btn_pause:hover(x, y) then
                    set_paused(not state.paused)
                elseif which == 'stop' and btn_stop:hover(x, y) then
                    stop_run('Stopped by button.')
                end
            end
            return true
        end
        return
    end

    if blocked or not state.active then return end

    -- Left button pressed: remember the button and swallow the click
    if type == 1 then
        if btn_pause:hover(x, y) then
            pressed = 'pause'
            return true
        elseif btn_stop:hover(x, y) then
            pressed = 'stop'
            return true
        end
    end
end)

------------------------------------------------------------
-- Events
------------------------------------------------------------
windower.register_event('load', function()
    for k, v in pairs(res.items) do
        inverted[string.lower(v.english)] = {id = k, targets = v.targets, cast = v.cast_time}
    end
    hide_hud()
end)

windower.register_event('unload', function()
    state.run_id = state.run_id + 1
    state.active = false
    hud:destroy(); btn_pause:destroy(); btn_stop:destroy()
end)

windower.register_event('logout', function()
    stop_run('Stopped (logout).')
end)

windower.register_event('addon command', function(...)
    local args = {...}
    local cmd = (args[1] or ''):lower()

    if cmd == 'pause' then
        set_paused(true)
    elseif cmd == 'resume' then
        set_paused(false)
    elseif cmd == 'stop' then
        stop_run('Stopped.')
    elseif cmd == 'pos' and tonumber(args[2]) and tonumber(args[3]) then
        settings.pos.x = tonumber(args[2])
        settings.pos.y = tonumber(args[3])
        config.save(settings)
        layout()
    elseif #args == 0 then
        log('Usage: //pouches <item name> | pause | resume | stop | pos <x> <y>')
    else
        local name = windower.convert_auto_trans(table.concat(args, ' ')):lower()
        start_run(name)
    end
end)

-- Copyright © 2017, Cair
-- All rights reserved.

-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:

    -- * Redistributions of source code must retain the above copyright
      -- notice, this list of conditions and the following disclaimer.
    -- * Redistributions in binary form must reproduce the above copyright
      -- notice, this list of conditions and the following disclaimer in the
      -- documentation and/or other materials provided with the distribution.
    -- * Neither the name of ROE nor the
      -- names of its contributors may be used to endorse or promote products
      -- derived from this software without specific prior written permission.

-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL Cair BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


_addon = {}
_addon.name = 'ROE'
_addon.version = '1.3'
_addon.author = "Cair"
_addon.commands = {'roe'}

packets = require('packets')
config = require('config')
require('logger')

-- optional id -> name table used by add/remove/fuzzy; the addon still loads without it
local roe_mapping_ok, roe_mapping = pcall(require, 'data.roe_mapping')
if not roe_mapping_ok or type(roe_mapping) ~= 'table' then
    roe_mapping = {}
end


local defaults = T{
    profiles = T{
        default = S{},
    },
    blacklist = S{},
    clear = true,
    clearprogress = false,
    clearall = false,
    alliance = true, -- `roe party ...` also reaches alliance members
    delay = 0.5,    -- seconds between each accept/cancel packet
    retries = 2,    -- how many times to re-send objectives that did not stick
    stagger = 1.5,  -- seconds between party members when using `roe party ...`
    jitter = 6,     -- max random delay (seconds) per character when using `roe all ...`
    debug = false,
}

settings = config.load(defaults)

-- profiles are stored as comma separated strings in the settings file
local function normalize_profiles()
    for k,v in pairs(settings.profiles) do
        if type(v) == "string" then
            settings.profiles[k] = S(v:split(','):map(tonumber))
        end
    end
end

_roe = T{
    active = T{},
    complete = T{},
    max_count = 30,
}


local function pace()
    coroutine.sleep(settings.delay)
end

local function dbg(fmt, ...)
    if settings.debug then
        windower.add_to_chat(207, 'ROE debug: ' .. string.format(fmt, ...))
    end
end

local function is_locked(id)
    id = tonumber(id)
    return id ~= nil and id >= 4008 and id <= 4021
end

local function cancel_roe(id)
    id = tonumber(id)

    if not id then return end

    if settings.blacklist[id] or not _roe.active[id] then return end

    local p = packets.new('outgoing', 0x10d, {['RoE Quest'] = id })
    packets.inject(p)
end

local function accept_roe(id)
    id = tonumber(id)

    if not id or _roe.complete[id] or _roe.active[id] then return end
    if is_locked(id) then return end

    local p = packets.new('outgoing', 0x10c, {['RoE Quest'] = id })
    packets.inject(p)
end

local function eval(...)
    assert(loadstring(table.concat({...}, ' ')))()
end

local function save(name)
    if type(name) ~= "string" then
        error('`save` : specify a profile name')
        return
    end

    name = name:lower()

    settings.profiles[name] = S(_roe.active:keyset())
    settings:save('global')
    notice('saved %d objectives to the profile %s':format(_roe.active:length(), name))
end


local function list()
    notice('You have saved the following profiles: ')
    notice(settings.profiles:keyset())
end

-- Objectives in the profile that are still not active (and could be accepted)
local function get_missing(name)
    local missing = S{}
    for id in settings.profiles[name]:it() do
        -- profile entries can be strings when loaded from the settings file
        id = tonumber(id)
        if id and not _roe.active[id] and not _roe.complete[id] and not is_locked(id) then
            missing:add(id)
        end
    end
    return missing
end

local function set(name)
    if type(name) ~= "string" then
        error('`set` : specify a profile name')
        return
    end

    name = name:lower()

    if not settings.profiles[name] then
        error('`set` : the profile \'%s\' does not exist':format(name))
        return
    end

    local needed_quests = settings.profiles[name]:diff(_roe.active:keyset())
    local available_slots = _roe.max_count - _roe.active:length()
    local to_remove = S{}

    if settings.clearall then
        to_remove:update(_roe.active:keyset())
    elseif settings.clear then
        for id,progress in pairs(_roe.active) do
            if (needed_quests:length() - to_remove:length()) <= available_slots then
                break
            end
            if (progress == 0 or settings.clearprogress) and not settings.blacklist[id] then
                to_remove:add(id)
            end
        end
    end


    if (needed_quests:length() - to_remove:length()) > available_slots then
        error('you do not have enough available quest slots')
        return
    end

    for id in to_remove:it() do
        cancel_roe(id)
        pace()
    end

    -- give the server a moment to free the slots before accepting new objectives
    if to_remove:length() > 0 then
        pace()
    end

    for id in needed_quests:it() do
        accept_roe(id)
        pace()
    end

    -- verify against the server's 0x111 update and re-send anything that did not stick
    local retries = math.floor(tonumber(settings.retries) or 0)
    local wait = math.max(2, settings.delay * 4)

    for attempt = 0, retries do
        coroutine.sleep(wait)

        local missing = get_missing(name)
        if missing:length() == 0 then
            notice('loaded the profile \'%s\'':format(name))
            return
        end

        if attempt == retries then
            error('profile \'%s\': %d objective(s) failed to set: %s':format(name, missing:length(), missing:tostring()))
            return
        end

        notice('retry %d/%d: %d objective(s) not set yet':format(attempt + 1, retries, missing:length()))
        for id in missing:it() do
            accept_roe(id)
            pace()
        end
    end
end

-- Objectives currently active that `unset` should remove
local function get_removable(name)
    local ids = S{}
    if name then
        for id in settings.profiles[name]:it() do
            id = tonumber(id)
            if id and _roe.active[id] and not settings.blacklist[id] then
                ids:add(id)
            end
        end
    else
        for id, progress in pairs(_roe.active) do
            if (progress == 0 or settings.clearprogress) and not settings.blacklist[id] then
                ids:add(id)
            end
        end
    end
    return ids
end

local function unset(name)

    name = name and name ~= '' and name:lower() or nil

    if name and not settings.profiles[name] then
        error('`unset` : the profile \'%s\' does not exist':format(name))
        return
    end

    if name then
        notice('unsetting the profile \'%s\'':format(name))
    else
        notice('clearing ROE objectives.')
    end

    local retries = math.floor(tonumber(settings.retries) or 0)
    local wait = math.max(2, settings.delay * 4)
    local removable = get_removable(name)

    for attempt = 0, retries do
        for id in removable:it() do
            cancel_roe(id)
            pace()
        end

        -- verify against the server's 0x111 update and re-send any cancels that did not stick
        coroutine.sleep(wait)
        removable = get_removable(name)

        if removable:length() == 0 then
            notice('unset complete')
            return
        end

        if attempt == retries then
            error('%d objective(s) failed to unset: %s':format(removable:length(), removable:tostring()))
            return
        end

        notice('retry %d/%d: %d objective(s) still set':format(attempt + 1, retries, removable:length()))
    end

end

local true_strings = S{'true','t','y','yes','on'}
local false_strings = S{'false','f','n','no','off'}
local bool_strings = true_strings:union(false_strings)

local function handle_setting(setting,val)
    setting = setting and setting:lower() or setting
    val = val and val:lower() or val

    if not setting or not settings:containskey(setting) then
        error('specified setting (%s) does not exist':format(setting or ''))
    elseif type(settings[setting]) == "boolean" then
        if not val or not bool_strings:contains(val) then
            settings[setting] = not settings[setting]
        elseif true_strings:contains(val) then
            settings[setting] = true
        else
            settings[setting] = false
        end

        settings:save()
        notice('%s setting is now %s':format(setting, tostring(settings[setting])))
    elseif type(settings[setting]) == "number" then
        local n = val and tonumber(val)

        if not val then
            notice('%s setting is currently %s':format(setting, tostring(settings[setting])))
        elseif not n or n < 0 then
            error('`settings` : %s needs a number >= 0':format(setting))
        else
            settings[setting] = n
            settings:save()
            notice('%s setting is now %s':format(setting, tostring(n)))
        end
    end

end

local function blacklist(add_remove,id)
    add_remove = add_remove and add_remove:lower()
    id = id and tonumber(id)


    if add_remove and id then
        if add_remove == 'add' then
            settings.blacklist:add(id)
            notice('roe quest %d added to the blacklist':format(id))
        elseif add_remove == 'remove' then
            if is_locked(id) then
                return
            else
                settings.blacklist:remove(id)
                notice('roe quest %d removed from the blacklist':format(id))
            end
        else
            error('`blacklist` specify \'add\' or \'remove\'')
        end
    else
        error('`blacklist` requires two args, [add|remove] <quest id>')
    end

end

local function toggle_debug(val)
    handle_setting('debug', val)
end


-- Single objectives by id / name ----------------------------------------------

local _name_to_id = nil

local function name_to_id(name)
    if not _name_to_id then
        _name_to_id = {}
        for rid, rname in pairs(roe_mapping) do
            if type(rname) == 'string' then
                _name_to_id[rname:lower()] = rid
            end
        end
    end
    return _name_to_id[name:lower()]
end

local function add_roe(...)
    local joined = table.concat({...}, ' ')
    if joined == '' then
        error('`add` : specify a RoE id or exact name')
        return
    end

    local id = tonumber(joined)
    if id then
        accept_roe(id)
        return
    end

    joined = joined:gsub("^%s*['\"](.-)['\"]%s*$", "%1")

    local mapped_id = name_to_id(joined)
    if mapped_id then
        accept_roe(mapped_id)
        notice('added RoE: %s (%d)':format(roe_mapping[mapped_id], mapped_id))
    else
        error('`add` : RoE not found for name `%s`':format(joined))
    end
end

local function remove_roe(...)
    local joined = table.concat({...}, ' ')
    if joined == '' then
        error('`remove` : specify a RoE id or exact name')
        return
    end

    local id = tonumber(joined)
    if id then
        cancel_roe(id)
        return
    end

    joined = joined:gsub("^%s*['\"](.-)['\"]%s*$", "%1")

    local mapped_id = name_to_id(joined)
    if mapped_id then
        cancel_roe(mapped_id)
        notice('removed RoE: %s (%d)':format(roe_mapping[mapped_id], mapped_id))
    else
        error('`remove` : RoE not found for name `%s`':format(joined))
    end
end

-- top 10 objectives whose name contains the search term, best match first
local function fuzzy_find(term)
    local lower_search = term:lower()
    local escaped = lower_search:gsub('[%p]', '%%%1')
    local matches = {}

    for rid, rname in pairs(roe_mapping) do
        if type(rname) == 'string' then
            local lower_name = rname:lower()
            if lower_name:find(lower_search, 1, true) then
                local score
                if lower_name == lower_search then
                    score = 1000
                elseif lower_name:find(lower_search, 1, true) == 1 then
                    score = 500
                elseif lower_name:find('%f[%w]' .. escaped .. '%f[%W]') then
                    score = 200
                else
                    score = 100
                end

                -- bonus for shorter names (more specific)
                score = score + math.max(0, 50 - #rname)

                matches[#matches + 1] = {id = rid, name = rname, score = score}
            end
        end
    end

    table.sort(matches, function(a, b) return a.score > b.score end)

    local top = {}
    for i = 1, math.min(10, #matches) do
        top[i] = matches[i]
    end
    return top
end

local function fuzzy_apply(label, apply, past, ...)
    local term = table.concat({...}, ' ')
    if term == '' then
        error('`%s` : specify a search term':format(label))
        return
    end

    local top = fuzzy_find(term)
    if #top == 0 then
        error('`%s` : No RoE objectives found matching `%s`':format(label, term))
        return
    end

    notice('Found %d matching RoE objectives for "%s":':format(#top, term))
    for i, match in ipairs(top) do
        notice('%d. %s (ID: %d)':format(i, match.name, match.id))
    end

    for _, match in ipairs(top) do
        apply(match.id)
        pace()
    end

    notice('%s %d RoE objectives':format(past, #top))
end

local function fuzzy_search_roe(...)
    fuzzy_apply('fuzzy', accept_roe, 'Added', ...)
end

local function fuzzy_remove_roe(...)
    fuzzy_apply('fuzzyremove', cancel_roe, 'Removed', ...)
end


-- Multi-character support -----------------------------------------------------
-- Uses Windower IPC, so every character that has ROE loaded can be reached
-- without the `send` addon.

-- commands that can be triggered remotely (via `all`, `party` or mirror mode)
local remote_cmds = {
    set = set,
    unset = unset,
    add = add_roe,
    remove = remove_roe,
    fuzzy = fuzzy_search_roe,
    fuzzyremove = fuzzy_remove_roe,
}

-- commands that need an argument
local needs_arg = S{'set', 'add', 'remove', 'fuzzy', 'fuzzyremove'}

-- session only: nil, 'all' or 'party'
local mirror_mode = nil

local seeded = false

local function ipc_handler(msg)
    local parts = msg:split(';')
    if parts[1] ~= 'roe' then return end

    local mode, targets, cmd, arg = parts[2], parts[3], parts[4], parts[5]
    if not remote_cmds[cmd] then return end
    if arg == '' then arg = nil end

    local me = windower.ffxi.get_player()
    if not me then return end

    local wait = 0

    if mode == 'party' then
        local idx
        local i = 0
        for n in targets:split(','):it() do
            if n:lower() == me.name:lower() then
                idx = i
                break
            end
            i = i + 1
        end
        if not idx then return end
        wait = idx * settings.stagger
    elseif mode == 'all' then
        -- several clients can start in the same second, so seed with something unique per character
        if not seeded then
            math.randomseed(os.time() + me.id)
            seeded = true
        end
        wait = math.random() * settings.jitter
    else
        return
    end

    dbg('received `%s %s` from %s mode, running in %.1fs', cmd, arg or '', mode, wait)

    coroutine.schedule(function()
        if cmd == 'set' or cmd == 'unset' then
            -- pick up profiles saved by another character after this one loaded
            pcall(config.reload, settings)
            normalize_profiles()
        end
        remote_cmds[cmd](arg)
    end, wait)
end

-- you, then the rest of the party, then alliance members
local function party_names()
    local me = windower.ffxi.get_player()
    local party = windower.ffxi.get_party()
    if not me or not party then return nil end

    local names = {me.name}
    for i = 1, 5 do
        local member = party['p'..i]
        if member and member.name then
            names[#names + 1] = member.name
        end
    end

    -- alliance parties 2 and 3 (a10-a15, a20-a25)
    if settings.alliance then
        for _, base in ipairs({10, 20}) do
            for i = 0, 5 do
                local member = party['a'..(base + i)]
                if member and member.name then
                    names[#names + 1] = member.name
                end
            end
        end
    end

    return names
end

-- Sends the command to the other characters only. Returns how many party
-- members were addressed (nil for `all`, or if nobody could be reached).
local function send_remote(mode, cmd, arg)
    local targets = '*'
    local count = nil

    if mode == 'party' then
        local names = party_names()
        if not names or #names < 2 then
            dbg('no other party members to send `%s` to', cmd)
            return nil
        end
        targets = table.concat(names, ',')
        count = #names - 1
    end

    windower.send_ipc_message('roe;%s;%s;%s;%s':format(mode, targets, cmd, arg or ''))
    return count
end

-- Sends to the other characters, then runs on this one
local function dispatch(mode, cmd, arg, quiet)
    local count = send_remote(mode, cmd, arg)

    if not quiet then
        if mode == 'party' then
            notice('sent `%s` to %d party/alliance member(s), %.1fs apart':format(cmd, count or 0, settings.stagger))
        else
            notice('sent `%s` to all loaded characters (random delay up to %.1fs)':format(cmd, settings.jitter))
        end
    end

    remote_cmds[cmd](arg)
end

local function set_mirror(mode, val)
    val = val and val:lower()

    local on
    if val and bool_strings:contains(val) then
        on = true_strings:contains(val)
    else
        on = (mirror_mode ~= mode)
    end

    if on then
        mirror_mode = mode
        notice('mirror mode ON: your set/unset/add/remove/fuzzy commands and manual RoE changes are sent to %s':format(mode == 'party' and 'party/alliance members' or 'all loaded characters'))
    else
        mirror_mode = nil
        notice('mirror mode OFF')
    end
end

local function broadcast(mode, cmd, ...)
    cmd = cmd and cmd:lower()

    if cmd == 'mirror' then
        set_mirror(mode, ...)
        return
    end

    if not cmd or not remote_cmds[cmd] then
        error('`%s` : use `roe %s <set|unset|add|remove|fuzzy|fuzzyremove|mirror> ...`':format(mode, mode))
        return
    end

    local arg = table.concat({...}, ' ')
    if arg == '' then arg = nil end

    if not arg and needs_arg:contains(cmd) then
        error('`%s %s` : missing argument':format(mode, cmd))
        return
    end

    dispatch(mode, cmd, arg, false)
end

local function send_all(cmd, ...)
    broadcast('all', cmd, ...)
end

local function send_party(cmd, ...)
    broadcast('party', cmd, ...)
end

local function toggle_mirror(val)
    set_mirror('party', val)
end


local function help()
    notice([[ROE - Command List:
1. help - Displays this help menu.
2. save <profile name> : saves the currently set ROE to the named profile
3. set <profile name> : attempts to set the ROE objectives in the profile
    - Objectives may be canceled automatically based on settings.
    - The default setting is to only cancel ROE that have 0 progress if space is needed
    - Objectives that do not register are re-sent (see retries)
4. unset [profile] : removes currently set objectives
    - By default, this will only remove objectives without progress made
    - Cancels that do not register are re-sent (see retries)
5. settings <settings name> [value] : toggles/sets the specified setting
    * settings:
        * clear : removes objectives if space is needed (default true)
        * clearprogress : remove objectives even if they have non-zero progress (default false)
        * clearall : clears every objective before setting new ones (default false)
        * alliance : `party` also includes alliance members (default true)
        * delay : seconds between each packet (default 0.5)
        * retries : times to re-send objectives that failed (default 2)
        * stagger : seconds between party members for `party` (default 1.5)
        * jitter : max random delay per character for `all` (default 6)
        * debug : shows debug output for remote commands and mirror (default false)
6. blacklist [add|remove] <id> : blacklists a quest from ever being removed
    - I do not currently have a mapping of quest IDs to names
7. add <id|name> : adds a single RoE by id or exact name
8. remove <id|name> : removes a single RoE by id or exact name
9. fuzzy <search term> : adds up to 10 RoE whose name matches the term
10. fuzzyremove <search term> : removes up to 10 RoE whose name matches the term
11. all <command> [args] : runs it here and on every character with ROE loaded
12. party <command> [args] : runs it here and on party/alliance members, staggered
    - commands for 11 and 12: set, unset, add, remove, fuzzy, fuzzyremove
13. all mirror [on|off] / party mirror [on|off] : while on, everything you set
    (set, unset, add, remove, fuzzy, fuzzyremove, and RoE changes made in the
    game menu) is also sent to all characters / the party. Resets on reload.
14. mirror [on|off] : same as `party mirror`
15. debug [on|off] : toggles debug output]])
end

local cmd_handlers = {
    eval = eval,
    save = save,
    list = list,
    set = set,
    unset = unset,
    settings = handle_setting,
    blacklist = blacklist,
    add = add_roe,
    remove = remove_roe,
    fuzzy = fuzzy_search_roe,
    fuzzyremove = fuzzy_remove_roe,
    all = send_all,
    party = send_party,
    mirror = toggle_mirror,
    debug = toggle_debug,
    help = help,
}


local function inc_chunk_handler(id,data)
    if id == 0x111 then
        _roe.active:clear()
        for i = 1, _roe.max_count do
            local offset = 5 + ((i - 1) * 4)
            local id,progress = data:unpack('b12b20', offset)
            if id > 0 then
                _roe.active[id] = progress
            end
        end
    elseif id == 0x112 then
        local complete = T{data:unpack('b1':rep(1024),4)}:key_map(
            function(k)
                return (k + 1024*data:unpack('H', 133) - 1)
            end):map(
            function(v)
                return (v == 1)
            end)
        _roe.complete:update(complete)
    end
end

-- Mirrors objectives you accept/cancel by hand in the game menu. Packets sent
-- by this addon are injected, so they are ignored here (set/unset/add/... are
-- mirrored at the command level instead), which also prevents any loop.
local function out_chunk_handler(id, original, modified, injected, blocked)
    if not mirror_mode or injected or blocked then return end
    if id ~= 0x10c and id ~= 0x10d then return end

    local ok, p = pcall(packets.parse, 'outgoing', original)
    local roe_id = ok and p and p['RoE Quest']
    if not roe_id or roe_id == 0 then return end

    local cmd = (id == 0x10c) and 'add' or 'remove'
    dbg('manual %s of %d, mirroring to %s', cmd, roe_id, mirror_mode)
    send_remote(mirror_mode, cmd, tostring(roe_id))
end

local mirrored_cmds = S{'set', 'unset', 'add', 'remove', 'fuzzy', 'fuzzyremove'}

local function addon_command_handler(command,...)
    local cmd  = command and command:lower() or "help"

    if not cmd_handlers[cmd] then
        error('unknown command `%s`':format(cmd or ''))
        return
    end

    if mirror_mode and mirrored_cmds:contains(cmd) then
        local arg = table.concat({...}, ' ')
        if arg == '' then arg = nil end

        -- invalid commands (missing argument) are only run locally so they report their own error
        if arg or not needs_arg:contains(cmd) then
            dispatch(mirror_mode, cmd, arg, true)
            return
        end
    end

    cmd_handlers[cmd](...)
end

local function load_handler()
    normalize_profiles()

    local last_roe = windower.packets.last_incoming(0x111)
    if last_roe then inc_chunk_handler(0x111,last_roe) end

end

windower.register_event('incoming chunk', inc_chunk_handler)
windower.register_event('outgoing chunk', out_chunk_handler)
windower.register_event('addon command', addon_command_handler)
windower.register_event('ipc message', ipc_handler)
windower.register_event('load', load_handler)

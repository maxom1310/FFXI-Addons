_addon.name = 'TradePlayer'
_addon.author = 'Tny5989'
--Updated to 0.2.1b by Skynet
--Added "party" target to trade to all party members
--Added "all" keyword to trade full count of desired item in inventory
--Added named trade lists (lists/<name>.txt): //tp list <name> <target>
_addon.version = '0.2.1b'
_addon.commands = {'tradeplayer', 'tp'}

--------------------------------------------------------------------------------
require('logger')
packets = require('util/packets')
settings = require('util/settings')
resources = require('resources')

local CommandFactory = require('command/factory')
local NilCommand = require('command/nil')

--------------------------------------------------------------------------------
local command = NilCommand:NilCommand()

--------------------------------------------------------------------------------
-- List support
--------------------------------------------------------------------------------
local queue = nil   -- { target = 'name', batches = { {item, 'all', item, 'all'}, ... } }
local LIST_DIR = windower.addon_path .. 'lists/'
local MAX_SLOTS = 8

local function ListFile(name)
    return LIST_DIR .. name:lower() .. '.txt'
end

local function ReadList(name)
    local f = io.open(ListFile(name), 'r')
    if not f then return nil end
    local items = {}
    for line in f:lines() do
        line = line:gsub('^%s+', ''):gsub('%s+$', '')
        if line ~= '' and line:sub(1, 1) ~= '#' then
            items[#items + 1] = line
        end
    end
    f:close()
    return items
end

local function ShowLists()
    local files = windower.get_dir(LIST_DIR) or {}
    local names = {}
    for _, file in ipairs(files) do
        local n = file:match('^(.+)%.txt$')
        if n then names[#names + 1] = n end
    end
    if #names == 0 then
        log('No lists found in ' .. LIST_DIR)
    else
        table.sort(names)
        log('Lists: ' .. table.concat(names, ', '))
    end
end

-- Maps lowercase item name -> { slots = stacks used, count = total quantity }
-- (main inventory only, unequipped items only)
local function InventoryStacks()
    local stacks = {}
    local bag = windower.ffxi.get_items(0)
    if not bag then return stacks end
    for i = 1, bag.max do
        local entry = bag[i]
        if entry and entry.id and entry.id ~= 0 and entry.status == 0 then
            local res = resources.items[entry.id]
            if res then
                local key = res.en:lower()
                local s = stacks[key] or { slots = 0, count = 0 }
                s.slots = s.slots + 1
                s.count = s.count + (entry.count or 1)
                stacks[key] = s
            end
        end
    end
    return stacks
end

-- Each batch is a flat arg list: count, item, count, item, ...
local function BuildBatches(items)
    local stacks = InventoryStacks()
    local batches, current, used, found = {}, {}, 0, 0
    for _, name in ipairs(items) do
        local s = stacks[name:lower()]
        if s then
            found = found + 1
            if used + s.slots > MAX_SLOTS and used > 0 then
                batches[#batches + 1] = current
                current, used = {}, 0
            end
            current[#current + 1] = s.count
            current[#current + 1] = name
            used = used + s.slots
        end
    end
    if used > 0 then batches[#batches + 1] = current end
    return batches, found
end

local OnSuccess, OnFailure

-- Called whenever a list run ends (complete, failed, rejected). Used so the
-- multi-character coordinator knows when this character is done.
local on_finish = nil

local function Finish(status)
    local cb = on_finish
    on_finish = nil
    queue = nil
    if cb then cb(status) end
end

local function StartNextBatch()
    if not queue then return end
    if #queue.batches == 0 then
        log('List complete')
        Finish('complete')
        return
    end
    local batch = table.remove(queue.batches, 1)
    -- Factory expects: count, item, count, item, ..., target
    local args = {}
    for _, v in ipairs(batch) do args[#args + 1] = v end
    args[#args + 1] = queue.target
    command = CommandFactory.CreateCommand(unpack(args))
    if command:Type() == 'NilCommand' then
        -- factory already logged why (bad target, unparsed item, out of range, etc.)
        Finish('failed')
        return
    end
    command:SetSuccessCallback(OnSuccess)
    command:SetFailureCallback(OnFailure)
    command()
end

local function ResetCommand()
    command = NilCommand:NilCommand()
    if queue then
        coroutine.schedule(StartNextBatch, 2)   -- short pause between trades
    elseif on_finish then
        Finish('complete')                      -- plain (non-list) trade finished
    end
end

-- cb (optional) is called with a status string when this character is finished
local function StartList(listname, target, cb)
    local function bail(msg, status)
        log(msg)
        if cb then cb(status) end
    end

    if queue or command:Type() ~= 'NilCommand' then
        return bail('A trade is already running', 'busy')
    end
    local t = tostring(target):lower()
    if t == 'party' or t == 'ally' then
        return bail('Lists can only be traded to a single player, not party/ally', 'failed')
    end
    local items = ReadList(listname)
    if not items then
        return bail('List not found: ' .. listname, 'list not found')
    end
    local batches, found = BuildBatches(items)
    if #batches == 0 then
        return bail('None of the items in "' .. listname .. '" are in your inventory', 'nothing to trade')
    end
    log(('Trading %d of %d items from "%s" in %d trade(s)'):format(found, #items, listname, #batches))
    queue = { target = target, batches = batches }
    on_finish = cb
    StartNextBatch()
end

-- Plain (non-list) trade for one character. args = count, item, ..., target
-- cb (optional) is called with a status string when this character is finished
local function StartTrade(args, cb)
    local function bail(msg, status)
        log(msg)
        if cb then cb(status) end
    end

    if queue or command:Type() ~= 'NilCommand' then
        return bail('A trade is already running', 'busy')
    end

    -- skip characters that don't carry every requested item
    local stacks = InventoryStacks()
    for i = 2, #args - 1, 2 do
        local name = tostring(args[i])
        local converted = windower.convert_auto_trans(name)
        if not stacks[(converted or name):lower()] then
            return bail('Missing item: ' .. name, 'nothing to trade')
        end
    end

    command = CommandFactory.CreateCommand(unpack(args))
    if command:Type() == 'NilCommand' then
        -- factory already logged why
        if cb then cb('failed') end
        return
    end
    on_finish = cb
    command:SetSuccessCallback(OnSuccess)
    command:SetFailureCallback(OnFailure)
    command()
end

--------------------------------------------------------------------------------
-- Multi-character coordination (all loaded characters take turns)
--------------------------------------------------------------------------------
-- One character runs //tp everyone <normal trade or list command>. It asks every
-- other loaded character to report in (via IPC), then gives each one a turn,
-- waiting for "done" before starting the next. The target is never included.
--   //tp everyone list <listname> <target>
--   //tp everyone <count|all> <item> [<count|all> <item> ...] <target>
--------------------------------------------------------------------------------
local MULTI_KEYWORD = 'everyone'   -- //tp everyone ...  (change this word if you like)
local TURN_TIMEOUT = 180   -- seconds to wait for one character before skipping it
local coord = nil          -- { kind, args, order = {names}, idx, token, collecting }

local function RunKind(kind, args, cb)
    if kind == 'list' then
        StartList(args[1], args[2], cb)
    else
        StartTrade(args, cb)
    end
end

local function MyName()
    local p = windower.ffxi.get_player()
    return p and p.name
end

local function Send(...)
    windower.send_ipc_message('tp|' .. table.concat({...}, '|'))
end

local NextTurn

local function TurnDone(name, status)
    if not coord or coord.collecting then return end
    if coord.order[coord.idx] ~= name then return end   -- stale/unexpected
    log(name .. ': ' .. tostring(status))
    coord.token = coord.token + 1                        -- cancels this turn's timeout
    coroutine.schedule(NextTurn, 2)
end

NextTurn = function()
    if not coord then return end
    coord.idx = coord.idx + 1
    local name = coord.order[coord.idx]
    if not name then
        log('All characters finished')
        coord = nil
        return
    end

    coord.token = coord.token + 1
    local token = coord.token
    log('Turn: ' .. name)

    local me = MyName()
    if me and name:lower() == me:lower() then
        RunKind(coord.kind, coord.args, function(status) TurnDone(name, status) end)
    else
        Send('turn', name, coord.kind, unpack(coord.args))
    end

    coroutine.schedule(function()
        if coord and coord.token == token then
            log(name .. ' timed out, skipping')
            NextTurn()
        end
    end, TURN_TIMEOUT)
end

-- kind = 'list' (args = {listname, target}) or 'trade' (args = count,item,...,target)
local function StartAll(kind, args)
    if coord then log('Already coordinating a trade (//tp stop to cancel)') return end
    local me = MyName()
    if not me then log('Not logged in') return end
    local target = args[#args]
    local t = tostring(target):lower()
    if t == 'party' or t == 'ally' then
        log('//tp everyone needs a single player as the target, not party/ally')
        return
    end
    if kind == 'list' and not ReadList(args[1]) then
        log('List not found: ' .. tostring(args[1]))
        return
    end

    coord = { kind = kind, args = args, order = {}, idx = 0, token = 0, collecting = true }
    if me:lower() ~= t then
        coord.order[1] = me   -- this character takes part too, unless it is the target
    end
    log('Looking for other characters...')
    Send('roster', me, target)

    coroutine.schedule(function()
        if not coord then return end
        coord.collecting = false
        table.sort(coord.order)
        if #coord.order == 0 then
            log('No characters found to trade')
            coord = nil
            return
        end
        log('Order: ' .. table.concat(coord.order, ', '))
        NextTurn()
    end, 2)
end

local function OnIPC(msg)
    local parts = {}
    for p in (tostring(msg) .. '|'):gmatch('(.-)|') do parts[#parts + 1] = p end
    if parts[1] ~= 'tp' then return end

    local me = MyName()
    if not me then return end
    local cmd = parts[2]

    if cmd == 'roster' then
        -- parts: roster | initiator | target
        if me:lower() ~= tostring(parts[4]):lower() then
            Send('here', parts[3], me)
        end
    elseif cmd == 'here' then
        -- parts: here | initiator | name
        if coord and coord.collecting and parts[3] == me then
            table.insert(coord.order, parts[4])
        end
    elseif cmd == 'turn' then
        -- parts: turn | name | kind | args...
        if parts[3] == me then
            local args = {}
            for i = 5, #parts do args[#args + 1] = parts[i] end
            RunKind(parts[4], args, function(status) Send('done', me, status) end)
        end
    elseif cmd == 'done' then
        -- parts: done | name | status
        TurnDone(parts[3], parts[4])
    elseif cmd == 'stop' then
        queue = nil
        on_finish = nil
    end
end

--------------------------------------------------------------------------------
OnSuccess = function()
    if command:Type() == 'SequentialTradeCommand' then
        -- If all trades are complete, don't log "Accepted" again, just reset
        if command._all_trades_complete then
            ResetCommand()
            return
        end
        -- Otherwise, log "Accepted" for this individual trade and keep going
        log('Accepted')
        return
    end

    log('Accepted')
    if command:Type() ~= 'PartyCommand' then
        ResetCommand()
    elseif command._all_trades_complete then
        -- All party trades completed, reset the command
        ResetCommand()
    end
end

--------------------------------------------------------------------------------
OnFailure = function()
    log('Rejected')
    local was_list = (queue ~= nil) or (on_finish ~= nil)
    if command:Type() ~= 'PartyCommand' then
        command = NilCommand:NilCommand()
    elseif command._all_trades_complete then
        -- All party trades completed, reset the command
        command = NilCommand:NilCommand()
    end
    -- stop the rest of a list if a trade fails, and tell the coordinator
    if was_list then Finish('rejected') end
end

--------------------------------------------------------------------------------
local function OnLoad()
    settings.load()
    if windower.create_dir then windower.create_dir(LIST_DIR) end
end

--------------------------------------------------------------------------------
local function OnCommand(...)
    local args = {...}

    -- Handle timeout command
    if #args >= 2 and tostring(args[1]):lower() == 'timeout' then
        local timeout_value = tonumber(args[2])
        if timeout_value and timeout_value > 0 then
            settings.config.timeout = timeout_value
            settings.save()
            log('Timeout set to ' .. timeout_value .. ' seconds')
        else
            log('Invalid timeout value. Must be a positive number.')
        end
        return
    end

    -- List commands
    local first = args[1] and tostring(args[1]):lower()
    if first == 'lists' then
        ShowLists()
        return
    elseif first == MULTI_KEYWORD then
        if args[2] and tostring(args[2]):lower() == 'list' then
            -- //tp everyone list <listname> <target>
            if #args >= 4 then
                StartAll('list', { tostring(args[3]), tostring(args[4]) })
            else
                log('Usage: //tp ' .. MULTI_KEYWORD .. ' list <listname> <target>')
            end
        elseif #args >= 4 and (#args - 1) % 2 == 1 then
            -- //tp everyone <count|all> <item> [...] <target>
            local rest = {}
            for i = 2, #args do rest[#rest + 1] = tostring(args[i]) end
            StartAll('trade', rest)
        else
            log('Usage: //tp ' .. MULTI_KEYWORD .. ' list <listname> <target>')
            log('   or: //tp ' .. MULTI_KEYWORD .. ' <count|all> <item> ... <target>')
        end
        return
    elseif first == 'stop' then
        coord = nil
        queue = nil
        on_finish = nil
        Send('stop')
        log('Stopped (a trade already in progress will finish)')
        return
    elseif first == 'list' then
        if #args >= 3 and tostring(args[2]):lower() == 'show' then
            local items = ReadList(tostring(args[3]))
            if items then
                log(args[3] .. ': ' .. table.concat(items, ', '))
            else
                log('List not found: ' .. tostring(args[3]))
            end
        elseif #args >= 3 then
            if command:Type() ~= 'NilCommand' then
                log('Already running a complex command')
            else
                StartList(tostring(args[2]), args[3])
            end
        else
            log('Usage: //tp list <listname> <target>  |  //tp list show <listname>  |  //tp lists')
        end
        return
    end

    if command:Type() == 'NilCommand' then
        command = CommandFactory.CreateCommand(...)
        command:SetSuccessCallback(OnSuccess)
        command:SetFailureCallback(OnFailure)
        command()
    else
        log('Already running a complex command')
    end
end

--------------------------------------------------------------------------------
local function OnIncomingData(id, _, pkt, b, i)
    if not packets.is_duplicate(id, pkt) then
        return command:OnIncomingData(id, pkt)
    else
        return false
    end
end

--------------------------------------------------------------------------------
local function OnOutgoingData(id, _, pkt, b, i)
    return command:OnOutgoingData(id, pkt)
end

--------------------------------------------------------------------------------
windower.register_event('load', OnLoad)
windower.register_event('addon command', OnCommand)
windower.register_event('incoming chunk', OnIncomingData)
windower.register_event('outgoing chunk', OnOutgoingData)
windower.register_event('ipc message', OnIPC)

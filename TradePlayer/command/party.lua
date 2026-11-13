local NilCommand = require('command/nil')
local OfferCommand = require('command/offer')

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local PartyCommand = NilCommand:NilCommand()
PartyCommand.__index = PartyCommand

--------------------------------------------------------------------------------
function PartyCommand:PartyCommand(items, is_alliance)
    local o = NilCommand:NilCommand()
    setmetatable(o, self)
    o._items = items
    o._type = 'PartyCommand'
    o._is_alliance = is_alliance or false
    o._party_members = {}
    o._current_index = 1
    o._current_command = nil
    o._wait_start_time = nil
    o._all_trades_complete = false
    return o
end

--------------------------------------------------------------------------------
function PartyCommand:GetPartyMembers()
    local party = windower.ffxi.get_party()
    local members = {}
    
    if not party then
        return members
    end
    
    local player = windower.ffxi.get_player()
    
    -- Determine the range based on whether this is an alliance command
    local max_index = self._is_alliance and 17 or 5
    
    log('DEBUG: is_alliance=' .. tostring(self._is_alliance) .. ', max_index=' .. max_index)
    
    -- Process party members
    -- Party: p1-p5 (excluding p0 which is the player)
    -- Alliance: p1-p17 (excluding p0 which is the player)
    for i = 1, max_index do
        local member = party['p' .. i]
        if member and member.mob and not member.mob.is_npc then
            -- Skip the current player (shouldn't be needed since we start at p1, but keeping for safety)
            if player and member.mob.id ~= player.id then
                table.insert(members, member.mob.name)
                log('DEBUG: Added member p' .. i .. ': ' .. member.mob.name)
            end
        end
    end
    
    log('DEBUG: Total members found: ' .. #members)
    return members
end

--------------------------------------------------------------------------------
function PartyCommand:StartNextTrade()
    if self._current_index > #self._party_members then
        -- All trades completed
        self._wait_start_time = nil
        self._current_command = nil
        self._all_trades_complete = true
        -- Don't call _on_success() here - the last trade's success callback already called it
        return
    end
    
    local member_name = self._party_members[self._current_index]
    local mob = windower.ffxi.get_mob_by_name(member_name)
    
    if not mob or mob.is_npc then
        log('Could not find party member: ' .. member_name)
        self._current_index = self._current_index + 1
        self:StartNextTrade()
        return
    end
    
    -- Create an OfferCommand for this party member
    self._current_command = OfferCommand:OfferCommand(mob.id, self._items)
    local is_last_trade = (self._current_index == #self._party_members)
    self._current_command:SetSuccessCallback(function() 
        -- If this is the last trade, mark as complete before calling callback
        if is_last_trade then
            self._all_trades_complete = true
        end
        -- Call parent callback to log "Accepted" message
        self._on_success()
        -- If this is the last trade, we're done (don't start timer)
        if is_last_trade then
            self._current_command = nil
        else
            -- When trade completes, start timer before next member
            self._wait_start_time = os.clock()
            self._current_command = nil
        end
    end)
    self._current_command:SetFailureCallback(function() self._on_failure() end)
    
    log('Starting trade with ' .. member_name)
    self._current_command()
end

--------------------------------------------------------------------------------
function PartyCommand:CheckWaitTimer()
    local timeout = settings.config.timeout or 2.0
    if self._wait_start_time and (os.clock() - self._wait_start_time) >= timeout then
        self._wait_start_time = nil
        self._current_index = self._current_index + 1
        self._current_command = nil
        self:StartNextTrade()
    end
end

--------------------------------------------------------------------------------
function PartyCommand:OnIncomingData(id, pkt)
    -- Check if we need to move to next trade (3 second wait elapsed)
    self:CheckWaitTimer()
    
    if self._current_command then
        return self._current_command:OnIncomingData(id, pkt)
    end
    return false
end

--------------------------------------------------------------------------------
function PartyCommand:OnOutgoingData(id, pkt)
    -- Check if we need to move to next trade (3 second wait elapsed)
    self:CheckWaitTimer()
    
    if self._current_command then
        return self._current_command:OnOutgoingData(id, pkt)
    end
    return false
end

--------------------------------------------------------------------------------
function PartyCommand:__call()
    self._party_members = self:GetPartyMembers()
    
    if #self._party_members == 0 then
        local member_type = self._is_alliance and 'alliance' or 'party'
        log('No ' .. member_type .. ' members found')
        self._on_failure()
        return
    end
    
    local member_type = self._is_alliance and 'alliance' or 'party'
    log('Found ' .. #self._party_members .. ' ' .. member_type .. ' member(s)')
    self:StartNextTrade()
end

return PartyCommand


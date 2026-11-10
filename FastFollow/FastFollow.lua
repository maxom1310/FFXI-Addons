_addon.name = 'FastFollow'
_addon.author = 'DiscipleOfEris'
_addon.version = '1.3.0'
_addon.commands = {'fastfollow', 'ffo'}

require('strings')
require('tables')
require('coroutine')
config = require('config')
texts = require('texts')
require('logger')

defaults = {}
defaults.show = true
defaults.min = 0.5
defaults.display = {}
defaults.display.pos = {}
defaults.display.pos.x = 0
defaults.display.pos.y = 0
defaults.display.bg = {}
defaults.display.bg.red = 0
defaults.display.bg.green = 0
defaults.display.bg.blue = 0
defaults.display.bg.alpha = 102
defaults.display.text = {}
defaults.display.text.font = 'Consolas'
defaults.display.text.red = 255
defaults.display.text.green = 255
defaults.display.text.blue = 255
defaults.display.text.alpha = 255
defaults.display.text.size = 11
defaults.other_size = 6 -- text size for characters that are in another zone
defaults.align = 'right' -- 'left' or 'right' text alignment in the info list

settings = config.load(defaults)
box = texts.new("", settings.display, settings)

-- Separate, smaller box for characters that are in a different zone.
-- Not linked to settings, so it doesn't save its own position; it follows the main box, and dragging it
-- moves the main box (which is what gets saved).
other_box = texts.new("", {
    pos = {x = settings.display.pos.x, y = settings.display.pos.y},
    bg = {
        red = settings.display.bg.red,
        green = settings.display.bg.green,
        blue = settings.display.bg.blue,
        alpha = settings.display.bg.alpha,
    },
    text = {
        font = settings.display.text.font,
        red = settings.display.text.red,
        green = settings.display.text.green,
        blue = settings.display.text.blue,
        alpha = settings.display.text.alpha,
        size = settings.other_size,
    },
    flags = {draggable = true}, -- dragging it moves the whole list (see updateInfo)
})

follow_me = 0
following = false
target = nil
last_target = nil
min_dist = settings.min^2
max_dist = 50.0^2
repeated = false
running = false
tracking = true -- followers report their position unless the leader turns it off

track_info = T{}
current_player = nil
last_layout = ''
layout_refresh = 0
was_active = false
check_started = 0 -- when the last "are you still loaded?" check began
check_deadline = nil -- when that check ends and non-responders are removed
check_timeout = 1.0 -- seconds to wait for replies (replies normally arrive within a frame or two)
last_pong = 0

-- Keep track of when the addon loads or the player logs in
windower.register_event('load', function()
    clearTrackingInfo()
    updateCurrentPlayer()
end)

-- Clear tracking when addon is unloaded
windower.register_event('unload', function()
    -- Don't send anything extra here (it crashes on reload); other characters drop us via the alive check.
    windower.send_command('ffo stop')
    coroutine.sleep(0.25) -- Reduce crash on reload, since Windower seems to crash if IPC messages are received as it's restarting.
end)

-- Handle character changes/logout
windower.register_event('login', function(name)
    clearTrackingInfo()
    updateCurrentPlayer()
end)

windower.register_event('logout', function()
    follow_me = 0
    following = false
    target = nil
    last_target = nil
    running = false
    tracking = true
    
    clearTrackingInfo()
    current_player = nil
end)

-- Check for zone changes which could indicate character switching
windower.register_event('zone change', function(new_id, old_id)
    updateCurrentPlayer()
end)

-- Update current player information
function updateCurrentPlayer()
    local player = windower.ffxi.get_player()
    if player then
        -- If current player has changed, clear tracking info
        if current_player and current_player ~= player.name then
            clearTrackingInfo()
        end
        current_player = player.name
    end
end

-- Clear tracking information
function clearTrackingInfo()
    track_info = T{}
    hideBoxes()
end

function showHelp()
  local lines = {
    'FastFollow commands (//ffo or //fastfollow):',
    '  help                     - show this list',
    '  <name>                   - follow that character (same as follow <name>)',
    '  follow <name>            - follow that character',
    '  me | followme            - make all other characters follow this one',
    '  stop                     - stop following (this character only)',
    '  stopall                  - stop following on all characters',
    '  info [on|off]            - toggle (or set) the distance list on all characters',
    '  size <main> [other]      - text size of the list and of other-zone names (4-32)',
    '  align left|right         - text alignment of the info list',
    '  min <distance>           - how close to get to the leader (0.2-10)',
    '  clear                    - clear this character\'s list',
  }
  for _, line in ipairs(lines) do
    windower.add_to_chat(207, line)
  end
end

windower.register_event('addon command', function(command, ...)
  command = command and command:lower() or nil
  local args = T{...}
  
  if not command or command == 'help' then
    showHelp()
  elseif command == 'followme' or command == 'me' then
    local me = windower.ffxi.get_mob_by_target('me')
    if not me then
      if not repeated then
        repeated = true
        windower.send_command('@wait 1; ffo followme')
      else
        repeated = false
      end
      return
    end
    
    repeated = false
    windower.send_ipc_message('follow '..me.name)
    windower.send_ipc_message('track '..(settings.show and 'on' or 'off'))
  elseif command == 'stop' then
    if following then windower.send_ipc_message('stopfollowing '..following) end
    following = false
    if running then windower.ffxi.run(false) end
    running = false
  elseif command == 'stopall' then
    follow_me = 0
    following = false
    if running then windower.ffxi.run(false) end
    running = false
    windower.send_ipc_message('stop')
  elseif command == 'follow' then
    if #args == 0 then
      return windower.add_to_chat(0, 'FastFollow: You must provide a player name to follow.')
    end
    following = args[1]:lower()
    startAliveCheck()
    target = nil
    last_target = nil
    windower.send_ipc_message('following '..following)
    windower.ffxi.follow()
  elseif command == 'info' then
    if not args[1] then
      settings.show = not settings.show
    elseif args[1] == 'on' then
      settings.show = true
    elseif args[1] == 'off' then
      settings.show = false
    end
    
    windower.send_ipc_message('track '..(settings.show and 'on' or 'off'))
    
    config.save(settings)
  elseif command == 'size' then
    local size = tonumber(args[1])
    local other = tonumber(args[2])
    if not size then
      return windower.add_to_chat(0, 'FastFollow: Usage: ffo size <main> [other-zone] (current: '..tostring(settings.display.text.size)..' '..tostring(settings.other_size)..')')
    end
    
    size = math.min(math.max(4, size), 32)
    settings.display.text.size = size
    box:size(size)
    
    if other then
      other = math.min(math.max(4, other), 32)
      settings.other_size = other
      other_box:size(other)
    end
    config.save(settings)
  elseif command == 'align' then
    local side = args[1] and args[1]:lower()
    if side ~= 'left' and side ~= 'right' then
      return windower.add_to_chat(0, 'FastFollow: Usage: ffo align left|right (current: '..tostring(settings.align)..')')
    end

    settings.align = side
    last_layout = '' -- force the small box to be repositioned
    config.save(settings)
    windower.add_to_chat(0, 'FastFollow: Info list aligned '..side..'.')
  elseif command == 'min' then
    local dist = tonumber(args[1])
    if not dist then return end
    
    dist = math.min(math.max(0.2, dist), 10)
    
    settings.min = dist
    min_dist = settings.min^2
    config.save(settings)
  elseif command == 'clear' then
    clearTrackingInfo()
    windower.add_to_chat(0, 'FastFollow: Tracking information cleared.')
  elseif command then
    windower.send_command('ffo follow '..command)
  end
end)

windower.register_event('ipc message', function(msgStr)
  local args = msgStr:lower():split(' ')
  local command = args:remove(1)
  
  if command == 'stop' then
    follow_me = 0
    following = false
    running = false
    windower.ffxi.run(false)
  elseif command == 'follow' then
    if following then windower.send_ipc_message('stopfollowing '..following) end
    following = args[1]
    startAliveCheck()
    target = nil
    last_target = nil
    windower.send_ipc_message('following '..following)
    windower.ffxi.follow()
  elseif command == 'following' then
    local me = windower.ffxi.get_player()
    if not me or me.name:lower() ~= args[1] then return end
    follow_me = follow_me + 1
  elseif command == 'stopfollowing' then
    local me = windower.ffxi.get_player()
    if not me or me.name:lower() ~= args[1] then return end
    follow_me = math.max(follow_me - 1, 0)
  elseif command == 'update' then
    local zone_id = tonumber(args[2])
    local x, y = tonumber(args[3]), tonumber(args[4])
    if not x or not y then return end
    
    track_info[args[1]] = {x=x, y=y, zone=zone_id, time=os.clock()}
    
    if not following or args[1] ~= following then return end
    
    target = {x=x, y=y, zone=zone_id}
    
    if not last_target then last_target = target end
    
    if target.zone ~= -1 and (target.x ~= last_target.x or target.y ~= last_target.y or target.zone ~= last_target.zone) then
      last_target = target
    end
  elseif command == 'ping' then
    -- Someone is starting a follow and checking who is still loaded. Answer so we stay on their list,
    -- and run the same check on our own list (we hear everyone's replies too, so no extra messages needed).
    sendPong()
    local now = os.clock()
    if next(track_info) ~= nil and not (check_deadline and now < check_deadline) then
      beginAliveCheck(now)
    end
  elseif command == 'pong' then
    local entry = args[1] and track_info[args[1]]
    if entry then entry.time = os.clock() end
  elseif command == 'track' then
    tracking = args[1] == 'on'
  elseif command == 'cleartracking' then
    clearTrackingInfo()
  end
end)

windower.register_event('prerender', function()
  runAliveCheck()
  updateInfo()
  
  local me = windower.ffxi.get_mob_by_target('me')
  local info = windower.ffxi.get_info()
  
  if not me or not info then return end
  
  -- When a follow involving us begins, check which listed characters are still loaded.
  local active = (follow_me > 0 or following) and true or false
  if active and not was_active then startAliveCheck() end
  was_active = active
  
  -- Original broadcasting: only while someone is following us, or while we are following (if tracking is on).
  if follow_me > 0 then
    windower.send_ipc_message('update '..me.name..' '..info.zone..' '..me.x..' '..me.y)
  end
  
  if following then
    if tracking and follow_me <= 0 then
      windower.send_ipc_message('update '..me.name..' '..info.zone..' '..me.x..' '..me.y)
    end
    
    if not target then
      if running then
        windower.ffxi.run(false)
        running = false
      end
      return
    end
    
    local distSq = distanceSquared(target, me)
    local len = math.sqrt(distSq)
    if len < 1 then len = 1 end
    
    if target.zone == info.zone and distSq > min_dist and distSq < max_dist then
      windower.ffxi.run((target.x - me.x)/len, (target.y - me.y)/len)
      running = true
    elseif target.zone == info.zone and distSq <= min_dist then
      windower.ffxi.run(false)
      running = true
    elseif running then
      windower.ffxi.run(false)
      running = false
    end
  end
end)

function updateInfo()
  if not settings.show then
    hideBoxes()
    return
  end
  
  -- Save the list position shortly after the small box stops being dragged.
  if drag_save_at and os.clock() >= drag_save_at then
    drag_save_at = nil
    config.save(settings)
  end

  local me = windower.ffxi.get_mob_by_target('me')
  local info = windower.ffxi.get_info()

  if not me or not info then
    hideBoxes()
    return
  end
  
  -- Entries stay up after follows end. They go away when they fail the alive check
  -- at the start of a follow, or on 'ffo clear'.
  local names = T{}
  for char, _ in pairs(track_info) do
    names:insert(char)
  end
  table.sort(names)
  
  -- Characters in another zone ("--") go in their own smaller box above the main list.
  local other_lines = T{}
  local same_lines = T{}
  -- Left-align names in a fixed-width column and give distances a fixed width,
  -- so the text doesn't shift sideways when a distance gains or loses a digit.
  local nameWidth = 1
  for _, char in ipairs(names) do nameWidth = math.max(nameWidth, #char) end
  
  local right = settings.align == 'right'
  for _, char in ipairs(names) do
    local pos = track_info[char]
    local label = right and char:lpad(' ', nameWidth) or char:rpad(' ', nameWidth)
    if pos.zone == info.zone then
      same_lines:insert(label..string.format(' %6.2f', math.sqrt(distanceSquared(me, pos))))
    else
      other_lines:insert(label..' --')
    end
  end
  
  setBox(box, same_lines)
  setBox(other_box, other_lines)
  
  -- Stack the other-zone box directly above the main box (below it if there is no room above).
  -- Layout is only recalculated when something changes (not every frame) to keep the per-frame work light.
  if #other_lines > 0 then
    local x, y = box:pos()

    -- Dragging the small box moves the whole list: shift the main box by the same amount.
    if other_ex then
      local cx, cy = other_box:pos()
      local dx, dy = cx - other_ex, cy - other_ey
      if math.abs(dx) > 1 or math.abs(dy) > 1 then
        x, y = x + dx, y + dy
        box:pos(x, y)
        other_ex, other_ey = cx, cy
        drag_save_at = os.clock() + 0.5
      end
    end

    local key =tostring(x)..','..tostring(y)..','..#other_lines..','..#same_lines..','..tostring(settings.align)
    if key ~= last_layout then
      last_layout = key
      layout_refresh = 3 -- a few frames, since box sizes lag a frame behind text changes
    end
    
    if layout_refresh > 0 then
      layout_refresh = layout_refresh - 1
      local other_w, other_h = other_box:extents()
      local main_w, main_h = box:extents()
      local ox, oy = x, y
      if #same_lines > 0 then
        oy = y - other_h
        if oy < 0 then oy = y + main_h end
        -- With right alignment, line the small box's right edge up with the main box's.
        if right then ox = x + main_w - other_w end
      end
      other_box:pos(ox, oy)
      other_ex, other_ey = ox, oy
    end
  else
    last_layout = ''
    other_ex = nil
  end
end

function setBox(b, lines)
  if #lines == 0 then
    b:text("")
    b:visible(false)
    return
  end
  
  b:text(table.concat(lines, '\n'))
  b:visible(true)
end

-- When a follow starts, ask every loaded character to answer. Anyone on the list who doesn't answer
-- (or send any other message) within check_timeout seconds is removed completely.
function startAliveCheck()
  local now = os.clock()
  if check_deadline and now < check_deadline then return end -- a check is already running
  
  -- Always ping, even if our own list is empty: other characters use the ping to clean their lists.
  if next(track_info) ~= nil then beginAliveCheck(now) end
  windower.send_ipc_message('ping')
  sendPong() -- so everyone hears from us too
end

function beginAliveCheck(now)
  check_started = now
  check_deadline = now + check_timeout
end

function sendPong()
  local now = os.clock()
  if now - last_pong < 1.0 then return end
  last_pong = now
  
  local me = windower.ffxi.get_player()
  if me then windower.send_ipc_message('pong '..me.name) end
end

function runAliveCheck()
  if not check_deadline then return end
  
  local now = os.clock()
  if now < check_deadline then return end
  
  check_deadline = nil
  for char, entry in pairs(track_info) do
    if entry.time < check_started then
      track_info[char] = nil
    end
  end
end

function hideBoxes()
  box:text("")
  box:visible(false)
  other_box:text("")
  other_box:visible(false)
end

function distanceSquared(A, B)
  local dx = B.x-A.x
  local dy = B.y-A.y
  return dx*dx + dy*dy
end

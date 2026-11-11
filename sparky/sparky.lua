require 'pack'
require 'lists'
require 'strings'
res = require 'resources'
packets = require 'packets'


_addon.name = 'Sparky'
_addon.version = '1'
_addon.author = 'Byrth'
_addon.commands = {'sparky'}

item = 12385 -- Default to Acheron's Shield
number_to_sell = nil
current_sparks = nil
print_code = false
start_buying = false
appraise = false
start_selling = true
last_seq = nil

option_strings = {
    [12385]={str=string.char(9,0,0x29,0),cost=2755}, -- Acheron's Shield
    [12302]={str=string.char(8,0,0x24,0),cost=473}, -- Darksteel Buckler
    [16834]={str=string.char(4,0,0xE,0),cost=60}, -- Brass Spear
    [17081]={str=string.char(4,0,0x15,0),cost=60}, -- Brass Rod
    [16407]={str=string.char(4,0,0,0),cost=60}, -- Brass Baghnakhs
    [12680]={str=string.char(5,0,0x1F,0),cost=141}, -- Chain Mittens
    [12936]={str=string.char(5,0,0x21,0),cost=129}, -- Greaves
    [12299]={str=string.char(3,0,0x3F,0),cost=50,id=12299}, -- Aspis
    [16704]={str=string.char(3,0,0xC,0),cost=50}, -- Butterfly Axe
    [16390]={str=string.char(3,0,0x1,0),cost=50}, -- Bronze Knuckles
    [16900]={str=string.char(3,0,0x12,0),cost=50}, -- Wakizashi
    [16960]={str=string.char(4,0,0x12,0),cost=68}, -- Uchigatana
    [16419]={str=string.char(7,0,2,0),cost=416}, -- Patas
    [16406]={str=string.char(5,0,1,0),cost=144}, -- Baghnakhs
    [16470]={str=string.char(9,0,2,0),cost=300}, -- Gully
    [13871]={str=string.char(6,0,0x43,0),cost=302}, -- Iron Visor
    [13783]={str=string.char(6,0,0x44,0),cost=464}, -- Iron Scale Mail
    [12938]={str=string.char(7,0,0x32,0),cost=322}, -- Sollerets
    [16644]={str=string.char(6,0,0x0D,0),cost=540}, -- Mythril Axe
}

purge_items = S{
	5945, --Prize Powder
    3297, --Flame Geode
    3298, --Snow Geode
    3299, --Breeze Geode
    3300, --Soil Geode
    3301, --Thunder Geode
    3302, --Aqua Geode
    3303, --Light Geode
    3304, --Shadow Geode

    3520, --Ifritite
    3521, --Shivite
    3522, --Garudite
    3523, --Titanite
    3524, --Ramuite
    3525, --Leviatite
    3526, --Carbite
    3527, --Fenrite

    12385, --Acheron shield

    626, --Black Pepper
    643, --Iron Ore
    645, --Darksteel Ore
    685, --Khroma Ore
    3920, --Vanadium Ore
    1469, --Wootz Ore
    3928, --Velkk Necklace
    20772, --Voay Sword -1
    638, --Sage
    4386, --King Truffle
    623, --Bay Leaves
    2112, --Vanilla
    2155, --Lesser Chigoe
    4402, --Red Terrapin
    1771, --Dragon Bone
    1695, --Habaneros
    700, --Mahogany Log
    690, --Elm Log
    3993, --Grove Cuttings
    4478, --Three-eyed fish
    5965, --Isleracea
    1522, --Fresh Marjoram
    635, --Win. Tea Leaves
    5474, --Ca Cuong
    881, --Crab Shell
    1193, --H.Q. Crab Shell
    612, --Kazham Peppers
    614, --Mhaura Garlic
    4424, --Melon Juice
    1236, --Cactus Stems
    5138, --Black Ghost
    895, --Ram Horn
    4304, --Grimmonite
    4020, --Titanium Ore
    897, --Scorpion Claw
    835, --Flax Flower
    4473, --Crescent Fish
    1590, --Holy Basil
    5984, --Gnatbane
    4566, --Deathball
    2763, --Swamp Ore
    4384, --Black Sole


    2290, -- Imperial Cermet

    4199, -- Strength Potion
    4201, -- Dexterity Potion
    4203, -- Vitality Potion
    4205, -- Agility Potion
    4207, -- Intelligence Potion
    4209, -- Mind Potion
    4211, -- Charisma Potion

    4167, -- Cracker
    4168, -- Twinkle Shower
    4183, -- Konron Hassen
    4169, -- Little Comet
    4184, -- Kongou Inaho
    4185, -- Meifu Goma
    4186, -- Ariborn
    4215, -- Popstar
    4216, -- Brilliant Snow
    4217, -- Sparkling Hand
    4218, -- Air Rider
    4250, -- Crackler
    4251, -- Festive Fan
    4252, -- Summer Fan
    4253, -- Spirit Masque
    4256, -- Ouka Ranman
    4257, -- Papillion
    5360, -- Muteppo
    5361, -- Datechochin
    5441, -- Angelwing
    5725, -- Goshikitenge
    5769, -- Popper
    5881, -- Shisai Kaboku
    5882, -- Marine Bliss
    5883, -- Falling Star
    6457, -- Flarelet
    5884, -- Rengedama
    5936, -- Mog Missile
    5532, -- Ichinin. Koma
    6268, -- Komanezumi
    5937, -- Bubble Breeze


    4096, -- Fire crystal
    4097, -- Ice Crystal
    4098, -- Wind crystal
    4099, -- Earth crystal
    4100, -- Lightning Crystal
    4101, -- Water Crystal
    4102, -- Light Crystal
    4103, -- Dark Crystal
    17088, -- Ash Staff
    16465, -- Bronze Knife
    17034, -- Bronze Mace
    16565,--Spatha
    19224,--Musketoon

    4370, -- Honey
    3941, -- Chapuli Wing
    3932, -- Chapuli Horn
    2150, -- Colibri Feather
    925, -- Giant Stinger
    --4358, --hare meat
    856, --rabbit hide
    926,  --lizard tail
    852,  --lizard skin
    4362, -- lizard egg
--        853,  --raptor skin
--        3930, --twitherym wing
    3936, -- Acuex Poison
    2506, -- Ladybug wing
    5566, -- Date
    5908, -- Butterpear
    2417, -- Aht Urghan Brass



    2784, -- Fire Fewell
    2785, -- Ice Fewell
    2786, -- Wind Fewell
    2787, -- Earth Fewell
    2788, -- Lightning Fewell
    2789, -- Water Fewell
    2790, -- Light Fewell
    2791, -- Dark Fewell

--        750, --Silver Beastcoin
    3541, -- Seasoning Stone
    922, -- Bat Wing
    891, -- Bat Fang

    858, -- Wolf Hide
    1691,--Giant Scale
    868, -- Pugil Scales

--        955, -- Golem Shard
    1689, -- Recollection of Guilt
    1687, -- Recollection of Fear
    1688, -- Recollection of Pain

    769, -- Red Rock
    770, -- Blue Rock
    771, -- Yellow Rock
    772, -- Green Rock
    773, -- Translucent Rock
    774, -- Purple Rock
    775, -- Black Rock
    776, -- White Rock

    4114, -- Potion +2
    4118, -- Hi-Potion +2
    4119, -- Hi-Potion +3
    4122, -- X-Potion +2
    4123, -- X-Potion +2
    4454, -- Emperor Fish

    698, -- Ash Log
    951, -- Wijnruit
    4504, -- Acorn
    4767, -- Scroll of Stone
    4388, -- Eggplant
    4363, -- Faerie Apple
    5966, --Ulbuconut
    620, -- Tarutaru Rice
--        690, -- Elm Log
    693, -- Walnut Log
    691, -- Maple Log
    727, -- Dogwood Log
    923, -- Dryad Root
    941, -- Red Rose
    1524, -- Fresh Mugwort
    2213, -- Pine Nuts
    5661, -- Walnut
    4491, -- Watermelon
    642, -- Zinc Ore
    1650, -- Kopparnickle Ore
    900, -- Fish Bones
    882, -- Sheep Tooth
--        644, -- Mythril Ore
    1984, -- Snapping Mole
    4468, -- Pamamas
    5964, -- Felicifruit
    1982, -- King Locust
    613, -- Faded Crystal
    582, -- Meteorite
    894, -- Beetle Jaw
    1654, -- Igneous Rock
    2417, -- Aht Urhgan Brass
    768, -- Flint Stone
    641, -- Tin Ore
    2305, -- Auric Sand
    5235, -- Napa
    5650, -- Nopales
--        1236, -- Cactus Stems
--        17396, -- Little Worm
    4899, -- Earth Spirit Pact
    3934, -- Matamata Shell
    639, -- Chestnut
--        736, -- Silver Ore
    1845, -- Red Moko Grass
    1983, -- Mushroom Locust
    834, -- Saruta Cotton
    833, -- Moko Grass
    1981, -- Skull Locust
    4365, -- Rolanberry
    880, -- Bone Chip
    948, -- Carnation
--        643, -- Iron Ore
    775, -- Black Rock
    4445, -- Yagudo Cherry
    1228, -- Darksteel Nugget
    17296, -- Pebble
--        640, -- Copper Ore
    2960, -- Water Lily
    3942, -- Locust Elutriator

    4018, -- Guatambu Log
    3926, -- Urunday Log
    694, -- Chestnut Log
    4273, -- Kitron
    4274, -- Persikos
    4461, -- Bastore Bream
    4474, -- Gigant Squid
    4479, -- Bhefhel Marlin
    740, -- Phrygian Ore
    896, -- Scorpion Shell
    1618, -- Uragnite Shell
    1309, -- Gold Leaf
    1473, -- H.Q. Scp. Shell
    1622, -- Bugard Tusk
    21191, -- Voay Staff -1
    8709, -- Raaz Tusk
    2765, -- Fool's Gold Ore
    2427, -- Wivre Maul
    5604, -- El. Pachira Fruit
    4399, -- Bluetail
    702, -- Ebony Log
    3929, -- Velkk Mask
    903, -- Dragon Talon
    4446, -- Pumpkin Pie
    4288, -- Zebra Eel
    5950, -- Mackerel
    885, -- Turtle Shell
    1237, -- Tree Cuttings
    1446, -- Lacquer Tree Log
    1616, -- Antlion Jaw
    2496, -- Anc. Beast Horn
    2408, -- Flocon-de-mer
    3915, -- Saffron Blossom
    722, -- Divine Log
    4138, -- Super Ether +2
    4477, -- Gavial Fish
    4475, -- Sea Zombie

    784, -- Jadeite
    785, -- Emerald
    786, -- Ruby
    787, -- Diamond
    788, -- Peridot
    789, -- Topaz
    790, -- Garnet
    791, -- Aquamarine
    792, -- Pearl
    793, -- Black Pearl
    794, -- Sapphire
    795, -- Lapis Lazuli
    796, -- Light Opal
    797, -- Painite
    798, -- Turquoise
    799, -- Onyx
    800, -- Amethyst
    801, -- Chrysoberyl
    802, -- Moonstone
    803, -- Sunstone
    804, -- Spinel
    805, -- Zircon
    806, -- Tourmaline
    807, -- Sardonyx
    808, -- Goshenite
    809, -- Clear Topaz
    810, -- Fluorite
    811, -- Ametrine
    812, -- Deathstone
    813, -- Angelstone
    814, -- Amber
    815, -- Sphene

    4401, -- Moat Carp
    4428, -- Dark Bass
    5952, -- Ruddy Seema
    4464, -- Pipira
    5960, -- Ulbukan Lobster
    5948, -- Black Prawn
    4514, -- Quus
    5463, -- Yayinbaligi
    5959, -- Dragonfish
    4429, -- Black Eel
    4469, -- Giant Catfish
    4484, -- Shall Shell
    4515, -- Copper Frog
    4579, -- Elshimo Newt
    5121, -- Moorish Idol
    5536, -- Yorchete
    5651, -- Burdock
    5662, -- Dragon Fruit
    5951, -- Bloodblotch
    5128, -- Cone Calamary
    5961, -- Contortopus
    6145, -- Dwarf Remora
    5954, -- Barnacle
    5469, -- Brass Loach
    --4480, -- Gugru Tuna
    3965, -- Adoulinian Kelp
    4427, -- Gold Carp
    5963, -- Senroh Sardine
    4472, -- Crayfish


    924, -- Fiend Blood

    842, -- Giant Bird Feather
    14242, -- Rusty Subligar
    14117, -- Rusty Leggings
    688, -- Arrowwood Log
    4443, -- Cobalt Jellyfish
    90, -- Rusty Bucket
    861, -- Tiger Hide
    884, -- Black Tiger Fang
    846, -- Insect Wing
    912, -- Beehive Chip
    839, -- Crawler Cocoon
    4373, -- Woozyshroom
    4375, -- Danceshroom
    4374, -- Sleepshroom
    4570, -- Bird Egg
    847, -- Bird Feather
    5569, -- Puk Egg
    2148, -- Puk Wing
    2229, -- Chimera Blood
    }

sparks_npcs = L{'Eternal Flame','Rolandienne','Isakoth','Fhelm Jobeizat'}

items_to_sell = L{}
appraised = S{}
buying = nil

windower.register_event('outgoing chunk',function(id,org,mod,inj)
    local seq = org:unpack('H',3)
    if not last_seq then last_seq = seq end
    if not inj and seq ~= last_seq then
        last_seq = seq
        if start_selling and items_to_sell:length()>0 then
            local item_tab = items_to_sell:remove(1)
            windower.packets.inject_outgoing(0x84,string.char(0x84,0x06,0,0)..'I':pack(item_tab.count)..'H':pack(item_tab.id)..string.char(item_tab.slot,0))
            windower.packets.inject_outgoing(0x85,string.char(0x85,0x04,0,0)..'I':pack(1))
        elseif buying then
            buy_one()
        end
    end
    if not inj and id == 0x05B then
        local name = (windower.ffxi.get_mob_by_id(org:unpack('I',5)) or {}).name
        if name == 'Ardrick' then
            return org:sub(1,8)..string.char(1,0,60,0)..org:sub(13)
        end
    end
end)

windower.register_event('addon command',function(...)
    local commands = {...}
    local first = table.remove(commands,1):lower()
    if first then
        if first == 'buy' then
            local second = table.remove(commands,1)
            second = tonumber(second)
            for i,v in pairs(windower.ffxi.get_mob_array()) do
                if v.name and sparks_npcs:contains(v.name) and math.sqrt(v.distance)<10 and windower.ffxi.get_player().status == 0 then
                    windower.packets.inject_outgoing(0x1A,string.char(0x1A,0xE,0,0)..'IHHHHIII':pack(v.id,v.index,0,0,0,0,0,0))
                    start_buying = tonumber(second) and second or true
                    break
                end
            end
        elseif first == 'sell' then
            local second = table.remove(commands,1)
            if tonumber(second) then
                number_to_sell = tonumber(second)
            else
                number_to_sell = nil
            end
            if not res.items[item] then
                print('Sparky: Item cannot be sold because id is not in the resources')
            elseif res.items[item].flags['No NPC Sale'] then
                print('Sparky: Item cannot be sold because it is unsellable')
            else
                items_to_sell = L{}
                local inv = windower.ffxi.get_items(0)
                for i,v in ipairs(inv) do
                    if v.id and v.id == item then
                        items_to_sell:append(v)
                        if number_to_sell and number_to_sell == items_to_sell:length() then break end
                    end
                end
                if items_to_sell:length() > 0 then
                    windower.packets.inject_outgoing(0x84,string.char(0x84,0x06,0,0)..'I':pack(items_to_sell[1].count)..'H':pack(item)..string.char(items_to_sell[1].slot,0))
                    appraise = true
                end
            end
        elseif first == 'item' then
            local pot_item = table.concat(commands,' '):lower()
            if tonumber(pot_item) and res.items[tonumber(pot_item)] then
                item = tonumber(pot_item)
                pot_item = nil
                print('Sparky: Item is now '..res.items[item].en)
            else
                counter = 0
                for i,v in pairs(res.items) do
                    if v.en and v.en:lower() == pot_item then
                        item = i
                        pot_item = nil
                        print('Sparky: Item is now '..res.items[item].en)
                        break
                    end
                    counter = counter + 1
                    if counter%1000 == 0 then
                        coroutine.sleep(0.04) -- Sleep 1 frame every 1000 items searched to avoid lagging people out
                    end
                end
            end
            if pot_item then
                print('Sparky: Item not found. Item is still '..res.items[item].en)
            end
        elseif first == 'purge' then
            if not res.items[item] then
                print('Sparky: Item cannot be sold because id is not in the resources')
            elseif res.items[item].flags['No NPC Sale'] then
                print('Sparky: Item cannot be sold because it is unsellable')
            else
                items_to_sell = L{}
                appraised = S{}
                local inv = windower.ffxi.get_items(0)
                for i,v in ipairs(inv) do
                    if v.id and purge_items:contains(v.id) then
                        items_to_sell:append(v)
                        if number_to_sell and number_to_sell == items_to_sell:length() then break end
                    end
                end

                for _,v in ipairs(items_to_sell) do
                    if not appraised:contains(v.id) then
                        windower.packets.inject_outgoing(0x84,string.char(0x84,0x06,0,0)..'I':pack(v.count)..'H':pack(v.id)..string.char(v.slot,0))
                        appraised:append(v.id)
                    end
                end
            end
        elseif first == 'powder' then
            local second = (table.remove(commands,1) or ''):lower()
            if second == 'debug' then
                powder_start('debug')
            elseif second == 'peek' then
                powder_start('peek')
            elseif second == 'max' or second == '' then
                powder_start('max')
            elseif tonumber(second) and tonumber(second) >= 1 then
                powder_start(math.floor(tonumber(second)))
            else
                print('Sparky: Usage: //sparky powder <count|max>')
            end
        elseif first == 'log' then
            sparks_log_toggle()
        elseif first == 'sellpowder' then
            start_sell(powder.item_id)
        elseif first == 'hud' then
            hud_command(commands)
        elseif first == 'print' then
            print_code = not print_code
            print('Sparky: Print is now set to '..tostring(print_code))
        end
    end
end)

function buy_one()
    if buying and buying.number > 0 then
        buying.number = buying.number - 1
        windower.packets.inject_outgoing(0x5B,buying.buy_packet)
    end
    if buying and buying.number <= 0 then
        windower.packets.inject_outgoing(0x5B,buying.end_packet)
        buying = nil
    end
end

windower.register_event('incoming chunk',function(id,org)
    if id == 0x034 and sparks_npcs:contains(windower.ffxi.get_mob_by_id(org:unpack('I',5)).name) and option_strings[item] and start_buying then
        local current_sparks = org:unpack('I',13)
        local weekly_cap = org:unpack('I',29) -- menu param 5: remaining weekly sparks cap
        local inv_stats = windower.ffxi.get_bag_info(0)
        local can_afford = math.floor(current_sparks/option_strings[item].cost)
        local cap_afford = math.floor(weekly_cap/option_strings[item].cost)
        if cap_afford < can_afford then
            print('Sparky: Weekly sparks cap leaves '..weekly_cap..' sparks, limiting purchase to '..cap_afford)
        end
        buying = {
            number = math.min(can_afford,cap_afford,inv_stats.max - inv_stats.count),
            buy_packet = string.char(0x5B,0xA,0,0)..org:sub(5,8)..option_strings[item].str..org:sub(0x29,0x2A)..string.char(1,0)..org:sub(0x2B,0x2E),
            end_packet = string.char(0x5B,0xA,0,0)..org:sub(5,8)..string.char(1,0,0,0)..org:sub(0x29,0x2A)..string.char(0,0)..org:sub(0x2B,0x2E)
            }
        if type(start_buying) == 'number' then
            buying.number = math.min(buying.number,start_buying)
        end
        local spent = (buying.number or 0) * option_strings[item].cost
        buy_one()
        start_buying = false
        if spent > 0 then
            -- Estimate for the HUD; the next menu open or currency packet corrects it.
            coroutine.schedule(function()
                hud.sparks = math.max((hud.sparks or current_sparks) - spent, 0)
                hud.sparks_cap = math.max((hud.sparks_cap or weekly_cap) - spent, 0)
                hud_update()
            end, 0.5)
        end
        return true
    elseif id == 0x03D and appraise then
        appraise = false
        start_selling = true
    elseif id == 0x00A then
        appraised = S{}
    end
end)


--------------------------------------------------------------------------------
-- Prize Powder (Unity NPC) buying:  //sparky powder <count|max>
--------------------------------------------------------------------------------
powder = {
    item_id = 5945,
    item_idx = 12,        -- Prize Powder's menu index on the Unity NPC
    stack = 99,
    cost = 10,            -- accolades per powder
    max_count = 7920,     -- 80 slots * 99
}

unity_npcs = {
    [230] = 'Urbiolaine',        -- Southern San d'Oria
    [235] = 'Igsli',             -- Bastok Markets
    [241] = 'Teldro-Kesdrodo',   -- Windurst Woods
    [256] = 'Nunaarl Bthtrogg',  -- Western Adoulin
}

unity = nil             -- active purchase session
unity_last = {}         -- last packet header seen per id (duplicate filter)
unity_accolades = nil   -- latest accolades from the server (incoming 0x113)
powder_wait = nil       -- set while waiting for the accolades reply

function unity_send_choice(option, uk1, automated)
    packets.inject(packets.new('outgoing', 0x05B, {
        ['Target'] = unity.npc_id,
        ['Option Index'] = option,
        ['_unknown1'] = uk1,
        ['Target Index'] = unity.npc_index,
        ['Automated Message'] = automated,
        ['_unknown2'] = 0,
        ['Zone'] = unity.zone,
        ['Menu ID'] = unity.menu_id,
    }))
end

-- Leave the NPC event (same exit packets the old Prize.lua used).
function unity_finish()
    if unity and unity.count == 'debug' then
        powder_flush()
    end
    if unity and unity.menu_id then
        unity_send_choice(0, 16384, false)
        local me = windower.ffxi.get_mob_by_target('me')
        if me then
            packets.inject(packets.new('outgoing', 0x016, {['Target Index'] = me.index}))
        end
    end
    unity = nil
end

-- How many powder fit in the inventory: free slots * 99, plus room left in partial stacks.
function powder_capacity()
    local bag = windower.ffxi.get_bag_info(0)
    local room = (bag.max - bag.count) * powder.stack
    for _,v in ipairs(windower.ffxi.get_items(0)) do
        if v.id == powder.item_id and v.count < powder.stack then
            room = room + (powder.stack - v.count)
        end
    end
    return math.min(room, powder.max_count)
end

function unity_find_npc()
    local zone = windower.ffxi.get_info().zone
    local name = unity_npcs[zone]
    if not name then
        return nil, 'Not in a zone with a Unity NPC'
    end
    for _,v in pairs(windower.ffxi.get_mob_array()) do
        if v.name == name then
            if math.sqrt(v.distance) < 6 then
                return v, zone
            end
            return nil, 'Too far from '..name
        end
    end
    return nil, 'Cannot find '..name
end

-- Step 1: checks, then ask the server for current accolades (same request autounm uses).
function powder_start(count)
    if unity or powder_wait then
        print('Sparky: Powder purchase already in progress')
        return
    end
    local player = windower.ffxi.get_player()
    if not player or player.status ~= 0 then
        print('Sparky: Must be standing idle')
        return
    end
    local npc, zone = unity_find_npc()
    if not npc then
        print('Sparky: '..zone)
        return
    end
    if count ~= 'debug' and count ~= 'peek' and powder_capacity() < 1 then
        print('Sparky: Inventory full')
        return
    end

    if count == 'debug' then
        powder_debug_lines = {}
    end
    powder_wait = {count = count}
    local wait = powder_wait
    windower.packets.inject_outgoing(0x10F, '0000')
    coroutine.schedule(function()
        if powder_wait == wait then
            powder_wait = nil
            print('Sparky: No accolades reply from the server')
        end
    end, 3)
end

-- Step 2 (runs when the accolades reply arrives): poke the NPC and open the menu.
function powder_begin(count)
    local npc, zone = unity_find_npc()
    if not npc then
        print('Sparky: '..zone)
        return
    end

    unity = {npc_id = npc.id, npc_index = npc.index, zone = zone, count = count, accolades = unity_accolades, stage = 'menu'}
    unity_last = {}
    local session = unity

    packets.inject(packets.new('outgoing', 0x01A, {
        ['Target'] = npc.id,
        ['Target Index'] = npc.index,
        ['Category'] = 0,
        ['Param'] = 0,
        ['_unknown1'] = 0,
    }))

    coroutine.schedule(function()
        if unity == session then
            print('Sparky: Timed out waiting for the NPC')
            unity_finish()
        end
    end, 10)
end

-- Debug output goes to the console and is also saved to powder_debug.txt in the addon folder.
powder_debug_lines = {}

function powder_log(s)
    print('Sparky: '..s)
    powder_debug_lines[#powder_debug_lines + 1] = s
end

function powder_flush()
    local path = windower.addon_path..'powder_debug.txt'
    local f = io.open(path, 'w')
    if f then
        f:write(table.concat(powder_debug_lines, '\n')..'\n')
        f:close()
        print('Sparky: Debug output saved to '..path)
    else
        print('Sparky: Could not write '..path)
    end
end

-- Log every numeric field of a parsed packet (used by //sparky powder debug).
function powder_dump(p)
    local keys = {}
    for k,v in pairs(p) do
        if type(k) == 'string' and type(v) == 'number' then
            keys[#keys + 1] = k
        end
    end
    table.sort(keys)
    for _,k in ipairs(keys) do
        powder_log(('%s = %d'):format(k, p[k]))
    end
end

-- Raw hex of a packet, 16 bytes per line (used by //sparky powder debug).
function powder_hex(label, data)
    powder_log(('--- %s: raw hex (%d bytes) ---'):format(label, #data))
    for i = 1, #data, 16 do
        local row = {}
        for j = i, math.min(i + 15, #data) do
            row[#row + 1] = ('%02X'):format(data:byte(j))
        end
        powder_log(('%04X: %s'):format(i - 1, table.concat(row, ' ')))
    end
end

-- Log eight 32-bit params starting at 1-based byte offset `start`, in decimal and hex.
function powder_params(start, data)
    for i = 0, 7 do
        local off = start + i * 4
        if off + 3 <= #data then
            local v = data:unpack('I', off)
            powder_log(('param %d = %d (0x%08X)'):format(i, v, v))
        end
    end
end

windower.register_event('incoming chunk', function(id, data)
    -- Currency reply: Sparks / Unity Accolades
    if id == 0x113 then
        local p = packets.parse('incoming', data)
        if p and powder_wait and powder_wait.count == 'debug' then
            powder_log('--- currency packet (0x113) ---')
            powder_dump(p)
            powder_hex('0x113 currency', data)
        end
        unity_accolades = p and p['Unity Accolades']
        if powder_wait then
            local wait = powder_wait
            powder_wait = nil
            if unity_accolades then
                powder_begin(wait.count)
            else
                print('Sparky: Could not read accolades from the server')
            end
        end
        return
    end

    if not unity then return end
    if id == 0x037 then return true end
    if id ~= 0x034 and id ~= 0x032 and id ~= 0x05C then return end

    local hdr = data:sub(1, 4)
    if unity_last[id] == hdr then return true end
    unity_last[id] = hdr

    if id == 0x05C then
        if unity.count == 'peek' then
            if unity.stage == 'item' then
                hud.acc_cap = data:unpack('I', 17)
                hud.acc_time = os.time()
                hud_update()
                unity.stage = 'count'
                unity_send_choice(powder.item_idx * 32 + 3, 0, true)
            elseif unity.stage == 'count' then
                unity_finish()
            end
            return true
        end
        if unity.count == 'debug' then
            -- Debug: log the event-update packets at each step, never send the quantity.
            powder_log('--- event update (0x05C) at stage: '..tostring(unity.stage)..' ---')
            powder_params(5, data)
            powder_hex('0x05C '..tostring(unity.stage), data)
            if unity.stage == 'item' then
                unity.stage = 'count'
                unity_send_choice(powder.item_idx * 32 + 3, 0, true)
            elseif unity.stage == 'count' then
                unity_finish()
            end
            return true
        end
        if unity.stage == 'item' then
            -- Param 3 of this first event update is the remaining weekly accolade cap (100,000/week).
            -- (The quantity-stage packet does not always carry it, so read it here.)
            unity.cap = data:unpack('I', 17)
            unity.stage = 'count'
            unity_send_choice(powder.item_idx * 32 + 3, 0, true)
        elseif unity.stage == 'count' then
            local cap = unity.cap
            if not cap then
                print('Sparky: Could not read the weekly accolade cap')
                unity_finish()
                return true
            end
            local cap_count = math.floor(cap / powder.cost)
            hud.acc_cap = cap
            hud.acc_time = os.time()
            if cap_count < 1 then
                print('Sparky: Weekly accolade cap reached (remaining '..cap..')')
                unity_finish()
                return true
            end
            if cap_count < unity.final then
                print('Sparky: Weekly cap leaves '..cap..' accolades; reducing '..unity.final..' to '..cap_count)
                unity.final = cap_count
            end
            unity.stage = 'done'
            local c = unity.final
            local spent = c * powder.cost
            hud.acc_cap = math.max(cap - spent, 0)
            hud.acc = math.max((unity.accolades or hud.acc or 0) - spent, 0)
            hud_update()
            unity_send_choice((c % 8) * 8192 + powder.item_idx * 32 + 4, math.floor(c / 8), true)
            local session = unity
            coroutine.schedule(function()
                if unity == session then unity_finish() end
            end, 1)
        end
        return true
    end

    -- 0x034 / 0x032: the NPC's menu
    if data:unpack('I', 5) ~= unity.npc_id then return end
    if unity.stage ~= 'menu' then
        if unity.count == 'debug' then
            powder_hex(('0x%03X (stage %s)'):format(id, tostring(unity.stage)), data)
        end
        return true
    end

    local p = packets.parse('incoming', data)
    unity.menu_id = p and p['Menu ID']
    if not unity.menu_id or unity.menu_id == 0 then
        print('Sparky: Could not read the NPC menu')
        unity = nil
        return
    end

    if unity.count == 'debug' then
        powder_log('--- NPC menu parameters (0x034) ---')
        powder_params(9, data)
        powder_hex('0x034 menu', data)
        -- Continue into the item and quantity screens so their packets get logged.
        unity.stage = 'item'
        unity_send_choice(10, 0, true)
        return true
    end

    if unity.count == 'peek' then
        -- HUD refresh: go to the quantity prompt to read the cap, buy nothing.
        unity.stage = 'item'
        unity_send_choice(10, 0, true)
        return true
    end

    local room = powder_capacity()
    local affordable = math.floor(unity.accolades / powder.cost)
    local count
    if unity.count == 'max' then
        count = math.min(room, affordable)
    else
        count = math.min(unity.count, room, affordable)
    end

    if count < 1 then
        print('Sparky: Nothing to buy (room for '..room..', accolades '..unity.accolades..')')
        unity_finish()
        return true
    end

    local note = ''
    if unity.count ~= 'max' and count < unity.count then
        note = ' (reduced from '..unity.count..')'
    end
    print('Sparky: Buying '..count..' Prize Powder'..note..' - accolades '..unity.accolades)

    unity.final = count
    unity.stage = 'item'
    unity_send_choice(10, 0, true)
    return true
end)


--------------------------------------------------------------------------------
-- Passive packet logger for finding the weekly Sparks cap:  //sparky log
-- Turn it on, talk to a sparks NPC yourself, open the item list / quantity
-- prompt, then turn it off.  Nothing is sent to the server.
-- Output goes to sparks_debug.txt in the addon folder.
--------------------------------------------------------------------------------
sparks_log_lines = nil  -- non-nil while logging

local function slog(s)
    sparks_log_lines[#sparks_log_lines + 1] = s
end

local function shex(label, data)
    slog(('--- %s: raw hex (%d bytes) ---'):format(label, #data))
    for i = 1, #data, 16 do
        local row = {}
        for j = i, math.min(i + 15, #data) do
            row[#row + 1] = ('%02X'):format(data:byte(j))
        end
        slog(('%04X: %s'):format(i - 1, table.concat(row, ' ')))
    end
end

local function sparams(start, data)
    for i = 0, 7 do
        local off = start + i * 4
        if off + 3 <= #data then
            local v = data:unpack('I', off)
            slog(('param %d = %d (0x%08X)'):format(i, v, v))
        end
    end
end

function sparks_log_toggle()
    if sparks_log_lines then
        local path = windower.addon_path..'sparks_debug.txt'
        local f = io.open(path, 'w')
        if f then
            f:write(table.concat(sparks_log_lines, '\n')..'\n')
            f:close()
            print('Sparky: Log saved to '..path)
        else
            print('Sparky: Could not write '..path)
        end
        sparks_log_lines = nil
    else
        sparks_log_lines = {}
        print('Sparky: Logging on. Open the sparks NPC and item screen, then run //sparky log again.')
    end
end

windower.register_event('incoming chunk', function(id, data)
    if not sparks_log_lines then return end
    if id == 0x034 or id == 0x032 or id == 0x05C then
        slog(('=== incoming 0x%03X ==='):format(id))
        sparams(id == 0x05C and 5 or 9, data)
        shex(('0x%03X'):format(id), data)
    elseif id == 0x110 or id == 0x113 or id == 0x118 then
        slog(('=== incoming 0x%03X ==='):format(id))
        shex(('0x%03X'):format(id), data)
    end
end)

windower.register_event('outgoing chunk', function(id, data)
    if not sparks_log_lines then return end
    if id == 0x05B or id == 0x01A then
        slog(('=== outgoing 0x%03X ==='):format(id))
        shex(('0x%03X (out)'):format(id), data)
    end
end)


--------------------------------------------------------------------------------
-- Sell all of one item id (used by the HUD's Prize Powder sell button).
-- Same flow as //sparky sell; the vendor's shop menu must be open.
--------------------------------------------------------------------------------
function start_sell(id)
    if not res.items[id] then
        print('Sparky: Item cannot be sold because id is not in the resources')
        return
    elseif res.items[id].flags['No NPC Sale'] then
        print('Sparky: Item cannot be sold because it is unsellable')
        return
    end
    items_to_sell = L{}
    for _,v in ipairs(windower.ffxi.get_items(0)) do
        if v.id and v.id == id then
            items_to_sell:append(v)
        end
    end
    if items_to_sell:length() > 0 then
        windower.packets.inject_outgoing(0x84,string.char(0x84,0x06,0,0)..('I'):pack(items_to_sell[1].count)..('H'):pack(id)..string.char(items_to_sell[1].slot,0))
        appraise = true
    else
        print('Sparky: No '..res.items[id].en..' in inventory')
    end
end


--------------------------------------------------------------------------------
-- HUD:  //sparky hud            show / hide
--       //sparky hud reset      move it back to the default spot
--       //sparky hud sparkscap <n>   total weekly sparks cap, to show "left / total"
-- Drag it by the title bar.  Sparks cap updates whenever a sparks NPC menu opens;
-- the accolades cap updates on purchases and when you click Refresh.
--------------------------------------------------------------------------------
texts = require('texts')
config = require('config')

hud_settings = config.load({pos = {x = 40, y = 300}, sparks_total = 0})
ACCOLADES_WEEKLY_CAP = 100000

hud = {
    x = tonumber(hud_settings.pos.x) or 40,
    y = tonumber(hud_settings.pos.y) or 300,
    visible = true,
    sparks = nil, sparks_cap = nil, sparks_time = nil,
    acc = nil, acc_cap = nil, acc_time = nil,
    last = {},
}

local function hud_box(text, bg)
    return texts.new(text, {
        pos = {x = 0, y = 0},
        text = {font = 'Consolas', size = 10, stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0}},
        bg = {alpha = 190, red = bg[1], green = bg[2], blue = bg[3]},
        flags = {draggable = false},
        padding = 3,
    })
end

local BUY_BG, SELL_BG, INFO_BG = {35, 95, 55}, {110, 45, 45}, {20, 20, 20}

hud_title = hud_box(' Sparky ', {40, 40, 40})
hud_sparks = hud_box(' ', INFO_BG)
hud_acc = hud_box(' ', INFO_BG)

-- dx/dy are offsets from the HUD's top-left corner.
hud_layout_items = {
    {box = hud_title,  dx = 0, dy = 0},
    {box = hud_sparks, dx = 0, dy = 24},
    {box = hud_acc,    dx = 0, dy = 78},
}
hud_buttons = {
    {label = ' Buy Max ', dx = 0,   dy = 48,  cmd = 'sparky buy',         bg = BUY_BG},
    {label = ' Sell ',    dx = 80,  dy = 48,  cmd = 'sparky sell',        bg = SELL_BG},
    {label = ' Buy Max ', dx = 0,   dy = 102, cmd = 'sparky powder max',  bg = BUY_BG},
    {label = ' Sell ',    dx = 80,  dy = 102, cmd = 'sparky sellpowder',  bg = SELL_BG},
    {label = ' Refresh ', dx = 140, dy = 102, cmd = 'sparky powder peek', bg = {50, 60, 110}},
}
for _,b in ipairs(hud_buttons) do
    b.box = hud_box(b.label, b.bg)
    hud_layout_items[#hud_layout_items + 1] = b
end

function hud_layout()
    for _,e in ipairs(hud_layout_items) do
        e.box:pos(hud.x + e.dx, hud.y + e.dy)
    end
end

function hud_show()
    for _,e in ipairs(hud_layout_items) do e.box:show() end
end

function hud_hide()
    for _,e in ipairs(hud_layout_items) do e.box:hide() end
end

local function commas(n)
    local s = tostring(math.floor(n))
    local r
    repeat s, r = s:gsub('^(-?%d+)(%d%d%d)', '%1,%2') until r == 0
    return s
end

local function hud_set(box, key, s)
    if hud.last[key] ~= s then
        hud.last[key] = s
        box:text(s)
    end
end

local function cap_line(label, have, cap, total, stamp)
    local s = ' '..label..' '..(have and commas(have) or '?')..' | Cap left '..(cap and commas(cap) or '?')
    if total and total > 0 then
        s = s..' / '..commas(total)
    end
    if stamp then
        s = s..' ('..os.date('%H:%M', stamp)..') '
    else
        s = s..' '
    end
    return s
end

function hud_update()
    local name = (res.items[item] or {}).en or '?'
    hud_set(hud_title, 'title', ' Sparky - buying: '..name..' ')
    hud_set(hud_sparks, 'sparks', cap_line('Sparks', hud.sparks, hud.sparks_cap, tonumber(hud_settings.sparks_total), hud.sparks_time))
    hud_set(hud_acc, 'acc', cap_line('Accolades', hud.acc, hud.acc_cap, ACCOLADES_WEEKLY_CAP, hud.acc_time))
end

function hud_command(args)
    local a = (args[1] or ''):lower()
    if a == 'reset' then
        hud.x, hud.y = 40, 300
        hud_layout()
        hud.visible = true
        hud_show()
    elseif a == 'sparkscap' and tonumber(args[2]) then
        hud_settings.sparks_total = tonumber(args[2])
        config.save(hud_settings)
        hud_update()
        print('Sparky: Weekly sparks cap set to '..commas(tonumber(args[2])))
    else
        hud.visible = not hud.visible
        if hud.visible then hud_show() else hud_hide() end
    end
end

-- Mouse: click buttons (action fires on release over the same button) and drag by the title.
local hud_pressed, hud_dragging = nil, nil
windower.register_event('mouse', function(mtype, x, y, delta, blocked)
    if blocked or not hud.visible then return end
    if hud_dragging then
        if mtype == 0 then
            hud.x, hud.y = x - hud_dragging.dx, y - hud_dragging.dy
            hud_layout()
            return true
        elseif mtype == 2 then
            hud_dragging = nil
            return true
        end
        return
    end
    if mtype == 1 then
        for _,b in ipairs(hud_buttons) do
            if b.box:hover(x, y) then
                hud_pressed = b
                return true
            end
        end
        if hud_title:hover(x, y) then
            hud_dragging = {dx = x - hud.x, dy = y - hud.y}
            return true
        end
    elseif mtype == 2 and hud_pressed then
        local b = hud_pressed
        hud_pressed = nil
        if b.box:hover(x, y) then
            windower.send_command(b.cmd)
        end
        return true
    end
end)

-- Passive data feeds: sparks menu (current sparks + weekly cap) and the currency packet.
windower.register_event('incoming chunk', function(id, data)
    if id == 0x034 then
        local mob = windower.ffxi.get_mob_by_id(data:unpack('I', 5))
        if mob and sparks_npcs:contains(mob.name) then
            hud.sparks = data:unpack('I', 13)
            hud.sparks_cap = data:unpack('I', 29)
            hud.sparks_time = os.time()
            hud_update()
        end
    elseif id == 0x113 then
        local p = packets.parse('incoming', data)
        if p then
            hud.sparks = p['Sparks of Eminence'] or hud.sparks
            hud.acc = p['Unity Accolades'] or hud.acc
            hud_update()
        end
    end
end)

windower.register_event('logout', function() hud_hide() end)
windower.register_event('login', function()
    if hud.visible then hud_show() end
end)
windower.register_event('unload', function()
    hud_settings.pos.x, hud_settings.pos.y = hud.x, hud.y
    config.save(hud_settings)
end)

hud_layout()
hud_update()
hud_show()

-- Ask the server for the currency packet so sparks / accolades fill in right away.
if (windower.ffxi.get_info() or {}).logged_in then
    windower.packets.inject_outgoing(0x10F, '0000')
end

-- Keep the item name and timestamps fresh (cheap: text is only re-sent when it changes).
coroutine.schedule(function()
    while true do
        coroutine.sleep(2)
        hud_update()
    end
end, 0)

--[[
Armor Ledger - tracks every Artifact, Relic and Empyrean piece you are still missing or haven't fully upgraded,
and what items, currency and clears are still needed to finish them.

Install: put this folder in Windower/addons/ArmorLedger/ then  //lua load ArmorLedger
Commands: //armor or //al

  //armor  or  //armor gui [job] [kind]  open the window with job tabs, armor filters, and Unlocks, Cards,
                                     and Materials views. Drag the title bar or scroll with the mouse wheel.
  //armor summary [job] [kind]         progress grid in chat, one line per job (a piece per slot: head body hands legs feet)
  //armor missing [job] [kind]         pieces you own no version of, and what to obtain first
  //armor job <job> [kind]             every unfinished piece of that job with each step's materials (have/need)
  //armor need [job] [kind] [all]      shopping list: items and currency short for everything unfinished
  //armor clears [job] [kind]          unlock requirements (missions, Sortie, Dynamis - Divergence...) still open
  //armor next [job] [kind]            steps you could do right now, grouped by NPC
  //armor done <id> [job]              mark a requirement as cleared (//armor flags lists the ids)
  //armor undo <id> [job]              unmark it
  //armor flags [job]                  every requirement id and whether it counts as met
  //armor final 3|4                    treat +3 or +4 as the last Artifact/Relic tier (default 4; Empyrean ends at +3)
  //armor export                       write the whole report to addons/ArmorLedger/data/report_<name>.txt
Armor stored on storage slips is always included (talk to the Porter Moogle first so the slips are up to date).

Items count from every bag (and Rem's Tales stored with Monisette). Currency (Escha Beads, Gallimaufry,
Apollyon/Temenos Units) is read from the game's currency pages.

Recipe data was adapted from Reforge by Opo-Opo and BG Wiki. Armor Ledger only reads
your bags and never trades. Use Reforge (//frg start) to do the actual upgrades.
]]

_addon.name = 'Armor Ledger'
_addon.author = 'Maxom'
_addon.version = '0.1.0'
_addon.commands = {'armor', 'al'}

local res = require('resources')
local packets = require('packets')
local slips = require('slips')
local texts = require('texts')
local U = (function()
--[[
Upgrade data for Reforge.

Item names must match Windower/res/items.lua, either the short name (`en`) or the full name (`enl`).
Anything not marked "confirmed" comes from BG Wiki (Oct 2026) and hasn't been checked against a real trade.
Where the wiki gives no quantity for an ingredient, it is taken as 1.

Armor Ledger embeds this recipe data from Reforge along with its +4 furnaces, requirements,
and key items.

Reforge covers the upgrades that wait for a game day. For Artifact and Relic armor:
  old level 75 set (or its +1/+2) -> iL109 -> +1 -> +2 -> +3
And for Empyrean armor:
  old level 99 set (+1 or +2 only) -> iL109 -> +1 -> +2 -> +3
The Limbus +4 furnaces are instant; Armor Ledger's copy includes them (artifact4 / relic4).
]]

local upgrades = {}

-- First word of each reforged set's full item name: {artifact, relic, empyrean}
upgrades.jobs = {
    WAR = {"pummeler's", 'agoge', 'boii'},
    MNK = {"anchorite's", "hesychast's", 'bhikku'},
    WHM = {'theophany', 'piety', 'ebers'},
    BLM = {"spaekona's", "archmage's", 'wicce'},
    RDM = {'atrophy', 'vitiation', 'lethargy'},
    THF = {"pillager's", "plunderer's", "skulker's"},
    PLD = {'reverence', 'caballarius', "chevalier's"},
    DRK = {'ignominy', "fallen's", "heathen's"},
    BST = {'totemic', 'ankusa', 'nukumi'},
    BRD = {'brioso', 'bihu', 'fili'},
    RNG = {'orion', 'arcadian', 'amini'},
    SAM = {'wakido', 'sakonji', 'kasuga'},
    NIN = {'hachiya', 'mochizuki', 'hattori'},
    DRG = {'vishap', 'pteroslaver', "peltast's"},
    SMN = {"convoker's", 'glyphic', "beckoner's"},
    BLU = {"assimilator's", 'luhlaza', 'hashishin'},
    COR = {"laksamana's", 'lanun', "chasseur's"},
    PUP = {'foire', 'pitre', 'karagoz'},
    DNC = {'maxixi', 'horos', 'maculele'},
    SCH = {"academic's", 'pedagogy', 'arbatel'},
    GEO = {'geomancy', 'bagua', 'azimuth'},
    RUN = {'runeist', 'futhark', 'erilaz'},
}

-- Old level 75 sets that Monisette reforges into the iL109 sets. Full item names, head to feet.
-- Old Artifact can start from the NQ or +1 piece, old Relic from NQ, +1 or +2. GEO and RUN have none.
upgrades.old_sets = {
    WAR = {
        artifact = {"Fighter's Mask", "Fighter's Lorica", "Fighter's Mufflers", "Fighter's Cuisses", "Fighter's Calligae"},
        relic = {"Warrior's Mask", "Warrior's Lorica", "Warrior's Mufflers", "Warrior's Cuisses", "Warrior's Calligae"},
    },
    MNK = {
        artifact = {'Temple Crown', 'Temple Cyclas', 'Temple Gloves', 'Temple Hose', 'Temple Gaiters'},
        relic = {'Melee Crown', 'Melee Cyclas', 'Melee Gloves', 'Melee Hose', 'Melee Gaiters'},
    },
    WHM = {
        artifact = {"Healer's Cap", "Healer's Bliaut", "Healer's Mitts", "Healer's Pantaloons", "Healer's Duckbills"},
        relic = {"Cleric's Cap", "Cleric's Bliaut", "Cleric's Mitts", "Cleric's Pantaloons", "Cleric's Duckbills"},
    },
    BLM = {
        artifact = {"Wizard's Petasos", "Wizard's Coat", "Wizard's Gloves", "Wizard's Tonban", "Wizard's Sabots"},
        relic = {"Sorcerer's Petasos", "Sorcerer's Coat", "Sorcerer's Gloves", "Sorcerer's Tonban", "Sorcerer's Sabots"},
    },
    RDM = {
        artifact = {"Warlock's Chapeau", "Warlock's Tabard", "Warlock's Gloves", "Warlock's Tights", "Warlock's Boots"},
        relic = {"Duelist's Chapeau", "Duelist's Tabard", "Duelist's Gloves", "Duelist's Tights", "Duelist's Boots"},
    },
    THF = {
        artifact = {"Rogue's Bonnet", "Rogue's Vest", "Rogue's Armlets", "Rogue's Culottes", "Rogue's Poulaines"},
        relic = {"Assassin's Bonnet", "Assassin's Vest", "Assassin's Armlets", "Assassin's Culottes", "Assassin's Poulaines"},
    },
    PLD = {
        artifact = {'Gallant Coronet', 'Gallant Surcoat', 'Gallant Gauntlets', 'Gallant Breeches', 'Gallant Leggings'},
        relic = {'Valor Coronet', 'Valor Surcoat', 'Valor Gauntlets', 'Valor Breeches', 'Valor Leggings'},
    },
    DRK = {
        artifact = {'Chaos Burgeonet', 'Chaos Cuirass', 'Chaos Gauntlets', 'Chaos Flanchard', 'Chaos Sollerets'},
        relic = {'Abyss Burgeonet', 'Abyss Cuirass', 'Abyss Gauntlets', 'Abyss Flanchard', 'Abyss Sollerets'},
    },
    BST = {
        artifact = {'Beast Helm', 'Beast Jackcoat', 'Beast Gloves', 'Beast Trousers', 'Beast Gaiters'},
        relic = {'Monster Helm', 'Monster Jackcoat', 'Monster Gloves', 'Monster Trousers', 'Monster Gaiters'},
    },
    BRD = {
        artifact = {'Choral Roundlet', 'Choral Justaucorps', 'Choral Cuffs', 'Choral Cannions', 'Choral Slippers'},
        relic = {"Bard's Roundlet", "Bard's Justaucorps", "Bard's Cuffs", "Bard's Cannions", "Bard's Slippers"},
    },
    RNG = {
        artifact = {"Hunter's Beret", "Hunter's Jerkin", "Hunter's Bracers", "Hunter's Braccae", "Hunter's Socks"},
        relic = {"Scout's Beret", "Scout's Jerkin", "Scout's Bracers", "Scout's Braccae", "Scout's Socks"},
    },
    SAM = {
        artifact = {'Myochin Kabuto', 'Myochin Domaru', 'Myochin Kote', 'Myochin Haidate', 'Myochin Sune-Ate'},
        relic = {'Saotome Kabuto', 'Saotome Domaru', 'Saotome Kote', 'Saotome Haidate', 'Saotome Sune-Ate'},
    },
    NIN = {
        artifact = {'Ninja Hatsuburi', 'Ninja Chainmail', 'Ninja Tekko', 'Ninja Hakama', 'Ninja Kyahan'},
        relic = {'Koga Hatsuburi', 'Koga Chainmail', 'Koga Tekko', 'Koga Hakama', 'Koga Kyahan'},
    },
    DRG = {
        artifact = {'Drachen Armet', 'Drachen Mail', 'Drachen Finger Gauntlets', 'Drachen Brais', 'Drachen Greaves'},
        relic = {'Wyrm Armet', 'Wyrm Mail', 'Wyrm Finger Gauntlets', 'Wyrm Brais', 'Wyrm Greaves'},
    },
    SMN = {
        artifact = {"Evoker's Horn", "Evoker's Doublet", "Evoker's Bracers", "Evoker's Spats", "Evoker's Pigaches"},
        relic = {"Summoner's Horn", "Summoner's Doublet", "Summoner's Bracers", "Summoner's Spats", "Summoner's Pigaches"},
    },
    BLU = {
        artifact = {'Magus Keffiyeh', 'Magus Jubbah', 'Magus Bazubands', 'Magus Shalwar', 'Magus Charuqs'},
        relic = {'Mirage Keffiyeh', 'Mirage Jubbah', 'Mirage Bazubands', 'Mirage Shalwar', 'Mirage Charuqs'},
    },
    COR = {
        artifact = {"Corsair's Tricorne", "Corsair's Frac", "Corsair's Gants", "Corsair's Culottes", "Corsair's Bottes"},
        relic = {'Commodore Tricorne', 'Commodore Frac', 'Commodore Gants', 'Commodore Trews', 'Commodore Bottes'},
    },
    PUP = {
        artifact = {'Puppetry Taj', 'Puppetry Tobe', 'Puppetry Dastanas', 'Puppetry Churidars', 'Puppetry Babouches'},
        relic = {'Pantin Taj', 'Pantin Tobe', 'Pantin Dastanas', 'Pantin Churidars', 'Pantin Babouches'},
    },
    DNC = {
        artifact = {"Dancer's Tiara", "Dancer's Casaque", "Dancer's Bangles", "Dancer's Tights", "Dancer's Toe Shoes"},
        relic = {'Etoile Tiara', 'Etoile Casaque', 'Etoile Bangles', 'Etoile Tights', 'Etoile Toe Shoes'},
    },
    SCH = {
        artifact = {"Scholar's Mortarboard", "Scholar's Gown", "Scholar's Bracers", "Scholar's Pants", "Scholar's Loafers"},
        relic = {'Argute Mortarboard', 'Argute Gown', 'Argute Bracers', 'Argute Pants', 'Argute Loafers'},
    },
}

-- Old set pieces whose full name differs at some tier: full name without +N -> name used above
upgrades.old_aliases = {
    ["commodore's tricorne"] = 'Commodore Tricorne', -- the +2 is spelt differently
}

-- Old level 99 Empyrean sets that Monisette reforges into the iL109 Empyrean sets. Full item names, head to feet.
-- Only a +1 or +2 piece can be reforged, not the NQ. GEO and RUN have none.
upgrades.old_empyrean = {
    WAR = {"Ravager's Mask", "Ravager's Lorica", "Ravager's Mufflers", "Ravager's Cuisses", "Ravager's Calligae"},
    MNK = {"Tantra Crown", "Tantra Cyclas", "Tantra Gloves", "Tantra Hose", "Tantra Gaiters"},
    WHM = {"Orison Cap", "Orison Bliaut", "Orison Mitts", "Orison Pantaloons", "Orison Duckbills"},
    BLM = {"Goetia Petasos", "Goetia Coat", "Goetia Gloves", "Goetia Chausses", "Goetia Sabots"},
    RDM = {"Estoqueur's Chappel", "Estoqueur's Sayon", "Estoqueur's Gantherots", "Estoqueur's Fuseau", "Estoqueur's Houseaux"},
    THF = {"Raider's Bonnet", "Raider's Vest", "Raider's Armlets", "Raider's Culottes", "Raider's Poulaines"},
    PLD = {"Creed Armet", "Creed Cuirass", "Creed Gauntlets", "Creed Cuisses", "Creed Sabatons"},
    DRK = {"Bale Burgeonet", "Bale Cuirass", "Bale Gauntlets", "Bale Flanchard", "Bale Sollerets"},
    BST = {"Ferine Cabasset", "Ferine Gausape", "Ferine Manoplas", "Ferine Quijotes", "Ferine Ocreae"},
    BRD = {"Aoidos' Calot", "Aoidos' Hongreline", "Aoidos' Manchettes", "Aoidos' Rhingrave", "Aoidos' Cothurnes"},
    RNG = {"Sylvan Gapette", "Sylvan Caban", "Sylvan Glovelettes", "Sylvan Bragues", "Sylvan Bottillons"},
    SAM = {"Unkai Kabuto", "Unkai Domaru", "Unkai Kote", "Unkai Haidate", "Unkai Sune-ate"},
    NIN = {"Iga Zukin", "Iga Ningi", "Iga Tekko", "Iga Hakama", "Iga Kyahan"},
    DRG = {"Lancer's Mezail", "Lancer's Plackart", "Lancer's Vambraces", "Lancer's Cuissots", "Lancer's Schynbalds"},
    SMN = {"Caller's Horn", "Caller's Doublet", "Caller's Bracers", "Caller's Spats", "Caller's Pigaches"},
    BLU = {"Mavi Kavuk", "Mavi Mintan", "Mavi Bazubands", "Mavi Tayt", "Mavi Basmak"},
    COR = {"Navarch's Tricorne", "Navarch's Frac", "Navarch's Gants", "Navarch's Culottes", "Navarch's Bottes"},
    PUP = {"Cirque Cappello", "Cirque Farsetto", "Cirque Guanti", "Cirque Pantaloni", "Cirque Scarpe"},
    DNC = {"Charis Tiara", "Charis Casaque", "Charis Bangles", "Charis Tights", "Charis Toe Shoes"},
    SCH = {"Savant's Bonnet", "Savant's Gown", "Savant's Bracers", "Savant's Pants", "Savant's Loafers"},
}

-- Equipment slot index (as in res.items[id].slots) -> name
upgrades.slots = {[4] = 'head', [5] = 'body', [6] = 'hands', [7] = 'legs', [8] = 'feet'}
upgrades.slot_order = {'head', 'body', 'hands', 'legs', 'feet'}

-- Old set -> iL109 at Monisette. One game day. Rem's Tale Ch.1-5 by slot.
local monisette = {npc = 'Monisette', zone = 'Port Jeuno (I-8)'}
local il109_slot_item = {head = 'Phoenix Feather', body = 'Malboro Fiber', hands = 'Beetle Blood', legs = 'Damascene Cloth', feet = 'Oxblood'}

upgrades.artifact109 = {
    npc = monisette.npc, zone = monisette.zone,
    tales = {[0] = 10, [1] = 5}, -- Rem's Tales for an NQ or +1 piece
    chapter = {head = 1, body = 2, hands = 3, legs = 4, feet = 5},
    slot_item = il109_slot_item,
    job_item = {
        WAR = 'Tiger Leather', BST = 'Tiger Leather',
        MNK = 'Gold Thread', THF = 'Gold Thread', DNC = 'Gold Thread',
        WHM = 'Imp. Silk Cloth', BRD = 'Imp. Silk Cloth', BLU = 'Imp. Silk Cloth',
        BLM = 'Karakul Cloth', RNG = 'Karakul Cloth', COR = 'Karakul Cloth', PUP = 'Karakul Cloth',
        RDM = 'Scarlet Linen', SMN = 'Scarlet Linen', SCH = 'Scarlet Linen',
        PLD = 'Gold Sheet', DRG = 'Gold Sheet',
        DRK = 'Darksteel Sheet',
        SAM = 'Tama-Hagane', NIN = 'Tama-Hagane',
    },
    note = 'Needs Promathia Mission 7-5, then a chat with Sagheera ("Just wanted to chat").',
}

-- Each old Relic piece goes straight to iL109; lower starting pieces cost more Dynamis currency.
-- An augmented +2 costs the same as a plain one.
upgrades.relic109 = {
    npc = monisette.npc, zone = monisette.zone,
    tales = 10,
    chapter = {head = 1, body = 2, hands = 3, legs = 4, feet = 5},
    slot_item = il109_slot_item,
    currency_count = {[0] = 2, [1] = 1, [2] = 0}, -- for an NQ, +1 or +2 piece
    currency = {
        WAR = '100 Byne Bill', MNK = '100 Byne Bill', DRK = '100 Byne Bill', BRD = '100 Byne Bill',
        SAM = '100 Byne Bill', NIN = '100 Byne Bill', COR = '100 Byne Bill', SCH = '100 Byne Bill',
        WHM = 'M. Silverpiece', RDM = 'M. Silverpiece', PLD = 'M. Silverpiece', DRG = 'M. Silverpiece',
        BLU = 'M. Silverpiece', DNC = 'M. Silverpiece',
        BLM = 'L. Jadeshell', THF = 'L. Jadeshell', BST = 'L. Jadeshell', RNG = 'L. Jadeshell',
        SMN = 'L. Jadeshell', PUP = 'L. Jadeshell',
    },
    job_item = {
        WAR = 'Wootz Ore', PLD = 'Wootz Ore', DRK = 'Wootz Ore',
        MNK = 'Griffon Hide', RDM = 'Griffon Hide', THF = 'Griffon Hide', BRD = 'Griffon Hide',
        RNG = 'Griffon Hide', DRG = 'Griffon Hide', BLU = 'Griffon Hide',
        WHM = 'Sparkling Stone', BLM = 'Sparkling Stone', COR = 'Sparkling Stone',
        BST = 'Mammoth Tusk', DNC = 'Mammoth Tusk',
        SAM = 'Relic Iron', NIN = 'Relic Iron',
        SMN = 'Lancewood Log', PUP = 'Lancewood Log', SCH = 'Lancewood Log',
    },
}

-- Old Empyrean +1/+2 -> iL109 at Monisette. One game day. Rem's Tale Ch.1-5 by slot.
upgrades.empyrean109 = {
    npc = monisette.npc, zone = monisette.zone,
    tales = {[1] = 10, [2] = 5}, -- Rem's Tales for a +1 or +2 piece
    chapter = {head = 1, body = 2, hands = 3, legs = 4, feet = 5},
    slot_item = il109_slot_item,
    job_item = {
        WAR = 'Helm of Briareus', DRK = 'Helm of Briareus',
        MNK = 'Itzpapa. Scale',
        WHM = "Orthrus's Claw",
        BLM = 'Glavoid Shell',
        RDM = 'Cirein. Lantern',
        THF = "Alfard's Fang",
        PLD = "Kukulkan's Fang",
        BST = "Carabosse's Gem", SMN = "Carabosse's Gem", PUP = "Carabosse's Gem",
        BRD = "Dragua's Scale",
        RNG = "Ulhuadshi's Fang",
        SAM = 'Apademak Horn',
        NIN = "Bukhis's Wing",
        DRG = "Azdaja's Horn",
        BLU = "Isgebind's Heart",
        COR = "Sobek's Skin",
        DNC = 'Two-Leaf Chloris Bud',
        SCH = "Sedna's Tusk",
    },
}

-- iL109 -> +1 at Monisette. One game day. Rem's Tale Ch.6-10 by slot.
upgrades.artifact1 = {
    npc = monisette.npc, zone = monisette.zone,
    tales = 8,
    chapter = {head = 6, body = 7, hands = 8, legs = 9, feet = 10},
    slot_item = {head = 'Maliyakaleya Orb', body = 'Hepatizon Ingot', hands = 'Beryllium Ingot', legs = 'Exalted Lumber', feet = "Sif's Macrame"},
    job_item = {
        WAR = 'Behem. Leather', BST = 'Behem. Leather',
        MNK = 'Platinum Silk', THF = 'Platinum Silk', DNC = 'Platinum Silk',
        WHM = 'Raxa', BRD = 'Raxa', BLU = 'Raxa', GEO = 'Raxa',
        BLM = 'Twill Damask', RNG = 'Twill Damask', COR = 'Twill Damask', PUP = 'Twill Damask',
        RDM = "Siren's Hair", SMN = "Siren's Hair", SCH = "Siren's Hair",
        PLD = 'Orichalcum Sheet', DRG = 'Orichalcum Sheet',
        DRK = 'Durium Sheet',
        SAM = 'Damascus Ingot', NIN = 'Damascus Ingot', RUN = 'Damascus Ingot',
    },
}

upgrades.relic1 = {
    npc = monisette.npc, zone = monisette.zone,
    tales = 8,
    chapter = {head = 6, body = 7, hands = 8, legs = 9, feet = 10},
    slot_item = {head = 'Gabbrath Horn', body = 'Yggdreant Bole', hands = 'Bztavian Stinger', legs = 'Waktza Rostrum', feet = 'Rockfin Tooth'},
    job_item = {
        WAR = 'Voidwrought Plate', NIN = 'Voidwrought Plate', DRG = 'Voidwrought Plate',
        MNK = "Kaggen's Cuticle", THF = "Kaggen's Cuticle", BRD = "Kaggen's Cuticle", COR = "Kaggen's Cuticle",
        WHM = "Akvan's Pennon", BLM = "Akvan's Pennon", SCH = "Akvan's Pennon", GEO = "Akvan's Pennon",
        RDM = "Pil's Tuille", PLD = "Pil's Tuille", DRK = "Pil's Tuille", SAM = "Pil's Tuille", BLU = "Pil's Tuille",
        BST = "Hahava's Mail", SMN = "Hahava's Mail", PUP = "Hahava's Mail",
        RNG = "Celaeno's Cloth", DNC = "Celaeno's Cloth", RUN = "Celaeno's Cloth",
    },
}

-- Empyrean iL109 -> +1 at Monisette. One game day. The same for every job.
upgrades.empyrean1 = {
    npc = monisette.npc, zone = monisette.zone,
    tales = 8,
    chapter = {head = 6, body = 7, hands = 8, legs = 9, feet = 10},
    memories = {head = 15, body = 25, hands = 15, legs = 20, feet = 15}, -- Etched Memory
    slot_item = {head = 'Defiant Sweat', body = 'Dark Matter', hands = 'Macuil Horn', legs = 'Tartarian Chain', feet = 'Plovid Effluvium'},
    note = "Needs The Truth Beckons, and the slot's Vagary boss beaten "
        .. '(head Palloritus, body Plouton, hands Putraxia, legs Perfidien, feet Rancibus).',
}

-- +1 -> +2: the job ingredient is the same for Artifact and Relic.
upgrades.plus2_job_item = {
    WAR = 'S. Faulpie Leather', BST = 'S. Faulpie Leather', RNG = 'S. Faulpie Leather',
    MNK = 'Cypress Log', THF = 'Cypress Log', DNC = 'Cypress Log',
    WHM = 'Khoma Thread', BRD = 'Khoma Thread', BLU = 'Khoma Thread', GEO = 'Khoma Thread',
    BLM = 'Azure Leaf', COR = 'Azure Leaf', PUP = 'Azure Leaf',
    RDM = 'Cyan Coral', SMN = 'Cyan Coral', SCH = 'Cyan Coral',
    PLD = 'Ruthenium Ore', DRG = 'Ruthenium Ore',
    DRK = 'Niobium Ore', SAM = 'Niobium Ore', NIN = 'Niobium Ore', RUN = 'Niobium Ore',
}

-- Artifact +1 -> +2 at Coelestrox. One game day.
upgrades.artifact2 = {
    npc = 'Coelestrox', zone = 'Reisenjima',
    beads = 10,
    instant = 500, -- what the instant option costs; Reforge never picks it, it checks the menu shows this
    cards = {head = 4, body = 5, hands = 3, legs = 4, feet = 3},
    slot_item = {
        head = "Emperor Arthro's Shell", body = "Joyous's Moss", hands = "Imperator's Wing",
        legs = "Warblade Beak's Hide", feet = "Abyssdiver's Feather",
    },
}

-- Relic +1 -> +2 in Ru'Lude Gardens. One game day.
upgrades.relic2 = {
    npc = '??? (Aurix)', zone = "Ru'Lude Gardens (G-8)",
    shards = 2,
    slot_item = upgrades.relic1.slot_item,
}

-- Artifact +2 -> +3 at Coelestrox. Two trades, a game day apart.
-- Stopping partway loses everything already traded.
upgrades.artifact3 = {
    npc = 'Coelestrox',
    zone = 'Reisenjima',
    zone_id = 291,
    -- Escha Beads for the normal (wait a day) option, confirmed from the NPC's menu for both days (GEO, 2026-10-27).
    beads = {day1 = 200, day2 = 300},
    -- What the instant option would cost. Reforge never picks it; it checks the menu shows these numbers.
    instant = {day1 = 10000, day2 = 15000},
    -- Day 1: the +2 piece, P. cards for its job and the job's scale.
    -- Card counts are the same for every job since the May 2025 reduction.
    cards = {head = 12, body = 15, hands = 9, legs = 12, feet = 9},
    scale = {
        WAR = "Kin's Scale", MNK = "Kin's Scale", PLD = "Kin's Scale", DRK = "Kin's Scale", SAM = "Kin's Scale",
        THF = "Gin's Scale", NIN = "Gin's Scale", DNC = "Gin's Scale", RUN = "Gin's Scale",
        WHM = "Kei's Scale", BLM = "Kei's Scale", RDM = "Kei's Scale", BLU = "Kei's Scale", SCH = "Kei's Scale",
        BRD = "Kyou's Scale", RNG = "Kyou's Scale", COR = "Kyou's Scale", GEO = "Kyou's Scale",
        BST = "Fu's Scale", DRG = "Fu's Scale", SMN = "Fu's Scale", PUP = "Fu's Scale",
    },
    -- Day 2: crafted materials and Cyan Orbs, the same for every job. Feet confirmed for GEO on 2026-10-27.
    day2 = {
        head = {{'Khoma Cloth', 1}, {'S. Faulpie Leather', 1}, {'Cyan Orb', 2}},
        body = {{'Niobium Ingot', 1}, {'Cypress Lumber', 1}, {'Cyan Orb', 3}},
        hands = {{'Faulpie Leather', 3}, {'Cypress Log', 1}, {'Cyan Orb', 1}},
        legs = {{'Ruthenium Ingot', 1}, {'Cypress Lumber', 1}, {'Cyan Orb', 2}},
        feet = {{'Azure Cermet', 3}, {'Khoma Thread', 1}, {'Cyan Orb', 1}},
    },
}

-- Relic +2 -> +3 in Ru'Lude Gardens. Takes one game day.
-- Shards and voids are named per slot and job, e.g. "Footshard: GEO" and "Voidfoot: GEO".
-- The wiki says these counts were reduced in May 2025 but doesn't give the new ones.
upgrades.relic3 = {
    npc = '??? (Aurix)',
    zone = "Ru'Lude Gardens (G-8)",
    count = 2,
    shard = {head = 'Headshard', body = 'Torsoshard', hands = 'Handshard', legs = 'Legshard', feet = 'Footshard'},
    void = {head = 'Voidhead', body = 'Voidtorso', hands = 'Voidhand', legs = 'Voidleg', feet = 'Voidfoot'},
    material = {head = 'Defiant Scarf', body = "Hades' Claw", hands = 'Macuil Plating', legs = 'Tartarian Soul', feet = 'Plovid Flesh'},
}

-- Empyrean +1 -> +2 at Ruspix. One game day.
upgrades.empyrean2 = {
    npc = 'Ruspix',
    zone = 'Leafallia (H-8)',
    items = {{"Ra'Kaz. Sapphire", 1}},
    currency = {'Gallimaufry', 10000},
    note = 'Needs The Light Within, and a Sortie visit on that job.',
}

-- Empyrean +2 -> +3 at Ruspix. One game day (BG Wiki / FFXI Wiki).
upgrades.empyrean3 = {
    npc = 'Ruspix',
    zone = 'Leafallia (H-8)',
    items = {{"Ra'Kaz. Starstone", 1}},
    currency = {'Gallimaufry', 70000},
}


----------------------------------------------------------------------------------------------- Armor Ledger additions
-- Sources: FFXI Wiki category pages for Reforged Artifact/Relic/Empyrean armor (checked Nov 2026).

upgrades.job_order = {'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN'}

-- Highest tier each kind reaches
upgrades.max_tier = {artifact = 4, relic = 4, empyrean = 3}

-- Base Empyrean armor. Each job group uses one Scars zone and one Heroes zone.
-- https://www.bg-wiki.com/ffxi/Category:Empyrean_Armor
local abyssea_starts = {
    {scars = 'Attohwa', head = 'G-10', legs = 'G-8', heroes = 'Altepa', camp = 'K-5'},
    {scars = 'Misareaux', head = 'K-7', legs = 'I-7', heroes = 'Uleguerand', camp = 'G-11'},
    {scars = 'Vunkerl', head = 'F-4', legs = 'I-9', heroes = 'Grauberg', camp = 'D-14'},
}
local abyssea_jobs = {
    {'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF'},
    {'PLD', 'DRK', 'BST', 'BRD', 'RNG'},
    {'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH'},
}
upgrades.empyrean_starts = {}
for i, jobs in ipairs(abyssea_jobs) do
    local z = abyssea_starts[i]
    local source = {
        'Cruor Prospector, Abyssea - ' .. z.scars .. ' (' .. z.head .. ') | 5,000 Cruor',
        'Dominion Tactician, Abyssea - ' .. z.heroes .. ' (' .. z.camp .. ') | 1,500 Dominion Notes',
        'Cruor Prospector, Abyssea - ' .. z.heroes .. ' (' .. z.camp .. ') | 5,000 Cruor',
        'Bastion Prefect, Abyssea - ' .. z.scars .. ' (' .. z.legs .. ') | 300 Resistance Credits',
        'Gold Sturdy Pyxis, Abyssea - ' .. z.scars,
    }
    for _, job in ipairs(jobs) do upgrades.empyrean_starts[job] = source end
end

-- GEO and RUN obtain their starting pieces at iL109 in Adoulin.
upgrades.adoulin_starts = {
    GEO = {
        relic = 'Speak to Hestefa, Celennia Memorial Library, wearing all five Geomancy pieces',
        empyrean = 'Treasures of the Earth, Sylvie in Western Adoulin (I-5)',
    },
    RUN = {
        relic = 'Speak to Hestefa, Celennia Memorial Library, wearing all five Runeist pieces',
        empyrean = 'Epiphany, Octavernost in Western Adoulin (K-9)',
    },
}

-- https://pegasusxi.com/wiki/Category:Relic_Armor
-- Head, body, hands, legs, feet.
upgrades.relic_starts = {
    BLM = {
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Windurst / Buburimu",
        "Dynamis - Bastok / Qufim",
        "Dynamis - Jeuno / Valkurm",
    },
    BLU = {
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - San d'Oria / Qufim",
        "Dynamis - Bastok / Buburimu",
        "Dynamis - Windurst / Valkurm",
    },
    BRD = {
        "Dynamis - San d'Oria / Buburimu",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Bastok / Qufim",
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Jeuno / Valkurm",
    },
    BST = {
        "Dynamis - Windurst / Valkurm",
        "Dynamis - Bastok / Buburimu",
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - San d'Oria / Qufim",
        "Dynamis - Beaucedine / Tavnazia",
    },
    COR = {
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Jeuno / Buburimu",
        "Dynamis - San d'Oria / Valkurm",
        "Dynamis - Bastok / Qufim",
    },
    DNC = {
        "Dynamis - Bastok / Buburimu",
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Windurst / Valkurm",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Jeuno / Qufim",
    },
    DRG = {
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Jeuno / Qufim",
        "Dynamis - Bastok / Valkurm",
        "Dynamis - San d'Oria / Buburimu",
    },
    DRK = {
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Windurst / Buburimu",
        "Dynamis - Jeuno / Qufim",
        "Dynamis - Bastok / Valkurm",
    },
    MNK = {
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Jeuno / Qufim",
        "Dynamis - San d'Oria / Buburimu",
        "Dynamis - Bastok / Valkurm",
    },
    NIN = {
        "Dynamis - Windurst / Qufim",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - San d'Oria / Valkurm",
        "Dynamis - Jeuno / Buburimu",
    },
    PLD = {
        "Dynamis - Bastok / Qufim",
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - San d'Oria / Buburimu",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Windurst / Valkurm",
    },
    PUP = {
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Windurst / Qufim",
        "Dynamis - Jeuno / Valkurm",
        "Dynamis - San d'Oria / Buburimu",
    },
    RDM = {
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Bastok / Buburimu",
        "Dynamis - Jeuno / Qufim",
        "Dynamis - San d'Oria / Valkurm",
    },
    RNG = {
        "Dynamis - Jeuno / Qufim",
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Windurst / Valkurm",
        "Dynamis - San d'Oria / Buburimu",
        "Dynamis - Beaucedine / Tavnazia",
    },
    SAM = {
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Bastok / Qufim",
        "Dynamis - Windurst / Buburimu",
        "Dynamis - Jeuno / Valkurm",
    },
    SCH = {
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - San d'Oria / Valkurm",
        "Dynamis - Bastok / Qufim",
        "Dynamis - Windurst / Buburimu",
    },
    SMN = {
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Bastok / Buburimu",
        "Dynamis - Windurst / Valkurm",
        "Dynamis - San d'Oria / Qufim",
    },
    THF = {
        "Dynamis - Windurst / Valkurm",
        "Dynamis - Bastok / Buburimu",
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Jeuno / Qufim",
    },
    WAR = {
        "Dynamis - Windurst / Qufim",
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Jeuno / Buburimu",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - San d'Oria / Valkurm",
    },
    WHM = {
        "Dynamis - San d'Oria / Buburimu",
        "Dynamis - Beaucedine / Tavnazia",
        "Dynamis - Xarcabard / Tavnazia",
        "Dynamis - Jeuno / Qufim",
        "Dynamis - Windurst / Valkurm",
    },
}

-- +3 -> +4 in the Limbus furnaces. Instant. Same unit costs for both.
local furnace_cost = {head = 20000, body = 30000, hands = 15000, legs = 25000, feet = 10000}
upgrades.artifact4 = {npc = 'Apollyon Furnace', zone = 'Apollyon', currency = 'Apollyon Units', cost = furnace_cost}
upgrades.relic4 = {npc = 'Temenos Furnace', zone = 'Temenos', currency = 'Temenos Units', cost = furnace_cost}

-- Old Empyrean NQ -> +1 (Trial of the Magians, Magian Moogle with the blue puffball). Instant.
-- One Kupon I-Seal can be traded for the seals for a whole piece (the raw cost is 8 seals, 10 for body).
upgrades.empyrean_seals = {npc = 'Magian Moogle (blue puffball)', zone = 'Trial of the Magians', item = 'Kupon I-Seal', count = 1}

-- Dynamis - Divergence zones. Relic +2 needs the zone entered on the job; +3 needs its mid-boss
-- (or 100 squadron kills) on the job. Body needs all four.
upgrades.zone_name = {
    sandoria = "Dynamis - San d'Oria [D]",
    bastok = 'Dynamis - Bastok [D]',
    windurst = 'Dynamis - Windurst [D]',
    jeuno = 'Dynamis - Jeuno [D]',
}
upgrades.zone_slot = {sandoria = 'feet', bastok = 'hands', windurst = 'head', jeuno = 'legs'}
upgrades.slot_zones = {
    head = {'windurst'},
    body = {'sandoria', 'bastok', 'windurst', 'jeuno'},
    hands = {'bastok'},
    legs = {'jeuno'},
    feet = {'sandoria'},
}

-- Key items (lowercase: Armor Ledger lowercases res.key_items names before looking them up)
-- Relic +3: given once all four Divergence zones are done on the job (unlocks every slot).
upgrades.shard_ki = {
    WAR = "courageous warrior's shard",
    MNK = "dedicated monk's shard",
    WHM = "stalwart white mage's shard",
    BLM = "storied black mage's shard",
    RDM = "peerless red mage's shard",
    THF = "refined thief's shard",
    PLD = "elegant paladin's shard",
    DRK = "stoic dark knight's shard",
    BST = "fervent beastmaster's shard",
    BRD = "distinguished bard's shard",
    RNG = "relentless ranger's shard",
    SAM = "inimitable samurai's shard",
    NIN = "valiant ninja's shard",
    DRG = "heroic dragoon's shard",
    SMN = "learned summoner's shard",
    BLU = "unrivalled blue mage's shard",
    COR = "unparalleled corsair's shard",
    PUP = "dignified puppetmaster's shard",
    DNC = "graceful dancer's shard",
    SCH = "clever scholar's shard",
    GEO = "dynamic geomancer's shard",
    RUN = "ardent rune fencer's shard",
}
-- Empyrean +3: given the first time a Bitzer device is used on the job.
upgrades.soul_ki = {
    WAR = "courageous warrior's soul",
    MNK = "dedicated monk's soul",
    WHM = "stalwart white mage's soul",
    BLM = "storied black mage's soul",
    RDM = "peerless red mage's soul",
    THF = "refined thief's soul",
    PLD = "elegant paladin's soul",
    DRK = "stoic dark knight's soul",
    BST = "fervent beastmaster's soul",
    BRD = "distinguished bard's soul",
    RNG = "relentless ranger's soul",
    SAM = "inimitable samurai's soul",
    NIN = "valiant ninja's soul",
    DRG = "heroic dragoon's soul",
    SMN = "learned summoner's soul",
    BLU = "unrivalled blue mage's soul",
    COR = "unparalleled corsair's soul",
    PUP = "dignified puppetmaster's soul",
    DNC = "graceful dancer's soul",
    SCH = "clever scholar's soul",
    GEO = "dynamic geomancer's soul",
    RUN = "ardent rune fencer's soul",
}

-- scope 'char' = once per character, 'job' = once per job
local R = {}
local function req(id, scope, text) R[id] = {scope = scope, text = text} end
req('pm75', 'char', "Promathia Mission 7-5 (The Warrior's Path), for Al'Taieu access")
req('pm35', 'char', "Promathia Mission 3-5 (Darkness Named) and start the Dynamis quest line")
req('truth', 'char', 'Quest: The Truth Beckons (Empyrean iL119)')
req('light', 'char', 'Mission: The Light Within (Empyrean +2)')
req('orb', 'char', "Scintillating Rhapsody (mission: The Orb's Radiance)")
req('garden', 'char', 'Mission: Garden of Antiquity')
req('omen', 'char', 'Enter Omen at least once (Artifact +2/+3)')
req('apollyon', 'char', 'Apollyon verification key (Artifact +4)')
req('temenos', 'char', 'Temenos verification key (Relic +4)')
req('sortie', 'job', 'Sortie: Enter (unlocks Empyrean +2)')
req('bitzer', 'job', 'Sortie: Enter Basement (unlocks Empyrean +3)')
local vagary = {head = 'Palloritus', body = 'Plouton', hands = 'Putraxia', legs = 'Perfidien', feet = 'Rancibus'}
for _, slot in ipairs(upgrades.slot_order) do
    req('vag_' .. slot, 'char', 'Defeat Vagary ' .. vagary[slot] .. ' (or win the alternate Vagary battlefield): unlocks Empyrean ' .. slot)
end
for zone, name in pairs(upgrades.zone_name) do
    req('dd_' .. zone, 'job', 'Enter ' .. name .. ' on this job (Relic +2, ' .. upgrades.zone_slot[zone] .. ')')
    req('ddc_' .. zone, 'job', 'Beat the ' .. name .. ' mid-boss (or 100 squadron kills) on this job (Relic +3, ' .. upgrades.zone_slot[zone] .. ')')
end
upgrades.requirements = R

-- FFXIAH retail browse categories and vendor listings, keyed by Windower item ID.
-- https://www.ffxiah.com/browse
upgrades.material_sources = {}
for category, ids in pairs({
    ["Materials > Alchemy"] = {
        1110, 3491, 3980, 8986, 9002, 9007, 9062, 9063, 9257, 9258,
    },
    ["Materials > Bonecraft"] = {
        1311, 1458, 3977, 3979, 4012, 8720, 8983, 9005, 9061, 9255, 9256,
    },
    ["Materials > Clothcraft"] = {
        823, 836, 837, 844, 1132, 1313, 1699, 2200, 2288, 2340, 2476, 3449, 8728, 8979,
        8981, 9006, 9251, 9252,
    },
    ["Materials > Goldsmithing"] = {
        668, 752, 1470, 8722, 9249, 9250,
    },
    ["Materials > Leathercraft"] = {
        855, 862, 1516, 3445, 8988, 9003, 9253, 9254,
    },
    ["Materials > Smithing"] = {
        657, 658, 664, 758, 1466, 1469, 3447, 3490, 3492, 8724, 9004, 9064, 9247, 9248,
    },
    ["Materials > Woodworking"] = {
        1464, 4014, 8726, 9245, 9246,
    },
    ["Others > Misc 3"] = {
        1450, 1453, 1456, 9544, 9545, 9546, 9547, 9548, 9549, 9550, 9551, 9552, 9553, 9554,
        9555, 9556, 9557, 9558, 9559, 9560, 9561, 9562, 9563, 9564, 9565, 9566, 9567, 9568,
        9569, 9570, 9571, 9572, 9573, 9574, 9575, 9576, 9577, 9578, 9579, 9580, 9581, 9582,
        9583, 9584, 9585, 9586, 9587, 9588, 9589, 9590, 9591, 9592, 9593, 9594, 9595, 9596,
        9597, 9598, 9599, 9600, 9601, 9602, 9603, 9604, 9605, 9606, 9607, 9608, 9609, 9610,
        9611, 9612, 9613, 9614, 9615, 9616, 9617, 9618, 9619, 9620, 9621, 9622, 9623, 9624,
        9625, 9626, 9627, 9628, 9629, 9630, 9631, 9632, 9633, 9634, 9635, 9636, 9637, 9638,
        9639, 9640, 9641, 9642, 9643, 9644, 9645, 9646, 9647, 9648, 9649, 9650, 9651, 9652,
        9653, 9654, 9655, 9656, 9657, 9658, 9659, 9660, 9661, 9662, 9663, 9664, 9665, 9666,
        9667, 9668, 9669, 9670, 9671, 9672, 9673, 9674, 9675, 9676, 9677, 9678, 9679, 9680,
        9681, 9682, 9683, 9684, 9685, 9686, 9687, 9688, 9689, 9690, 9691, 9692, 9693, 9694,
        9695, 9696, 9697, 9698, 9699, 9700, 9701, 9702, 9703, 9704, 9705, 9706, 9707, 9708,
        9709, 9710, 9711, 9712, 9713, 9714, 9715, 9716, 9717, 9718, 9719, 9720, 9721, 9722,
        9723, 9724, 9725, 9726, 9727, 9728, 9729, 9730, 9731, 9732, 9733, 9734, 9735, 9736,
        9737, 9738, 9739, 9740, 9741, 9742, 9743, 9744, 9745, 9746, 9747, 9748, 9749, 9750,
        9751, 9752, 9753, 9754, 9755, 9756, 9757, 9758, 9759, 9760, 9761, 9762, 9763,
    },
}) do
    for _, id in ipairs(ids) do upgrades.material_sources[id] = {ah = category} end
end

-- Guild and shop listings from FFXIAH. Currency exchanges are listed below.
upgrades.material_sources[657].npcs = {
    "Amalasanda - Lower Jeuno",
    "Vuliaie - Norg",
    "Jabbar - Port Bastok",
    "Tsutsuroon - Nashmau",
}
upgrades.material_sources[823].npcs = {
    "Meriri / Kuzah Hpirohpon - Windurst Woods",
    "Tilala / Gibol - Selbina",
    "Tatan-Bilten - Bearclaw Pinnacle",
}
upgrades.material_sources[855].npcs = {
    "Kueh Igunahmori - Southern San d'Oria (D-8), Tanners' Guild (upper floor)",
}
upgrades.material_sources[855].stock = "Limited stock | 03:00-18:00 Vana'diel time | Closed Iceday"

-- Delve boss materials at the Mweya Plasm exchange, after the relevant Delve clear.
-- https://ffxiclopedia.fandom.com/wiki/Delve_Rewards
local delve_vendor = {"Forri-Porri - Western Adoulin (I-10), Mweya Plasm exchange"}
for _, id in ipairs({3977, 3979, 3980, 4012, 4014}) do upgrades.material_sources[id].npcs = delve_vendor end

-- Sortie material purchases require progress in Sortie.
-- https://ffxiclopedia.fandom.com/wiki/Ruspix
local sortie_vendor = {"Ruspix - Leafallia (H-8), Gallimaufry exchange"}
for _, id in ipairs({9927, 9928}) do upgrades.material_sources[id] = {npcs = sortie_vendor} end

return upgrades
end)()

local KINDS = {'artifact', 'relic', 'empyrean'}
local KIND_NAME = {artifact = 'Artifact', relic = 'Relic', empyrean = 'Empyrean'}
local KIND_SHORT = {artifact = 'AF', relic = 'RE', empyrean = 'EM'}
local KIND_ALIAS = {af = 'artifact', artifact = 'artifact', relic = 'relic', empy = 'empyrean', emp = 'empyrean',
    empyrean = 'empyrean'}
local SLOTS = U.slot_order
local SLOT_LETTER = {head = 'H', body = 'B', hands = 'A', legs = 'L', feet = 'F'}
local SKIP_BAGS = {[3] = true, [17] = true} -- temporary items, recycle bin

local WHITE, RED, GREEN, YELLOW = 207, 167, 158, 36

local emit = function(text, color) windower.add_to_chat(color or WHITE, text) end
local function say(text, color) emit(text, color) end

----------------------------------------------------------------------------------------------- settings

-- Per character: flags = {char = {id = true}, jobs = {JOB = {id = true}}}, final = 3 or 4
local settings = {char = {}, jobs = {}, aurix = {}, final = 4, gui = nil}
local player_name = nil

local function serialize(v)
    if type(v) == 'table' then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for _, k in ipairs(keys) do parts[#parts + 1] = string.format('[%q]=%s', tostring(k), serialize(v[k])) end
        return '{' .. table.concat(parts, ',') .. '}'
    elseif type(v) == 'string' then
        return string.format('%q', v)
    end
    return tostring(v)
end

local function data_path(name)
    return windower.addon_path .. 'data/' .. name
end

local function settings_file()
    return data_path('flags_' .. (player_name or 'unknown') .. '.lua')
end

local function save_settings()
    if not player_name then return end
    windower.create_dir(windower.addon_path .. 'data')
    local f = io.open(settings_file(), 'w')
    if not f then return say('Armor Ledger: could not write ' .. settings_file(), RED) end
    f:write('return ' .. serialize(settings) .. '\n')
    f:close()
end

local function load_settings()
    local info = windower.ffxi.get_info()
    local player = info and info.logged_in and windower.ffxi.get_player()
    player_name = player and player.name or nil
    settings = {char = {}, jobs = {}, aurix = {}, final = 4}
    if not player_name then return end
    local chunk = loadfile(settings_file())
    local ok, loaded = false, nil
    if chunk then ok, loaded = pcall(chunk) end
    if ok and type(loaded) == 'table' then
        settings.char = type(loaded.char) == 'table' and loaded.char or {}
        settings.jobs = type(loaded.jobs) == 'table' and loaded.jobs or {}
        settings.aurix = type(loaded.aurix) == 'table' and loaded.aurix or {}
        settings.ruspix = type(loaded.ruspix) == 'table' and loaded.ruspix or nil
        settings.final = loaded.final == 3 and 3 or 4
        settings.gui = type(loaded.gui) == 'table' and loaded.gui or nil
    end
end

local function final_tier(kind)
    return math.min(U.max_tier[kind], settings.final)
end

-- Dynamis - Divergence progress read from Aurix (see the Aurix sync section). settings.aurix[zone] holds two
-- job masks, dd (entered, Relic +2) and ddc (mid-boss beaten, Relic +3); bit N is the job at U.job_order[N].
local JOB_BIT = {}
for index, job in ipairs(U.job_order) do JOB_BIT[job] = index end

local function mask_has(mask, job)
    local bit = JOB_BIT[job]
    return type(mask) == 'number' and bit ~= nil and math.floor(mask / 2 ^ bit) % 2 == 1
end

local function aurix_flag(job, id)
    local kind, zone = id:match('^(ddc?)_(%a+)$')
    local entry = kind and settings.aurix and settings.aurix[zone]
    return entry ~= nil and mask_has(entry[kind], job)
end

-- Sortie progress read from Ruspix (see the Aurix sync section). settings.ruspix.locked is a job mask counted from
-- zero (bit 0 = WAR, bit 1 = MNK ...) of the jobs that have NOT entered Sortie yet; a clear bit means entered.
local function sortie_entered(job)
    local r = settings.ruspix
    local bit = JOB_BIT[job]
    return r ~= nil and type(r.locked) == 'number' and bit ~= nil and math.floor(r.locked / 2 ^ (bit - 1)) % 2 == 0
end

local AURIX_HOWTO = "Read Dynamis unlocks: Ru'Lude Gardens > talk to Aurix > View the List > Relic Armor."

local function aurix_unread(kind)
    return (not kind or kind == 'relic') and next(settings.aurix or {}) == nil
end

local function aurix_status()
    local newest = 0
    for _, entry in pairs(settings.aurix or {}) do
        if (entry.time or 0) > newest then newest = entry.time end
    end
    if newest == 0 then return 'Not read from Aurix yet.' end
    return 'Last read from Aurix: ' .. os.date('%Y-%m-%d %H:%M', newest) .. '.'
end

----------------------------------------------------------------------------------------------- items

local ids_by_name = nil -- lowercase short or full name -> item id, built on first use
local function item_id(name)
    if not ids_by_name then
        ids_by_name = {}
        for id, item in pairs(res.items) do
            for _, key in ipairs({item.en, item.enl}) do
                if key then
                    key = key:lower()
                    if not ids_by_name[key] then ids_by_name[key] = id end
                end
            end
        end
    end
    return ids_by_name[name:lower()]
end

local slot_index = {}
for i, slot in ipairs(SLOTS) do slot_index[slot] = i end

-- first word of a reforged set's long name -> {job, kind}
local set_of = {}
for job, words in pairs(U.jobs) do
    for i, word in ipairs(words) do set_of[word] = {job = job, kind = KINDS[i]} end
end

-- full name of an old set piece, lowercase and without +1/+2 -> {job, kind, slot}
local old_of = {}
for job, sets in pairs(U.old_sets) do
    for kind, names in pairs(sets) do
        for i, name in ipairs(names) do old_of[name:lower()] = {job = job, kind = kind, slot = SLOTS[i]} end
    end
end
for job, names in pairs(U.old_empyrean) do
    for i, name in ipairs(names) do old_of[name:lower()] = {job = job, kind = 'empyrean', slot = SLOTS[i]} end
end
for alias, name in pairs(U.old_aliases) do old_of[alias] = old_of[name:lower()] end

local function slot_name(slots)
    if type(slots) ~= 'table' then return nil end
    local found = nil
    for index in pairs(slots) do
        if found or not U.slots[index] then return nil end
        found = U.slots[index]
    end
    return found
end

-- Armor without a +N is labelled NQ so "Bagua Pants NQ -> +1" can't be misread
local function piece_label(item)
    return item.en:find(' %+%d$') and item.en or (item.en .. ' NQ')
end

-- {id, name, job, kind, slot, tier, old}, or nil when the item is not one of these sets
local function classify(id)
    local item = res.items[id]
    if not item or item.category ~= 'Armor' then return nil end
    local long = (item.enl or item.en or ''):lower()
    local tier = tonumber(long:match(' %+(%d)$')) or 0

    local old = old_of[(long:gsub(' %+%d$', ''))]
    if old then
        return {id = id, name = piece_label(item), job = old.job, kind = old.kind, slot = old.slot, tier = tier, old = true}
    end

    if (item.item_level or 0) < 109 then return nil end
    local slot = slot_name(item.slots)
    local set = slot and set_of[long:match('^(%S+)')]
    if not set then return nil end
    return {id = id, name = piece_label(item), job = set.job, kind = set.kind, slot = slot, tier = tier}
end

-- Reforged item id by job|kind|slot|tier, built on first use (Maxixi and some others have two, one per race)
local reforged = nil
local function reforged_name(job, kind, slot, tier)
    if not reforged then
        reforged = {}
        for id, item in pairs(res.items) do
            if item.category == 'Armor' then
                local p = classify(id)
                if p and not p.old then
                    local key = p.job .. '|' .. p.kind .. '|' .. p.slot .. '|' .. p.tier
                    if not reforged[key] or id < reforged[key] then reforged[key] = id end
                end
            end
        end
    end
    local id = reforged[job .. '|' .. kind .. '|' .. slot .. '|' .. tier]
    return id and res.items[id].en or nil
end

local function old_name(job, kind, slot)
    local list = kind == 'empyrean' and U.old_empyrean[job] or (U.old_sets[job] and U.old_sets[job][kind])
    return list and list[slot_index[slot]] or nil
end

----------------------------------------------------------------------------------------------- bags

-- owned pieces and holdings: id -> {total, inventory, bags = {bag name -> count}}
local function read_bags()
    local pieces, holdings = {}, {}
    local inventory = windower.ffxi.get_items() or {}
    for bag_id = 0, 17 do
        local bag = res.bags[bag_id]
        if bag and not SKIP_BAGS[bag_id] then
            -- A bag can be inaccessible in this zone and still have known contents.
            local items = inventory[bag.api] or windower.ffxi.get_items(bag_id) or {}
            for index, item in pairs(items) do
                if type(index) == 'number' and type(item) == 'table' and item.id and item.id > 0 then
                    local h = holdings[item.id]
                    if not h then
                        h = {total = 0, inventory = 0, bags = {}}
                        holdings[item.id] = h
                    end
                    h.total = h.total + item.count
                    h.bags[bag.en] = (h.bags[bag.en] or 0) + item.count
                    if bag_id == 0 then h.inventory = h.inventory + item.count end
                    local piece = classify(item.id)
                    if piece then
                        piece.bag = bag.en
                        pieces[#pieces + 1] = piece
                    end
                end
            end
        end
    end
    return pieces, holdings
end

local function slip_contents()
    local found = {}
    local ok, all = pcall(slips.get_player_items)
    if not ok then return found, 'the slips library errored: ' .. tostring(all) end
    if type(all) ~= 'table' then return found, 'the slips library returned nothing' end
    for slip_id, ids in pairs(all) do
        local list = {}
        for _, id in ipairs(ids) do list[#list + 1] = id end
        if #list > 0 and res.items[slip_id] then found[res.items[slip_id].en] = list end
    end
    return found
end

----------------------------------------------------------------------------------------------- currency

local balances = {}
local raw_pages = {}
local waiting = {}
local missing_pages = {}

local function run_waiting()
    local run = waiting
    waiting, missing_pages = {}, {}
    for _, f in ipairs(run) do f() end
end

local function with_balances(fn)
    waiting[#waiting + 1] = fn
    if #waiting > 1 then return end
    balances, raw_pages = {}, {}
    missing_pages = {[0x113] = "Currencies 1 (stored Rem's Tales)", [0x118] = 'Currencies 2 (beads, Gallimaufry)'}
    packets.inject(packets.new('outgoing', 0x10F, {}))
    packets.inject(packets.new('outgoing', 0x115, {}))
    coroutine.schedule(function()
        if #waiting == 0 then return end
        for _, page in pairs(missing_pages) do
            say("Armor Ledger: couldn't read " .. page .. '; not checked this time.', RED)
        end
        run_waiting()
    end, 3)
end

-- Reads a number off the parsed pages: exact field name first, then any field containing the word
local function page_value(exact, word)
    for _, page in pairs(raw_pages) do
        if type(page[exact]) == 'number' then return page[exact] end
    end
    if word then
        for _, page in pairs(raw_pages) do
            for key, value in pairs(page) do
                if type(key) == 'string' and type(value) == 'number' and key:lower():find(word, 1, true) then
                    return value
                end
            end
        end
    end
    return nil
end

local function currencies_arrived(id, data)
    if not missing_pages[id] then return end
    local ok, p = pcall(packets.parse, 'incoming', data)
    if ok and p then
        raw_pages[id] = p
        if id == 0x113 then
            balances.tales = {}
            for chapter = 1, 10 do balances.tales[chapter] = p['Rems Tale Chapter ' .. chapter] end
        end
    end
    missing_pages[id] = nil
    if next(missing_pages) == nil then run_waiting() end
end

local function currency_amount(value)
    if value == nil then return '?' end
    local sign = value < 0 and '-' or ''
    local digits = string.format('%.0f', math.abs(value))
    local grouped = digits:reverse():gsub('(%d%d%d)', '%1,')
    return sign .. grouped:reverse():gsub('^,', '')
end

local function currency_balance(name)
    if name == 'Escha Beads' then return page_value('Escha Beads', 'escha') end
    if name == 'Gallimaufry' then return page_value('Gallimaufry', 'gallimaufry') end
    if name == 'Apollyon Units' then return page_value('Apollyon Units', 'apollyon') end
    if name == 'Temenos Units' then return page_value('Temenos Units', 'temenos') end
    return nil
end

----------------------------------------------------------------------------------------------- state

-- Everything one command works from: the best piece owned per job/kind/slot, holdings, key items
local function read_state(quiet)
    local pieces, holdings = read_bags()
    do
        local contents, err = slip_contents()
        local n_slips, n_items, n_pieces = 0, 0, 0
        for slip, ids in pairs(contents) do
            n_slips = n_slips + 1
            for _, id in ipairs(ids) do
                n_items = n_items + 1
                local h = holdings[id] or {total = 0, inventory = 0, bags = {}}
                holdings[id] = h
                h.total = h.total + 1
                h.bags[slip] = 1
                local piece = classify(id)
                if piece then
                    n_pieces = n_pieces + 1
                    piece.bag = slip
                    pieces[#pieces + 1] = piece
                end
            end
        end
        if err and not quiet then
            say('Armor Ledger: slips not read: ' .. err, RED)
        elseif not err and n_slips == 0 and not quiet then
            say('Armor Ledger: no slips with items found (slips must be in a bag you can reach, and update after you talk to the Porter Moogle).', RED)
        end
    end
    -- Rem's Tales stored with Monisette can be withdrawn, so they count as owned
    for chapter, count in pairs(balances.tales or {}) do
        local id = item_id("Rem's Tale Ch." .. chapter)
        if id and count > 0 then
            local h = holdings[id] or {total = 0, inventory = 0, bags = {}}
            holdings[id] = h
            h.total = h.total + count
            h.bags['Stored'] = count
        end
    end

    local function better(a, b)
        if (a.old or false) ~= (b.old or false) then return not a.old end
        return a.tier > b.tier
    end
    local owned = {}
    for _, p in ipairs(pieces) do
        owned[p.job] = owned[p.job] or {}
        owned[p.job][p.kind] = owned[p.job][p.kind] or {}
        local cur = owned[p.job][p.kind][p.slot]
        if not cur or better(p, cur) then owned[p.job][p.kind][p.slot] = p end
    end

    local ki = {}
    local ids = windower.ffxi.get_key_items and windower.ffxi.get_key_items() or {}
    for _, id in ipairs(ids) do
        local entry = res.key_items and res.key_items[id]
        if entry and entry.en then ki[entry.en:lower()] = true end
    end

    -- highest reforged tier owned, per kind overall
    local max = {artifact = -1, relic = -1, empyrean = -1}
    for _, p in ipairs(pieces) do
        if not p.old and p.tier > max[p.kind] then max[p.kind] = p.tier end
    end
    return {owned = owned, holdings = holdings, ki = ki, max = max}
end

local function reforged_tier(state, job, kind, slot)
    local p = state.owned[job] and state.owned[job][kind] and state.owned[job][kind][slot]
    return (p and not p.old) and p.tier or -1
end

-- true when something you own or a key item proves the requirement was cleared
local function inferred(state, job, id)
    local max = state.max
    if id == 'pm75' then return max.artifact >= 1 end
    if id == 'pm35' then return max.relic >= 1 end
    if id == 'truth' then return max.empyrean >= 1 end
    if id == 'light' then return max.empyrean >= 2 end
    if id == 'orb' then return max.empyrean >= 2 or max.artifact >= 4 or max.relic >= 4 end
    if id == 'garden' then return max.artifact >= 4 or max.relic >= 4 end
    if id == 'omen' then return max.artifact >= 2 end
    if id == 'apollyon' then return max.artifact >= 4 end
    if id == 'temenos' then return max.relic >= 4 end
    local boss_slot = id:match('^vag_(%a+)$')
    if boss_slot then
        for _, j in ipairs(U.job_order) do
            if reforged_tier(state, j, 'empyrean', boss_slot) >= 1 then return true end
        end
        return false
    end
    if not job then return false end
    if id == 'sortie' then
        for _, slot in ipairs(SLOTS) do
            if reforged_tier(state, job, 'empyrean', slot) >= 2 then return true end
        end
        return false
    elseif id == 'bitzer' then
        if state.ki[U.soul_ki[job]] then return true end
        for _, slot in ipairs(SLOTS) do
            if reforged_tier(state, job, 'empyrean', slot) >= 3 then return true end
        end
        return false
    end
    local prefix, zone = id:match('^(ddc?)_(%a+)$')
    if prefix then
        if state.ki[U.shard_ki[job]] then return true end
        local need = prefix == 'dd' and 2 or 3
        return reforged_tier(state, job, 'relic', U.zone_slot[zone]) >= need
            or reforged_tier(state, job, 'relic', 'body') >= need
    end
    return false
end

-- A later unlock proves the earlier one: the Sortie basement (bitzer) means you entered Sortie, and beating
-- a Dynamis - Divergence zone (ddc_*) means you entered it (dd_*).
local function stronger_id(id)
    if id == 'sortie' then return 'bitzer' end
    local zone = id:match('^dd_(%a+)$')
    if zone then return 'ddc_' .. zone end
    return nil
end

local function req_met(state, job, id)
    local def = U.requirements[id]
    if def.scope == 'job' then
        if settings.jobs[job] and settings.jobs[job][id] then return true end
    elseif settings.char[id] then
        return true
    end
    if def.scope == 'job' and aurix_flag(job, id) then return true end
    if def.scope == 'job' and id == 'sortie' and sortie_entered(job) then return true end
    if inferred(state, job, id) then return true end
    local stronger = stronger_id(id)
    return stronger ~= nil and req_met(state, job, stronger)
end

-- true when a Dynamis - Divergence zone (Relic +2 or +3) is still open for the job (any job when nil)
local function dyn_open(state, job)
    for _, j in ipairs(job and {job} or U.job_order) do
        for zone in pairs(U.zone_name) do
            if not req_met(state, j, 'dd_' .. zone) or not req_met(state, j, 'ddc_' .. zone) then return true end
        end
    end
    return false
end

----------------------------------------------------------------------------------------------- steps

local function tale(chapter, count) return {"Rem's Tale Ch." .. chapter, count} end

local function copy_items(list)
    local out = {}
    for i, item in ipairs(list) do out[i] = {item[1], item[2]} end
    return out
end

local function zone_reqs(prefix, slot)
    local reqs = {}
    for _, zone in ipairs(U.slot_zones[slot]) do reqs[#reqs + 1] = prefix .. '_' .. zone end
    return reqs
end

-- Step from an old set piece to iL109. tier is the old piece's +N.
local function old_step(job, kind, slot, tier)
    if kind == 'artifact' then
        local a = U.artifact109
        return {target = 'iL109', npc = a.npc, zone = a.zone, days = 1, reqs = {'pm75'}, mats = {
            tale(a.chapter[slot], a.tales[tier] or a.tales[1]), {a.job_item[job], 1}, {a.slot_item[slot], 1}}}
    elseif kind == 'relic' then
        local r = U.relic109
        local mats = {tale(r.chapter[slot], r.tales)}
        local count = r.currency_count[tier] or 0
        if count > 0 then mats[#mats + 1] = {r.currency[job], count} end
        mats[#mats + 1] = {r.job_item[job], 1}
        mats[#mats + 1] = {r.slot_item[slot], 1}
        return {target = 'iL109', npc = r.npc, zone = r.zone, days = 1, reqs = {'pm35'}, mats = mats}
    end
    local e = U.empyrean109
    return {target = 'iL109', npc = e.npc, zone = e.zone, days = 1, reqs = {}, mats = {
        tale(e.chapter[slot], e.tales[tier] or e.tales[1]), {e.job_item[job], 1}, {e.slot_item[slot], 1}}}
end

-- Step from reforged tier t to t+1
local function reforged_step(job, kind, slot, t)
    local target = '+' .. (t + 1)
    if t >= 3 then
        local f = U[kind .. '4']
        return {target = target, npc = f.npc, zone = f.zone, days = 0,
            reqs = {'garden', 'orb', kind == 'artifact' and 'apollyon' or 'temenos'},
            mats = {}, cur = {{f.currency, f.cost[slot]}}}
    end
    if kind == 'empyrean' then
        if t == 0 then
            local e = U.empyrean1
            return {target = target, npc = e.npc, zone = e.zone, days = 1, reqs = {'truth', 'vag_' .. slot}, mats = {
                tale(e.chapter[slot], e.tales), {'Etched Memory', e.memories[slot]}, {e.slot_item[slot], 1}}}
        elseif t == 1 then
            local e = U.empyrean2
            return {target = target, npc = e.npc, zone = e.zone, days = 1, reqs = {'light', 'orb', 'sortie'},
                mats = copy_items(e.items), cur = {{e.currency[1], e.currency[2]}}}
        end
        local e = U.empyrean3
        return {target = target, npc = e.npc, zone = e.zone, days = 1, reqs = {'light', 'orb', 'bitzer'},
            mats = copy_items(e.items), cur = {{e.currency[1], e.currency[2]}}}
    end
    if t == 0 then
        local u = U[kind .. '1']
        return {target = target, npc = u.npc, zone = u.zone, days = 1, reqs = {kind == 'artifact' and 'pm75' or 'pm35'},
            mats = {tale(u.chapter[slot], u.tales), {u.job_item[job], 1}, {u.slot_item[slot], 1}}}
    elseif t == 1 then
        local plus2 = {U.plus2_job_item[job], 1}
        if kind == 'artifact' then
            local a = U.artifact2
            return {target = target, npc = a.npc, zone = a.zone, days = 1, reqs = {'omen'},
                mats = {{'P. ' .. job .. ' Card', a.cards[slot]}, plus2, {a.slot_item[slot], 1}},
                cur = {{'Escha Beads', a.beads}}}
        end
        local r = U.relic2
        return {target = target, npc = r.npc, zone = r.zone, days = 1, reqs = zone_reqs('dd', slot),
            mats = {{U.relic3.shard[slot] .. ': ' .. job, r.shards}, plus2, {r.slot_item[slot], 1}}}
    end
    if kind == 'artifact' then
        local a = U.artifact3
        local mats = {{'P. ' .. job .. ' Card', a.cards[slot]}, {a.scale[job], 1}}
        for _, item in ipairs(a.day2[slot]) do mats[#mats + 1] = {item[1], item[2]} end
        return {target = target, npc = a.npc, zone = a.zone, days = 2, reqs = {'omen'}, mats = mats,
            cur = {{'Escha Beads', a.beads.day1 + a.beads.day2}}}
    end
    local r = U.relic3
    return {target = target, npc = r.npc, zone = r.zone, days = 1, reqs = zone_reqs('ddc', slot), mats = {
        {r.shard[slot] .. ': ' .. job, r.count}, {r.void[slot] .. ': ' .. job, r.count}, {r.material[slot], r.count}}}
end

local function has_old_set(job, kind)
    if kind == 'empyrean' then return U.old_empyrean[job] ~= nil end
    return U.old_sets[job] ~= nil and U.old_sets[job][kind] ~= nil
end

-- Old Empyrean NQ -> +1 at the Magian Moogle, paid with a Kupon I-Seal (one per piece). Instant.
local function seal_step()
    local s = U.empyrean_seals
    return {target = 'old +1', npc = s.npc, zone = s.zone, days = 0, reqs = {}, mats = {{s.item, s.count}}}
end

local AF_START = 'Do AF Quests / Coffers'

-- All the steps from what you own to the last tier: {steps}, and note for a missing piece
local function build_steps(job, kind, slot, piece, final)
    local steps = {}
    local from = 0
    if piece and not piece.old then
        from = piece.tier
    else
        local usable = piece and piece.old and not (kind == 'empyrean' and piece.tier == 0)
        local nq = kind == 'empyrean' and piece and piece.old and piece.tier == 0
        if usable then
            steps[#steps + 1] = old_step(job, kind, slot, piece.tier)
        elseif nq then
            steps[#steps + 1] = seal_step()
            steps[#steps + 1] = old_step(job, kind, slot, 1)
        elseif has_old_set(job, kind) then
            local base = old_name(job, kind, slot)
            local source = kind == 'artifact' and AF_START or U[kind .. '_starts'][job][slot_index[slot]]
            steps[#steps + 1] = {acquire = true, target = 'base piece', base = base, source = source,
                text = 'get ' .. base .. ' | ' .. source}
            if kind == 'empyrean' then steps[#steps + 1] = seal_step() end
            steps[#steps + 1] = old_step(job, kind, slot, kind == 'empyrean' and 1 or 0)
        else
            local name = reforged_name(job, kind, slot, 0) or (job .. ' ' .. kind .. ' ' .. slot)
            local source = kind == 'artifact' and AF_START or U.adoulin_starts[job][kind]
            steps[#steps + 1] = {acquire = true, target = 'iL109', base = name, source = source,
                text = 'get ' .. name .. ' | ' .. source}
        end
    end
    for t = from, final - 1 do steps[#steps + 1] = reforged_step(job, kind, slot, t) end
    return steps
end

local function tier_label(piece)
    if not piece then return '--' end
    if piece.old then
        return piece.tier == 0 and 'old NQ' or ('old +' .. piece.tier)
    end
    return piece.tier == 0 and 'iL109' or ('+' .. piece.tier)
end

local function tier_char(piece)
    if not piece then return '-' end
    if piece.old then return '0' end
    return piece.tier == 0 and 'i' or tostring(piece.tier)
end

-- One entry per job/kind/slot: {job, kind, slot, piece, final, done, steps}
local function entries_for(state, job_filter, kind_filter)
    local list = {}
    for _, job in ipairs(U.job_order) do
        if not job_filter or job_filter == job then
            for _, kind in ipairs(KINDS) do
                if not kind_filter or kind_filter == kind then
                    for _, slot in ipairs(SLOTS) do
                        local piece = state.owned[job] and state.owned[job][kind] and state.owned[job][kind][slot]
                        local final = final_tier(kind)
                        local e = {job = job, kind = kind, slot = slot, piece = piece, final = final}
                        e.done = piece ~= nil and not piece.old and piece.tier >= final
                        if not e.done then e.steps = build_steps(job, kind, slot, piece, final) end
                        list[#list + 1] = e
                    end
                end
            end
        end
    end
    return list
end

----------------------------------------------------------------------------------------------- evaluation

-- Pools of what you hold; steps take from them in order so a shared item is only counted once
local function new_pools(state)
    local items = {}
    for id, h in pairs(state.holdings) do items[id] = h.total end
    local cur = {}
    for _, name in ipairs({'Escha Beads', 'Gallimaufry', 'Apollyon Units', 'Temenos Units'}) do
        cur[name] = currency_balance(name) -- nil when the page didn't arrive
    end
    return {items = items, cur = cur}
end

local function take_item(pools, name, count, commit)
    local id = item_id(name)
    local have = id and pools.items[id] or 0
    local got = math.min(have, count)
    if commit and id then pools.items[id] = have - got end
    return {name = name, need = count, got = got, short = count - got, unknown = id == nil}
end

local function take_currency(pools, name, amount, commit)
    local have = pools.cur[name]
    if have == nil then return {name = name, need = amount, got = nil, short = nil} end
    local got = math.min(have, amount)
    if commit then pools.cur[name] = have - got end
    return {name = name, need = amount, got = got, short = amount - got}
end

-- Evaluates one step: lines for materials and currency, and which requirements are open
local function eval_step(state, pools, e, step, commit)
    local r = {mats = {}, cur = {}, open = {}, ok = true}
    if step.acquire then
        r.ok = false
        return r
    end
    for _, m in ipairs(step.mats) do
        local line = take_item(pools, m[1], m[2], commit)
        r.mats[#r.mats + 1] = line
        if line.short > 0 then r.ok = false end
    end
    for _, c in ipairs(step.cur or {}) do
        local line = take_currency(pools, c[1], c[2], commit)
        r.cur[#r.cur + 1] = line
        if line.short == nil or line.short > 0 then r.ok = false end
    end
    for _, id in ipairs(step.reqs) do
        if not req_met(state, e.job, id) then r.open[#r.open + 1] = id end
    end
    return r
end

local function color_for(line)
    if line.short == nil then return WHITE end
    return line.short > 0 and RED or GREEN
end

----------------------------------------------------------------------------------------------- rendering

local function grid_segment(state, job, kind)
    local letters, complete, missing = {}, true, false
    for _, slot in ipairs(SLOTS) do
        local piece = state.owned[job] and state.owned[job][kind] and state.owned[job][kind][slot]
        letters[#letters + 1] = tier_char(piece)
        local done = piece and not piece.old and piece.tier >= final_tier(kind)
        if not done then complete = false end
        if not piece then missing = true end
    end
    return KIND_SHORT[kind] .. ' [' .. table.concat(letters, ' ') .. ']', complete, missing
end

local function show_summary(state, job, kind)
    local kinds = kind and {kind} or KINDS
    local complete_jobs, total, done_count = {}, 0, 0
    for _, e in ipairs(entries_for(state, job, kind)) do
        total = total + 1
        if e.done then done_count = done_count + 1 end
    end
    say(string.format('Armor Ledger: %d of %d pieces fully upgraded (Artifact/Relic to +%d, Empyrean to +3).',
        done_count, total, final_tier('artifact') == 4 and 4 or 3))
    say('  slots: head body hands legs feet.  - none owned, 0 Non-iLvl gear, i iL109, 1 iLvl 119 (+1)')
    for _, j in ipairs(U.job_order) do
        if not job or job == j then
            local segs, all_done, any_missing = {}, true, false
            for _, k in ipairs(kinds) do
                local seg, complete, missing = grid_segment(state, j, k)
                segs[#segs + 1] = seg
                all_done = all_done and complete
                any_missing = any_missing or missing
            end
            if all_done then
                complete_jobs[#complete_jobs + 1] = j
            else
                say(string.format('  %-4s %s', j, table.concat(segs, '  ')), any_missing and RED or WHITE)
            end
        end
    end
    if #complete_jobs > 0 then say('  complete: ' .. table.concat(complete_jobs, ' '), GREEN) end
    say('  //armor missing | job <job> | need | clears | next | export')
end

local function show_missing(state, job, kind)
    local any = false
    for _, e in ipairs(entries_for(state, job, kind)) do
        if not e.done and e.steps and e.steps[1].acquire then
            if not any then say('Armor Ledger: pieces with no usable version owned:') end
            any = true
            say(string.format('  %s %s %s: %s', e.job, KIND_SHORT[e.kind], e.slot, e.steps[1].text),
                RED)
        end
    end
    if not any then say('Armor Ledger: you own a usable version of every piece' .. (job and (' for ' .. job) or '') .. '.', GREEN) end
end

local function wait_text(step)
    if step.days == 0 then return 'instant' end
    return step.days == 1 and '1 game day' or (step.days .. ' game days')
end

local function print_step(state, pools, e, step)
    if step.acquire then
        say('   ' .. step.text, RED)
        return
    end
    say(string.format('   -> %s at %s, %s (%s)', step.target, step.npc, step.zone, wait_text(step)))
    local r = eval_step(state, pools, e, step, true)
    for _, m in ipairs(r.mats) do
        local text = string.format('      %s %d/%d', m.name, m.got, m.need)
        if m.unknown then text = text .. ' (name not in resources)' end
        if m.short > 0 then text = text .. ' - get ' .. m.short end
        say(text, color_for(m))
    end
    for _, c in ipairs(r.cur) do
        if c.short == nil then
            say(string.format('      %s ?/%s (balance not read)', c.name, currency_amount(c.need)))
        else
            say(string.format('      %s %s/%s%s', c.name, currency_amount(c.got), currency_amount(c.need),
                c.short > 0 and (' - get ' .. currency_amount(c.short)) or ''),
                color_for(c))
        end
    end
    for _, id in ipairs(r.open) do
        say('      [ ] ' .. U.requirements[id].text .. '  (' .. id .. ')', YELLOW)
    end
end

local function show_job(state, job, kind)
    local pools = new_pools(state)
    local any = false
    for _, e in ipairs(entries_for(state, job, kind)) do
        if not e.done then
            if not any then say('== ' .. job .. ' ==') end
            any = true
            local path = {}
            for _, s in ipairs(e.steps) do if not s.acquire then path[#path + 1] = s.target end end
            say(string.format(' %s %s: %s -> %s', KIND_NAME[e.kind], e.slot,
                e.piece and (e.piece.name .. ' (' .. e.piece.bag .. ')') or 'not owned',
                #path > 0 and table.concat(path, ', ') or '?'))
            for _, step in ipairs(e.steps) do print_step(state, pools, e, step) end
        end
    end
    if not any then say('Armor Ledger: nothing left to upgrade for ' .. job .. '.', GREEN) end
    if (not kind or kind == 'relic') and dyn_open(state, job) then
        say('Armor Ledger: ' .. AURIX_HOWTO .. ' ' .. aurix_status(), YELLOW)
    end
end

-- Totals of everything the unfinished pieces still need, and what is short
local function show_need(state, job, kind, show_all)
    local totals, order, curtotals, curorder = {}, {}, {}, {}
    local pieces, missing_pieces, open = 0, 0, {}
    for _, e in ipairs(entries_for(state, job, kind)) do
        if not e.done then
            pieces = pieces + 1
            for _, s in ipairs(e.steps) do
                if s.acquire then
                    missing_pieces = missing_pieces + 1
                else
                    for _, m in ipairs(s.mats) do
                        if not totals[m[1]] then totals[m[1]] = 0; order[#order + 1] = m[1] end
                        totals[m[1]] = totals[m[1]] + m[2]
                    end
                    for _, c in ipairs(s.cur or {}) do
                        if not curtotals[c[1]] then curtotals[c[1]] = 0; curorder[#curorder + 1] = c[1] end
                        curtotals[c[1]] = curtotals[c[1]] + c[2]
                    end
                    for _, id in ipairs(s.reqs) do
                        if not req_met(state, e.job, id) then open[id .. '|' .. (U.requirements[id].scope == 'job' and e.job or '')] = true end
                    end
                end
            end
        end
    end
    if pieces == 0 then
        return say('Armor Ledger: everything is fully upgraded' .. (job and (' for ' .. job) or '') .. '.', GREEN)
    end
    table.sort(order)
    local pools = new_pools(state)
    local short_count = 0
    say(string.format('Armor Ledger: %d unfinished piece%s. Items still needed:', pieces, pieces == 1 and '' or 's'))
    for _, name in ipairs(order) do
        local line = take_item(pools, name, totals[name], true)
        if line.short > 0 then short_count = short_count + 1 end
        if line.short > 0 or show_all then
            say(string.format('  %s: have %d / need %d%s%s', name, line.got, line.need,
                line.short > 0 and (' - get ' .. line.short) or '', line.unknown and ' (name not in resources)' or ''),
                line.short > 0 and RED or GREEN)
        end
    end
    if short_count == 0 then say('  every item is already in your bags.', GREEN) end
    table.sort(curorder)
    for _, name in ipairs(curorder) do
        local have = currency_balance(name)
        if have == nil then
            say(string.format('  %s: need %s (balance not read)', name, currency_amount(curtotals[name])))
        else
            local short = math.max(curtotals[name] - have, 0)
            say(string.format('  %s: have %s / need %s%s', name, currency_amount(have), currency_amount(curtotals[name]),
                short > 0 and (' - get ' .. currency_amount(short)) or ''), short > 0 and RED or GREEN)
        end
    end
    if missing_pieces > 0 then
        say(string.format('  %d piece%s not owned in any form: //armor missing', missing_pieces, missing_pieces == 1 and '' or 's'), RED)
    end
    local n = 0
    for _ in pairs(open) do n = n + 1 end
    if n > 0 then say(string.format('  %d unlock requirement%s open: //armor clears', n, n == 1 and '' or 's'), YELLOW) end
end

local function step_label(kind, step)
    return KIND_NAME[kind] .. ' ' .. step.target
end

local function show_clears(state, job, kind)
    local globals, per_job = {}, {}
    local g_order, j_order = {}, {}
    for _, e in ipairs(entries_for(state, job, kind)) do
        if not e.done then
            for _, s in ipairs(e.steps) do
                if not s.acquire then
                    for _, id in ipairs(s.reqs) do
                        if not req_met(state, e.job, id) then
                            local label = step_label(e.kind, s)
                            if U.requirements[id].scope == 'job' then
                                local key = e.job .. '|' .. id
                                if not per_job[key] then per_job[key] = {job = e.job, id = id, for_ = {}, seen = {}}; j_order[#j_order + 1] = key end
                                if not per_job[key].seen[label] then per_job[key].seen[label] = true; table.insert(per_job[key].for_, label) end
                            else
                                if not globals[id] then globals[id] = {id = id, for_ = {}, seen = {}}; g_order[#g_order + 1] = id end
                                if not globals[id].seen[label] then globals[id].seen[label] = true; table.insert(globals[id].for_, label) end
                            end
                        end
                    end
                end
            end
        end
    end
    if #g_order == 0 and #j_order == 0 then
        return say('Armor Ledger: no open unlock requirements' .. (job and (' for ' .. job) or '') .. '.', GREEN)
    end
    if #g_order > 0 then
        say('Armor Ledger: open requirements for the character:')
        for _, id in ipairs(g_order) do
            say(string.format('  [ ] %s', U.requirements[id].text), YELLOW)
            say(string.format('      needed for %s; mark with //armor done %s', table.concat(globals[id].for_, ', '), id))
        end
    end
    if #j_order > 0 then
        say('Armor Ledger: open requirements per job:')
        local last = nil
        for _, key in ipairs(j_order) do
            local c = per_job[key]
            if c.job ~= last then say('  ' .. c.job .. ':'); last = c.job end
            say(string.format('    [ ] %s', U.requirements[c.id].text), YELLOW)
            say(string.format('        needed for %s; //armor done %s %s', table.concat(c.for_, ', '), c.id, c.job))
        end
        for _, key in ipairs(j_order) do
            if per_job[key].id:match('^ddc?_') then
                say('Armor Ledger: ' .. AURIX_HOWTO .. ' ' .. aurix_status(), YELLOW)
                break
            end
        end
    end
end

-- Steps ready to do now (items, currency and requirements all there), grouped by NPC
local function show_next(state, job, kind)
    local pools = new_pools(state)
    local groups, order = {}, {}
    local blocked = 0
    for _, e in ipairs(entries_for(state, job, kind)) do
        local step = (not e.done) and e.steps[1]
        if step and not step.acquire then
            local r = eval_step(state, pools, e, step, false)
            if r.ok and #r.open == 0 then
                eval_step(state, pools, e, step, true) -- take it from the pools so two pieces can't both claim it
                local key = step.npc .. ', ' .. step.zone
                if not groups[key] then groups[key] = {}; order[#order + 1] = key end
                table.insert(groups[key], string.format('%s %s %s: %s -> %s', e.job, KIND_SHORT[e.kind], e.slot,
                    e.piece and e.piece.name or '?', step.target))
            else
                blocked = blocked + 1
            end
        elseif step then
            blocked = blocked + 1
        end
    end
    if #order == 0 then
        return say('Armor Ledger: no piece has everything for its next step yet (//armor need, //armor clears).', RED)
    end
    say('Armor Ledger: ready to upgrade now:', GREEN)
    for _, key in ipairs(order) do
        say('  ' .. key)
        for _, line in ipairs(groups[key]) do say('    ' .. line, GREEN) end
    end
    if blocked > 0 then say(string.format('  %d more are waiting on items, currency or a requirement.', blocked)) end
    say('  Reforge (//frg start) can trade these for you.')
end

local function show_flags(state, job)
    say('Armor Ledger: requirements (met = marked, proved by what you own, or key item):')
    local ids = {}
    for id in pairs(U.requirements) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local def = U.requirements[id]
        if def.scope == 'char' or job then
            local met = req_met(state, job, id)
            say(string.format('  %s %-9s %s%s', met and '[x]' or '[ ]', id, def.scope == 'job' and (job .. ': ') or '', def.text),
                met and GREEN or WHITE)
        end
    end
    if not job then say('  Per-job ids (sortie, bitzer, dd_*, ddc_*) are listed with //armor flags <job>.') end
    say('  //armor done <id> [job]  or  //armor undo <id> [job]  (dd / ddc set all four zones)')
end

----------------------------------------------------------------------------------------------- commands

local function set_flag(id, job, value, quiet)
    local ids = {id}
    if id == 'dd' or id == 'ddc' then
        ids = {}
        for zone in pairs(U.zone_name) do ids[#ids + 1] = id .. '_' .. zone end
    end
    for _, one in ipairs(ids) do
        local def = U.requirements[one]
        if not def then return say('Armor Ledger: unknown requirement "' .. id .. '"; //armor flags lists them.', RED) end
        if def.scope == 'job' then
            if not job then return say('Armor Ledger: ' .. one .. ' is per job: //armor done ' .. one .. ' <job>', RED) end
            settings.jobs[job] = settings.jobs[job] or {}
            settings.jobs[job][one] = value or nil
        else
            settings.char[one] = value or nil
        end
    end
    save_settings()
    if not quiet then
        say(string.format('Armor Ledger: %s %s%s.', id, value and 'marked as cleared' or 'unmarked', job and (' for ' .. job) or ''),
            value and GREEN or WHITE)
    end
end

-- The whole report, written out through the same renderers
local function export(state)
    local lines = {}
    local saved = emit
    emit = function(text) lines[#lines + 1] = text end
    show_summary(state)
    emit('')
    show_missing(state)
    emit('')
    show_need(state, nil, nil, true)
    emit('')
    show_clears(state)
    emit('')
    show_next(state)
    for _, job in ipairs(U.job_order) do
        emit('')
        show_job(state, job)
    end
    emit = saved
    windower.create_dir(windower.addon_path .. 'data')
    local path = data_path('report_' .. (player_name or 'unknown') .. '.txt')
    local f = io.open(path, 'w')
    if not f then return say('Armor Ledger: could not write ' .. path, RED) end
    f:write(table.concat(lines, '\n') .. '\n')
    f:close()
    say('Armor Ledger: report written to ' .. path, GREEN)
end

----------------------------------------------------------------------------------------------- probe

-- Records Aurix's menu packets (what the game sends when you talk to him and open View armor) so the unlock
-- list can be decoded. Passive: it never sends or blocks anything.
local AURIX_ID = 17772865
local probe = {on = false, count = 0, last = nil}

-- NPCs the probe records besides Aurix, matched by name (they have no fixed id here yet). Ruspix (Leafallia,
-- Sortie) is where Empyrean +2 unlocks are read.
local PROBE_NPC_NAMES = {Ruspix = true}
local RUSPIX_ID = 17928266 -- seen in the probe: target index 74, Leafallia zone 281, menu 71
local function probe_npc(id)
    if id == AURIX_ID then return 'Aurix' end
    if id == RUSPIX_ID then return 'Ruspix' end
    local mob = id and windower.ffxi.get_mob_by_id and windower.ffxi.get_mob_by_id(id)
    return mob and PROBE_NPC_NAMES[mob.name] and mob.name or nil
end

local function hex_dump(data)
    return (data:gsub('.', function(c) return string.format('%02X ', c:byte()) end))
end

-- Writes a whole packet as hex. Sub-menu updates (0x05C) carry no NPC id, so they are only recorded
-- shortly after Aurix last sent or was sent a menu packet.
local PROBE_WINDOW = 120
-- If a 32-bit value only uses bits 1-22 it is probably a job mask (bit = job id: 1 WAR ... 20 SCH ... 22 RUN)
local function job_mask_text(value)
    if value == 0 or value % 2 == 1 or value >= 2 ^ 23 then return nil end
    local have, lack = {}, {}
    for id, job in ipairs(U.job_order) do
        if math.floor(value / 2 ^ id) % 2 == 1 then have[#have + 1] = job else lack[#lack + 1] = job end
    end
    if #lack == 0 then return 'all jobs' end
    if #lack <= 6 then return 'all jobs except ' .. table.concat(lack, ' ') end
    return table.concat(have, ' ')
end

local function probe_params_text(data, skip)
    skip = skip or 4 -- a 0x05C packet has a 4 byte header; menu parameters start at 0
    local out = {}
    for n = 1, 8 do
        local b1, b2, b3, b4 = data:byte(skip + (n - 1) * 4 + 1, skip + n * 4)
        if b4 then
            local value = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
            local mask = job_mask_text(value)
            out[#out + 1] = string.format('p%d=%08X%s', n, value, mask and (' [' .. mask .. ']') or '')
        end
    end
    return table.concat(out, '  ')
end

local function probe_raw(tag, id, data)
    windower.create_dir(windower.addon_path .. 'data')
    local f = io.open(data_path('probe.log'), 'a')
    if not f then return end
    local player = windower.ffxi.get_player() or {}
    local decoded = id == 0x05C and probe_params_text(data) or ''
    f:write(os.date('[%Y-%m-%d %H:%M:%S] ') .. string.format('job %s/%s  %s 0x%03X len %d: %s\n',
        tostring(player.main_job), tostring(player.sub_job), tag, id, #data, hex_dump(data)))
    if decoded ~= '' then f:write('    decoded: ' .. decoded .. '\n') end
    f:close()
    probe.count = probe.count + 1
    say(string.format('Armor Ledger probe: %s 0x%03X (%d bytes)', tag, id, #data), YELLOW)
    if decoded ~= '' then say('    ' .. decoded, YELLOW) end
end

local function probe_log(direction, id, data)
    local ok, p = pcall(packets.parse, direction == 'in' and 'incoming' or 'outgoing', data)
    if not ok or not p then return end
    local npc = p['NPC'] or p['Target']
    local npc_name = probe_npc(npc)
    if not npc_name then return end
    probe.last = os.time()
    local player = windower.ffxi.get_player() or {}
    local line, decoded
    if direction == 'in' then
        local params = p['Menu Parameters'] or ''
        line = string.format('%s IN  menu %s params %s', npc_name, tostring(p['Menu ID']), hex_dump(params))
        if #params >= 32 then decoded = probe_params_text(params, 0) end
    else
        -- XIChecklist tells menus apart by more than the option: _unknown1 and byte 12 (a second option index) too
        line = string.format('%s OUT menu %s option %s  unk1 %s  second %s  index %s  raw %s', npc_name,
            tostring(p['Menu ID']), tostring(p['Option Index']), tostring(p['_unknown1']), tostring(data:byte(12)),
            tostring(p['Target Index']), hex_dump(data))
    end
    windower.create_dir(windower.addon_path .. 'data')
    local f = io.open(data_path('probe.log'), 'a')
    if f then
        f:write(os.date('[%Y-%m-%d %H:%M:%S] ') .. string.format('job %s/%s  ', tostring(player.main_job), tostring(player.sub_job)) .. line .. '\n')
        if decoded then f:write('    decoded: ' .. decoded .. '\n') end
        f:close()
    end
    probe.count = probe.count + 1
    say('Armor Ledger probe: ' .. line, YELLOW)
end

----------------------------------------------------------------------------------------------- aurix sync

-- Talking to Aurix and opening View armor makes the game send the Dynamis - Divergence progress of every job
-- at once (nothing is sent by this addon). Menu 3007 option 1 answers with San d'Oria and Bastok, option 2 with
-- Windurst and Jeuno, in a 0x05C packet of eight 32-bit values: p1/p2 = first zone, p4/p5 = second zone. Each
-- value is a job mask (bit N = job N). p1/p4 are read as "entered" (dd) and p2/p5 as "mid-boss beaten" (ddc);
-- that split is a guess until a job turns up with one and not the other.
local AURIX_MENU = 3007
local AURIX_PAGES = {
    [1] = {{zone = 'sandoria', dd = 1, ddc = 2}, {zone = 'bastok', dd = 4, ddc = 5}},
    [2] = {{zone = 'windurst', dd = 1, ddc = 2}, {zone = 'jeuno', dd = 4, ddc = 5}},
}
local AURIX_REPLY_WINDOW = 5
local aurix_wait = nil
local aurix_synced = nil -- set once the window exists: redraws it after a sync

local function packet_u32(data, n)
    local b1, b2, b3, b4 = data:byte(n * 4 + 1, n * 4 + 4)
    if not b4 then return nil end
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function jobs_lacking(mask)
    local lack = {}
    for _, job in ipairs(U.job_order) do
        if not mask_has(mask, job) then lack[#lack + 1] = job end
    end
    if #lack == 0 then return 'all jobs' end
    if #lack <= 8 then return 'all but ' .. table.concat(lack, ' ') end
    return (#U.job_order - #lack) .. ' of ' .. #U.job_order .. ' jobs'
end

-- Ruspix (Leafallia, menu 71): option 1 answers with the Sortie job mask in its first value (see settings.ruspix)
local RUSPIX_MENU, RUSPIX_OPTION = 71, 1
local ruspix_wait = nil

local function sortie_text(locked)
    local lack = {}
    for _, job in ipairs(U.job_order) do
        if math.floor(locked / 2 ^ (JOB_BIT[job] - 1)) % 2 == 1 then lack[#lack + 1] = job end
    end
    if #lack == 0 then return 'every job' end
    if #lack == #U.job_order then return 'no job yet' end
    return string.format('%d of %d jobs, not yet: %s', #U.job_order - #lack, #U.job_order, table.concat(lack, ' '))
end

local function aurix_outgoing(data)
    local ok, p = pcall(packets.parse, 'outgoing', data)
    if not ok or not p then return end
    local option = tonumber(p['Option Index'])
    if probe_npc(p['Target']) == 'Ruspix' then
        aurix_wait = nil
        if tonumber(p['Menu ID']) == RUSPIX_MENU and option == RUSPIX_OPTION then
            ruspix_wait = {time = os.time()}
        else
            ruspix_wait = nil
        end
        return
    end
    if p['Target'] ~= AURIX_ID then return end
    ruspix_wait = nil
    if tonumber(p['Menu ID']) == AURIX_MENU and AURIX_PAGES[option] then
        aurix_wait = {page = option, time = os.time()}
    else
        aurix_wait = nil
    end
end

local function ruspix_incoming(data)
    local wait = ruspix_wait
    if not wait or os.time() - wait.time > AURIX_REPLY_WINDOW or #data < 36 then return false end
    ruspix_wait = nil
    local locked = packet_u32(data, 1)
    if not locked or locked >= 2 ^ #U.job_order then return true end
    if not player_name then load_settings() end
    if not player_name then return true end
    settings.ruspix = {locked = locked, time = os.time()}
    save_settings()
    say('Armor Ledger: Ruspix - Sortie entered on ' .. sortie_text(locked) .. '.', GREEN)
    if aurix_synced then aurix_synced() end
    return true
end

local function aurix_incoming(data)
    if ruspix_incoming(data) then return end
    local wait = aurix_wait
    if not wait or os.time() - wait.time > AURIX_REPLY_WINDOW or #data < 36 then return end
    -- the unlock pages have nothing in p3, p6, p7 and p8; the item pages (options 16-25) do
    for _, n in ipairs({3, 6, 7, 8}) do
        if packet_u32(data, n) ~= 0 then return end
    end
    aurix_wait = nil
    if not player_name then load_settings() end
    if not player_name then return end
    settings.aurix = settings.aurix or {}
    local differ = {}
    for _, field in ipairs(AURIX_PAGES[wait.page]) do
        local entered, cleared = packet_u32(data, field.dd), packet_u32(data, field.ddc)
        settings.aurix[field.zone] = {dd = entered, ddc = cleared, time = os.time()}
        say(string.format('Armor Ledger: Aurix - %s (%s): entered %s, mid-boss %s.', U.zone_name[field.zone],
            U.zone_slot[field.zone], jobs_lacking(entered), jobs_lacking(cleared)), GREEN)
        if entered ~= cleared then differ[#differ + 1] = string.format('%s %08X/%08X', field.zone, entered, cleared) end
    end
    save_settings()
    if aurix_synced then aurix_synced() end
    if #differ > 0 then
        say('Armor Ledger: the two fields differ (' .. table.concat(differ, ', ') .. '). Please send me data/probe.log or this line.', YELLOW)
    end
end

local function show_aurix(clear)
    if clear then
        settings.aurix = {}
        settings.ruspix = nil
        save_settings()
        return say('Armor Ledger: Aurix and Ruspix data cleared. Talk to them again to read it.', WHITE)
    end
    local any = false
    for _, zone in ipairs({'sandoria', 'bastok', 'windurst', 'jeuno'}) do
        local entry = settings.aurix and settings.aurix[zone]
        if entry then
            any = true
            say(string.format('  %-30s (%s)  entered: %s | mid-boss: %s  [%s]', U.zone_name[zone], U.zone_slot[zone],
                jobs_lacking(entry.dd), jobs_lacking(entry.ddc), os.date('%Y-%m-%d %H:%M', entry.time or 0)), WHITE)
        end
    end
    if settings.ruspix then
        any = true
        say(string.format('  Sortie (Ruspix): entered %s  [%s]', sortie_text(settings.ruspix.locked),
            os.date('%Y-%m-%d %H:%M', settings.ruspix.time or 0)), WHITE)
    end
    if not any then
        say("Armor Ledger: no Aurix data yet. Talk to Aurix (Ru'Lude Gardens) and open View armor once; it covers every job.", YELLOW)
    else
        say('  Read from Aurix; it counts alongside //armor done. //armor aurix clear forgets it.', WHITE)
    end
end

----------------------------------------------------------------------------------------------- window

-- A window built from Windower text boxes: clickable job tabs and filters, a detail panel,
-- and read-only Unlocks, Cards, and Materials views.
local gui = {visible = false, job = nil, kind = nil, material_slot = nil, scroll = 0, x = 60, y = 60, boxes = nil,
    state = nil, limit = 36, view = 'steps', line_count = 0, busy = false, drag = nil, pressed = false,
    material_page = 1}
local FILTERS = {{'All', false}, {'AF', 'artifact'}, {'Relic', 'relic'}, {'Empy', 'empyrean'}}

local C = {
    green = {120, 230, 120}, yellow = {240, 220, 110}, red = {240, 110, 110},
    white = {235, 235, 235}, gray = {150, 150, 150}, cyan = {130, 200, 255},
}

local ARMOR_ACCENT = {
    [false] = {195, 205, 225},
    artifact = {120, 205, 255},
    relic = {220, 165, 255},
    empyrean = {110, 225, 200},
}
local JOB_ACCENT = {
    WAR = {255, 180, 100}, MNK = {245, 220, 105}, WHM = {250, 240, 225},
    BLM = {184, 155, 255}, RDM = {255, 120, 140}, THF = {150, 225, 105},
    PLD = {165, 205, 255}, DRK = {193, 133, 203}, BST = {201, 187, 118},
    BRD = {255, 193, 215}, RNG = {110, 214, 140}, SAM = {249, 142, 109},
    NIN = {137, 151, 220}, DRG = {204, 160, 239}, SMN = {137, 225, 198},
    BLU = {100, 171, 255}, COR = {255, 215, 163}, PUP = {226, 176, 141},
    DNC = {246, 143, 198}, SCH = {224, 206, 181}, GEO = {187, 232, 148},
    RUN = {108, 214, 235},
}

local function paint(color, text)
    return string.format('\\cs(%d,%d,%d)%s\\cr', color[1], color[2], color[3], text)
end

local function clip(text, n)
    if #text > n then return text:sub(1, n - 3) .. '...' end
    return text
end

local function make_box()
    return texts.new('', {
        pos = {x = 0, y = 0},
        bg = {alpha = 215, red = 18, green = 20, blue = 28, visible = true},
        flags = {draggable = false, bold = false},
        padding = 3,
        text = {size = 10, font = 'Consolas', fonts = {'Consolas', 'Courier New'},
            red = 235, green = 235, blue = 235, alpha = 255,
            stroke = {width = 0, alpha = 0, red = 0, green = 0, blue = 0}},
    })
end

local function ensure_boxes()
    if gui.boxes then return end
    local b = {title = make_box(), close = make_box(), refresh = make_box(), unlocks = make_box(), cards = make_box(), body = make_box(),
        progress = make_box(), materials = make_box(), next_only = make_box(), continuation = make_box(), third = make_box(),
        pages = {make_box(), make_box()},
        filters = {}, tabs = {}, slots = {}}
    b.refresh:font('Segoe UI Symbol', 'Consolas')
    for i = 1, #FILTERS do b.filters[i] = make_box() end
    for i = 1, #U.job_order + 1 do b.tabs[i] = make_box() end
    for i = 1, #SLOTS + 1 do b.slots[i] = make_box() end
    gui.boxes = b
end

local function each_box(fn)
    local b = gui.boxes
    if not b then return end
    for _, name in ipairs({'title', 'close', 'refresh', 'progress', 'unlocks', 'cards', 'materials', 'next_only', 'body', 'continuation', 'third'}) do
        fn(b[name])
    end
    for _, box in ipairs(b.pages) do fn(box) end
    for _, box in ipairs(b.filters) do fn(box) end
    for _, box in ipairs(b.tabs) do fn(box) end
    for _, box in ipairs(b.slots) do fn(box) end
end

local function box_size(box)
    local w, h = box:extents()
    if not w or w <= 0 or not h or h <= 0 then return 40, 16 end
    return w, h
end

local function layout()
    local b = gui.boxes
    if not b then return end
    local x, y = gui.x, gui.y
    local _, th = box_size(b.title)
    local rowh = th + 2

    b.title:pos(x, y)
    local tw = box_size(b.title)
    b.close:pos(x + tw + 4, y)
    local refresh_x = x + tw + box_size(b.close) + 8
    b.refresh:pos(refresh_x, y)
    local page_x = refresh_x + math.max(box_size(b.refresh), box_size(b.close)) + 6
    for _, box in ipairs(b.pages) do
        box:pos(page_x, y)
        page_x = page_x + box_size(box) + 2
    end

    local cx = x
    for _, f in ipairs(b.filters) do
        f:pos(cx, y + rowh)
        cx = cx + box_size(f) + 2
    end
    cx = cx + 8
    for _, button in ipairs({b.progress, b.unlocks, b.cards, b.materials}) do
        button:pos(cx, y + rowh)
        cx = cx + box_size(button) + 2
    end

    local per_row = 12
    local ty = y + rowh * 2
    cx = x
    local first_tab = gui.view == 'materials' and 2 or 1
    for i = first_tab, #b.tabs do
        local t = b.tabs[i]
        if i > first_tab and (i - first_tab) % per_row == 0 then
            cx = x
            ty = ty + rowh
        end
        t:pos(cx, ty)
        cx = cx + box_size(t) + 2
    end

    local by = ty + rowh + 2
    if gui.view == 'materials' and gui.job then
        cx = x
        for i, box in ipairs(b.slots) do
            box:pos(cx, by)
            local label = SLOTS[i - 1] or 'All'
            -- Newly shown text boxes can report stale extents until Windower draws them.
            local min_width = (#label + 2) * math.max(10, (th - 6) * 0.5) + 6
            cx = cx + math.max(box_size(box), min_width) + 2
        end
        b.next_only:pos(cx + 4, by)
        by = by + rowh
    end
    if gui.has_second_panel then
        local width = box_size(b.body)
        local second_width = box_size(b.continuation)
        local total_width = width + second_width + 8
        if gui.has_third_panel then total_width = total_width + box_size(b.third) + 8 end
        local cfg = windower.get_windower_settings and windower.get_windower_settings()
        local screen = cfg and cfg.ui_x_res or 1920
        local left = math.max(0, math.min(x, screen - total_width))
        b.body:pos(left, by)
        b.continuation:pos(left + width + 8, by)
        if gui.has_third_panel then b.third:pos(left + width + second_width + 16, by) end
    else
        b.body:pos(x, by)
    end
end

local function cell(state, job, kind, slot)
    local p = state.owned[job] and state.owned[job][kind] and state.owned[job][kind][slot]
    if not p then return '-', C.red end
    local done = (not p.old) and p.tier >= final_tier(kind)
    return tier_char(p), done and C.green or C.yellow
end

local function overview_lines(state, kind_filter)
    local lines = {paint(C.gray, 'Click a job tab for its upgrade steps.')}
    lines[#lines + 1] = paint(C.gray, '- none   0 Non-iLvl gear   i iL109   1 iLvl 119 (+1)')
    for _, job in ipairs(U.job_order) do
        local parts = {string.format('%-4s', job)}
        for _, kind in ipairs(KINDS) do
            if not kind_filter or kind_filter == kind then
                local cells = {}
                for _, slot in ipairs(SLOTS) do
                    local ch, color = cell(state, job, kind, slot)
                    cells[#cells + 1] = paint(color, ch)
                end
                parts[#parts + 1] = paint(ARMOR_ACCENT[kind], KIND_SHORT[kind]) .. ' [' .. table.concat(cells, ' ') .. ']'
            end
        end
        lines[#lines + 1] = table.concat(parts, '  ')
    end
    return lines
end

local DYN_ZONES = {'sandoria', 'bastok', 'windurst', 'jeuno'}

-- Every unlock that matters for the chosen kinds (all kinds when none is chosen)
local function applicable_ids(kind_filter)
    local ids, seen = {}, {}
    local function add(id)
        if not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    for _, kind in ipairs(KINDS) do
        if not kind_filter or kind_filter == kind then
            if kind == 'artifact' then
                add('pm75')
                add('omen')
                if final_tier('artifact') >= 4 then add('garden'); add('orb'); add('apollyon') end
            elseif kind == 'relic' then
                add('pm35')
                for _, z in ipairs(DYN_ZONES) do add('dd_' .. z) end
                for _, z in ipairs(DYN_ZONES) do add('ddc_' .. z) end
                if final_tier('relic') >= 4 then add('garden'); add('orb'); add('temenos') end
            else
                add('truth')
                for _, slot in ipairs(SLOTS) do add('vag_' .. slot) end
                add('light')
                add('orb')
                add('sortie')
                add('bitzer')
            end
        end
    end
    return ids
end

-- Splits a job's unlocks into completed ids and incomplete ones ({id = ...})
local function unlocks_for_job(state, job, kind_filter)
    local done, open = {}, {}
    for _, id in ipairs(applicable_ids(kind_filter)) do
        if U.requirements[id] then
            if req_met(state, job, id) then
                done[#done + 1] = id
            else
                open[#open + 1] = {id = id, for_ = {}}
            end
        end
    end
    return done, open
end

-- Detail for one job: each unfinished piece, its path, and the state of its next step.
local function currency_label(name, required, current)
    local label = string.format('%s x%s (Current: %s)', name, currency_amount(required), currency_amount(current))
    return paint(current and current > 0 and C.green or C.yellow, label)
end

local function job_lines(state, job, kind_filter)
    local lines, groups = {}, {}
    local pools = new_pools(state)
    local entries = entries_for(state, job, kind_filter)
    local _, open_list = unlocks_for_job(state, job, kind_filter)
    local open = #open_list
    if open > 0 then
        lines[#lines + 1] = paint(C.yellow, string.format('%d unlock%s incomplete for %s - see the Unlocks button',
            open, open == 1 and '' or 's', job))
    end
    for _, kind in ipairs(KINDS) do
        if not kind_filter or kind_filter == kind then
            local done, pieces = 0, {}
            for _, e in ipairs(entries) do
                if e.kind == kind then
                    pieces[#pieces + 1] = e
                    if e.done then done = done + 1 end
                end
            end
            groups[#groups + 1] = #groups == 0 and 1 or #lines + 1
            lines[#lines + 1] = paint(ARMOR_ACCENT[kind], KIND_NAME[kind]) .. paint(done == #pieces and C.green or C.gray,
                string.format('  %d/%d done', done, #pieces))
            if kind == 'relic' and dyn_open(state, job) then
                lines[#lines + 1] = ' ' .. paint(C.yellow, clip(AURIX_HOWTO, 110))
                lines[#lines + 1] = ' ' .. paint(C.gray, aurix_status())
            end
            for _, e in ipairs(pieces) do
                local label = string.format(' %-6s', e.slot:gsub('^%l', string.upper))
                if e.done then
                    local piece = e.piece.name .. ' (' .. e.piece.bag .. ')'
                    lines[#lines + 1] = paint(C.green, label .. clip(piece, 89) .. '  Complete')
                else
                    local path = {}
                    for _, s in ipairs(e.steps) do
                        if not s.acquire then path[#path + 1] = s.target end
                    end
                    local have = e.piece and (e.piece.name .. ' (' .. e.piece.bag .. ')') or 'Not started'
                    lines[#lines + 1] = paint(ARMOR_ACCENT[kind], label) .. clip(have .. '  >  ' .. table.concat(path, ' > '), 103)

                    local step = e.steps[1]
                    if step.acquire then
                        lines[#lines + 1] = '       ' .. paint(C.red, clip(step.text, 100))
                    else
                        local r = eval_step(state, pools, e, step, true)
                        if r.ok and #r.open == 0 then
                            lines[#lines + 1] = '       ' .. paint(C.green, clip(string.format('READY  %s at %s, %s (%s)',
                                step.target, step.npc, step.zone, wait_text(step)), 100))
                        else
                            local parts = {}
                            for _, m in ipairs(r.mats) do
                                if m.short > 0 then parts[#parts + 1] = string.format('%s %d/%d', m.name, m.got, m.need) end
                            end
                            for _, id in ipairs(r.open) do parts[#parts + 1] = 'unlock ' .. id end
                            if #parts > 0 then
                                local text = step.target .. ' needs: ' .. table.concat(parts, ', ')
                                lines[#lines + 1] = '       ' .. paint(C.yellow, clip(text, 100))
                            end
                        end
                        for _, c in ipairs(r.cur) do
                            lines[#lines + 1] = '       ' .. currency_label(c.name, c.need, currency_balance(c.name))
                        end
                    end
                end
            end
        end
    end
    return lines, groups
end

local function pad(text, width)
    return text .. string.rep(' ', math.max(0, width - #text))
end

-- P. <JOB> Cards still needed to take a job's Artifact set to +3 (Coelestrox: +1 -> +2 and +2 -> +3).
-- A slot already at +2 only needs the +3 cards, and a slot at +3 or +4 needs none.
-- Spare cards of one job convert to a card of any other job at this many to one
local CARD_CONVERT = 5

local function cards_for(state, job)
    local c2, c3 = U.artifact2.cards, U.artifact3.cards
    local id = item_id('P. ' .. job .. ' Card')
    local h = id and state.holdings[id]
    local have = h and h.total or 0
    local per_slot, tiers, need = {}, {}, 0
    for _, slot in ipairs(SLOTS) do
        local t = reforged_tier(state, job, 'artifact', slot)
        tiers[slot] = t
        local n = (t < 2 and c2[slot] or 0) + (t < 3 and c3[slot] or 0)
        per_slot[slot] = n
        need = need + n
    end
    local spare = math.max(have - need, 0)
    return {job = job, have = have, need = need, short = math.max(need - have, 0),
        spare = spare, convert = math.floor(spare / CARD_CONVERT), left = spare % CARD_CONVERT,
        per_slot = per_slot, tiers = tiers, unknown = id == nil}
end

local function cards_lines(state, job)
    local lines = {paint(C.gray, 'P. <JOB> Cards still needed for ') .. paint(ARMOR_ACCENT.artifact, 'Artifact +3')
        .. paint(C.gray, '. Slots already at +2 only need the +3 cards; +3 needs none.')}
    local header = pad('Job', 5) .. pad('Need', 6) .. pad('Have', 6) .. pad('Short', 7) .. pad('Spare', 7)
    for _, slot in ipairs(SLOTS) do header = header .. pad(slot:sub(1, 1):upper() .. slot:sub(2), 7) end
    lines[#lines + 1] = paint(C.gray, header)
    local total_need, total_have, total_short, total_convert = 0, 0, 0, 0
    local spare_jobs, short_jobs = {}, {}
    for _, j in ipairs(U.job_order) do
        if not job or job == j then
            local c = cards_for(state, j)
            total_need, total_have, total_short = total_need + c.need, total_have + math.min(c.have, c.need), total_short + c.short
            local color = c.need == 0 and C.green or (c.short == 0 and C.green or (c.have > 0 and C.yellow or C.red))
            total_convert = total_convert + c.convert
            if c.convert > 0 then spare_jobs[#spare_jobs + 1] = c end
            if c.short > 0 then short_jobs[#short_jobs + 1] = c end
            local row = pad(j, 5) .. pad(tostring(c.need), 6) .. pad(tostring(c.have), 6) .. pad(tostring(c.short), 7)
                .. pad(c.spare == 0 and '.' or tostring(c.spare), 7)
            row = paint(color, row)
            for _, slot in ipairs(SLOTS) do
                local count = c.per_slot[slot]
                row = row .. paint(count == 0 and C.green or color, pad(tostring(count), 7))
            end
            lines[#lines + 1] = row .. (c.unknown and paint(C.red, ' (card name not in resources)') or '')
        end
    end
    if not job then
        lines[#lines + 1] = paint(C.cyan, pad('All', 5) .. pad(tostring(total_need), 6) .. pad(tostring(total_have), 6)
            .. pad(tostring(total_short), 7) .. '(have counts only up to what each job needs)')
        lines[#lines + 1] = ''
        if #spare_jobs == 0 then
            lines[#lines + 1] = paint(C.gray, string.format('No spare cards to convert (%d spare of one job = 1 card of another job).', CARD_CONVERT))
        else
            lines[#lines + 1] = paint(C.cyan, string.format('Convertible spare cards (%d : 1 into any other job\'s card):', CARD_CONVERT))
            for _, c in ipairs(spare_jobs) do
                lines[#lines + 1] = paint(C.green, string.format(' %-4s %d spare -> %d card%s%s', c.job, c.spare, c.convert,
                    c.convert == 1 and '' or 's', c.left > 0 and (' (' .. c.left .. ' left over)') or ''))
            end
            if #short_jobs > 0 then
                local parts = {}
                for _, c in ipairs(short_jobs) do parts[#parts + 1] = c.job .. ' ' .. c.short end
                lines[#lines + 1] = paint(C.yellow, clip(string.format(' %d card%s available to convert; still short: %s', total_convert,
                    total_convert == 1 and '' or 's', table.concat(parts, ', ')), 110))
            else
                lines[#lines + 1] = paint(C.gray, ' No job is short, so nothing needs converting right now.')
            end
        end
    else
        local c = cards_for(state, job)
        lines[#lines + 1] = ''
        for _, slot in ipairs(SLOTS) do
            local t = c.tiers[slot]
            local why
            if t >= 3 then
                why = paint(C.green, 'Complete')
            else
                why = string.format('Needed for +2: %d  +3: %d', t < 2 and U.artifact2.cards[slot] or 0,
                    U.artifact3.cards[slot])
            end
            lines[#lines + 1] = string.format(' %-6s %s', slot:sub(1, 1):upper() .. slot:sub(2), why)
        end
        lines[#lines + 1] = ''
        if c.convert > 0 then
            lines[#lines + 1] = paint(C.green, string.format('Spare: %d P. %s Card%s. %d : 1 converts to %d card%s of another job%s.',
                c.spare, job, c.spare == 1 and '' or 's', CARD_CONVERT, c.convert, c.convert == 1 and '' or 's',
                c.left > 0 and (' (' .. c.left .. ' left over)') or ''))
        elseif c.spare > 0 then
            lines[#lines + 1] = paint(C.gray, string.format('Spare: %d (need %d to convert 1 card of another job).', c.spare, CARD_CONVERT))
        else
            lines[#lines + 1] = paint(C.gray, 'No spare cards for ' .. job .. '.')
        end
    end
    return lines
end

local function zones_met(state, job, prefix)
    local n = 0
    for _, z in ipairs(DYN_ZONES) do
        if req_met(state, job, prefix .. '_' .. z) then n = n + 1 end
    end
    return n
end

-- One cell of the per-job table: Completed or Incomplete
local function flag_cell(state, job, id, width)
    if req_met(state, job, id) then return paint(C.green, pad('Completed', width)) end
    return paint(C.red, pad('Incomplete', width))
end

local function show_cards(state, job)
    for _, line in ipairs(cards_lines(state, job)) do
        say((line:gsub('\\cs%(%d+,%d+,%d+%)', ''):gsub('\\cr', '')))
    end
end

local ZONE_LETTER = {sandoria = 'S', bastok = 'B', windurst = 'W', jeuno = 'J'}

local AURIX_INCOMPLETE = 'Incomplete - Update at Aurix'
local function aurix_has_read(zone, prefix)
    local entry = settings.aurix and settings.aurix[zone]
    return entry and type(entry[prefix]) == 'number'
end

-- Completed, an Aurix update reminder, or the letters of zones still to do.
local function zone_cell(state, job, prefix, width)
    local missing = {}
    for _, zone in ipairs(DYN_ZONES) do
        if not req_met(state, job, prefix .. '_' .. zone) then
            if not aurix_has_read(zone, prefix) then return paint(C.yellow, pad(AURIX_INCOMPLETE, width)) end
            missing[#missing + 1] = ZONE_LETTER[zone]
        end
    end
    if #missing == 0 then return paint(C.green, pad('Completed', width)) end
    return paint(#missing == #DYN_ZONES and C.red or C.yellow, pad('Missing ' .. table.concat(missing, ','), width))
end

local UNLOCK_COLUMNS = {
    {label = 'Sortie Enter', kind = 'empyrean', min = 10, cell = function(s, j, w) return flag_cell(s, j, 'sortie', w) end},
    {label = 'Sortie Basement', kind = 'empyrean', min = 10, cell = function(s, j, w) return flag_cell(s, j, 'bitzer', w) end},
    {label = 'Dyna D Enter', kind = 'relic', min = #AURIX_INCOMPLETE, cell = function(s, j, w) return zone_cell(s, j, 'dd', w) end},
    {label = 'Dyna D W1 Boss', kind = 'relic', min = #AURIX_INCOMPLETE, cell = function(s, j, w) return zone_cell(s, j, 'ddc', w) end},
}

-- The Unlocks view, read only: everything is a line in the window.
--  A job tab: every unlock for that job, Incomplete ones first, then Completed ones.
--  ALL: a table with a row per job, then the character-wide unlocks that are still incomplete.
local function unlocks_lines(state, job, kind_filter)
    local lines = {}
    local unread = aurix_unread(kind_filter)
    if unread then
        lines[#lines + 1] = paint(C.yellow, 'DYNAMIS UNLOCKS: AURIX MENU NOT CHECKED')
        lines[#lines + 1] = paint(C.yellow, AURIX_HOWTO)
        lines[#lines + 1] = ''
    end
    if job then
        local done, open = unlocks_for_job(state, job, kind_filter)
        if #open == 0 then
            lines[#lines + 1] = paint(C.green, job .. ': Completed - every unlock is done')
        else
            lines[#lines + 1] = paint(C.cyan, string.format('%s: %d incomplete, %d completed', job, #open, #done))
        end
        for _, item in ipairs(open) do
            local prefix, zone = item.id:match('^(ddc?)_(%a+)$')
            local needs_read = prefix and not aurix_has_read(zone, prefix)
            local status = needs_read and (AURIX_INCOMPLETE .. '  ') or pad('Incomplete', 12)
            lines[#lines + 1] = paint(needs_read and C.yellow or C.red, status)
                .. clip(U.requirements[item.id].text, math.min(80, 100 - #status))
                .. paint(C.gray, ' (' .. item.id .. ')')
        end
        for _, id in ipairs(done) do
            lines[#lines + 1] = paint(C.green, pad('Completed', 12)) .. paint(C.gray, clip(U.requirements[id].text, 90))
        end
        if #open > 0 then
            lines[#lines + 1] = paint(C.gray, 'Read from what you own and your key items. If one is wrong: //armor done <id> ' .. job)
        end
        for _, item in ipairs(open) do
            if not unread and item.id:match('^ddc?_') then
                lines[#lines + 1] = paint(C.yellow, clip(AURIX_HOWTO, 110))
                lines[#lines + 1] = paint(C.gray, aurix_status())
                break
            end
        end
        return lines
    end

    local cols = {}
    for _, col in ipairs(UNLOCK_COLUMNS) do
        if not kind_filter or kind_filter == col.kind then cols[#cols + 1] = col end
    end
    if #cols == 0 then
        lines[#lines + 1] = paint(ARMOR_ACCENT.artifact, 'Artifact') .. paint(C.gray, ' armor has no per-job unlocks.')
    else
        lines[#lines + 1] = paint(C.cyan, 'Per-job unlocks. Pick a job tab for the full list.')
        local head = {paint(C.gray, pad('Job', 5))}
        for _, col in ipairs(cols) do
            head[#head + 1] = paint(ARMOR_ACCENT[col.kind], pad(col.label, math.max(#col.label, col.min) + 2))
        end
        lines[#lines + 1] = table.concat(head)
        for _, j in ipairs(U.job_order) do
            local row = {pad(j, 5)}
            for _, col in ipairs(cols) do
                row[#row + 1] = col.cell(state, j, math.max(#col.label, col.min) + 2)
            end
            lines[#lines + 1] = table.concat(row)
        end
        for _, col in ipairs(cols) do
            if col.kind == 'relic' then
                lines[#lines + 1] = paint(C.gray, "Zones: S San d'Oria (feet)  B Bastok (hands)  W Windurst (head)  J Jeuno (legs)")
                if not unread and dyn_open(state, nil) then
                    lines[#lines + 1] = paint(C.yellow, clip(AURIX_HOWTO, 110))
                    lines[#lines + 1] = paint(C.gray, aurix_status())
                end
                break
            end
        end
    end

    local done, open = 0, {}
    for _, id in ipairs(applicable_ids(kind_filter)) do
        local def = U.requirements[id]
        if def and def.scope == 'char' then
            if req_met(state, nil, id) then done = done + 1 else open[#open + 1] = id end
        end
    end
    if #open == 0 then
        lines[#lines + 1] = paint(C.green, string.format('Character-wide unlocks: Completed (%d)', done))
    else
        lines[#lines + 1] = paint(C.cyan, string.format('Character-wide unlocks: %d incomplete, %d completed', #open, done))
        for _, id in ipairs(open) do
            lines[#lines + 1] = paint(C.red, pad('Incomplete', 12)) .. clip(U.requirements[id].text, 80)
                .. paint(C.gray, ' (' .. id .. ')')
        end
    end
    return lines
end

local function material_label(name, count, holding)
    local label = string.format('    %s x%d', name, count)
    local locations = {}
    if holding then
        for bag, quantity in pairs(holding.bags) do
            if bag ~= 'Stored' then
                locations[#locations + 1] = string.format('%s x%d', bag, quantity)
            end
        end
        table.sort(locations)
    end
    local chapter = tonumber(name:match("^Rem's Tale Ch%.(%d+)$"))
    if chapter then
        local stored = balances.tales and balances.tales[chapter]
        table.insert(locations, 1, 'Stored: ' .. currency_amount(stored))
    end
    if #locations > 0 then label = label .. ' (' .. table.concat(locations, ', ') .. ')' end
    return holding and holding.total > 0 and paint(C.green, label) or label
end

local function materials_lines(state, job, kind_filter, slot_filter, next_only, stage)
    if not job then return {paint(C.gray, 'Select a job to see its upgrade materials.')} end

    local lines, groups, blocks = {}, {}, {}
    local last_kind
    for _, e in ipairs(entries_for(state, job, kind_filter)) do
        if (not slot_filter or e.slot == slot_filter)
            and (not stage or stage == 1 or (e.steps and e.steps[stage])) then
            local entry_start = #lines + 1
            local status = e.piece and (e.piece.name .. ' (' .. tier_label(e.piece) .. ')') or '(Not started)'
            lines[#lines + 1] = paint(ARMOR_ACCENT[e.kind], string.format('%s %s  %s', KIND_NAME[e.kind],
                e.slot:gsub('^%l', string.upper), status))
            if e.done then
                blocks[#blocks + 1] = entry_start
                lines[#lines + 1] = '  ' .. paint(C.green, 'Complete')
            else
                local last = slot_filter and not next_only and #e.steps or (stage or 1)
                for i = stage or 1, last do
                    local step = e.steps[i]
                    local step_start = #lines + 1
                    if step.acquire then
                        local instruction = 'Obtain ' .. step.base
                        local inline_source = e.kind == 'relic' and step.target == 'base piece'
                        if inline_source then instruction = instruction .. ' from ' .. step.source end
                        local show_start_hint = not next_only and (last > 1 or (stage and #e.steps > 1))
                        local start_hint = show_start_hint and paint(C.cyan, '  < Start here') or ''
                        lines[#lines + 1] = '  ' .. paint(C.yellow, instruction) .. start_hint
                        if not inline_source then lines[#lines + 1] = '    ' .. step.source end
                        if e.kind == 'empyrean' and e.slot == 'legs' and step.target == 'base piece' then
                            lines[#lines + 1] = "    1 Copper Voucher gives 1,000 Resistance Credits at a Sparks NPC:"
                            lines[#lines + 1] = "    Rolandienne (Southern San d'Oria G-10) or Isakoth (Bastok Markets E-11)"
                            lines[#lines + 1] = "    Fhelm Jobeizat (Windurst Woods J-10) or Eternal Flame (Western Adoulin H-11)"
                        end
                    else
                        for _, material in ipairs(step.mats) do
                            local name, count = material[1], material[2]
                            local id = item_id(name)
                            local holding = state.holdings[id]
                            local label = material_label(name, count, holding)
                            local source = (not holding or holding.total == 0) and U.material_sources[id]
                            if source and not source.npcs and source.ah then
                                label = label .. paint(C.gray, ' | AH: ' .. source.ah)
                            end
                            lines[#lines + 1] = label
                            if source and source.npcs then
                                for _, npc in ipairs(source.npcs) do
                                    lines[#lines + 1] = paint(C.gray, '      NPC: ' .. npc)
                                end
                                if source.stock then
                                    lines[#lines + 1] = paint(C.gray, '           ' .. source.stock)
                                end
                                if source.ah then
                                    lines[#lines + 1] = paint(C.gray, '      AH: ' .. source.ah)
                                end
                            end
                        end
                        for _, currency in ipairs(step.cur or {}) do
                            local name, required = currency[1], currency[2]
                            local current = currency_balance(name)
                            lines[#lines + 1] = '    ' .. currency_label(name, required, current)
                        end
                        if #lines >= step_start then
                            local heading = '  ' .. paint(C.white, step.target)
                            if i == (e.steps[1].acquire and 2 or 1) then
                                heading = heading .. paint(C.cyan, '  < Next upgrade')
                            end
                            table.insert(lines, step_start, heading)
                        end
                    end
                    if #lines >= step_start then
                        blocks[#blocks + 1] = step_start == entry_start + 1 and entry_start or step_start
                    end
                end
            end
            if e.kind ~= last_kind then
                groups[#groups + 1] = entry_start
                last_kind = e.kind
            end
        end
    end
    return lines, groups, blocks
end

local function max_lines()
    local cfg = windower.get_windower_settings and windower.get_windower_settings()
    local screen = cfg and cfg.ui_y_res or 1080
    if gui.view == 'materials' then
        local _, title_height = box_size(gui.boxes.title)
        local row_height = math.max(21, title_height - 6)
        local header_height = (title_height + 2) * (gui.job and 5 or 4) + 8
        local fit = math.floor((screen - gui.y - header_height) / row_height)
        return math.max(1, math.min(24, fit))
    end
    local fit = math.floor((screen - gui.y - 150) / 15)
    return math.max(12, math.min(40, fit))
end

local function material_panels(lines, limit, groups, blocks)
    if #lines == 0 then return {} end
    local starts = blocks and #blocks > 0 and blocks or {1}
    local end_of_lines = #lines + 1
    local breaks, group_starts = {1}, {}
    local used, group = 0, 1
    for i, first in ipairs(starts) do
        local size = (starts[i + 1] or end_of_lines) - first
        local group_size = 0
        if groups and groups[group] == first then
            group_starts[i] = true
            group_size = (groups[group + 1] or end_of_lines) - first
            group = group + 1
        end
        if used > 0 and used + math.max(size, group_size) > limit then
            breaks[#breaks + 1] = i
            used = 0
        end
        used = used + size
    end

    -- Move whole upgrades into short overflow panels, without crossing armor-type boundaries.
    for i = #breaks, 2, -1 do
        local right_end = starts[breaks[i + 1]] or end_of_lines
        local left_start = starts[breaks[i - 1]]
        local split = breaks[i]
        while split > breaks[i - 1] + 1 and not group_starts[split] do
            local candidate = starts[split - 1]
            local left_size = candidate - left_start
            local right_size = right_end - candidate
            if right_size > limit or left_size <= right_size then break end
            split = split - 1
        end
        breaks[i] = split
    end

    local panels = {}
    for i, first in ipairs(breaks) do
        local next_line = starts[breaks[i + 1]] or end_of_lines
        panels[i] = table.concat(lines, '\n', starts[first], next_line - 1)
    end
    return panels
end

local function show_panels(b, first, second, third, pages)
    b.body:text(first)
    gui.has_second_panel = second ~= nil
    if gui.has_second_panel then
        b.continuation:text(second)
        b.continuation:show()
    else
        b.continuation:hide()
    end
    gui.has_third_panel = third ~= nil
    if gui.has_third_panel then
        b.third:text(third)
        b.third:show()
    else
        b.third:hide()
    end
    if pages > 1 then
        b.pages[1]:text(paint(gui.material_page > 1 and C.white or C.gray, ' < Prev '))
        b.pages[2]:text(paint(gui.material_page < pages and C.white or C.gray,
            string.format(' Next > (%d/%d) ', gui.material_page, pages)))
        for _, box in ipairs(b.pages) do box:show() end
    else
        for _, box in ipairs(b.pages) do box:hide() end
    end
    gui.material_pages = pages
end

local function render_material_panels(b, lines, limit, groups, blocks)
    local panels = material_panels(lines, limit, groups, blocks)
    local pages = math.max(1, math.ceil(#panels / 3))
    gui.material_page = math.min(gui.material_page, pages)
    local first = (gui.material_page - 1) * 3 + 1
    show_panels(b, panels[first] or '', panels[first + 1], panels[first + 2], pages)
end

local function render_material_stages(b, state, limit)
    local headings = {'Current objective', 'Next upgrade', 'Following upgrade'}
    local columns = {}
    local pages, last = 1, 1
    for stage, heading in ipairs(headings) do
        local lines, _, blocks = materials_lines(state, gui.job, gui.kind, nil, false, stage)
        if #lines > 0 then last = stage end
        if #lines == 0 then
            lines[1] = paint(C.gray, 'No further upgrades.')
        end
        local panels = material_panels(lines, math.max(1, limit - 1), nil, blocks)
        for i, panel in ipairs(panels) do panels[i] = paint(JOB_ACCENT[gui.job], heading) .. '\n' .. panel end
        columns[stage] = panels
        pages = math.max(pages, #panels)
    end
    gui.material_page = math.min(gui.material_page, pages)
    local page = gui.material_page
    show_panels(b, columns[1][page] or '',
        last >= 2 and (columns[2][page] or '') or nil, last >= 3 and (columns[3][page] or '') or nil, pages)
end

local panel_layout_pending = false
local function render()
    if not gui.visible or not gui.boxes then return end
    local b = gui.boxes
    local state = gui.state
    local progress_view = gui.view == 'steps'
    local unlocks_view = gui.view == 'unlocks'
    local cards_view = gui.view == 'cards'
    local materials_view = gui.view == 'materials'
    local stages_view = materials_view and state and gui.job and gui.kind and not gui.material_slot and not gui.material_next_only

    b.title:text(paint(C.cyan, ' Armor Ledger ') .. paint(C.gray, gui.busy and '(reading...) ' or '(drag here) '))
    b.close:text(paint(C.red, ' X '))
    b.refresh:text(paint(gui.busy and C.gray or C.white, ' ↻ '))
    b.progress:text(paint(progress_view and C.yellow or C.white, progress_view and '[Progress]' or ' Progress '))
    b.unlocks:text(paint(unlocks_view and C.yellow or C.white, unlocks_view and '[Unlocks]' or ' Unlocks '))
    b.cards:text(paint(cards_view and C.yellow or C.white, cards_view and '[Cards]' or ' Cards '))
    b.materials:text(paint(materials_view and C.yellow or C.white, materials_view and '[Materials]' or ' Materials '))
    if materials_view and gui.job then
        b.next_only:text(paint(gui.material_next_only and C.yellow or C.white, gui.material_next_only and '[Compact]' or ' Compact '))
        b.next_only:show()
    else
        b.next_only:hide()
    end
    for i, box in ipairs(b.slots) do
        if materials_view and gui.job then
            local slot = SLOTS[i - 1]
            local label = slot and slot:gsub('^%l', string.upper) or 'All'
            local selected = slot == gui.material_slot
            box:text(paint(selected and C.yellow or C.white, selected and ('[' .. label .. ']') or (' ' .. label .. ' ')))
            box:show()
        else
            box:hide()
        end
    end
    for i, f in ipairs(FILTERS) do
        local sel = (gui.kind or false) == f[2]
        b.filters[i]:text(paint(ARMOR_ACCENT[f[2]], sel and ('[' .. f[1] .. ']') or (' ' .. f[1] .. ' ')))
    end
    for i, t in ipairs(b.tabs) do
        local job = i > 1 and U.job_order[i - 1] or nil
        local label = job or 'ALL'
        local sel = job == gui.job
        local color = JOB_ACCENT[label] or ARMOR_ACCENT[false]
        if t:bold() ~= sel then t:bold(sel) end
        t:text(paint(color, sel and ('[' .. label .. ']') or (' ' .. label .. ' ')))
    end
    if materials_view then b.tabs[1]:hide() else b.tabs[1]:show() end

    local lines, material_groups, material_blocks, progress_groups
    if not state then
        lines = {paint(C.gray, 'Reading your bags...')}
    elseif cards_view then
        lines = cards_lines(state, gui.job)
    elseif stages_view then
        lines = {}
    elseif materials_view then
        lines, material_groups, material_blocks = materials_lines(state, gui.job, gui.kind, gui.material_slot, gui.material_next_only)
    elseif unlocks_view then
        lines = unlocks_lines(state, gui.job, gui.kind)
    elseif gui.job then
        lines, progress_groups = job_lines(state, gui.job, gui.kind)
    else
        lines = overview_lines(state, gui.kind)
    end
    local split_progress = progress_groups and #progress_groups == 3
    gui.line_count = #lines
    if materials_view then
        if stages_view then
            render_material_stages(b, state, max_lines())
        else
            render_material_panels(b, lines, max_lines(), material_groups, material_blocks)
        end
    else
        local limit = max_lines()
        if split_progress then
            gui.line_count = math.max(progress_groups[2] - progress_groups[1], progress_groups[3] - progress_groups[2],
                #lines - progress_groups[3] + 1)
        end
        if gui.line_count <= limit + 3 then limit = gui.line_count end
        gui.limit = limit
        gui.scroll = math.max(0, math.min(gui.scroll, gui.line_count - limit))

        local function panel_text(first, last)
            local slice = table.concat(lines, '\n', first + gui.scroll, math.min(last, first + gui.scroll + limit - 1))
            if last - first + 1 > limit then
                slice = slice .. '\n' .. paint(C.gray, '-- mouse wheel scrolls --')
            end
            return slice
        end
        if split_progress then
            show_panels(b, panel_text(1, progress_groups[2] - 1),
                panel_text(progress_groups[2], progress_groups[3] - 1), panel_text(progress_groups[3], #lines), 1)
        else
            show_panels(b, panel_text(1, #lines), nil, nil, 1)
        end
    end
    layout()
    if (materials_view or split_progress) and not panel_layout_pending then
        panel_layout_pending = true
        coroutine.schedule(function()
            panel_layout_pending = false
            if gui.visible and (gui.view == 'materials' or gui.has_second_panel) then layout() end
        end, 0.1)
    end
end

local function gui_refresh()
    gui.busy = true
    render()
    with_balances(function()
        gui.busy = false
        gui.state = read_state()
        render()
    end)
end

-- A fresh Aurix read redraws the open window with the exact zones still missing. The two pages arrive a
-- second apart, so the redraw waits a moment and covers both.
local aurix_redraw_pending = false
aurix_synced = function()
    if not gui.visible or aurix_redraw_pending then return end
    aurix_redraw_pending = true
    coroutine.schedule(function()
        aurix_redraw_pending = false
        if not gui.visible then return end
        gui.state = read_state()
        render()
    end, 0.5)
end

local function gui_close(announce)
    gui.visible = false
    gui.drag, gui.pressed = nil, false
    each_box(function(box) box:hide() end)
    if announce then say('Armor Ledger: Type //armor to reopen the HUD.', WHITE) end
end

local aurix_reminded = {}
local function remind_aurix()
    if not player_name or aurix_reminded[player_name] or not aurix_unread(gui.kind) then return end
    aurix_reminded[player_name] = true
    say('Armor Ledger: Aurix menu not checked. ' .. AURIX_HOWTO, YELLOW)
end

local function gui_open(job, kind)
    ensure_boxes()
    local pos = settings.gui
    if pos and tonumber(pos.x) and tonumber(pos.y) then gui.x, gui.y = tonumber(pos.x), tonumber(pos.y) end
    if job or gui.view ~= 'materials' then gui.job = job end
    if kind then gui.kind = kind end
    gui.visible = true
    gui.scroll = 0
    gui.material_page = 1
    each_box(function(box) box:show() end)
    render()
    coroutine.schedule(function() if gui.visible then render() end end, 0.3) -- text sizes are only known once drawn
    gui_refresh()
end

local function gui_command(opts)
    if gui.visible and not opts.job and not opts.kind then return gui_close(true) end
    gui_open(opts.job, opts.kind)
end

local function gui_hit(x, y)
    local b = gui.boxes
    if b.close:hover(x, y) then return 'close' end
    if b.title:hover(x, y) then return 'title' end
    if b.refresh:hover(x, y) then return 'refresh' end
    if b.progress:hover(x, y) then return 'progress' end
    if b.unlocks:hover(x, y) then return 'unlocks' end
    if b.cards:hover(x, y) then return 'cards' end
    if b.materials:hover(x, y) then return 'materials' end
    if gui.view == 'materials' and gui.material_pages > 1 then
        for i, box in ipairs(b.pages) do if box:hover(x, y) then return 'material_page', i end end
    end
    for i, f in ipairs(b.filters) do if f:hover(x, y) then return 'filter', i end end
    for i, t in ipairs(b.tabs) do if t:hover(x, y) then return 'tab', i end end
    if gui.view == 'materials' and gui.job then
        if b.next_only:hover(x, y) then return 'material_next_only' end
        for i, box in ipairs(b.slots) do if box:hover(x, y) then return 'slot', i end end
    end
    if b.body:hover(x, y) or b.continuation:hover(x, y) or b.third:hover(x, y) then return 'body' end
    return nil
end

windower.register_event('mouse', function(kind, x, y, delta, blocked)
    -- Consume the release before hiding the HUD so the game never receives the close click.
    if kind == 2 and gui.pressed == 'close' then
        gui_close(true)
        return true
    end
    if blocked or not gui.visible or not gui.boxes then return end
    if kind == 0 then
        if gui.drag then
            gui.x, gui.y = x - gui.drag.dx, y - gui.drag.dy
            layout()
            return true
        end
    elseif kind == 1 then
        local what, i = gui_hit(x, y)
        if not what then return end
        gui.pressed = what
        if what == 'close' then
            return true
        elseif what == 'title' then
            gui.drag = {dx = x - gui.x, dy = y - gui.y}
        elseif what == 'refresh' then
            gui_refresh()
        elseif what == 'progress' then
            gui.view = 'steps'
            gui.job = nil
            gui.scroll = 0
            render()
        elseif what == 'unlocks' or what == 'cards' or what == 'materials' then
            gui.view = gui.view == what and 'steps' or what
            if gui.view == 'unlocks' then remind_aurix() end
            if gui.view == 'materials' then
                gui.material_page = 1
                gui.state = read_state(true)
                if not gui.job then
                    local player = windower.ffxi.get_player()
                    if player and JOB_BIT[player.main_job] then gui.job = player.main_job end
                end
            else
                gui.job = nil
            end
            gui.scroll = 0
            render()
        elseif what == 'material_next_only' then
            gui.material_next_only = not gui.material_next_only
            gui.material_page = 1
            render()
        elseif what == 'material_page' then
            gui.material_page = math.max(1, math.min(gui.material_pages, gui.material_page + (i == 1 and -1 or 1)))
            render()
        elseif what == 'slot' then
            gui.material_slot = SLOTS[i - 1]
            gui.material_page = 1
            gui.scroll = 0
            render()
        elseif what == 'filter' then
            gui.kind = FILTERS[i][2] or nil
            gui.material_page = 1
            gui.scroll = 0
            render()
        elseif what == 'tab' then
            gui.job = i > 1 and U.job_order[i - 1] or nil
            gui.material_page = 1
            gui.scroll = 0
            render()
        end
        return true
    elseif kind == 2 then
        if gui.drag then
            gui.drag = nil
            settings.gui = {x = gui.x, y = gui.y}
            save_settings()
            if gui.view == 'materials' then render() end
        end
        if gui.pressed then
            gui.pressed = false
            return true
        end
    elseif kind == 10 then
        local b = gui.boxes
        if gui.view ~= 'materials' and gui.line_count > gui.limit
            and (b.body:hover(x, y) or b.continuation:hover(x, y) or b.third:hover(x, y)) then
            gui.scroll = gui.scroll + (delta > 0 and -3 or 3)
            render()
            return true
        end
    end
end)

local materials_refresh_pending = false
windower.register_event('add item', 'remove item', function()
    if not gui.visible or gui.view ~= 'materials' or materials_refresh_pending then return end
    materials_refresh_pending = true
    coroutine.schedule(function()
        materials_refresh_pending = false
        if not gui.visible or gui.view ~= 'materials' then return end
        gui.state = read_state(true)
        render()
    end, 0.3)
end)

windower.register_event('unload', function()
    each_box(function(box) box:destroy() end)
end)

local function parse_args(args)
    local opts = {words = {}}
    for _, word in ipairs(args) do
        local lower = word:lower()
        if lower == 'slips' then
            -- slips are always read now; the word is accepted and ignored
        elseif lower == 'all' then
            opts.all = true
        elseif KIND_ALIAS[lower] then
            opts.kind = KIND_ALIAS[lower]
        elseif U.jobs[word:upper()] then
            opts.job = word:upper()
        else
            opts.words[#opts.words + 1] = word
        end
    end
    return opts
end

windower.register_event('addon command', function(cmd, ...)
    cmd = cmd and cmd:lower() or 'gui'
    local args = {...}
    if cmd == 'help' then
        say('Armor Ledger: //armor (opens the window) | //armor gui [job] [af|relic|empy] | //armor summary [job] [af|relic|empy] | missing | job <job> | need [all] | clears | next | cards [job] | export | aurix | probe')
        say('Armor Ledger: //armor done|undo <id> [job] | flags [job] | final 3|4')
        return
    end
    -- a first word that is really a job or kind opens the window on it
    if cmd ~= 'summary' and cmd ~= 'missing' and cmd ~= 'job' and cmd ~= 'need' and cmd ~= 'clears'
        and cmd ~= 'next' and cmd ~= 'done' and cmd ~= 'undo' and cmd ~= 'flags' and cmd ~= 'final'
        and cmd ~= 'export' and cmd ~= 'gui' and cmd ~= 'cards' and cmd ~= 'probe' and cmd ~= 'aurix' then
        table.insert(args, 1, cmd)
        cmd = 'gui'
    end
    local opts = parse_args(args)
    if not player_name then load_settings() end

    if cmd == 'gui' then return gui_command(opts) end
    if cmd == 'aurix' then return show_aurix(opts.words[1] and opts.words[1]:lower() == 'clear') end
    if cmd == 'probe' then
        local mode = opts.words[1] and opts.words[1]:lower()
        if mode == 'note' then
            -- //armor probe note WAR head hands unlocked: tags the log so each sample says what it should decode to
            local text = table.concat(opts.words, ' ', 2)
            if opts.job then text = opts.job .. ' ' .. text end
            if text == '' then return say('Armor Ledger: //armor probe note <what this sample should show>') end
            windower.create_dir(windower.addon_path .. 'data')
            local f = io.open(data_path('probe.log'), 'a')
            if f then
                local player = windower.ffxi.get_player() or {}
                f:write(os.date('[%Y-%m-%d %H:%M:%S] ') .. string.format('job %s/%s  NOTE %s\n',
                    tostring(player.main_job), tostring(player.sub_job), text))
                f:close()
            end
            return say('Armor Ledger: note written to data/probe.log.', GREEN)
        end
        probe.on = (mode == 'on') or (mode ~= 'off' and not probe.on)
        if probe.on then
            say("Armor Ledger: probe ON. Stand by Aurix (Ru'Lude Gardens) or Ruspix (Leafallia), talk to him, open his list, then back out. "
                .. 'Nothing is sent; menus are only recorded to data/probe.log. //armor probe off to stop.', GREEN)
        else
            say('Armor Ledger: probe off. ' .. probe.count .. ' packets logged to data/probe.log.')
        end
        return
    end
    if cmd == 'final' then
        local n = tonumber(opts.words[1])
        if n ~= 3 and n ~= 4 then return say('Armor Ledger: //armor final 3|4 (now +' .. settings.final .. ')') end
        settings.final = n
        save_settings()
        return say('Armor Ledger: Artifact and Relic now count as finished at +' .. n .. '.', GREEN)
    elseif cmd == 'done' or cmd == 'undo' then
        local id = opts.words[1] and opts.words[1]:lower()
        if not id then return say('Armor Ledger: //armor ' .. cmd .. ' <id> [job]; //armor flags lists the ids.') end
        return set_flag(id, opts.job, cmd == 'done')
    end

    with_balances(function()
        local state = read_state()
        if cmd == 'summary' then
            show_summary(state, opts.job, opts.kind)
        elseif cmd == 'missing' then
            show_missing(state, opts.job, opts.kind)
        elseif cmd == 'job' then
            if not opts.job then return say('Armor Ledger: //armor job <job> [af|relic|empy]') end
            show_job(state, opts.job, opts.kind)
        elseif cmd == 'need' then
            show_need(state, opts.job, opts.kind, opts.all)
        elseif cmd == 'clears' then
            show_clears(state, opts.job, opts.kind)
        elseif cmd == 'next' then
            show_next(state, opts.job, opts.kind)
        elseif cmd == 'flags' then
            show_flags(state, opts.job)
        elseif cmd == 'cards' then
            show_cards(state, opts.job)
        elseif cmd == 'export' then
            export(state)
        end
    end)
end)

windower.register_event('incoming chunk', function(id, original)
    if id == 0x113 or id == 0x118 then currencies_arrived(id, original) end
    if id == 0x05C then aurix_incoming(original) end
    if probe.on then
        if id == 0x034 then
            probe_log('in', id, original)
        elseif id == 0x05C and probe.last and os.time() - probe.last < PROBE_WINDOW then
            probe_raw('IN  submenu', id, original)
        elseif (id == 0x036 or id == 0x02A or id == 0x03C or id == 0x03D) and probe.last and os.time() - probe.last < 30 then
            -- what the NPC says (0x036, 0x02A) and any shop/trade list (0x03C, 0x03D): the +2 info may come as text
            probe_raw('IN  pkt', id, original)
        elseif id == 0x033 then
            local ok, p = pcall(packets.parse, 'incoming', original)
            if ok and p and probe_npc(p['NPC']) then
                probe.last = os.time()
                probe_raw('IN  string menu', id, original)
            end
        end
    end
end)

windower.register_event('outgoing chunk', function(id, original)
    if id == 0x05B then
        aurix_outgoing(original)
        if probe.on then probe_log('out', id, original) end
    end
end)

local function open_hud_on_load()
    load_settings()
    if player_name and not gui.visible then gui_open() end
end

windower.register_event('load', open_hud_on_load)
windower.register_event('login', function()
    coroutine.schedule(function()
        if not player_name then open_hud_on_load() end
    end, 3)
end)
windower.register_event('logout', function() player_name = nil; gui_close() end)

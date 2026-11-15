# LimbusBar

A [Windower 4](https://www.windower.net/) addon for Temenos and Apollyon (Limbus). It shows the floor's progress bar on screen, estimates how many kills are left to fill it, marks a floor as completed once you hold its temp item, and can run a command of your choice when the bar passes a percentage.

The addon only reads incoming packets. It never sends anything itself; the only thing it ever runs is the command you give it with `//lb auto`.

## Install

1. Put `limbusbar.lua` in `Windower4/addons/limbusbar/`.
2. Load it with `//lua load limbusbar` (add `lua load limbusbar` to your `init.txt` to load it automatically).
3. The commands are `//limbusbar` or `//lb`.

## What you see

The bar appears automatically in Temenos and Apollyon and hides when you leave:

```
 North_Tower_F1: 42 / 100 (42%)
 [||||||||||||||..................]
 last kill: +21 | ~3 kills to full | ~5 per bar
```

- The bar is red below 33%, yellow below 66%, and green from 66%.
- **Kill line:** each time the bar goes up, the increase is recorded as the last kill's gain. "Kills to full" is the points remaining divided by that gain, rounded up. "Per bar" is the same calculation from 0: how many kills a whole bar takes at that gain. It measures again on every new floor. It counts bar increases rather than mobs, so treat it as an estimate. It corrects itself on the next single kill.
- **Floor completed:** if the temp item for the floor you're on is already in your temporary items bag, the bar and all the text turn cyan and the header reads `- Floor completed *`.

## Commands

| Command | What it does |
| --- | --- |
| `//lb hide` / `//lb show` | Hide or show the bar. |
| `//lb kills on` / `off` | Show or hide the last-kill / kills-to-full line (on by default). |
| `//lb width <n>` | Bar length in characters (default 30). |
| `//lb test <n>` | Preview the bar at value `n` anywhere. Run it twice (e.g. `21` then `42`) to preview the kill line. |
| `//lb test <n> done` | Preview the cyan Floor completed look. |
| `//lb auto <command>` | Run `<command>` once when the bar is over 50% **and** this floor's temp item is already held. |
| `//lb auto <n> <command>` | Same, at `n`% instead of 50%. |
| `//lb auto <n>` | Change the percentage only, keeping the current command. |
| `//lb auto` | Show the auto trigger status. |
| `//lb auto off` | Turn the auto trigger off. |
| `//lb complete <command>` | Run `<command>` once when the temp item for the floor you're on is **gained** (the bar filled and the item arrived). |
| `//lb complete` / `//lb complete off` | Show the status / turn it off. |
| `//lb autotemp off` / `on` | `off` ignores the temp item and fires on the bar percentage alone (useful for testing before you have a temp item). `on` requires it (default). |
| `//lb floor` | Diagnostic: shows the floor name read from the packet, the floor it maps to, its temp item ID, and whether you hold it. |
| `//lb help` | List the commands. |

You can drag the bar with the mouse. The position and width are saved to `addons/limbusbar/data/settings.xml`.

### Auto trigger

```
//lb auto input /echo Floor bar over 50%
//lb auto 70 input /ma "Cure" <me>
```

- `<command>` is any Windower console command. Game commands go through `input`.
- It fires **once per crossing**, then stays quiet until the bar drops back to the threshold or below (the bar empties when it fills) or you zone, which re-arms it.
- With the temp item check on (default), nothing fires on floors where you don't already hold that floor's temp item, or on floors that don't give one (such as the final Central floors).
- With `//lb autotemp off` it works in Temenos and Apollyon only, and fires as soon as the bar is over the threshold.

### Floor complete trigger

```
//lb complete input /echo Floor done!
```

- It fires **once**, at the moment the temp item for your current floor goes from not held to held.
- The first check on each floor only records whether you already hold the item. Setting the trigger, entering a floor, or zoning while you already have the item never fires it.
- If the bar fills but you already held the floor's temp item, you get units instead of an item. Nothing fires in that case. Use `//lb auto` if you want a command in that situation.
- It does not poll. It looks at your temporary items bag only shortly after an item packet arrives. It reads the game's local memory and sends nothing to the server.
- Like `//lb auto`, it depends on the floor name being recognized (see Known limitations). It does not need `//lb auto` to be on.

## How it works

- The floor bar comes from packet `0x075` (172 bytes, type byte `0x02` at offset 36). The bar value is a 4-byte little-endian number at offset 60, on a scale of 0 to 100. The floor name is a string at offset 64.
- The bar is read only in Temenos (zone 37) and Apollyon (zone 38).
- Temp item IDs are the ones used by Superwarp's `limbus.lua`. The floor name from the packet is mapped to a floor (`North_Tower_F1` → N1, `Center_Tower_F2` → C2, `NW_Floor_#1` → NW1) and then to its item ID. The addon checks your temporary items bag (bag 3) for that item ID, and also for the item's in-game name (`Tem. C-F1`, `Apollyon NW #1`), so a wrong ID can't hide an item you hold.

## Known limitations

- The floor name mapping has been confirmed for Temenos `North_Tower_F1` and `Center_Tower_F2` and Apollyon `NW_Floor_#1`. The other floors follow the same naming pattern but are unconfirmed. If a floor name isn't recognized while the auto trigger needs it, you get a single warning with the exact name. Please report it.
- The final Central floors (Temenos Central B1 and Central Apollyon) have no temp item, and their floor names are unconfirmed.
- Kills to full is based on the last kill's bar gain, so it can be off when several mobs die at once or the bar moves for another reason.
- The bar value and the temp item check cover only the floor you're currently on.

## Credits

- Written by maxom.
- Floor temp item IDs from Superwarp's `limbus.lua`.

# Focus

A Windower 4 addon for Final Fantasy XI that lets you pick a **focus target** by name and use weaponskills, job abilities and spells on it from a macro **without changing your current target**. It works with GearSwap, so your precast, midcast and aftercast sets still run. It also draws an optional on-screen HP bar for the focus.

The focus target is a feature of this addon, not of the game. FFXI itself only has a main target and a subtarget.

## Requirements

- Windower 4
- GearSwap (loaded). The `<ft>` feature relies on GearSwap understanding a mob ID typed as the target of a command.

## Installation

1. Create the folder `Windower4/addons/focus/`.
2. Put `focus.lua` inside it, so the path is `Windower4/addons/focus/focus.lua`.
3. In game, run `//lua load focus`.
4. To load it automatically, add `lua load focus` to your `init.txt`.

## Quick start

1. Set your focus: `//foc Goblin Smithy` (or target a mob and run `//foc` on its own).
2. Use it in a macro: `/ws "Savage Blade" <ft>`
3. Watch its HP on the bar, if the bar is on (it is by default).

## Setting the focus

| Command | What it does |
| --- | --- |
| `//foc <name>` | Sets the focus by name. Matching order: exact name, then a name that starts with what you typed, then a name that contains it. Not case sensitive. |
| `//foc <id>` | Sets the focus by mob ID (a number). |
| `//foc` | Sets the focus to your current target. |
| `//foc clear` | Clears the focus. |

The focus is cleared when you zone or log out.

Note: the words `bar`, `ws`, `ja` and `ma` are reserved as commands, so you can't set a focus by typing one of those as a name.

## Acting on the focus

Use `<ft>` as the target in any command or macro line:

```
/ws "Savage Blade" <ft>
/ma "Stun" <ft>
/ja "Provoke" <ft>
```

You can also run these from the console or from a `/console` line in a macro:

```
//foc ws Savage Blade
//foc ja Provoke
//foc ma Stun
/console foc ws Savage Blade
```

Your current target is not changed.

### How it works

GearSwap treats a number at the end of a typed command as a mob ID, builds the action aimed at that mob, and runs your sets for it. When you use `<ft>`, this addon replaces it with the focus's mob ID and re-sends the command. Because the command is re-sent, it doesn't matter whether Focus or GearSwap loaded first.

### Things to know

- If no valid focus is set, or the focus is out of range or has left the zone, the command is **blocked** and you get a warning in chat. It will not fall back to your current target.
- The game and server still enforce their normal rules: range, TP, recast and whether the action is allowed on that target. A failed action shows the usual game message.
- Weaponskills on a mob you are not engaged with may be refused by the server. Job abilities and spells such as Provoke or Stun are more likely to work on a non-engaged focus.
- Only `/ws`, `/ja` and `/ma` are covered by the `//foc ws/ja/ma` commands. `<ft>` itself is replaced in any command, but whether GearSwap handles a given command type is up to GearSwap.
- Pet commands (Sic, Ready moves) and other special ability types have not been tested.

## HP bar

The bar shows the focus's name and HP percentage above a bar that fills with color. It appears whenever a focus is set and in the zone. It stays visible at 0% if the focus dies, and hides when there is no focus, the focus leaves the zone, or you log out.

| Command | What it does |
| --- | --- |
| `//foc bar` | Toggles the bar on or off. |
| `//foc bar on` / `//foc bar off` | Turns the bar on or off. |
| `//foc bar unlock` | Makes the bar draggable. It is shown even with no focus (as "Focus target (drag me)") so you can grab it. |
| `//foc bar lock` | Stops dragging and saves the position. |
| `//foc bar pos <x> <y>` | Moves the bar to a screen position in pixels. |
| `//foc bar width <n>` | Sets the bar width in pixels. |
| `//foc bar height <n>` | Sets the bar height in pixels. |
| `//foc bar color <r> <g> <b>` | Sets the bar color, each value 0 to 255. |
| `//foc bar font <name>` | Sets the label font. |
| `//foc bar fontsize <n>` | Sets the label font size. |

To move the bar: run `//foc bar unlock`, click and hold it with the left mouse button, drag it where you want, release, then run `//foc bar lock`.

Settings are saved between sessions. The bar is always locked after the addon loads. While you are dragging, mouse clicks on the bar are not passed through to the game.

Default position is x 680, y 670. If you can't see the bar, make sure a focus is set, then try `//foc bar pos 400 300`.

## Troubleshooting

- **Nothing happens when I use `<ft>`:** make sure GearSwap is loaded and a focus is set. Turn the bar on (`//foc bar on`) to check that the focus is set and in range.
- **"No valid focus is set" warning:** set the focus again with `//foc <name>`. It clears when you zone.
- **I see a mob ID in chat but the action doesn't fire:** GearSwap is probably not loaded or is disabled. The game itself can't use a raw ID as a target.
- **The wrong mob is chosen when I set the focus by name:** several mobs may share the name. Target the one you want and run `//foc` with no name, or use `//foc <id>`.
- **The bar is gone after reloading:** check `//foc bar on` and that a focus is set. The position is saved, but the focus is not.

## Credits

The focus target name matching follows the logic used by the focus target feature in the enemybar2 addon by mmckee and akaden.

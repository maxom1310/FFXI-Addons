# LimbusBar

An on-screen progress bar for **Temenos** and **Apollyon** floors (Windower 4).

It shows how full the floor's bar is, how much each kill adds, and turns a different color once you have the floor's **temp item**. It can also run a command for you at the right moment, like using an item or sending a message.

---

## Install

1. Put everything in `Windower4/addons/limbusbar/`:
   - `limbusbar.lua`
   - `bg_body.png`
   - `bg_cap.png`
   - `fg_body.png`
2. In game, type:  `//lua load limbusbar`

To load it every time you start the game, add `lua load limbusbar` to your Windower `init.txt`.

Use either `//limbusbar` or the short form `//lb` for every command below.

---

## What you see

```
East_Tower_F2: 61 / 100 (61%) - Floor completed *
[██████████████░░░░░░░░░░]
Last kill: +9% | ~5 kills to full | ~12 per bar
```

| Part | Meaning |
|------|---------|
| Top line | Floor name, bar value, and percent. `Floor completed *` appears once you have the temp item. |
| The bar | Fill color changes as it fills (see below). |
| Bottom line | How much the last kill added, how many more kills to fill the bar, and roughly how many kills a full bar takes. |

**Bar colors**

| Color | Meaning |
|-------|---------|
| Red | Under 33% |
| Yellow | 33% to 65% |
| Green | 66% and up |
| Cyan or blue | You have this floor's temp item |

The bar only appears inside Temenos and Apollyon. It shows up as soon as the game sends the bar value (usually right after you enter a floor).

**Move it:** click and drag the top line with your mouse. The bar and bottom line follow.

---

## Everyday commands

| Command | What it does |
|---------|--------------|
| `//lb hide` | Hide the bar |
| `//lb show` | Bring it back |
| `//lb kills off` | Hide the "Last kill" line |
| `//lb kills on` | Show it again |
| `//lb floor` | Shows which floor the addon thinks you're on and whether it sees your temp item. Good for troubleshooting. |
| `//lb reset` | Put the box back in its default spot (use this if it ever ends up off screen) |

---

## Try it without being in Limbus

Handy for checking how it looks or tuning the layout.

| Command | What it does |
|---------|--------------|
| `//lb test 50` | Show the bar at 50% with a random kill amount |
| `//lb test 80 done` | Preview the "Floor completed" look |
| `//lb test random` | Random value and random kill amount, sometimes "Floor completed" |

The preview clears when you zone.

---

## Automatic actions

LimbusBar can run any game command for you. Two triggers are available.

### Run a command when the temp item is gained

```
//lb complete <command>
```

Example:

```
//lb complete input /p Temp item got, ready to move!
```

It runs once when you gain the floor's temp item. It will not run if you already had the item before you set it.

| Command | What it does |
|---------|--------------|
| `//lb complete` | Show the current setting |
| `//lb complete off` | Turn it off |
| `//lb complete sound on` or `off` | Play a chime when it fires |

### Run a command when the bar passes a percentage

```
//lb auto <command>
//lb auto <percent> <command>
```

Examples:

```
//lb auto input /p Bar is past halfway
//lb auto 70 input /ma "Cure" <me>
```

By default it triggers when the bar goes above **50%** and you have the floor's temp item. It fires once, then re-arms for the next floor.

| Command | What it does |
|---------|--------------|
| `//lb auto` | Show the current setting |
| `//lb auto 70` | Change the percentage without changing the command |
| `//lb auto off` | Turn it off |
| `//lb autotemp off` | Fire on bar percent alone, without needing the temp item (good for testing) |
| `//lb autotemp on` | Require the temp item again (default) |
| `//lb auto sound on` or `off` | Play a chime when it fires |

### Keep your automatic actions after reloading

```
//lb save
```

Without this, your `auto` and `complete` setups are forgotten when you unload the addon.

---

## Change how it looks

All of these take effect right away.

| Command | What it does |
|---------|--------------|
| `//lb width 30` | Bar length. Bigger number means a longer bar. |
| `//lb barheight 20` | Bar thickness in pixels (6 to 40). It grows downward. |
| `//lb baroffset 19` | Move the bar up or down inside the box |
| `//lb killsdrop 3` | Push the "Last kill" line down by this many pixels |
| `//lb font Lucida Console` | Change the text font (it must be installed on your PC) |
| `//lb fontsize 11` | Change the text size (6 to 40) |
| `//lb boxalpha 0` | Background transparency: 0 is invisible, 255 is solid |
| `//lb barbg 180 200 255` | Color of the empty part of the bar (red green blue, 0 to 255) |

**Saved automatically:** width, font, font size, background transparency, bar background color, and box position.

**Not saved (back to defaults after a reload):** bar height, bar offset, and kills drop. If you find numbers you like, edit the defaults near the top of `limbusbar.lua`.

**If the bar looks misaligned** after changing the font or size, use `//lb baroffset` to move it up or down, and `//lb killsdrop` to space the bottom line.

---

## Troubleshooting

| Problem | Try this |
|---------|----------|
| Nothing shows up | Check you are in Temenos or Apollyon. Run `//lb test 50` to confirm the addon is working. |
| Bar is missing but the text shows | Check the three PNG files are in the addon folder with exactly these names: `bg_body.png`, `bg_cap.png`, `fg_body.png` |
| The box is off screen | `//lb reset` |
| Wrong floor or temp item not detected | `//lb floor` shows what the addon sees. If it says the floor is not recognized, report the floor name it prints. |
| Odd symbols in the text | Your font may not support a character. Try `//lb font Lucida Console`. |
| Something else looks wrong | `//lb debug` prints positions and sizes to the console, useful when asking for help. |

Type `//lb` with no command to see the full command list in game.

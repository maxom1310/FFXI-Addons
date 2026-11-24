# LimbusBar

A [Windower 4](https://www.windower.net/) addon for Temenos and Apollyon (Limbus). It shows the floor's progress bar on screen, estimates how many kills are left to fill it, marks a floor as completed once you hold its temp item, and can run a command of your choice when the bar passes a percentage.

The addon only reads incoming packets. It never sends anything itself; the only thing it ever runs is the command you give it with `//lb auto` or `//lb complete`.

## Install

1. Extract the `limbusbar` folder into `Windower4/addons/limbusbar/`.
2. Load it with `//lua load limbusbar` (add `lua load limbusbar` to your `init.txt` to load it automatically).
3. The commands are `//limbusbar` or `//lb`.

## What you see

The bar appears automatically in Temenos and Apollyon and hides when you leave:

- **Color states:** Soft crimson below 33%, warm gold below 66%, emerald green from 66%, and sky blue with a `Floor completed *` badge once you hold the floor's temporary item.
- **Kill line:** Each time the bar goes up, the increase is recorded as the last kill's gain. "Kills to full" is the points remaining divided by that gain, rounded up. "Per bar" is the same calculation from 0.

## Commands

| Command | What it does |
| --- | --- |
| `//lb hide` / `//lb show` | Hide or show the bar. |
| `//lb kills on` / `off` | Show or hide the last-kill / kills-to-full line (on by default). |
| `//lb width <n>` | Bar length (default 30). |
| `//lb barheight <n>` | Bar thickness in pixels (default 12). |
| `//lb boxalpha <0-255>` | Card background opacity (default 215). |
| `//lb test <n>` | Preview the bar at value `n` anywhere. |
| `//lb test <n> done` | Preview the sky-blue Floor completed look. |
| `//lb auto <command>` | Run `<command>` once when the bar is over 50% **and** this floor's temp item is already held. |
| `//lb auto <n> <command>` | Same, at `n`% instead of 50%. |
| `//lb complete <command>` | Run `<command>` once when the temp item for the floor you're on is **gained**. |
| `//lb save` | Save runtime commands and options. |
| `//lb help` | List all commands. |

# TradePlayer
A windower addon for trading items with other players via commands (uses packets).

The commands below will do nothing if you already have an outstanding trade request.

## Basic trading

Action                | Addon Command
--------------------- | -----------------------------
Trade                 | //tp \<quantity\> \<item name\> ... \[player name\]

Item names with spaces need quotes, for example `"Lustreless Hide"`.
If you leave off the player name, the addon trades to your current target.

### Party / alliance

Trade to every party member (or alliance member):

    //tp 1 mercanbaligi party
    //tp 1 mercanbaligi ally

### The "all" keyword

Use `all` instead of a number to trade your full count of an item:

    //tp all "Lustreless Hide" banker

`all` can't be used with `party` or `ally`, because everything would go to the first person.

### Timeout

    //tp timeout <seconds>

## Lists

A list is a plain text file in the addon's `lists/` folder, with one item name per line. Lines starting with `#` are ignored. Item names must match the in-game item name (capitalization doesn't matter).

Example `lists/limbus.txt`:

    # Limbus items
    Alabaster Part I
    Alabaster Part II
    Hydro Oil
    Shard of Bravery

To make a new list, add another `.txt` file to `lists/`. No code changes are needed.

Action                | Addon Command
--------------------- | -----------------------------
Trade a list          | //tp list \<listname\> \<player name\>
Show a list's items   | //tp list show \<listname\>
Show available lists  | //tp lists

How lists work:

- Everything on the list that you are carrying is traded, in the full quantity you have.
- Items you don't have are skipped.
- The trade window holds 8 slots, so a long list is split into several trades. The next trade starts automatically after the previous one is accepted.
- If a trade is rejected, the rest of the list is stopped.
- Lists only work with a single player as the target, not `party` or `ally`.

## Multiple characters: //tp everyone

With several characters running the addon, one command can make every one of them take turns trading to the same player. The player receiving the items is always left out.

Action                  | Addon Command
----------------------- | -----------------------------
Every character, a list | //tp everyone list \<listname\> \<player name\>
Every character, items  | //tp everyone \<quantity\|all\> \<item name\> ... \<player name\>
Cancel                  | //tp stop

Examples:

    //tp everyone list limbus banker
    //tp everyone 12 "Hydro Oil" banker
    //tp everyone all "Hydro Oil" banker
    //tp everyone 1 "Ash Wood" 5 "Black Jadeite" banker

How it works:

- You can type the command on any character that has the addon loaded. It finds the other loaded characters automatically (no `//send` needed) and puts them in alphabetical order.
- Each character takes a turn and finishes before the next one starts.
- The character you typed it on takes part too, unless it is the player being traded to.
- A character is skipped if it is missing an item, can't find the target (out of range), has a trade rejected, or is already busy. A character that stalls is skipped after 180 seconds.
- A quantity is traded per character. `12` means each character tries to give 12, and `all` means each gives everything it has.
- The player name is required, and it can't be `party` or `ally`.
- Every character reads its own `lists/` folder. If your characters run from separate Windower installs, copy the `lists` folder to each.
- The player receiving the trades needs to accept them, either manually or with another addon.

## Installation

Put the addon in `Windower/addons/tradeplayer/`. For lists, create a `lists/` folder inside it (the addon will also try to create it on load) and add your `.txt` list files.

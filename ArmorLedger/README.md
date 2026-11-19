# Armor Ledger 0.1.0

A Windower 4 addon by Maxom for tracking Final Fantasy XI Artifact, Relic, and Empyrean armor across all 22 jobs.

## Install

1. Extract the ZIP into your Windower 4 addons directory. The entry point should be `Windower4/addons/ArmorLedger/ArmorLedger.lua`.
2. In-game, run `//lua load ArmorLedger`. The HUD opens automatically.
3. Use `//armor` to reopen or close the HUD. `//al` also works. If AutoLockstyle is loaded, use `//armor` because both addons register `//al`.

For an update, unload Armor Ledger, replace `ArmorLedger.lua`, and load it again. Keep your existing `ArmorLedger/data` folder to preserve character settings and unlocks.

## Use the HUD

- **Progress** shows armor tiers for all jobs. Select a job for its next requirements.
- **Materials** shows upgrade costs, holdings and bag locations, and known NPC and Auction House sources. Select an armor type to compare upcoming stages, or a slot for its remaining path. **Compact** shows only the current objective.
- **Cards** shows Artifact card requirements by job and slot.
- **Unlocks** shows requirements tracked from gear, key items, NPC menus, and manual flags.
- The circular-arrow button next to **X** refreshes bags, storage slips, key items, and currency balances.

To sync Dynamis-Divergence unlocks, visit **Aurix** in Ru'Lude Gardens and open **View the List > Relic Armor**. To sync Empyrean +2 unlocks, visit **Ruspix** in Leafallia and open his +2 unlock list. These reads are saved per character. If you use Porter Moogle storage slips, talk to the Porter Moogle to update them before refreshing.

Run `//armor help` for chat commands, including `//armor need` for a shopping list. Armor Ledger tracks progress. Upgrades are performed in game.

## Credits

- **Author** Maxom
- **Recipe data** Adapted from Reforge by Opo-Opo and [BG Wiki](https://www.bg-wiki.com/)
- **Auction House and vendor listings** [FFXIAH](https://www.ffxiah.com/)

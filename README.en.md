# Every Grain Earned / 粒粒皆辛苦

[简体中文](README.md) · [English Workshop description](WORKSHOP.en.txt) · [Steam 工坊中文介绍](WORKSHOP.zh.txt)

A farming mod for Don't Starve Together. Manage irrigation, salinity, cold and disease to keep your farm productive and grow giant crops. Numbers below assume Normal severity and 480 seconds per in-game day.

## Water and soil

- Watering and rain fill soil moisture first, up to 100. Excess becomes standing water, capped at 300. Liquid surface water can refill the soil, spending an equal amount of surface water.
- The transparent water surface has four depth bands. It starts with a faint wet-soil tint and shifts to pale cyan, blue and deep blue at 100, 170 and 240 surface water.
- Outdoor summer evaporation accounts for crop water use, aiming to balance a single sprinkler's full coverage. Great Tree canopies reduce evaporation. Weather, crop demand, coverage and overlapping sprinklers affect the result.
- Winter surface water freezes at 100. Ice kills crops in the flooded tile, makes it slippery and prevents tilling. Liquid flood damage stops accumulating while frozen.

## Salinity and ruined plots

- Every 100 units of untreated seawater add 50 salt, up to a soil cap of 300. White patches appear at 50, 120 and 200 salt. They use the vanilla wet-soil patterns for two, three and four watering-can uses on dry soil, rotated by 90°. Crop salt stress starts at 120.
- At 200 salt, severe exposure starts accumulating. It ruins the plot after three days at Normal severity. Below 200, existing progress recedes at twice the normal rate. Fresh water and rain provide water for flushing, and sandbag drainage carries salt out.
- Unfrozen surface water at 100 or more accumulates flood damage. A plot is ruined after three days of exposure. Progress recedes below 100 and clears when the surface drains completely.
- Empty plots can suffer summer drought. A plot with dry soil and no standing water gets one day of grace, then one day of damage before ruin. Rewetting clears drought progress.
- Two crack warnings appear at approximately 10% and 40% progress. The first is half the size of the second. Ruin and recovery cracks are displayed at 80% of their former size. White, marsh-colored and dry lakebed-colored patches mark salt, flood and drought damage respectively.
- A ruined plot remains in place and cannot be tilled for **four days**. When the fallow period ends, the original ground returns and the plot must be plowed again. Existing ruins keep their proportional recovery progress when migrated.
- One sprinkler fully covering a plot with untreated seawater reaches severe salinity in about 2.1 days from zero salt, then ruins it about three days later without drainage.

## Crops and pesticide

- Vanilla growth times from seed through medium growth are doubled. Growth definitions already adjusted by Shadow World retain their multiplier. Crops can grow out of season, but if still out of season at maturity they wither without fruit. Withered crops do not regrow. Prolonged cold can also rot susceptible crops.
- Growing crops have a separate **2%** disease roll each day and on entry to each growing stage. Roll history is saved with the crop. Prolonged flooding and nearby infected plants can also cause disease.
- Growing crops pause when surface water reaches their individual tolerance. Disease can start after about 0.8–1.4 days of soaking. Diseased plants stop growing and rot after about two untreated days. The legacy disease component attempts to infect one eligible plant within four units every 1.5–2.5 days, postponing attempts while the source is asleep.
- Equip and throw pesticide. The mist lasts about 80 seconds and checks every three seconds within a radius of roughly 5.66 units. Aim at the intersection of four farm tiles to reach all four outer corners. Treat crops after reducing standing water below 100. A cure preserves growth progress. Rotten crops cannot be cured.

## Equipment and recipes

| Item | Recipe | Use |
|---|---|---|
| Sprinkler | 2 Gears, 4 Gold Nuggets, 2 Boards | Irrigates from a nearby source, prioritizing fresh water |
| Desalinating Sprinkler | 2 Gears, 4 Blue Gems, 2 Living Logs | A consumed Blue Gem buys half a day of desalination. An Enlightened Shard provides continuous desalination |
| Cloth | 3 Silk | Used to make sandbags |
| Drainage Sandbag ×4 | 2 Cloth, 2 Rope, 8 Rocks | Drains standing water and carries dissolved salt away |
| Pesticide | 3 Nitre, 1 Glommer's Goop, 1 Empty Bottle | Throw to treat diseased crops in the area |

Build sprinklers within about 20 units of a water source. They can draw from the ocean, ponds, summer oases and supported cave pools. A running sprinkler can refill a watering can while supplying fresh water or actively desalinating.

A sandbag drains its own tile before helping nearby plots. Its default drain radius is four units, its lifetime capacity is 300 water, and each 100 water drained can carry up to 100 salt, subject to concentration. A full bag stops draining and deteriorates if it stays submerged. Inspect it to see water absorbed, salt removed and the average salt-to-water ratio.

## Multiplayer and settings

The host and all players need the same version. Configure flooding, drought, disease, cold damage, seasonal harvest, salinity, severity and sandbag range in the mod settings. English and Chinese are supported in-game, with bilingual configuration labels. Dynamic inspection text generated by a dedicated server follows the server's language.

This README describes the current local code. Run `tests/run_tests.py` for behavior checks. Rendering and multiplayer prompts can be checked in a test world.

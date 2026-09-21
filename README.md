# Sit Means Rest

Sitting down gives you a regeneration buff; standing up or moving takes it away.

An [ALE](https://github.com/azerothcore/mod-ale) (Lua) script for AzerothCore.
Drop `SitMeansRest.lua` into `env/dist/etc/modules/lua_scripts/` and restart the world —
ALE loads it at world start, so no rebuild is needed.

Installed for you by [Yu'lon](https://github.com/DadsMmoLab/dads-mmo-lab) from
this repository.

## Rested XP

Sitting still also builds rested XP, the blue part of the XP bar. Ground or
chair, any seat counts; bots are skipped. Moving, standing up or entering
combat stops it and starts the wait over.

| Key | Default | Meaning |
|---|---|---|
| `REST_XP_ENABLED` | `true` | `false` turns the feature off |
| `REST_XP_DELAY` | `30` | seconds of sitting still before it starts |
| `REST_XP_RATE` | `5.0` | percent of the current level's XP bar per minute |
| `REST_XP_MAX_LEVELS` | `1.5` | stop at this many levels' worth |

For scale, an inn gives 5 percent per eight hours; at the default a ten-minute
break is worth half a level. The core's own ceiling (`Rate.Rest.MaxBonus`)
always applies on top, and a max-level character gets none.

## Configuration

Everything tunable is the `CONFIG` table at the top of the file, commented in
place. Yu'lon's **Tuning** tab reads and writes those keys directly.

## Credit

Based on [Brytenwally/SitMeansRest](https://github.com/Brytenwally/SitMeansRest) by Brytenwally, MIT licensed. This
repository keeps that licence and adds its modifications under it; the original
copyright notice is retained in `LICENSE`.

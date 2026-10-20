# Changelog

All notable changes to Sit Means Rest. Dates are when the change landed on `main`.

## Unreleased

### Fixed
- Eating or drinking no longer loses the food to the regen buff: the real food or drink (and the Well Fed it gives, and the credit for eating and drinking) stays on the player. The script leaves the player alone while a food or drink aura is on them, also when the meal comes mid-rest, until they stand up. On ALE builds without `Unit:GetAuras` or `SpellInfo:GetSpellSpecific` it behaves as before. Patch and diagnosis by Kronir10 (#3).

### Added
- `tests/food.lua`: a mock-ALE simulation of eating and drinking, run on Lua 5.1 and 5.4 in CI.

## 2026-09-21

### Added
- Rested XP: sitting still builds rested XP, ground or chair, bots skipped. Settings `REST_XP_ENABLED`, `REST_XP_DELAY`, `REST_XP_RATE` and `REST_XP_MAX_LEVELS`.

### Fixed
- Rested XP: "full" is no longer latched, the core's own ceiling (0.75 of a level at the stock rate) is respected, and `IsBot` is optional.

## 2026-09-18

### Added
- CI: compile under Lua 5.1 and 5.4, luacheck against the ALE API, and the rested XP simulation.

## 2026-09-13

### Added
- First version: sitting gives a regeneration buff, standing up or moving takes it away. Based on Brytenwally/SitMeansRest (MIT).

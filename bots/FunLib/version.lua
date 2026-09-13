--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
-- Source of truth: typescript/bots/FunLib/version.ts (keep both in sync).
--
-- `number` / `recentChangeLogs` are the inherited OHA fields (read by FretBots,
-- Buff, mode_farm, mode_laning). `name` / `tag` / `stable` are this fork's
-- release identity: shown once per game as an all-chat banner from
-- ability_item_usage_generic.lua, because the lobby only ever shows
-- "Local Dev Script" or the Workshop title, never which release is loaded.
-- Bump `tag`/`stable` on every Workshop upload (docs/WORKSHOP_RELEASE.md).
local ____exports = {}
____exports.number = "0.7.41 - 2026/04/02"
____exports.recentChangeLogs = {"GLHF"}
____exports.name = "Dota2Bot Turbo Bots"
____exports.tag = "beta-20260913"
____exports.stable = "stable-v9"
return ____exports

---
name: patch-update
description: Check for a new Dota 2 patch or apply patch notes to this bot repo (items, builds, abilities, neutrals). Use when the user says a patch version, asks if we are behind, or mentions patch notes.
---

# Patch update

Authoritative runbook: `docs/PATCH_UPDATE_GUIDE.md`. Follow it in order.
Do not trust patch-note ability names until Liquipedia (or d2vpkr) agrees.

## Are we behind?

1. Fetch `https://www.dota2.com/datafeed/patchnoteslist?language=english`
2. Compare the latest version to "Last updated for" in
   `docs/PATCH_UPDATE_GUIDE.md`
3. If newer, run the update process below.

## Apply patch X.XX

When the user says "update for patch X.XX" or pastes notes:

1. Read `docs/PATCH_UPDATE_GUIDE.md`.
2. Fetch `https://www.dota2.com/datafeed/patchnotes?version=X.XX&language=english`
3. Fetch d2vpkr data (`shops.txt`, `neutral_items.txt`) for authoritative
   item/ability names.
4. Categorize each change: STRUCTURAL (needs code) vs NUMBER-ONLY (game API
   handles) vs TALENT SWAPS.
5. Verify ability names on Liquipedia — summaries can be wrong.
6. Checklist order: items → hero builds → abilities → neutrals → actives →
   map changes.
7. Always update **both** neutral item files (`bots/Buff/` and
   `bots/FretBots/`).
8. Always update TypeScript sources for any TS-generated Lua
   (ARCHITECTURE.md §13).
9. Focus heroes first (Axe, Zeus, WK, Lion, CM): re-verify builds and
   ability logic. A major patch still needs a T2 batch before anything else
   is "done," but that batch is queued, not launched from this skill.

## Rules that bite during patches

- Never rename/move/delete Lua under `bots/` or `game/`.
- Use `GetItemComponents()` for recipes.
- Use `sAbilityList[N]` when possible.
- Keep in-file credit headers.

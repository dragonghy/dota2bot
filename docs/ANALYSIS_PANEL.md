# Vision-Aware Replay Analysis Panel (spec)

**Why.** The bot AI decides using only its OWN team's vision. To judge a decision
("was that a blind walk into fog, or a real mistake?") the analyst must see what
the bot saw. So every rendered timepoint is from a chosen PERSPECTIVE, and shows
only what that perspective could see.

## Inputs
The extended dump (see `dumper/main.go`, "vision-aware dump") provides per tick
(subsampled): per-hero position/hp/mp/level, **`visible_to`** (which teams see
this unit — from the `m_iTaggedAsVisibleByTeam`-class bitmask if manta exposes it;
else reconstructed from vision sources), per-hero `items` + `abilities`
(name, cd_remaining, level), a `buildings` list (towers/rax alive+pos), a
subsampled `creeps` list, and wards. Confirm exact fields against the dumper
agent's feasibility report before building.

## Two synced components per timepoint

### A. Map panel (2D top-down, the storyboard evolved)
- Base: river midline (x+y=0), ancients, tower/rax markers **greyed when dead**.
- Heroes: colored by team, size/label = HP%, short trail = last ~3s movement.
- **Creep heatmap**: 2D density of creep positions (lane pressure at a glance).
- **VISION TOGGLE (the key feature): three modes**
  - `global` — omniscient (debugging / ground truth).
  - `radiant` — render ONLY units `visible_to` radiant (enemy heroes/creeps in
    radiant's fog are HIDDEN, or shown as a faded "last-known" ghost at their
    last-seen position + time).
  - `dire` — symmetric.
  Towers/own units always shown for the perspective team. This is what makes the
  panel show the bot's actual information state.

### B. Data table (cross-section at the same tick, per perspective)
Columns per hero (only rows the perspective can see for enemies):
- level; net worth (if available);
- **items** — for enemies, VISION-DIFFERENTIATED: show the loadout from the LAST
  time that enemy was in the perspective's vision, with a "seen @ m:ss" stamp
  (mirrors what a human/AI actually knows);
- **ability cooldowns** — by default BOTH sides visible (like the in-client
  scoreboard: last-cast time / on-CD flags), unless we decide to also fog these.

## Perspective composition
`radiant view = radiant map-vision + radiant-visible table`. Same for dire.
Global is the omniscient cross-check.

## Build phases
1. Data layer: dumper emits `visible_to` + items + cooldowns + buildings +
   creeps (agent in progress). Gate the whole feature on the visibility field
   being real; if manta lacks it, fall back to reconstructed vision (vision
   sources within range) and label it "approx".
2. Renderer: extend `storyboard.py` (or a new `panel.py`) to take a
   `--perspective {global,radiant,dire}` flag + emit map PNG + an HTML/markdown
   data table per keyframe. Keyframes at fight windows (reuse fight detection) +
   fixed cadence.
3. Wire into the eyes pipeline; the analyst reviews per-perspective panels.

## Open questions for the owner
- Fog the ability cooldowns too, or keep them always-visible (scoreboard model)?
- Show fogged enemies as last-known ghosts, or hide entirely? (ghosts are more
  useful for judging "should the bot have expected someone there".)
- Net worth / gold visible per perspective, or omniscient?

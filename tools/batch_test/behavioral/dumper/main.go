// behav-dump: extract a per-hero behavioral timeline from a Dota 2 Source 2
// .dem replay recorded by our dedicated soak-farm server.
//
// Output (single JSON object on stdout):
//
//	{
//	  "game":      { "start_time": <server-sec of the horn>,
//	                 "teams": { "<npc_name>": 2|3, ... },
//	                 "vision_note": <how to read fog-of-war from this dump> },
//	  "snapshots": [ { "t","hero","team","x","y","hp","hp_pct","mp_pct","level",
//	                   "items":[<name>,...],
//	                   "abilities":[{ "name","level","cd","cd_len" },...] }, ... ],
//	  "buildings": [ { "t","name","team","x","y","hp","hp_pct","alive" }, ... ],
//	  "creeps":    [ { "t","team","x","y" }, ... ],
//	  "wards":     [ { "type","team","x","y","t_start","t_end" }, ... ],
//	  "events":    [ { "t","type","actor","target","inflictor","value",
//	                   "actor_hero","target_hero" }, ... ]
//	}
//
// "t" is game-clock seconds (0 = horn), derived by subtracting the gamerules
// GameStartTime from the raw server timestamps.
//
// Sampling rates (all game-time seconds, all tunable via flags):
//   - snapshots (hero pos/hp/mp/level/items/abilities): -interval,          default 1.0s
//   - buildings (towers/rax/fort/watch-tower state):     -building-interval, default 5.0s
//   - creeps    (lane+neutral positions for heatmaps):   -creep-interval,    default 3.0s
//   - wards     are emitted once each, spanning [t_start, t_end] (t_end<0 = still up at
//     replay end); they are event-shaped, not sampled.
//
// FOG OF WAR / VISIBILITY -- important, read before building a vision panel:
//
//	Source 2 Dota replays record the GLOBAL entity stream (a "god" perspective).
//	Per-team fog visibility is computed server-side per recipient and is NOT
//	networked into the replay: there is no m_iTaggedAsVisibleByTeam (or any
//	"TaggedAsVisible*"/per-viewer visibility bitmask) in the flattened
//	serializer schema. Verified by dumping the full 5371-symbol pool of a pro
//	replay -- the only fog fields present are engine/HUD plumbing (m_nFoWTeam
//	[always 0 on units], m_iFoWFrameNumber, m_bIsPartOfFowSystem,
//	m_nHUDVisibilityBits, m_bNPCVisibleState) -- none give "which teams see unit
//	U at tick T". So visibility must be RECONSTRUCTED from vision SOURCES, which
//	this dump now provides in full: every hero position+team (snapshots), every
//	ward position+team (wards), and every standing tower/building position+team
//	(buildings). A panel reconstructs each team's vision by unioning day/night
//	vision radii around that team's sources (heroes ~1800/800u, obs ward 1600u,
//	towers 1900u), optionally minus high-ground occlusion. There is no exact
//	per-unit fog flag to read; this is the make-or-break finding.
//
// Dedicated-server replays carry no /dota_vNNNN/ build tag, so we vendor manta
// with a patched class.go that defaults GameBuild to 9999 (above every legacy
// field-patch range) -- see ../README.md.
//
// Dev-only tooling for tools/batch_test/; never shipped to the Workshop.
package main

import (
	"encoding/json"
	"flag"
	"os"
	"strings"

	"github.com/dotabuff/manta"
	"github.com/dotabuff/manta/dota"
)

const cellWidth = 128.0
const coordOffset = 16384.0 // MAX_COORD_INTEGER; world = cell*128 + vec - offset
const nullHandle = 16777215 // 0xFFFFFF: unset entity handle

type abilitySnap struct {
	Name  string  `json:"name"`
	Level int32   `json:"level"`
	Cd    float64 `json:"cd"`     // last networked cooldown REMAINING (s); 0 = ready
	CdLen float64 `json:"cd_len"` // full length of the current cooldown (s)
}

type snapshot struct {
	T         float64       `json:"t"`
	Hero      string        `json:"hero"`
	Idx       int32         `json:"idx"` // entity index; disambiguates a hero from its illusions (same class name)
	Team      int32         `json:"team"`
	X         float64       `json:"x"`
	Y         float64       `json:"y"`
	HP        int32         `json:"hp"`
	HPPct     float64       `json:"hp_pct"`
	MP        int32         `json:"mp"`
	MaxMP     int32         `json:"max_mp"`
	MPPct     float64       `json:"mp_pct"`
	Level     int32         `json:"level"`
	Items     []string      `json:"items"`
	Abilities []abilitySnap `json:"abilities"`
	TpCd      float64       `json:"tp_cd"`     // TP scroll/travel cooldown remaining (0 = ready)
	TpCdLen   float64       `json:"tp_cdlen"`  // its full cooldown length (for cast detection)
}

type building struct {
	T     float64 `json:"t"`
	Name  string  `json:"name"`
	Team  int32   `json:"team"`
	X     float64 `json:"x"`
	Y     float64 `json:"y"`
	HP    int32   `json:"hp"`
	HPPct float64 `json:"hp_pct"`
	Alive bool    `json:"alive"`
}

type creepSnap struct {
	T    float64 `json:"t"`
	Team int32   `json:"team"`
	X    float64 `json:"x"`
	Y    float64 `json:"y"`
}

type wardSnap struct {
	Type   string  `json:"type"` // "observer" | "sentry"
	Team   int32   `json:"team"`
	X      float64 `json:"x"`
	Y      float64 `json:"y"`
	TStart float64 `json:"t_start"`
	TEnd   float64 `json:"t_end"` // <0 = still standing at replay end
}

type event struct {
	T          float64 `json:"t"`
	Type       string  `json:"type"`
	Actor      string  `json:"actor"`
	Target     string  `json:"target"`
	Inflictor  string  `json:"inflictor"`
	Value      uint32  `json:"value"`
	ActorHero  bool    `json:"actor_hero"`
	TargetHero bool    `json:"target_hero"`
}

type heroState struct {
	idx   int32
	name  string
	team  int32
	x, y  float64
	hp    int32
	maxhp int32
	mp    float64
	maxmp float64
	level int32
	valid bool
}

type buildingState struct {
	name  string
	team  int32
	x, y  float64
	hp    int32
	maxhp int32
	dead  bool // entity deleted (structure destroyed)
}

type creepState struct {
	team    int32
	x, y    float64
	x0, y0  float64 // position when first seen (its spawn point)
	haveX0  bool
	active  bool // has moved from spawn -> a real marching creep (the engine
	// pre-creates each wave and parks it at the barracks ~26s before the horn;
	// those never move, so we don't emit them until they do)
}

type wardState struct {
	kind   string
	team   int32
	x, y   float64
	tStart float64
	tEnd   float64
}

// classToNPC converts "CDOTA_Unit_Hero_Skywrath_Mage" -> "npc_dota_hero_skywrath_mage"
// and "CDOTA_Unit_Hero_WitchDoctor" -> "npc_dota_hero_witch_doctor" by splitting
// on existing underscores AND camelCase boundaries. This matches the names the
// combat log uses, so snapshots and events cross-reference cleanly.
func classToNPC(cn string) string {
	return "npc_dota_hero_" + snakeFromClass(cn, "CDOTA_Unit_Hero_")
}

// snakeFromClass strips a prefix then converts the remainder (which mixes
// underscores and camelCase) to a single lower_snake_case token.
// "CDOTA_Item_Enchanted_Mango" (prefix "CDOTA_Item_") -> "enchanted_mango".
// "CDOTA_Ability_Nevermore_Shadowraze1"              -> "nevermore_shadowraze1".
func snakeFromClass(cn, prefix string) string {
	suffix := strings.TrimPrefix(cn, prefix)
	suffix = strings.ReplaceAll(suffix, "_", "")
	var b strings.Builder
	for i, r := range suffix {
		if i > 0 && r >= 'A' && r <= 'Z' {
			b.WriteByte('_')
		}
		b.WriteRune(r)
	}
	return strings.ToLower(b.String())
}

// getHandle reads an entity-handle property regardless of whether manta decoded
// it as a 32- or 64-bit unsigned int.
func getHandle(e *manta.Entity, path string) (uint64, bool) {
	if v, ok := e.GetUint64(path); ok {
		return v, true
	}
	if v, ok := e.GetUint32(path); ok {
		return uint64(v), true
	}
	return 0, false
}

// isRealAbility filters out talents (Special_Bonus_Base / _Attributes) and the
// generic hidden inherited abilities (courier warp, high-five, lamp, capture, …)
// so only castable hero spells + learned talents remain. Learned talents
// (Special_Bonus_*) are kept only once leveled.
func isRealAbility(cn string, hidden bool, level int32) bool {
	if strings.Contains(cn, "Special_Bonus_Base") || strings.Contains(cn, "Special_Bonus_Attributes") {
		return false
	}
	if strings.Contains(cn, "Special_Bonus") {
		return level > 0
	}
	if hidden {
		return false
	}
	for _, g := range []string{
		"_Plus_", "_Capture", "_Portal_Warp", "Twin_Gate", "_Lamp_Use",
		"HighFive", "GuildBanner", "Seasonal", "_Winter_",
	} {
		if strings.Contains(cn, g) {
			return false
		}
	}
	return true
}

func main() {
	interval := flag.Float64("interval", 1.0, "hero snapshot interval in game seconds")
	buildingInterval := flag.Float64("building-interval", 5.0, "building sample interval in game seconds")
	creepInterval := flag.Float64("creep-interval", 3.0, "creep sample interval in game seconds")
	pregame := flag.Float64("pregame", 90.0, "seconds before the horn (game-clock 0) to start sampling, so the pre-game prep phase is captured")
	flag.Parse()
	if flag.NArg() < 1 {
		os.Stderr.WriteString("usage: behav-dump [-interval S] [-building-interval S] [-creep-interval S] replay.dem > timeline.json\n")
		os.Exit(2)
	}
	f, err := os.Open(flag.Arg(0))
	if err != nil {
		panic(err)
	}
	defer f.Close()
	p, err := manta.NewStreamParser(f)
	if err != nil {
		panic(err)
	}

	name := func(idx uint32) string {
		s, _ := p.LookupStringByIndex("CombatLogNames", int32(idx))
		return s
	}

	heroes := map[int32]*heroState{}        // entity index -> latest state
	buildings := map[int32]*buildingState{} // entity index -> latest state
	creeps := map[int32]*creepState{}       // entity index -> latest position
	wards := map[int32]*wardState{}         // entity index -> lifespan record
	teams := map[string]int32{}
	var snaps []snapshot
	var buildingSnaps []building
	var creepSnaps []creepSnap
	var events []event

	serverNow := 0.0        // latest known raw server time (from combat log)
	gameStart := 0.0        // horn, from gamerules GameStartTime (last nonzero)
	tickInterval := 1.0 / 30 // engine seconds per tick, from ServerInfo
	armed := false          // sampling armed once the horn (gameStart) is known
	nextSample := 0.0       // next hero-snapshot game-clock boundary
	nextBuilding := 0.0     // next building-sample boundary
	nextCreep := 0.0        // next creep-sample boundary

	// resolveItems reads the hero's inventory handles and returns item names.
	// Slots 0-8 are the active inventory + backpack, 9-16 are stash/neutral/TP;
	// we include every held (non-null) slot so the panel can show full loadout.
	// Return exactly the 9 carried slots by position: 0-5 = active inventory
	// (usable), 6-8 = backpack (not directly usable). Empty slots are "" so the
	// panel can draw the 6|3 split. Stash/neutral/TP (slots 9+) are excluded.
	resolveItems := func(idx int32) []string {
		out := make([]string, 9)
		he := p.FindEntity(idx)
		if he == nil {
			return out
		}
		for i := 0; i < 9; i++ {
			h, ok := getHandle(he, slotPath("m_hItems", i))
			if !ok || h == nullHandle {
				continue
			}
			ie := p.FindEntityByHandle(h)
			if ie == nil {
				continue
			}
			out[i] = snakeFromClass(ie.GetClassName(), "CDOTA_Item_")
		}
		return out
	}

	// resolveTP returns the cooldown remaining + full length of the hero's Town
	// Portal Scroll / Boots of Travel (0,_ = ready). Used to show TP status and to
	// detect TP casts (remaining jumps from ~0 to full).
	resolveTP := func(idx int32) (float64, float64) {
		he := p.FindEntity(idx)
		if he == nil {
			return 0, 0
		}
		for i := 0; i < 19; i++ {
			h, ok := getHandle(he, slotPath("m_hItems", i))
			if !ok || h == nullHandle {
				continue
			}
			ie := p.FindEntityByHandle(h)
			if ie == nil {
				continue
			}
			n := snakeFromClass(ie.GetClassName(), "CDOTA_Item_")
			if strings.Contains(n, "teleport") || strings.Contains(n, "tpscroll") ||
				strings.Contains(n, "tp_scroll") || strings.Contains(n, "travel") {
				cd, _ := ie.GetFloat32("m_fCooldown")
				cdlen, _ := ie.GetFloat32("m_flCooldownLength")
				return float64(cd), float64(cdlen)
			}
		}
		return 0, 0
	}

	// resolveAbilities reads the hero's ability handles and returns spell state.
	resolveAbilities := func(idx int32) []abilitySnap {
		var out []abilitySnap
		he := p.FindEntity(idx)
		if he == nil {
			return out
		}
		for i := 0; i < 35; i++ {
			path := slotPath("m_vecAbilities", i)
			h, ok := getHandle(he, path)
			if !ok || h == nullHandle {
				continue
			}
			ae := p.FindEntityByHandle(h)
			if ae == nil {
				continue
			}
			cn := ae.GetClassName()
			lvl, _ := ae.GetInt32("m_iLevel")
			hidden, _ := ae.GetBool("m_bHidden")
			if !isRealAbility(cn, hidden, lvl) {
				continue
			}
			cd, _ := ae.GetFloat32("m_fCooldown")
			cdlen, _ := ae.GetFloat32("m_flCooldownLength")
			out = append(out, abilitySnap{
				Name:  snakeFromClass(cn, "CDOTA_Ability_"),
				Level: lvl,
				Cd:    round1(float64(cd)),
				CdLen: round1(float64(cdlen)),
			})
		}
		return out
	}

	dumpSnapshots := func(t float64) {
		for _, h := range heroes {
			if !h.valid || h.name == "" || h.maxhp <= 0 {
				continue
			}
			hpPct := 0.0
			if h.maxhp > 0 {
				hpPct = float64(h.hp) / float64(h.maxhp)
			}
			mpPct := 0.0
			if h.maxmp > 0 {
				mpPct = h.mp / h.maxmp
			}
			tpcd, tpcdlen := resolveTP(h.idx)
			snaps = append(snaps, snapshot{
				T: round1(t), Hero: h.name, Idx: h.idx, Team: h.team,
				X: round1(h.x), Y: round1(h.y),
				HP: h.hp, HPPct: round3(hpPct),
				MP: int32(h.mp + 0.5), MaxMP: int32(h.maxmp + 0.5), MPPct: round3(mpPct),
				Level:     h.level,
				Items:     resolveItems(h.idx),
				Abilities: resolveAbilities(h.idx),
				TpCd:      round1(tpcd),
				TpCdLen:   round1(tpcdlen),
			})
		}
	}

	dumpBuildings := func(t float64) {
		for _, b := range buildings {
			if b.name == "" {
				continue
			}
			hpPct := 0.0
			if b.maxhp > 0 {
				hpPct = float64(b.hp) / float64(b.maxhp)
			}
			alive := !b.dead && b.hp > 0
			buildingSnaps = append(buildingSnaps, building{
				T: round1(t), Name: b.name, Team: b.team,
				X: round1(b.x), Y: round1(b.y),
				HP: b.hp, HPPct: round3(hpPct), Alive: alive,
			})
		}
	}

	dumpCreeps := func(t float64) {
		for _, c := range creeps {
			// Lane/siege creeps march, so require them to have moved from spawn
			// (skips the wave the engine pre-parks at the barracks). Neutrals
			// (team 4) legitimately stand at their camp, so always emit them.
			if !c.active && c.team != 4 {
				continue
			}
			creepSnaps = append(creepSnaps, creepSnap{
				T: round1(t), Team: c.team, X: round1(c.x), Y: round1(c.y),
			})
		}
	}

	// worldXY computes world coordinates from the shared CBodyComponent cell/vec
	// encoding; returns ok=false if any component is missing.
	worldXY := func(e *manta.Entity) (float64, float64, bool) {
		cx, okcx := e.GetUint32("CBodyComponent.m_cellX")
		cy, okcy := e.GetUint32("CBodyComponent.m_cellY")
		vx, okvx := e.GetFloat32("CBodyComponent.m_vecX")
		vy, okvy := e.GetFloat32("CBodyComponent.m_vecY")
		if !(okcx && okcy && okvx && okvy) {
			return 0, 0, false
		}
		return float64(cx)*cellWidth + float64(vx) - coordOffset,
			float64(cy)*cellWidth + float64(vy) - coordOffset, true
	}

	p.OnEntity(func(e *manta.Entity, op manta.EntityOp) error {
		cn := e.GetClassName()

		if strings.Contains(cn, "Gamerules") {
			// m_flGameStartTime is 0 for the whole pre-game and only set (to the
			// horn engine-time) AT the horn. So it cannot clock the pre-game live;
			// we capture it here and convert engine-time samples to game-clock at
			// the end (see the post-Start pass). Sampling is armed on the first
			// hero position instead (below), so the pre-game walk-out is captured.
			if v, ok := e.GetFloat32("m_pGameRules.m_flGameStartTime"); ok && v > 0 {
				gameStart = float64(v)
			}
			return nil
		}

		// --- Structures: towers, barracks, fort, watch-tower ---
		if isBuildingClass(cn) {
			idx := e.GetIndex()
			b := buildings[idx]
			if b == nil {
				b = &buildingState{name: buildingName(cn)}
				buildings[idx] = b
			}
			if op&manta.EntityOpDeleted != 0 {
				b.dead = true
				return nil
			}
			if t, ok := e.GetUint32("m_iTeamNum"); ok && t > 0 {
				b.team = int32(t)
			}
			if x, y, ok := worldXY(e); ok {
				b.x, b.y = x, y
			}
			if v, ok := e.GetInt32("m_iHealth"); ok {
				b.hp = v
			}
			if v, ok := e.GetInt32("m_iMaxHealth"); ok {
				b.maxhp = v
			}
			return nil
		}

		// --- Wards: observer (vision) and sentry (true-sight) ---
		if kind := wardKind(cn); kind != "" {
			idx := e.GetIndex()
			w := wards[idx]
			if op&manta.EntityOpDeleted != 0 {
				if w != nil && w.tEnd < -0.5 {
					w.tEnd = round1(serverNow) // raw engine; converted below
				}
				return nil
			}
			if w == nil {
				w = &wardState{kind: kind, tStart: round1(serverNow), tEnd: -1e9}
				wards[idx] = w
			}
			if t, ok := e.GetUint32("m_iTeamNum"); ok && t > 0 {
				w.team = int32(t)
			}
			if x, y, ok := worldXY(e); ok {
				w.x, w.y = x, y
			}
			return nil
		}

		// --- Creeps: lane + neutral, positions only (for heatmaps) ---
		if isCreepClass(cn) {
			idx := e.GetIndex()
			if op&manta.EntityOpDeleted != 0 {
				delete(creeps, idx)
				return nil
			}
			c := creeps[idx]
			if c == nil {
				c = &creepState{}
				creeps[idx] = c
			}
			if t, ok := e.GetUint32("m_iTeamNum"); ok && t > 0 {
				c.team = int32(t)
			}
			if x, y, ok := worldXY(e); ok {
				c.x, c.y = x, y
				if !c.haveX0 {
					c.x0, c.y0, c.haveX0 = x, y, true
				} else if !c.active && (x-c.x0)*(x-c.x0)+(y-c.y0)*(y-c.y0) > 64*64 {
					c.active = true // moved from spawn -> a real marching creep
				}
			}
			return nil
		}

		if !strings.HasPrefix(cn, "CDOTA_Unit_Hero_") {
			return nil
		}
		// Skip illusions -- they distort positional detectors.
		if b, ok := e.GetBool("m_bIsIllusion"); ok && b {
			return nil
		}
		idx := e.GetIndex()
		h := heroes[idx]
		if h == nil {
			h = &heroState{idx: idx, name: classToNPC(cn)}
			heroes[idx] = h
		}
		// m_iTeamNum is networked as an unsigned int (2 = Radiant, 3 = Dire).
		if t, ok := e.GetUint32("m_iTeamNum"); ok && t > 0 {
			h.team = int32(t)
			teams[h.name] = int32(t)
		}
		if x, y, ok := worldXY(e); ok {
			h.x, h.y = x, y
			h.valid = true
			// Arm sampling on the first hero that has a real position (i.e. once
			// heroes have spawned in the pre-game). Boundaries are in ENGINE time;
			// they become game-clock after the horn is subtracted at the end.
			if !armed {
				armed = true
				en := float64(p.NetTick) * tickInterval
				b := float64(int(en/(*interval))) * (*interval)
				nextSample, nextBuilding, nextCreep = b, b, b
			}
		}
		if v, ok := e.GetInt32("m_iHealth"); ok {
			h.hp = v
		}
		if v, ok := e.GetInt32("m_iMaxHealth"); ok {
			h.maxhp = v
		}
		if v, ok := e.GetFloat32("m_flMana"); ok {
			h.mp = float64(v)
		}
		if v, ok := e.GetFloat32("m_flMaxMana"); ok {
			h.maxmp = float64(v)
		}
		if v, ok := e.GetInt32("m_iCurrentLevel"); ok {
			h.level = v
		}
		return nil
	})

	p.Callbacks.OnCMsgDOTACombatLogEntry(func(m *dota.CMsgDOTACombatLogEntry) error {
		ts := float64(m.GetTimestamp())
		if ts > serverNow {
			serverNow = ts // still tracked for event timestamps below
		}
		actor := name(m.GetAttackerName())
		target := name(m.GetTargetName())
		inflictor := name(m.GetInflictorName())
		if !m.GetIsAttackerHero() && !m.GetIsTargetHero() &&
			!strings.HasPrefix(actor, "npc_dota_hero_") &&
			!strings.HasPrefix(target, "npc_dota_hero_") {
			return nil // drop pure creep/tower noise; keep anything touching a hero
		}
		events = append(events, event{
			T:          round1(ts), // raw engine time; converted to game-clock below
			Type:       strings.TrimPrefix(m.GetType().String(), "DOTA_COMBATLOG_"),
			Actor:      actor,
			Target:     target,
			Inflictor:  inflictor,
			Value:      m.GetValue(),
			ActorHero:  m.GetIsAttackerHero(),
			TargetHero: m.GetIsTargetHero(),
		})
		return nil
	})

	// Exact engine seconds per tick, so NetTick*tickInterval == game engine time.
	p.Callbacks.OnCSVCMsg_ServerInfo(func(m *dota.CSVCMsg_ServerInfo) error {
		if ti := float64(m.GetTickInterval()); ti > 0 {
			tickInterval = ti
		}
		return nil
	})

	// Drive sampling off the per-tick clock (30 Hz). Boundaries are in ENGINE time
	// (NetTick*tickInterval) so we can sample the pre-game live, before the horn is
	// known; each snapshot's T is converted to game-clock (minus the horn) in the
	// post-Start pass. Each boundary is emitted with the positions in effect AT
	// that instant -- fixing the old bug where the whole pre-game backlog was
	// flushed at the horn with one (frozen) position.
	p.Callbacks.OnCNETMsg_Tick(func(m *dota.CNETMsg_Tick) error {
		if !armed {
			return nil
		}
		en := float64(m.GetTick()) * tickInterval
		for en >= nextSample {
			dumpSnapshots(nextSample)
			nextSample += *interval
		}
		for en >= nextBuilding {
			dumpBuildings(nextBuilding)
			nextBuilding += *buildingInterval
		}
		for en >= nextCreep {
			dumpCreeps(nextCreep)
			nextCreep += *creepInterval
		}
		return nil
	})

	if err := p.Start(); err != nil {
		panic(err)
	}

	// Convert every engine-time T to game-clock (0 = horn) now that the horn time
	// is known, and drop frames before the pre-game window. This is what lets the
	// pre-game be sampled live yet labeled correctly.
	horn := gameStart
	lo := -*pregame - 0.5
	ks := snaps[:0]
	for _, s := range snaps {
		s.T = round1(s.T - horn)
		if s.T >= lo {
			ks = append(ks, s)
		}
	}
	snaps = ks
	kb := buildingSnaps[:0]
	for _, b := range buildingSnaps {
		b.T = round1(b.T - horn)
		if b.T >= lo {
			kb = append(kb, b)
		}
	}
	buildingSnaps = kb
	kc := creepSnaps[:0]
	for _, c := range creepSnaps {
		c.T = round1(c.T - horn)
		if c.T >= lo {
			kc = append(kc, c)
		}
	}
	creepSnaps = kc
	for i := range events {
		events[i].T = round1(events[i].T - horn)
	}

	// Flatten wards into output records (converting their engine times too).
	var wardSnaps []wardSnap
	for _, w := range wards {
		if w.kind == "" {
			continue
		}
		tEnd := -1.0 // still up at end of replay
		if w.tEnd > -1e8 {
			tEnd = round1(w.tEnd - horn)
		}
		wardSnaps = append(wardSnaps, wardSnap{
			Type: w.kind, Team: w.team, X: round1(w.x), Y: round1(w.y),
			TStart: round1(w.tStart - horn), TEnd: tEnd,
		})
	}

	out := map[string]interface{}{
		"game": map[string]interface{}{
			"start_time": round1(gameStart),
			"teams":      teams,
			"vision_note": "No per-team fog bitmask exists in Source2 replays " +
				"(no m_iTaggedAsVisibleByTeam). Reconstruct each team's vision from " +
				"its vision sources: hero positions (snapshots), wards, and standing " +
				"buildings -- union day/night/ward/tower radii. See dumper header.",
		},
		"snapshots": snaps,
		"buildings": buildingSnaps,
		"creeps":    creepSnaps,
		"wards":     wardSnaps,
		"events":    events,
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(out); err != nil {
		panic(err)
	}
}

// slotPath builds a manta indexed-field path, e.g. slotPath("m_hItems", 3) ->
// "m_hItems.0003". manta zero-pads vector element indices to 4 digits.
func slotPath(base string, i int) string {
	d := []byte{'0', '0', '0', '0'}
	d[3] = byte('0' + i%10)
	d[2] = byte('0' + (i/10)%10)
	d[1] = byte('0' + (i/100)%10)
	d[0] = byte('0' + (i/1000)%10)
	return base + "." + string(d)
}

// isBuildingClass matches the structures we track (towers, barracks, ancient,
// watch-tower). Excludes filler/effigy building props.
func isBuildingClass(cn string) bool {
	switch cn {
	case "CDOTA_BaseNPC_Tower", "CDOTA_BaseNPC_Barracks",
		"CDOTA_BaseNPC_Fort", "CDOTA_BaseNPC_Watch_Tower":
		return true
	}
	return false
}

// buildingName maps a structure class to a short readable kind.
func buildingName(cn string) string {
	switch cn {
	case "CDOTA_BaseNPC_Tower":
		return "tower"
	case "CDOTA_BaseNPC_Barracks":
		return "barracks"
	case "CDOTA_BaseNPC_Fort":
		return "ancient"
	case "CDOTA_BaseNPC_Watch_Tower":
		return "watch_tower"
	}
	return snakeFromClass(cn, "CDOTA_BaseNPC_")
}

// wardKind classifies observer vs sentry (true-sight) ward entities.
func wardKind(cn string) string {
	switch cn {
	case "CDOTA_NPC_Observer_Ward":
		return "observer"
	case "CDOTA_NPC_Observer_Ward_TrueSight":
		return "sentry"
	}
	return ""
}

// isCreepClass matches lane and neutral creeps (and siege), excluding heroes,
// wards, buildings, couriers and summons handled elsewhere / not wanted.
func isCreepClass(cn string) bool {
	switch cn {
	case "CDOTA_BaseNPC_Creep_Lane", "CDOTA_BaseNPC_Creep_Siege",
		"CDOTA_BaseNPC_Creep_Neutral":
		return true
	}
	return false
}

func round1(v float64) float64 {
	return float64(int64(v*10+sign(v)*0.5)) / 10
}
func round3(v float64) float64 {
	return float64(int64(v*1000+sign(v)*0.5)) / 1000
}
func sign(v float64) float64 {
	if v < 0 {
		return -1
	}
	return 1
}

// behav-dump: extract a per-hero behavioral timeline from a Dota 2 Source 2
// .dem replay recorded by our dedicated soak-farm server.
//
// Output (single JSON object on stdout):
//
//	{
//	  "game":      { "start_time": <server-sec of the horn>,
//	                 "teams": { "<npc_name>": 2|3, ... } },
//	  "snapshots": [ { "t","hero","team","x","y","hp","hp_pct","mp_pct","level" }, ... ],
//	  "events":    [ { "t","type","actor","target","inflictor","value",
//	                   "actor_hero","target_hero" }, ... ]
//	}
//
// "t" is game-clock seconds (0 = horn), derived by subtracting the gamerules
// GameStartTime from the raw server timestamps. Snapshots are sampled at a
// fixed game-time interval (default 1.0s). Events are every combat-log entry
// that involves a hero as actor or target.
//
// Dedicated-server replays carry no /dota_vNNNN/ build tag, so we vendor manta
// with a patched class.go that defaults GameBuild to 9999 (above every legacy
// field-patch range) — see ../README.md.
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

type snapshot struct {
	T     float64 `json:"t"`
	Hero  string  `json:"hero"`
	Team  int32   `json:"team"`
	X     float64 `json:"x"`
	Y     float64 `json:"y"`
	HP    int32   `json:"hp"`
	HPPct float64 `json:"hp_pct"`
	MPPct float64 `json:"mp_pct"`
	Level int32   `json:"level"`
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

// classToNPC converts "CDOTA_Unit_Hero_Skywrath_Mage" -> "npc_dota_hero_skywrath_mage"
// and "CDOTA_Unit_Hero_WitchDoctor" -> "npc_dota_hero_witch_doctor" by splitting
// on existing underscores AND camelCase boundaries. This matches the names the
// combat log uses, so snapshots and events cross-reference cleanly.
func classToNPC(cn string) string {
	suffix := strings.TrimPrefix(cn, "CDOTA_Unit_Hero_")
	suffix = strings.ReplaceAll(suffix, "_", "")
	var b strings.Builder
	for i, r := range suffix {
		if i > 0 && r >= 'A' && r <= 'Z' {
			b.WriteByte('_')
		}
		b.WriteRune(r)
	}
	return "npc_dota_hero_" + strings.ToLower(b.String())
}

func main() {
	interval := flag.Float64("interval", 1.0, "snapshot interval in game seconds")
	flag.Parse()
	if flag.NArg() < 1 {
		os.Stderr.WriteString("usage: behav-dump [-interval S] replay.dem > timeline.json\n")
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

	heroes := map[int32]*heroState{} // entity index -> latest state
	teams := map[string]int32{}
	var snaps []snapshot
	var events []event

	serverNow := 0.0    // latest known raw server time (from combat log)
	gameStart := 0.0    // horn, from gamerules GameStartTime (last nonzero)
	nextSample := -1.0  // next game-clock sample boundary; armed once horn known

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
			snaps = append(snaps, snapshot{
				T: round1(t), Hero: h.name, Team: h.team,
				X: round1(h.x), Y: round1(h.y),
				HP: h.hp, HPPct: round3(hpPct), MPPct: round3(mpPct),
				Level: h.level,
			})
		}
	}

	p.OnEntity(func(e *manta.Entity, op manta.EntityOp) error {
		cn := e.GetClassName()

		if strings.Contains(cn, "Gamerules") {
			if v, ok := e.GetFloat32("m_pGameRules.m_flGameStartTime"); ok && v > 0 {
				gameStart = float64(v)
				if nextSample < 0 {
					nextSample = 0.0
				}
			}
			return nil
		}

		if !strings.HasPrefix(cn, "CDOTA_Unit_Hero_") {
			return nil
		}
		// Skip illusions — they distort positional detectors.
		if b, ok := e.GetBool("m_bIsIllusion"); ok && b {
			return nil
		}
		idx := e.GetIndex()
		h := heroes[idx]
		if h == nil {
			h = &heroState{name: classToNPC(cn)}
			heroes[idx] = h
		}
		// m_iTeamNum is networked as an unsigned int (2 = Radiant, 3 = Dire).
		if t, ok := e.GetUint32("m_iTeamNum"); ok && t > 0 {
			h.team = int32(t)
			teams[h.name] = int32(t)
		}
		cx, okcx := e.GetUint32("CBodyComponent.m_cellX")
		cy, okcy := e.GetUint32("CBodyComponent.m_cellY")
		vx, okvx := e.GetFloat32("CBodyComponent.m_vecX")
		vy, okvy := e.GetFloat32("CBodyComponent.m_vecY")
		if okcx && okcy && okvx && okvy {
			h.x = float64(cx)*cellWidth + float64(vx) - coordOffset
			h.y = float64(cy)*cellWidth + float64(vy) - coordOffset
			h.valid = true
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
			serverNow = ts
			// Emit any snapshots whose game-clock boundary we've now passed.
			if nextSample >= 0 && gameStart > 0 {
				for serverNow-gameStart >= nextSample {
					dumpSnapshots(nextSample)
					nextSample += *interval
				}
			}
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
			T:          round1(ts - gameStart),
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

	if err := p.Start(); err != nil {
		panic(err)
	}

	out := map[string]interface{}{
		"game": map[string]interface{}{
			"start_time": round1(gameStart),
			"teams":      teams,
		},
		"snapshots": snaps,
		"events":    events,
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(out); err != nil {
		panic(err)
	}
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

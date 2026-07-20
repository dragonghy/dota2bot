#!/usr/bin/env python3
"""Scenario-test driver: apply a scenario spec to a live headless dedicated
server over rcon, wait out the observation window, end the game, and (later,
offline) evaluate the spec's behavioral assertions against the replay
timeline produced by tools/batch_test/behavioral/.

Design + feasibility notes: docs/SCENARIO_TESTING.md.

Subcommands:
  run           drive a live server (rcon) through the scenario
  gen-customize emit the Customize draft-pin Lua file from the spec
  evaluate      run the spec's assertions against a behavioral timeline.json
  self-test     offline sanity check of the assertion evaluator

Typical farm usage (spot instance with a soak-style server on slot 1):
  python3 run_scenario.py run scenarios/ally_attacked_react.json \
      --port 27021 --password soakref \
      --console-log /opt/soak/slot1/stdout_<TAG>.log \
      --out /opt/soak/scenario/<TAG>
  # ...then, after behav-dump produced timeline.json from the .dem:
  python3 run_scenario.py evaluate scenarios/ally_attacked_react.json \
      --timeline timeline.json

STATUS / HONESTY: `run` has NOT been exercised against a live server yet
(this repo's dev container has no Dota install). The rcon protocol code is
copied from tools/batch_test/soak/referee.py, which IS proven live (it ends
every farm game). Everything else defensive: bounded retries, socket
timeouts, clear errors, never hangs. Lines marked UNTESTED: call out the
specific interactions still pending the live probe (docs/SCENARIO_TESTING.md
section 8). `evaluate` and `self-test` are fully offline and runnable now.

Exit codes:
  0 success (run: scenario driven to completion; evaluate: all assertions pass)
  1 assertion failure (evaluate only)
  2 environment/protocol failure (bad spec, no rcon, timeout, ...)
"""
import argparse
import json
import os
import socket
import struct
import sys
import time

# ---------------------------------------------------------------------------
# rcon client — copied from tools/batch_test/soak/referee.py (proven live on
# the farm; keep the two in sync if the protocol handling ever changes).
# ---------------------------------------------------------------------------
SERVERDATA_AUTH = 3
SERVERDATA_AUTH_RESPONSE = 2
SERVERDATA_EXECCOMMAND = 2


class Rcon:
    def __init__(self, host, port, password, timeout=5.0):
        self.sock = socket.create_connection((host, port), timeout=timeout)
        self.sock.settimeout(timeout)
        self._id = 0
        self._send(SERVERDATA_AUTH, password)
        while True:
            rid, rtype, _ = self._recv()
            if rtype == SERVERDATA_AUTH_RESPONSE:
                if rid == -1:
                    raise PermissionError("rcon auth refused")
                break

    def _send(self, ptype, body):
        self._id += 1
        payload = struct.pack("<ii", self._id, ptype) + body.encode() + b"\x00\x00"
        self.sock.sendall(struct.pack("<i", len(payload)) + payload)

    def _recv(self):
        raw = b""
        while len(raw) < 4:
            chunk = self.sock.recv(4 - len(raw))
            if not chunk:
                raise ConnectionError("rcon closed")
            raw += chunk
        (size,) = struct.unpack("<i", raw)
        data = b""
        while len(data) < size:
            chunk = self.sock.recv(size - len(data))
            if not chunk:
                raise ConnectionError("rcon closed")
            data += chunk
        rid, rtype = struct.unpack("<ii", data[:8])
        return rid, rtype, data[8:-2].decode(errors="replace")

    def cmd(self, command):
        self._send(SERVERDATA_EXECCOMMAND, command)
        _, _, body = self._recv()
        return body

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


def detect_host():
    """The dedicated server binds rcon to the primary interface, not
    127.0.0.1 (learned on the farm; see referee.py)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def rcon_connect(host, port, password, attempts, retry_delay_s, log):
    """Connect with bounded retries; raise the last error if all fail."""
    last = None
    for i in range(1, attempts + 1):
        try:
            rc = Rcon(host, port, password)
            log(f"rcon connected to {host}:{port} (attempt {i}/{attempts})")
            return rc
        except (OSError, PermissionError, ConnectionError) as e:
            last = e
            log(f"rcon attempt {i}/{attempts} failed: {e}")
            if isinstance(e, PermissionError):
                break  # wrong password never fixes itself
            time.sleep(retry_delay_s)
    raise SystemExit(f"FATAL: cannot connect rcon {host}:{port}: {last}")


# ---------------------------------------------------------------------------
# spec handling
# ---------------------------------------------------------------------------
def load_spec(path):
    try:
        with open(path) as f:
            spec = json.load(f)
    except (OSError, ValueError) as e:
        raise SystemExit(f"FATAL: cannot load spec {path}: {e}")
    for key in ("name", "observe", "end", "assertions"):
        if key not in spec:
            raise SystemExit(f"FATAL: spec {path} missing required key '{key}'")
    if spec["end"].get("method") != "surrender_flip":
        # the surrender flip is the ONLY verified end mechanism on our
        # dedicated build (dota_dev forcewin is a proven no-op; see
        # iterations/0008 and docs/SCENARIO_TESTING.md section 2).
        raise SystemExit("FATAL: only end.method='surrender_flip' is supported")
    return spec


# ---------------------------------------------------------------------------
# run mode
# ---------------------------------------------------------------------------
HORN_MARKER = "DOTA_GAMERULES_STATE_GAME_IN_PROGRESS"
GAME_OVER_MARKER = "Match signout"


def read_log_tail(path, max_bytes=4 << 20):
    """Read up to the last max_bytes of the console log (it can grow large)."""
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as f:
            if size > max_bytes:
                f.seek(size - max_bytes)
            return f.read().decode(errors="replace")
    except OSError:
        return ""


def wait_for_marker(log_path, marker, timeout_s, poll_s, log):
    """Poll the server console log until `marker` appears; False on timeout."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if marker in read_log_tail(log_path):
            return True
        log(f"waiting for '{marker}' in {log_path} "
            f"({int(deadline - time.time())}s left)")
        time.sleep(poll_s)
    return False


def cmd_run(args):
    spec = load_spec(args.spec)
    outdir = args.out or f"scenario_{spec['name']}_{time.strftime('%Y%m%d_%H%M%S')}"
    os.makedirs(outdir, exist_ok=True)
    transcript_path = os.path.join(outdir, "rcon_transcript.jsonl")
    transcript = open(transcript_path, "a")
    t0 = time.time()

    def log(msg):
        line = f"[{time.time() - t0:7.1f}s] {msg}"
        print(line, flush=True)

    def record(kind, **kw):
        kw.update({"t_wall": round(time.time() - t0, 1), "kind": kind})
        transcript.write(json.dumps(kw) + "\n")
        transcript.flush()

    result = {"scenario": spec["name"], "spec": os.path.abspath(args.spec),
              "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
              "phases": [], "ok": False}

    def finish(code):
        result["wall_s"] = round(time.time() - t0, 1)
        with open(os.path.join(outdir, "scenario_result.json"), "w") as f:
            json.dump(result, f, indent=2)
        transcript.close()
        log(f"result written to {outdir}/scenario_result.json")
        sys.exit(code)

    # 1. wait for the horn (game in progress) via the server console log.
    #    The console log is the only game-state channel we have (no rcon
    #    query surface on this build — verified, iterations/0007).
    if not args.console_log:
        raise SystemExit("FATAL: --console-log is required for run "
                         "(horn detection has no other channel)")
    log(f"waiting for horn (timeout {args.horn_timeout}s)")
    if not wait_for_marker(args.console_log, HORN_MARKER,
                           args.horn_timeout, args.poll, log):
        result["error"] = "horn never appeared in console log"
        finish(2)
    log("horn detected: game in progress")
    result["horn_wall_s"] = round(time.time() - t0, 1)

    # 2. connect rcon
    host = args.host or detect_host()
    rc = rcon_connect(host, args.port, args.password,
                      args.rcon_attempts, args.rcon_retry_delay, log)

    def send(cmdline):
        """Send one command; on transport error reconnect once, then give up
        on this command (record the failure and continue — a scenario with a
        failed shaping command is still worth observing/ending cleanly)."""
        nonlocal rc
        for attempt in (1, 2):
            try:
                resp = rc.cmd(cmdline)
                record("cmd", cmd=cmdline, resp=resp[:2000])
                log(f"rcon> {cmdline!r} -> {resp[:120]!r}")
                return resp
            except (OSError, ConnectionError) as e:
                record("cmd_error", cmd=cmdline, error=str(e), attempt=attempt)
                log(f"rcon> {cmdline!r} FAILED ({e}), attempt {attempt}")
                if attempt == 1:
                    try:
                        rc.close()
                        rc = rcon_connect(host, args.port, args.password,
                                          args.rcon_attempts,
                                          args.rcon_retry_delay, log)
                    except SystemExit:
                        return None
        return None

    # 3. apply phases (UNTESTED: individual cvar effects pending live probe —
    #    see docs/SCENARIO_TESTING.md section 8; transport itself is proven).
    for i, phase in enumerate(spec.get("phases", [])):
        pinfo = {"index": i, "when": phase.get("when", "in_progress"),
                 "enabled": phase.get("enabled", True),
                 "untested": phase.get("untested", False), "commands": []}
        if not pinfo["enabled"]:
            log(f"phase {i}: disabled in spec, skipping")
            result["phases"].append(pinfo)
            continue
        if pinfo["untested"]:
            log(f"phase {i}: marked UNTESTED in spec — running it, but treat "
                "effects as unproven until the live probe confirms them")
        for cmdline in phase.get("commands", []):
            resp = send(cmdline)
            pinfo["commands"].append({"cmd": cmdline, "ok": resp is not None})
        result["phases"].append(pinfo)

    # 4. observation window: game-minutes at the assumed timescale.
    obs = spec["observe"]
    ts = float(obs.get("assumed_timescale", 3.6))
    wall_s = float(obs["game_minutes"]) * 60.0 / max(ts, 0.1)
    log(f"observing: {obs['game_minutes']} game-min at ts~{ts} "
        f"=> ~{wall_s:.0f}s wall")
    deadline = time.time() + wall_s
    while time.time() < deadline:
        # early exit if the game somehow ended on its own
        if GAME_OVER_MARKER in read_log_tail(args.console_log):
            log("game ended on its own during observation window")
            break
        time.sleep(min(args.poll, max(0.5, deadline - time.time())))

    # 5. end the game — the VERIFIED surrender flip (referee.py mechanism).
    if GAME_OVER_MARKER not in read_log_tail(args.console_log):
        log("ending game via surrender flip")
        send("dota_surrender_on_disconnect 1")
        send("dota_auto_surrender_all_disconnected_timeout 1")
        if not wait_for_marker(args.console_log, GAME_OVER_MARKER,
                               args.end_timeout, args.poll, log):
            result["error"] = "game did not end after surrender flip"
            log("WARNING: no Match signout after surrender flip; "
                "the wall-clock backstop in the launcher must reap this game")
            rc.close()
            finish(2)
    log("game over (Match signout seen)")
    rc.close()

    result["ok"] = True
    result["next"] = ("run behavioral/run_replay.sh on this game's .dem, then: "
                      f"run_scenario.py evaluate {args.spec} --timeline <timeline.json>")
    finish(0)


# ---------------------------------------------------------------------------
# gen-customize mode: draft pin via the VERIFIED Customize channel
# (hero_selection.lua consumes Customize.Radiant_Heros / Dire_Heros).
# ---------------------------------------------------------------------------
def cmd_gen_customize(args):
    spec = load_spec(args.spec)
    draft = spec.get("draft")
    if not draft:
        raise SystemExit("FATAL: spec has no 'draft' block")
    for side in ("radiant", "dire"):
        heroes = draft.get(side)
        if not isinstance(heroes, list) or len(heroes) != 5:
            raise SystemExit(f"FATAL: draft.{side} must list exactly 5 heroes")

    def lua_list(heroes):
        return ",\n".join(f"    'npc_dota_hero_{h}'" for h in heroes)

    body = (
        "-- generated by run_scenario.py gen-customize; farm-instance only,\n"
        f"-- never shipped. Scenario: {spec['name']}\n"
        "-- Install: append these assignments to the END of\n"
        "-- bots/Customize/general.lua ON THE FARM INSTANCE (or apply them in\n"
        "-- a local overlay), so hero_selection.lua picks exactly this draft.\n"
        "Customize.Radiant_Heros = {\n" + lua_list(draft["radiant"]) + "\n}\n"
        "Customize.Dire_Heros = {\n" + lua_list(draft["dire"]) + "\n}\n"
        "Customize.Allow_Repeated_Heroes = false\n"
    )
    if args.out:
        with open(args.out, "w") as f:
            f.write(body)
        print(f"wrote {args.out}")
    else:
        sys.stdout.write(body)


# ---------------------------------------------------------------------------
# evaluate mode: assertions over a behavioral timeline
# (same data model as tools/batch_test/behavioral/detect.py)
# ---------------------------------------------------------------------------
def _dist(a, b):
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5


class Timeline:
    """Minimal view over dumper/main.go output: teams, snapshots, events."""

    def __init__(self, d):
        self.teams = d["game"]["teams"]
        self.events = sorted(d["events"], key=lambda e: e["t"])
        self.snaps = {}
        for s in d["snapshots"]:
            self.snaps.setdefault(s["hero"], []).append(s)
        for h in self.snaps:
            self.snaps[h].sort(key=lambda s: s["t"])
        self.heroes = list(self.teams.keys())

    def team(self, hero):
        return self.teams.get(hero, 0)

    def state_at(self, hero, t, tol=2.0):
        best = None
        for s in self.snaps.get(hero, []):
            dt = abs(s["t"] - t)
            if dt <= tol and (best is None or dt < best[0]):
                best = (dt, s)
        return best[1] if best else None

    def pos(self, hero, t, tol=2.0):
        s = self.state_at(hero, t, tol)
        return (s["x"], s["y"]) if s else None

    def alive_at(self, hero, t, tol=2.0):
        s = self.state_at(hero, t, tol)
        return bool(s and s["hp"] > 0)


def assert_ally_react(tl, params):
    """For every hero-on-hero damage incident, each living victim-side ally
    within notice_radius must, within react_window_s, either act against the
    attacker's team (ABILITY cast or hero DAMAGE dealt) or move at least
    retreat_min_units from where it stood at incident time."""
    notice = float(params.get("notice_radius", 1200))
    window = float(params.get("react_window_s", 3.0))
    retreat = float(params.get("retreat_min_units", 300))
    dedup = float(params.get("incident_dedup_s", 6.0))
    min_rate = float(params.get("min_react_rate", 0.6))

    incidents = []
    last_by_victim = {}
    for e in tl.events:
        if e["type"] != "DAMAGE" or not e.get("target_hero") or not e.get("actor_hero"):
            continue
        victim, attacker, t = e["target"], e["actor"], e["t"]
        if not victim.startswith("npc_dota_hero_") or \
                not attacker.startswith("npc_dota_hero_"):
            continue
        vteam = tl.team(victim)
        if vteam == 0 or tl.team(attacker) == vteam:
            continue  # unknown team or friendly fire artifact
        if t - last_by_victim.get(victim, -1e9) < dedup:
            continue  # one incident per victim per dedup window
        last_by_victim[victim] = t
        incidents.append((t, victim, attacker))

    checks = []
    for t, victim, attacker in incidents:
        vp = tl.pos(victim, t)
        if not vp:
            continue
        ateam = tl.team(attacker)
        for ally in tl.heroes:
            if ally == victim or tl.team(ally) != tl.team(victim):
                continue
            if not tl.alive_at(ally, t):
                continue
            ap0 = tl.pos(ally, t)
            if not ap0 or _dist(vp, ap0) > notice:
                continue
            # (a) fought back: ability cast, or damage dealt to the enemy team
            fought = False
            for e in tl.events:
                if e["t"] < t or e["t"] > t + window:
                    continue
                if e.get("actor") != ally:
                    continue
                if e["type"] == "ABILITY":
                    fought = True
                    break
                if e["type"] == "DAMAGE" and e.get("target_hero") and \
                        tl.team(e.get("target", "")) == ateam:
                    fought = True
                    break
            # (b) repositioned: moved >= retreat units by end of window
            moved = False
            ap1 = tl.pos(ally, t + window)
            move_d = _dist(ap0, ap1) if ap1 else 0.0
            if ap1 and move_d >= retreat:
                moved = True
            ok = fought or moved
            checks.append({
                "t": round(t, 1), "victim": victim, "attacker": attacker,
                "ally": ally, "ally_dist": round(_dist(vp, ap0)),
                "reacted": ok,
                "how": "fought" if fought else ("moved %.0fu" % move_d if moved else "IDLE"),
            })

    reacted = sum(1 for c in checks if c["reacted"])
    rate = reacted / len(checks) if checks else None
    passed = (rate is not None and rate >= min_rate) if checks else False
    return {
        "type": "ally_react", "incidents": len(incidents),
        "checks": len(checks), "reacted": reacted,
        "react_rate": None if rate is None else round(rate, 3),
        "min_react_rate": min_rate, "passed": passed,
        "detail": checks,
        "note": ("no scorable incidents — scenario produced no ally-attacked "
                 "situations; treat as FAILED setup, not passing behavior")
                if not checks else None,
    }


ASSERTION_TYPES = {
    "ally_react": assert_ally_react,
}


def evaluate_spec(spec, timeline_dict):
    tl = Timeline(timeline_dict)
    results = []
    for a in spec["assertions"]:
        fn = ASSERTION_TYPES.get(a.get("type"))
        if fn is None:
            raise SystemExit(f"FATAL: unknown assertion type {a.get('type')!r} "
                             f"(known: {sorted(ASSERTION_TYPES)})")
        results.append(fn(tl, a.get("params", {})))
    return results


def cmd_evaluate(args):
    spec = load_spec(args.spec)
    try:
        with open(args.timeline) as f:
            timeline = json.load(f)
    except (OSError, ValueError) as e:
        raise SystemExit(f"FATAL: cannot load timeline {args.timeline}: {e}")
    results = evaluate_spec(spec, timeline)
    all_pass = all(r["passed"] for r in results)
    for r in results:
        print(f"=== assertion {r['type']}: "
              f"{'PASS' if r['passed'] else 'FAIL'} "
              f"(react rate {r['react_rate']} vs min {r['min_react_rate']}; "
              f"{r['reacted']}/{r['checks']} checks over {r['incidents']} incidents)")
        if args.verbose:
            for c in r["detail"]:
                mark = "ok " if c["reacted"] else "MISS"
                print(f"  [{mark}] t={c['t']:>7} {c['ally']} "
                      f"({c['ally_dist']}u from {c['victim']} hit by "
                      f"{c['attacker']}) -> {c['how']}")
        if r.get("note"):
            print(f"  note: {r['note']}")
    if args.json:
        with open(args.json, "w") as f:
            json.dump({"scenario": spec["name"], "passed": all_pass,
                       "assertions": results}, f, indent=2)
        print(f"wrote {args.json}")
    sys.exit(0 if all_pass else 1)


# ---------------------------------------------------------------------------
# self-test: synthetic timeline exercises the evaluator offline
# ---------------------------------------------------------------------------
def cmd_self_test(_args):
    A, B = "npc_dota_hero_axe", "npc_dota_hero_lion"        # radiant
    E = "npc_dota_hero_sniper"                               # dire
    def snap(h, t, x, y, hp=1000):
        return {"t": t, "hero": h, "team": 2 if h in (A, B) else 3,
                "x": x, "y": y, "hp": hp, "hp_pct": hp / 1000.0,
                "mp_pct": 1.0, "level": 6}
    snapshots, events = [], []
    for t in range(0, 40):
        snapshots.append(snap(A, t, 0, 0))
        snapshots.append(snap(E, t, 400, 0))
        # incident 1 (t=5): lion nearby and FIGHTS BACK -> reacted
        # incident 2 (t=20): lion nearby and IDLES in place -> not reacted
        snapshots.append(snap(B, t, 600, 0))
    events.append({"t": 5.0, "type": "DAMAGE", "actor": E, "target": A,
                   "inflictor": "", "value": 60, "actor_hero": True,
                   "target_hero": True})
    events.append({"t": 6.0, "type": "ABILITY", "actor": B, "target": E,
                   "inflictor": "lion_impale", "value": 0, "actor_hero": True,
                   "target_hero": True})
    events.append({"t": 20.0, "type": "DAMAGE", "actor": E, "target": A,
                   "inflictor": "", "value": 60, "actor_hero": True,
                   "target_hero": True})
    timeline = {"game": {"start_time": 0, "teams": {A: 2, B: 2, E: 3}},
                "snapshots": snapshots, "events": events}
    spec = {"name": "self_test", "observe": {}, "end": {"method": "surrender_flip"},
            "assertions": [{"type": "ally_react",
                            "params": {"min_react_rate": 0.5}}]}
    res = evaluate_spec(spec, timeline)[0]
    ok = (res["incidents"] == 2 and res["checks"] == 2
          and res["reacted"] == 1 and res["passed"] is True)
    print(json.dumps({k: v for k, v in res.items() if k != "detail"}, indent=2))
    print("self-test:", "PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="mode", required=True)

    p = sub.add_parser("run", help="drive a live server through the scenario")
    p.add_argument("spec")
    p.add_argument("--port", type=int, required=True)
    p.add_argument("--password", required=True)
    p.add_argument("--host", default=None,
                   help="rcon host (default: auto-detect primary interface)")
    p.add_argument("--console-log", required=True,
                   help="the dedicated server's stdout log (game-state channel)")
    p.add_argument("--out", default=None, help="artifacts directory")
    p.add_argument("--horn-timeout", type=float, default=600,
                   help="max wall-seconds to wait for the game to start")
    p.add_argument("--end-timeout", type=float, default=120,
                   help="max wall-seconds to wait for Match signout after the flip")
    p.add_argument("--poll", type=float, default=10)
    p.add_argument("--rcon-attempts", type=int, default=5)
    p.add_argument("--rcon-retry-delay", type=float, default=5)
    p.set_defaults(fn=cmd_run)

    p = sub.add_parser("gen-customize",
                       help="emit the Customize draft-pin Lua from the spec")
    p.add_argument("spec")
    p.add_argument("--out", default=None, help="output .lua path (default stdout)")
    p.set_defaults(fn=cmd_gen_customize)

    p = sub.add_parser("evaluate",
                       help="run spec assertions against a behavioral timeline")
    p.add_argument("spec")
    p.add_argument("--timeline", required=True)
    p.add_argument("--json", default=None, help="write results JSON here")
    p.add_argument("--verbose", action="store_true")
    p.set_defaults(fn=cmd_evaluate)

    p = sub.add_parser("self-test", help="offline evaluator sanity check")
    p.set_defaults(fn=cmd_self_test)

    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()

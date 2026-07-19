#!/usr/bin/env python3
"""30-minute referee for soak-farm games (owner rule: the game is locked to
30 game-minutes; the ECONOMIC leader at the cap is the winner).

The dedicated server offers no query commands, bot print() never reaches any
log, and Lua error payloads are masked — so the referee learns the game clock
from the console stream itself: `Building: ... destroyed at <T>` lines carry
exact game time. Each poll records (wall_now, max_building_T) into a sidecar
state file, measures the achieved timescale live from consecutive
observations, and extrapolates the current game time. Once the estimate
passes the cap it fires `dota_dev forcewin` over RCON (verified: ends the
game instantly with a normal Match signout scoreboard).

Which team the engine credits is irrelevant: analyze_log.py overrides the
winner for capped games with the economic leader computed from the signout
scoreboard (sum of GPM x duration per team) — that is the owner's metric.

Usage:
    referee.py PORT PASSWORD LOG_PATH STATE_PATH [--cap-min 30]

Exit codes: 0 = game over / just force-ended;  1 = keep polling;
            2 = transient failure (no rcon / no data yet)
"""
import argparse
import json
import os
import re
import socket
import struct
import sys
import time

SERVERDATA_AUTH = 3
SERVERDATA_AUTH_RESPONSE = 2
SERVERDATA_EXECCOMMAND = 2

RE_BUILDING = re.compile(r"^Building: npc_dota_\w+ destroyed at ([0-9]+(?:\.[0-9]+)?)", re.M)
DEFAULT_TIMESCALE = 3.0   # measured 3.0-3.6 with 12 slots on short games


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


def detect_host():
    # the dedicated server binds rcon to the primary interface, not 127.0.0.1
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port", type=int)
    ap.add_argument("password")
    ap.add_argument("log_path")
    ap.add_argument("state_path")
    ap.add_argument("--host", default=None)
    ap.add_argument("--cap-min", type=float, default=30.0)
    args = ap.parse_args()

    try:
        text = open(args.log_path, errors="replace").read()
    except OSError as e:
        print(f"referee: cannot read log: {e}", file=sys.stderr)
        sys.exit(2)

    if "Match signout" in text:
        print("game already over")
        sys.exit(0)

    try:
        state = json.load(open(args.state_path))
    except (OSError, ValueError):
        state = {"obs": []}
    if state.get("forced"):
        sys.exit(0)

    now = time.time()

    # clock anchor: first sighting of the horn (t=0). Short caps (e.g. 10
    # game-min) can pass before any tower falls, so Building timestamps alone
    # are not enough. Anchor accuracy is +/- one poll interval.
    if "DOTA_GAMERULES_STATE_GAME_IN_PROGRESS" not in text:
        json.dump(state, open(args.state_path, "w"))
        sys.exit(1)
    if "anchor_w" not in state:
        state["anchor_w"] = now
        state["obs"] = [{"w": now, "t": 0.0}]

    obs = state["obs"]
    times = [float(t) for t in RE_BUILDING.findall(text)]
    if times and max(times) > obs[-1]["t"] + 0.5:
        obs.append({"w": now, "t": max(times)})
        obs[:] = obs[-30:]

    # live timescale estimate across the observation window
    ts = DEFAULT_TIMESCALE
    if len(obs) >= 2 and obs[-1]["w"] - obs[0]["w"] > 45:
        ts = max(1.0, (obs[-1]["t"] - obs[0]["t"]) / (obs[-1]["w"] - obs[0]["w"]))

    est_t = obs[-1]["t"] + (now - obs[-1]["w"]) * ts
    state["est_t"] = round(est_t, 1)
    state["ts"] = round(ts, 2)

    if est_t < args.cap_min * 60:
        json.dump(state, open(args.state_path, "w"))
        print(f"t~{est_t:.0f}s (ts~{ts:.2f}) below cap")
        sys.exit(1)

    # End mechanism: flip the all-bots-disconnected auto-surrender on with a
    # 1-second timeout — the engine ends the match within seconds and writes
    # a full, normal Match signout. (`dota_dev forcewin` is a no-op on this
    # dedicated build — its one apparent success was actually this very
    # auto-surrender firing with default settings on a test server launched
    # without the farm's +dota_surrender_on_disconnect 0.)
    host = args.host or detect_host()
    try:
        rc = Rcon(host, args.port, args.password)
        rc.cmd("dota_surrender_on_disconnect 1")
        rc.cmd("dota_auto_surrender_all_disconnected_timeout 1")
    except Exception as e:
        json.dump(state, open(args.state_path, "w"))
        print(f"referee: surrender trigger failed: {e}", file=sys.stderr)
        sys.exit(2)

    state["forced"] = round(est_t, 1)
    json.dump(state, open(args.state_path, "w"))
    print(f"SURRENDER triggered at estimated t={est_t:.0f}s (ts~{ts:.2f}); "
          "economic winner is decided by analyze_log from the signout")
    sys.exit(0)


if __name__ == "__main__":
    main()

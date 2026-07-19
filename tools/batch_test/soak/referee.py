#!/usr/bin/env python3
"""30-minute referee for soak-farm games (owner rule: game is capped at 30
game-minutes; the economically leading team at the cap wins).

Talks to the dedicated server over Source RCON (server must be launched with
-usercon +rcon_password ...) and uses the server-side `script` console command
(sv_cheats 1) to read game time + per-team networth and, once the cap is
reached, force the winner via GameRules:SetGameWinner — the game ends
IMMEDIATELY with a normal Match signout scoreboard.

Usage:
    referee.py PORT PASSWORD [--cap-min 30] [--query-only]

Exit codes:
    0  game was force-ended now (or a decision was executed)
    1  game still below the cap (caller keeps polling)
    2  rcon unreachable / query failed (game loading or already over)
"""
import argparse
import socket
import struct
import sys

SERVERDATA_AUTH = 3
SERVERDATA_AUTH_RESPONSE = 2
SERVERDATA_EXECCOMMAND = 2
SERVERDATA_RESPONSE_VALUE = 0


class Rcon:
    def __init__(self, host, port, password, timeout=5.0):
        self.sock = socket.create_connection((host, port), timeout=timeout)
        self.sock.settimeout(timeout)
        self._id = 0
        self._send(SERVERDATA_AUTH, password)
        # auth flow: optional empty RESPONSE_VALUE, then AUTH_RESPONSE
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


# One server-side Lua snippet: prints "SOAKREF t=<sec> r=<networth> d=<networth>"
QUERY_LUA = (
    "local t=math.floor(GameRules:GetDOTATime(false,false));"
    "local r,d=0,0;"
    "for i=0,23 do if PlayerResource:IsValidPlayerID(i) then "
    "local tm=PlayerResource:GetTeam(i);"
    "if tm==2 then r=r+PlayerResource:GetNetWorth(i) "
    "elseif tm==3 then d=d+PlayerResource:GetNetWorth(i) end end end;"
    "print(string.format('SOAKREF t=%d r=%d d=%d',t,r,d))"
)


def parse_query(out):
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("SOAKREF "):
            kv = dict(p.split("=") for p in line.split()[1:])
            return int(kv["t"]), int(kv["r"]), int(kv["d"])
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port", type=int)
    ap.add_argument("password")
    ap.add_argument("--host", default=None,
                    help="rcon host; the server binds its primary NIC IP, not 127.0.0.1")
    ap.add_argument("--cap-min", type=float, default=30.0)
    ap.add_argument("--query-only", action="store_true")
    args = ap.parse_args()

    host = args.host
    if not host:
        # the dedicated server binds rcon to the primary interface address
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.connect(("10.255.255.255", 1))
            host = s.getsockname()[0]
        except OSError:
            host = "127.0.0.1"
        finally:
            s.close()

    try:
        rc = Rcon(host, args.port, args.password)
        out = rc.cmd("script " + QUERY_LUA)
        parsed = parse_query(out)
    except Exception as e:
        print(f"referee: rcon/query failed: {e}", file=sys.stderr)
        sys.exit(2)

    if parsed is None:
        print(f"referee: no SOAKREF in response: {out!r}", file=sys.stderr)
        sys.exit(2)

    t, r, d = parsed
    print(f"t={t}s radiant_nw={r} dire_nw={d}")
    if args.query_only:
        sys.exit(0)

    if t < args.cap_min * 60:
        sys.exit(1)

    # Cap reached: richer team wins, ties break to radiant.
    winner = 2 if r >= d else 3
    rc.cmd(f"script GameRules:SetGameWinner({winner})")
    print(f"FORCED winner=team{winner} at t={t}s (r={r} d={d})")
    sys.exit(0)


if __name__ == "__main__":
    main()

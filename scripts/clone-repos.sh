#!/usr/bin/env bash
# Klont alle aktiven Repos aus repos.txt nach ~/dev — PARALLEL (xargs -P 6).
# Private Repos brauchen vorher `gh auth login`; ohne Auth schlagen sie dank
# GIT_TERMINAL_PROMPT=0 schnell fehl statt zu hängen -> nach der Anmeldung
# einfach erneut ausführen (idempotent, überspringt Vorhandenes).
set -uo pipefail
export GIT_TERMINAL_PROMPT=0
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV="$HOME/dev"; mkdir -p "$DEV"

XARGS_RC=0
grep -vE '^[[:space:]]*(#|$)' "$REPO_DIR/repos.txt" \
  | DEV="$DEV" xargs -P 6 -I {} bash -c '
      url="$1"; name="$(basename "$url" .git)"; dir="$DEV/$name"
      if [ -d "$dir" ]; then echo "  ok    $name"
      else echo "  clone $name"
        # http.lowSpeed*: bricht ab, wenn der Transfer 30s lang <1KB/s macht ->
        # ein stockender Klon kann den (parallelen) Lauf nicht endlos blockieren.
        git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=30 clone -q "$url" "$dir" \
          || { echo "  FAIL  $name (Auth? -> gh auth login  |  oder Netz/Timeout)"; exit 1; }
      fi' _ {} || XARGS_RC=$?
echo "Repo-Klone fertig (~/dev)."
exit $XARGS_RC

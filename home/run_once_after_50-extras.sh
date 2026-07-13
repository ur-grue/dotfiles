#!/usr/bin/env bash
# Nachgelagerte Einmal-Schritte: zk-Notizbuch initialisieren + pyradio (Web-Radio).
# Best-effort — Fehler hier dürfen das Setup nie stoppen.
set -uo pipefail

# --- zk-Notizbuch ---
# zk/zk-nvim brauchen ein initialisiertes Notebook (.zk-Ordner). Ohne das:
# "failed to locate notebook: no notebook found in ~/zk".
ZKDIR="${ZK_NOTEBOOK_DIR:-$HOME/zk}"
if command -v zk >/dev/null 2>&1 && [ ! -d "$ZKDIR/.zk" ]; then
  echo "▸ zk: Notizbuch in $ZKDIR initialisieren…"
  mkdir -p "$ZKDIR"
  zk init "$ZKDIR" >/dev/null 2>&1 || echo "  (zk init fehlgeschlagen — manuell: zk init \"$ZKDIR\")"
fi

# --- pyradio (bestes Terminal-Web-Radio; nicht in Homebrew -> via pipx) ---
if command -v pipx >/dev/null 2>&1 && ! command -v pyradio >/dev/null 2>&1; then
  echo "▸ pyradio (Web-Radio) via pipx…"
  pipx install pyradio >/dev/null 2>&1 || echo "  (pyradio nicht installiert — manuell: pipx install pyradio)"
fi

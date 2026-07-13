#!/usr/bin/env bash
# gstack (github.com/garrytan/gstack) — Claude-Code-Skills nach ~/.claude/skills/gstack.
# Braucht `claude` (cask claude-code) + `bun` (Brewfile). Best-effort: fehlt eins,
# wird's nur gemeldet und übersprungen — nie das Setup abbrechen.
set -uo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "  (claude fehlt -> gstack später: git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup)"
  exit 0
fi
if ! command -v bun >/dev/null 2>&1; then
  echo "  (bun fehlt -> brew install bun, dann gstack einrichten)"
  exit 0
fi

GS="$HOME/.claude/skills/gstack"
if [ -d "$GS/.git" ]; then
  echo "▸ gstack bereits vorhanden ($GS) — überspringe."
  exit 0
fi

echo "▸ gstack-Skills klonen + einrichten (baut browse-Binary via bun)…"
if git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$GS" >/dev/null 2>&1; then
  ( cd "$GS" && ./setup >/dev/null 2>&1 ) \
    || echo "  (gstack ./setup fehlgeschlagen — manuell: cd \"$GS\" && ./setup)"
else
  echo "  (gstack-Klon fehlgeschlagen — Netz? manuell nachziehen)"
fi

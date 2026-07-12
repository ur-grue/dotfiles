#!/usr/bin/env bash
# Baut die nvim-Plugins headless vor (lazy.nvim), damit der erste echte Start
# sofort einsatzbereit ist — spart den manuellen "nvim öffnen, Plugins bauen
# lassen"-Schritt. Best-effort: Fehler hier dürfen das Setup nie stoppen.
set -uo pipefail
command -v nvim >/dev/null 2>&1 || exit 0
echo "▸ nvim: Plugins vorbauen (lazy.nvim)…"
# Lazy! = ohne UI/Prompts; sync = install + update + clean; dann sauber beenden.
nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || \
  echo "  (nvim-Plugins nicht komplett — später einmal 'nvim' öffnen + :Lazy sync)"

#!/usr/bin/env bash
# Baut die nvim-Plugins headless vor (lazy.nvim), damit der erste echte Start
# sofort einsatzbereit ist — spart den manuellen "nvim öffnen, Plugins bauen
# lassen"-Schritt. Best-effort: Fehler hier dürfen das Setup nie stoppen.
set -uo pipefail
command -v nvim >/dev/null 2>&1 || exit 0
echo "▸ nvim: Plugins vorbauen (lazy.nvim)…"
# Lazy! = ohne UI/Prompts; dann sauber beenden.
# WICHTIG auf bestehenden Systemen (DOTFILES_EXISTING=1, von setup.sh --existing
# gesetzt): `install` STATT `sync`. `sync` = install+update+CLEAN und würde jedes
# Plugin ENTFERNEN, das nicht in dieser Repo-Spec steht — also die eigenen Plugins
# des Nutzers löschen. `install` fügt nur die fehlenden hinzu, räumt nichts weg.
# </dev/null: kein TTY erben -> ein blockierendes getchar()/input() (z.B. wenn der
# lazy.nvim-Bootstrap-Clone scheitert) bekommt sofort EOF statt ewig zu hängen.
if [ "${DOTFILES_EXISTING:-0}" = 1 ]; then _LAZY="+Lazy! install"; else _LAZY="+Lazy! sync"; fi
nvim --headless "$_LAZY" +qa </dev/null >/dev/null 2>&1 || \
  echo "  (nvim-Plugins nicht komplett — später einmal 'nvim' öffnen + :Lazy sync)"

# Treesitter-Parser SYNCHRON vorbauen. nvim-treesitter (main branch) installiert
# sonst asynchron, und headless quittet vorher -> Parser fehlen bis zum manuellen
# :TSUpdate (genau das im :checkhealth gesehene "missing"). tree-sitter-CLI kommt
# aus dem Brewfile. Alles in pcall/|| -> nie fatal.
if command -v tree-sitter >/dev/null 2>&1; then
  echo "▸ nvim: Treesitter-Parser vorbauen…"
  nvim --headless -c "lua pcall(function() local ts=require('nvim-treesitter'); local h=ts.install({'bash','regex','json','yaml','toml','python','javascript','typescript','html','css','diff','gitcommit','lua','vim','vimdoc','query','markdown','markdown_inline'}); if type(h)=='table' then if h.wait then h:wait(600000) elseif h.await then h:await() end end end)" -c "qa" </dev/null >/dev/null 2>&1 \
    || echo "  (Treesitter: Parser installieren sich sonst beim ersten Öffnen der Dateitypen)"
else
  echo "  (tree-sitter CLI fehlt -> brew install tree-sitter; Parser bauen beim ersten Öffnen)"
fi

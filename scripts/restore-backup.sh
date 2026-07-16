#!/usr/bin/env bash
# restore-backup.sh — stellt Dotfiles aus einem von `setup.sh --existing` erzeugten
# Backup wieder her. `--existing` sichert VOR `chezmoi apply` jede bereits
# vorhandene, verwaltete Zieldatei nach ~/.dotfiles-backup-<zeit>/ (Struktur =
# Pfad relativ zu $HOME). Dieses Skript spielt sie zurück.
#
#   ./scripts/restore-backup.sh                 # neuestes Backup, interaktiv
#   ./scripts/restore-backup.sh --list          # nur zeigen, was zurückkäme
#   ./scripts/restore-backup.sh ~/.dotfiles-backup-20260716-120000   # bestimmtes
#
# macOS-Systemdefaults werden NICHT hier zurückgesetzt — dafür liegt (falls
# macos-defaults.sh lief) ein eigenes ~/.dotfiles-macos-restore-<zeit>.sh.
set -uo pipefail

if [ -t 1 ]; then R=$'\033[0m'; CY=$'\033[36m'; YE=$'\033[33m'; GR=$'\033[32m'; DIM=$'\033[90m'
else R=''; CY=''; YE=''; GR=''; DIM=''; fi

LIST_ONLY=0; BK=""
for a in "${@:-}"; do case "$a" in
  --list|--dry-run) LIST_ONLY=1 ;;
  --help|-h) sed -n '2,14p' "$0"; exit 0 ;;
  "") ;;
  *) BK="$a" ;;
esac; done

# Neuestes Backup wählen, wenn keins angegeben.
if [ -z "$BK" ]; then
  # shellcheck disable=SC2012  # Backup-Namen sind reine ASCII-Zeitstempel -> ls -t ist sicher & simpel
  BK="$(ls -dt "$HOME"/.dotfiles-backup-* 2>/dev/null | head -1)"
  [ -n "$BK" ] || { printf '%s\n' "  ${YE}▲ Kein ~/.dotfiles-backup-* gefunden.${R}"; exit 1; }
fi
[ -d "$BK" ] || { printf '%s\n' "  ${YE}▲ Kein Verzeichnis: $BK${R}"; exit 1; }

printf '%s\n' "${CY}Backup:${R} $BK"
printf '%s\n' "${DIM}Diese Dateien würden zurückgespielt (überschreiben die aktuellen):${R}"
# Alle regulären Dateien im Backup relativ zu $BK auflisten.
# -type f -o -type l: auch Symlinks erfassen (falls je ein symlink_-Eintrag in die
# chezmoi-Quelle kommt) — cp -aRp unten stellt beide korrekt wieder her.
FILES="$(cd "$BK" && find . \( -type f -o -type l \) 2>/dev/null | sed 's|^\./||')"
[ -n "$FILES" ] || { printf '%s\n' "  ${YE}▲ Backup ist leer.${R}"; exit 1; }
printf '%s\n' "$FILES" | while IFS= read -r f; do printf '%s\n' "  ${DIM}~/$f${R}"; done

if [ "$LIST_ONLY" = 1 ]; then exit 0; fi

printf '%s' "  ${CY}Diese Dateien in \$HOME zurückspielen? [y/N] ${R}"
read -r ans </dev/tty 2>/dev/null || ans=""
case "$ans" in [yYjJ]*) ;; *) printf '%s\n' "  Abgebrochen."; exit 0 ;; esac

# Vor dem Zurückspielen den JETZIGEN Stand sichern (doppeltes Netz).
PRE="$HOME/.dotfiles-prerestore-$(date +%Y%m%d-%H%M%S)"
printf '%s\n' "$FILES" | while IFS= read -r f; do
  [ -e "$HOME/$f" ] && { mkdir -p "$PRE/$(dirname "$f")"; cp -aRp "$HOME/$f" "$PRE/$f" 2>/dev/null || true; }
  mkdir -p "$HOME/$(dirname "$f")"
  cp -aRp "$BK/$f" "$HOME/$f" 2>/dev/null || true
done
printf '%s\n' "  ${GR}✔${R} Zurückgespielt aus $BK"
printf '%s\n' "  ${DIM}Vorheriger Stand gesichert unter: $PRE${R}"
printf '%s\n' "  ${DIM}Neue Shell öffnen, damit ~/.zshrc etc. neu geladen werden.${R}"

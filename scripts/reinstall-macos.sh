#!/usr/bin/env bash
# reinstall-macos.sh — macOS ERASE + Neuinstallation (Werksreset via startosinstall).
#
#   LEBENSZYKLUS:  pre-wipe-backup.sh  →  reinstall-macos.sh  →  [Neustart]  →  setup.sh
#                  (sichern)             (löschen + neu)         (fresh macOS)  (aufsetzen)
#
#   ⚠  ACHTUNG — DIES LÖSCHT DIE GESAMTE INTERNE FESTPLATTE.
#      Alle Daten, Benutzer, Apps und Einstellungen sind danach WEG. Der Mac
#      startet in eine jungfräuliche macOS-Installation (wie fabrikneu).
#      Vorher ZWINGEND:  ./scripts/pre-wipe-backup.sh  — und offene Arbeit pushen.
#
#   Nutzung:
#     ./scripts/reinstall-macos.sh --check      # nur Bereitschaft prüfen (0 Änderungen)
#     ./scripts/reinstall-macos.sh --download   # nur Full-Installer laden, NICHT löschen
#     ./scripts/reinstall-macos.sh              # interaktiv; verlangt getippte Bestätigung
#
#   DREI WEGE ZUM FRISCHEN macOS (alle valide — Wahl nach Situation):
#
#   1) Dieses Skript  —  startosinstall --eraseinstall, AUS dem laufenden macOS.
#      Ein Befehl, lädt/nutzt einen Full-Installer, löscht alle Volumes, installiert
#      neu. Bequem, wenn das System noch bootet.
#
#   2) Erase Assistant (GUI, am schnellsten/sichersten auf Apple Silicon / T2):
#        open "/System/Library/CoreServices/Erase Assistant.app"
#      Systemeinstellungen ▸ „Alle Inhalte & Einstellungen löschen". Kryptografischer
#      Sofort-Reset OHNE Neu-Download, behält die macOS-Version, kann NICHT bricken.
#
#   3) Web-Install / Recovery (unabhängig vom installierten OS — am robustesten):
#      • Apple Silicon: Mac aus, Power-Knopf HALTEN bis „Startoptionen", ▸ Optionen
#        ▸ „macOS neu installieren" (lädt frisch von Apple).
#      • Intel:  Cmd-Option-R beim Booten = Internet-Recovery (lädt macOS aus dem Netz).
#      In Recovery kannst du in der FESTPLATTENDIENSTPROGRAMM-App die Platte auch
#      wirklich SAUBER neu anlegen (siehe unten).
#
#   „Partition vorher sauber neu erstellen?" — Ja, aber meist NICHT nötig: sowohl
#   eraseinstall (1) als auch Erase Assistant (2) legen automatisch ein sauberes
#   APFS-Volume an. Willst du den Container wirklich frisch partitionieren: in
#   RECOVERY ▸ Festplattendienstprogramm ▸ Darstellung „Alle Geräte einblenden" ▸
#   die OBERSTE physische Platte wählen ▸ Löschen ▸ APFS ▸ dann „macOS neu
#   installieren". ACHTUNG Apple Silicon: manuelles Löschen der internen Platte kann
#   im Fehlerfall eine DFU-Wiederbelebung per zweitem Mac (Apple Configurator)
#   nötig machen — daher dort lieber (2)/(1), außer die Platte ist wirklich defekt.
#   Dieses Skript nimmt bewusst Weg (1): frische OS-Kopie, repariert auch kaputte
#   Installationen, ohne manuelle Platten-Chirurgie.
set -uo pipefail

# ---- Farben (nur bei TTY) ----
if [ -t 1 ]; then R=$'\033[0m'; RED=$'\033[1;31m'; YEL=$'\033[1;33m'; GRN=$'\033[1;32m'; DIM=$'\033[90m'
else R=''; RED=''; YEL=''; GRN=''; DIM=''; fi
info(){ printf '%s\n' "  $*"; }
ok(){   printf '%s\n' "  ${GRN}✔${R} $*"; }
warn(){ printf '%s\n' "  ${YEL}▲ $*${R}"; }
die(){  printf '%s\n' "  ${RED}✖ $*${R}"; exit 1; }

# ---- Argumente ----
MODE=erase
for a in "${@:-}"; do case "$a" in
  --check|--dry-run) MODE=check ;;
  --download)        MODE=download ;;
  --help|-h) sed -n '2,44p' "$0"; exit 0 ;;
  "") ;;
  *) die "Unbekannte Option: $a  (--check | --download | --help)" ;;
esac; done

[ "$(uname -s)" = "Darwin" ] || die "Läuft nur unter macOS."
ARCH="$(uname -m)"
VER="$(sw_vers -productVersion 2>/dev/null || echo '?')"

# ---- Installer im /Applications suchen (erste passende .app mit startosinstall) ----
find_installer(){
  local app
  for app in /Applications/Install\ macOS*.app; do
    [ -x "$app/Contents/Resources/startosinstall" ] && { printf '%s' "$app"; return 0; }
  done
  return 1
}
download_installer(){
  info "Lade vollständigen macOS-Installer (softwareupdate --fetch-full-installer)…"
  info "${DIM}Verfügbare Versionen:${R}"
  softwareupdate --list-full-installers 2>/dev/null | sed 's/^/    /' || true
  softwareupdate --fetch-full-installer || die "Installer-Download fehlgeschlagen."
}

# ---- Banner ----
echo
printf '%s\n' "${RED}  ┌──────────────────────────────────────────────────────┐${R}"
printf '%s\n' "${RED}  │   macOS  ERASE + REINSTALL  —  LÖSCHT DIE FESTPLATTE  │${R}"
printf '%s\n' "${RED}  └──────────────────────────────────────────────────────┘${R}"
info "${DIM}macOS $VER · $ARCH · $(id -un) · $(date '+%Y-%m-%d %H:%M')${R}"
echo

# ---- Preflight ----
# 1) Netzstrom: startosinstall verweigert Akku-Betrieb -> im Echtlauf harter Stopp.
if pmset -g ps 2>/dev/null | grep -q "Battery Power"; then
  [ "$MODE" = erase ] && die "Auf Akku — Netzteil anschließen (startosinstall läuft nicht auf Akku)."
  warn "Auf Akku — für den echten Lauf Netzteil anschließen."
else ok "Am Netzstrom"; fi

# 2) Backup-Signal: an pre-wipe-backup.sh gekoppelt (schafft ~/mac-backup-JJJJMMTT).
if ls -d "$HOME"/mac-backup-* >/dev/null 2>&1; then
  ok "Backup gefunden: $(ls -dt "$HOME"/mac-backup-* 2>/dev/null | head -1)"
else
  warn "Kein ~/mac-backup-* gefunden — lief ./scripts/pre-wipe-backup.sh schon?"
fi

# 3) Freier Speicher: startosinstall läuft AUS dem System und muss den Installer
# vor dem Löschen vorstagen -> braucht ~20 GB frei, sonst bricht es NACH dem
# ERASE-Prompt ab ("nicht genügend freier Speicherplatz"). Früh warnen.
FREE_GB="$(df -g / 2>/dev/null | awk 'NR==2{print $4}')"
if [ -n "${FREE_GB:-}" ] && [ "${FREE_GB:-0}" -lt 20 ] 2>/dev/null; then
  warn "Nur ${FREE_GB} GB frei — startosinstall braucht ~20 GB zum Vorstagen."
  info "  → Platz schaffen: ${DIM}sudo tmutil deletelocalsnapshots / ; Papierkorb leeren${R}"
  info "  → ODER speicher-unabhängig löschen: Systemeinstellungen ▸ Allgemein ▸"
  info "    „Alle Inhalte & Einstellungen löschen\", oder Recovery (Power halten)."
else
  ok "Freier Speicher: ${FREE_GB:-?} GB"
fi

# 4) Zielmedium sichtbar machen (was gleich gelöscht wird).
info "${DIM}Interne Datenträger (werden gelöscht):${R}"
diskutil list internal 2>/dev/null | sed 's/^/    /' || diskutil list 2>/dev/null | sed 's/^/    /'
echo

# 5) Installer vorhanden? Sonst laden (bzw. Hinweis im Check-Modus).
if INSTALLER="$(find_installer)"; then
  ok "Installer: $INSTALLER"
else
  warn "Kein macOS-Installer in /Applications gefunden."
  case "$MODE" in
    check)    info "  → Laden mit:  ./scripts/reinstall-macos.sh --download" ;;
    *)        download_installer
              INSTALLER="$(find_installer)" || die "Installer nach Download nicht auffindbar."
              ok "Installer: $INSTALLER" ;;
  esac
fi
STARTOS="${INSTALLER:-}/Contents/Resources/startosinstall"

# ---- Nicht-löschende Modi enden hier ----
if [ "$MODE" = check ]; then
  echo; ok "Bereitschafts-Check fertig — nichts wurde verändert."
  info "${DIM}Echter Lauf:  ./scripts/reinstall-macos.sh${R}"
  exit 0
fi
if [ "$MODE" = download ]; then
  echo; ok "Installer bereit — nichts gelöscht. Echter Lauf: ./scripts/reinstall-macos.sh"
  exit 0
fi

# ---- Bestätigung: getippt, kein simples y/N (Schutz vor Fat-Finger) ----
echo
warn "Letzte Warnung: Der gesamte interne Datenträger wird GELÖSCHT und macOS neu installiert."
warn "Alle Daten / Accounts / Apps gehen verloren. Der Mac startet danach von selbst neu."
printf '  Tippe exakt  %sERASE%s  zum Fortfahren (alles andere bricht ab): ' "${RED}" "${R}"
read -r CONFIRM </dev/tty 2>/dev/null || die "Keine Eingabe — abgebrochen."
[ "$CONFIRM" = "ERASE" ] || die "Nicht bestätigt (\"$CONFIRM\") — abgebrochen."

# ---- sudo + Apple-Silicon-Volume-Owner ----
info "Adminrechte anfordern…"
sudo -v || die "sudo fehlgeschlagen — Adminrechte nötig."

# startosinstall --eraseinstall: löscht ALLE Volumes und installiert frisch.
CMD=( sudo "$STARTOS" --eraseinstall --agreetolicense --newvolumename "Macintosh HD" )
if [ "$ARCH" = "arm64" ]; then
  # Apple Silicon verlangt für den Erase einen Volume-Owner (Admin). WICHTIG (Tahoe/
  # macOS 26): --user ALLEIN löst KEINE Passwortabfrage aus -> startosinstall bricht
  # mit „Provide a password with --stdinpass or --passprompt" ab. Deshalb --passprompt:
  # startosinstall fragt das Passwort selbst sicher ab (kein Passwort in argv/auf Platte).
  DEF_USER="$(id -un)"
  printf '  Apple Silicon: Volume-Owner (Admin) für die Löschung [%s]: ' "$DEF_USER"
  read -r OWNER </dev/tty 2>/dev/null || OWNER="$DEF_USER"
  OWNER="${OWNER:-$DEF_USER}"
  CMD+=( --user "$OWNER" --passprompt )
  info "${DIM}startosinstall fragt gleich das Passwort von '$OWNER' ab.${R}"
fi

echo
warn "Starte Erase-Install — der Mac rebootet gleich selbstständig. NICHT ausschalten."
info "${DIM}${CMD[*]}${R}"
# exec: diese Shell durch startosinstall ersetzen (Countdown + Reboot laufen dort).
exec "${CMD[@]}"

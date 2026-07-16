#!/usr/bin/env bash
# Vernünftige macOS-Defaults. Konservativ gehalten. Abmelden/Neustart für alles.
set -euo pipefail

# ---- Reversibilität: aktuelle Werte sichern + Restore-Skript erzeugen ----
# `defaults export` fängt ALLE Keys einer Domain MIT Typ -> byte-genaues Zurück
# (anders als `defaults delete`, das nur auf Apple-Werkseinstellung zurücksetzt).
# Läuft IMMER (billig) -> jeder Lauf ist umkehrbar. Besonders wichtig, wenn man
# diese Defaults NACHTRÄGLICH auf ein bestehendes System (iMac) anwendet.
_TS="$(date +%Y%m%d-%H%M%S)"
SNAP_DIR="$HOME/.dotfiles-macos-snapshot-$_TS"
RESTORE="$HOME/.dotfiles-macos-restore-$_TS.sh"
mkdir -p "$SNAP_DIR"
for _dom in NSGlobalDomain com.apple.finder com.apple.dock com.apple.screencapture; do
  defaults export "$_dom" "$SNAP_DIR/$_dom.plist" 2>/dev/null || true
done
cat > "$RESTORE" <<RS
#!/usr/bin/env bash
# Auto-erzeugt von macos-defaults.sh am $_TS — stellt die VORHERIGEN Defaults her.
set -uo pipefail
for _dom in NSGlobalDomain com.apple.finder com.apple.dock com.apple.screencapture; do
  [ -f "$SNAP_DIR/\$_dom.plist" ] && defaults import "\$_dom" "$SNAP_DIR/\$_dom.plist" 2>/dev/null || true
done
# Caps Lock: ERST den LaunchAgent entfernen (sonst setzt der nächste Login das
# Mapping wieder), DANN hidutil leeren.
_PL="\$HOME/Library/LaunchAgents/com.ur-grue.capslock-to-control.plist"
launchctl bootout "gui/\$(id -u)" "\$_PL" 2>/dev/null || true
rm -f "\$_PL" 2>/dev/null || true
/usr/bin/hidutil property --set '{"UserKeyMapping":[]}' >/dev/null 2>&1 || true
killall Finder Dock SystemUIServer 2>/dev/null || true
echo "macOS-Defaults zurückgesetzt (Snapshot: $SNAP_DIR)."
RS
chmod +x "$RESTORE"

# Tastatur: schnelle Wiederholrate (gut für vim/tmux-Navigation)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Finder: Pfadleiste, Statusleiste, alle Endungen, versteckte Dateien
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"   # Listenansicht
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Screenshots gesammelt in ~/Pictures/Screenshots
mkdir -p "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture type -string "png"

# Dock: keine zuletzt benutzten Apps, kein Auto-Hide-Delay
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock autohide-delay -float 0

# Textbearbeitung: keine Auto-Korrektur/Smart-Quotes (stört beim Coden)
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Caps Lock -> Control (größter Gewinn für vim/tmux). Sofort aktiv via hidutil;
# reboot-fest über einen LaunchAgent, der die Zuordnung bei jedem Login neu setzt
# (hidutil-Mappings überleben sonst keinen Neustart). KOMPLETT best-effort:
# in eine Funktion gekapselt, die bei jedem Fehler `return 0` macht und mit
# `|| true` aufgerufen wird — ein Fehler hier bricht die restlichen Defaults NIE ab.
caps_to_control() {
  local REMAP='{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E0}]}'
  /usr/bin/hidutil property --set "$REMAP" >/dev/null 2>&1 || true   # sofort wirksam
  local LA_DIR="$HOME/Library/LaunchAgents" PLIST dom
  mkdir -p "$LA_DIR" 2>/dev/null || return 0
  PLIST="$LA_DIR/com.ur-grue.capslock-to-control.plist"
  cat > "$PLIST" <<PL || return 0
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.ur-grue.capslock-to-control</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/hidutil</string>
    <string>property</string>
    <string>--set</string>
    <string>$REMAP</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
PL
  # macOS 11+: bootout/bootstrap ist der aktuelle Weg (load -w ist deprecated und
  # registriert auf Sequoia/26 evtl. gar nicht). load -w nur als Fallback.
  dom="gui/$(id -u 2>/dev/null || echo "$UID")"
  launchctl bootout   "$dom" "$PLIST" 2>/dev/null || true
  launchctl bootstrap "$dom" "$PLIST" 2>/dev/null || launchctl load -w "$PLIST" 2>/dev/null || true
}
# Caps Lock -> Control ist die eingreifendste Änderung (kapert eine physische
# Taste, überlebt Reboots via LaunchAgent). Auf Wunsch überspringbar, ohne die
# harmlosen defaults zu verlieren:  MACOS_NO_CAPSLOCK=1 ./scripts/macos-defaults.sh
if [ "${MACOS_NO_CAPSLOCK:-0}" = 1 ]; then
  echo "  (Caps Lock -> Control übersprungen: MACOS_NO_CAPSLOCK=1)"
else
  caps_to_control || true
fi

# SystemUIServer mit-neustarten: sonst greift der neue Screenshot-Speicherort
# erst „irgendwann später" (Audit-Fund).
killall Finder Dock SystemUIServer 2>/dev/null || true
echo "macOS-Defaults gesetzt (einige greifen erst nach Ab-/Anmelden)."
[ "${MACOS_NO_CAPSLOCK:-0}" = 1 ] || echo "Caps Lock -> Control ist aktiv (sofort + reboot-fest via LaunchAgent)."
echo "Rückgängig machen (vorherige Werte): $RESTORE"
echo
echo "Noch manuell (bewusst NICHT automatisiert — Sicherheit):"
echo "  • FileVault aktivieren:  Systemeinstellungen > Datenschutz & Sicherheit"
echo "    (wichtig, sobald der iMac per Tailscale erreichbar ist)"

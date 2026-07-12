#!/usr/bin/env bash
# Vernünftige macOS-Defaults. Konservativ gehalten. Abmelden/Neustart für alles.
set -euo pipefail

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
caps_to_control || true

killall Finder Dock 2>/dev/null || true
echo "macOS-Defaults gesetzt (einige greifen erst nach Ab-/Anmelden)."
echo "Caps Lock -> Control ist aktiv (sofort + reboot-fest via LaunchAgent)."
echo
echo "Noch manuell (bewusst NICHT automatisiert — Sicherheit):"
echo "  • FileVault aktivieren:  Systemeinstellungen > Datenschutz & Sicherheit"
echo "    (wichtig, sobald der iMac per Tailscale erreichbar ist)"

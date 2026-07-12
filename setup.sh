#!/usr/bin/env bash
# ============================================================================
#  AUTOPUNK // BOOTSTRAP — frischer macOS-Dev-Setup.
#      ./setup.sh            # voller Lauf (Cyberpunk-Dashboard, wenn TTY)
#      ./setup.sh --check    # Trockenlauf: zeigt, was fehlt (0 Änderungen)
#      ./setup.sh --plain    # ohne Animationen (Pipes/CI/Debug)
#
#  ROBUSTHEIT: Pakete werden EINZELN installiert. Schlägt eines fehl, wird es
#  geloggt und ÜBERSPRUNGEN — der Rest läuft weiter. Am Ende: Liste der
#  übersprungenen Pakete. Voll-Log: ~/.dotfiles-setup-<zeit>.log
# ============================================================================
set -euo pipefail

# ---- Argumente ----
MODE=run; PLAIN=0
for a in "${@:-}"; do case "$a" in
  --check|--dry-run) MODE=check ;;
  --plain)           PLAIN=1 ;;
  --help|-h) sed -n '2,12p' "$0"; exit 0 ;;
esac; done

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$HOME/.dotfiles-setup-$(date +%Y%m%d-%H%M%S).log"
LOGD="$(mktemp -d)"
START=$(date +%s)
: > "$LOG"

# ---- Branding ----
BRAND="${BRAND:-ur-grue net inst}"     # Banner-Titel (überschreibbar per Env)

# ---- Farben / TTY / Dashboard-Erkennung ----
# Fallout-Amber-Theme: warmes Bernstein-Terminal (Vault-Tec-Vibe). Die Namen
# (PINK/CYAN/GREEN/…) bleiben, damit das restliche Skript automatisch recolored.
COLOR=0; TUI=0
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then COLOR=1; fi
if [ "$COLOR" = 1 ] && [ "$PLAIN" = 0 ]; then TUI=1; fi
if [ "$COLOR" = 1 ]; then
  R=$'\033[0m'
  PINK=$'\033[38;5;208m'    # Orange  — Struktur, Rahmen, Brand
  CYAN=$'\033[38;5;214m'    # Amber   — Header, Labels
  GREEN=$'\033[38;5;220m'   # Gold    — OK, Balken-Fill
  YELLOW=$'\033[38;5;172m'  # Dunkelamber — Warnung, Spinner
  PURPLE=$'\033[38;5;135m'  # Violett   — Summary-Header
  BLUE=$'\033[38;5;75m'     # Teal/Cyan — Offen-Marker
  DIM=$'\033[38;5;94m'      # Braun-Amber — Log, inaktiv, Rahmen-matt
  RED=$'\033[38;5;196m'     # Rot     — Fehler (bewusst Signalfarbe)
else R=''; PINK=''; CYAN=''; GREEN=''; YELLOW=''; PURPLE=''; BLUE=''; DIM=''; RED=''; fi
FR=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏); NF=${#FR[@]}; _fri=0; _first=1

# ---- Log + Ausgabe ----
logline() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" >> "$LOG"; }
step() { printf '\n%s\n' "${PINK}▓▒░${R} ${CYAN}$*${R}"; logline ">> $*"; }
ok()   { printf '%s\n' "  ${GREEN}✔${R} $*"; logline "OK $*"; }
warn() { printf '%s\n' "  ${YELLOW}▲ $*${R}"; logline "WARN $*"; }
die()  { printf '%s\n' "  ${RED}✖ $*${R}"; logline "DIE $*"; exit 1; }
# Ja/Nein-Frage von der echten TTY (auch wenn stdin sonst umgeleitet ist).
# Default NEIN. Gibt 0 nur bei ausdrücklichem y/j zurück.
ask_yn() { local q="${1:-?}" a=; printf '%s' "  ${CYAN}${q} [y/N] ${R}"
  read -r a </dev/tty 2>/dev/null || return 1; case "$a" in [yYjJ]*) return 0;; *) return 1;; esac; }

# ---- Traps ----
# cleanup läuft bei JEDEM Exit: Cursor sichtbar, Hintergrund-Helfer killen und das
# Scratch-Verzeichnis (mktemp -d) entfernen. Die Job-Logs sind da bereits in den
# bleibenden $HOME-Log kopiert; LOGD ist reines Wegwerf-Scratch -> kein Leak.
cleanup(){ printf '\033[?25h'; kill "${CAFF_PID:-}" "${SUDO_PID:-}" 2>/dev/null || true
  [ -n "${LOGD:-}" ] && [ -d "${LOGD:-}" ] && rm -rf "$LOGD" 2>/dev/null || true; }
# on_int fängt Strg-C / TERM ab: Parallel-Jobs (brew/git) mit-killen (die laufen
# sonst verwaist weiter), aufräumen und mit 130 SAUBER beenden. Die Job-PIDs nur
# HIER killen (nicht in cleanup/EXIT), da sie bei normalem Ende schon fertig sind
# und ihre PIDs dann fremd wiederverwendet sein könnten.
# \033[r hier (nicht in cleanup): Scroll-Region nur bei Abbruch mitten im Dashboard
# zurücksetzen; beim normalen Ende macht dashboard() das selbst — ein zweites \033[r
# in cleanup() hat Ghostty als visuellen Clear interpretiert.
on_int(){ trap - INT TERM
  kill "${P_INS:-}" "${P_OMZ:-}" "${P_REPOS:-}" "${P_MAC:-}" 2>/dev/null || true
  printf '\033[r'; cleanup; printf '\n%s\n' "${YELLOW:-}▲ Abgebrochen (Strg-C).${R:-}"; logline "INT/TERM — abgebrochen"; exit 130; }
trap cleanup EXIT
trap on_int INT TERM
trap 'ec=$?; if [ "$ec" -ne 0 ]; then printf "\n%s\n" "${RED:-}✖ Fehler (Exit $ec) Zeile ${LINENO}: ${BASH_COMMAND}${R:-}"; logline "ERR ${LINENO}: ${BASH_COMMAND}"; printf "%s\n" "  ${DIM:-}Log: ${LOG}${R:-}"; fi' ERR

# ---- Banner ----
banner() {
  local w=46 title len pl pr
  title="$(printf '%s' "$BRAND" | tr '[:lower:]' '[:upper:]')"   # bash-3.2-kompatibel (kein ${^^})
  len=${#title}; [ "$len" -gt "$w" ] && { title="$(printf '%s' "$title" | cut -c1-"$w")"; len=$w; }
  pl=$(( (w - len) / 2 )); pr=$(( w - len - pl ))
  printf '\n'
  printf '%s\n' "${PINK}   ▟████████████████████████████████████████████▙${R}"
  printf '%s%*s%s%*s%s\n' "${PINK}   █${CYAN}" "$pl" '' "$title" "$pr" '' "${PINK}█${R}"
  printf '%s\n' "${PINK}   ▜████████████████████████████████████████████▛${R}"
  printf '%s\n' "${DIM}   night-city dev-env · macOS $(sw_vers -productVersion 2>/dev/null || echo '?') · $(date '+%Y-%m-%d %H:%M')${R}"
}
banner

# ---- Preflight ----
step "Preflight"
[ "$(uname -s)" = "Darwin" ] || die "Läuft nur unter macOS."
ARCH="$(uname -m)"
printf '%s\n' "  ${DIM}macOS $(sw_vers -productVersion 2>/dev/null) · $ARCH · $(id -un) · Log $LOG${R}"
FREE_GB="$(df -g / 2>/dev/null | awk 'NR==2{print $4}')"
{ [ "${FREE_GB:-0}" -ge 15 ]; } 2>/dev/null || warn "Nur ${FREE_GB:-?}G frei — Casks brauchen Platz (>=15G empfohlen)."
curl -fsI --max-time 8 https://formulae.brew.sh >/dev/null 2>&1 || die "Kein Netz (formulae.brew.sh nicht erreichbar)."
for f in Brewfile repos.txt scripts/clone-repos.sh scripts/macos-defaults.sh; do
  [ -e "$REPO_DIR/$f" ] || die "Datei fehlt im Repo: $f"
done
ok "Preflight ok"

# ---- Brewfile parsen (Formeln + Casks) ----
BREWS=(); CASKS=()
while IFS= read -r line; do
  t="${line#"${line%%[![:space:]]*}"}"
  case "$t" in
    'brew "'*) n="${t#brew \"}"; n="${n%%\"*}"; BREWS+=("$n") ;;
    'cask "'*) n="${t#cask \"}"; n="${n%%\"*}"; CASKS+=("$n") ;;
  esac
done < "$REPO_DIR/Brewfile"
TOTAL=$(( ${#BREWS[@]} + ${#CASKS[@]} ))

# ---- Trockenlauf ----
if [ "$MODE" = "check" ]; then
  step "TROCKENLAUF — nichts wird verändert ($TOTAL Pakete im Brewfile)"
  if command -v brew >/dev/null 2>&1; then
    miss=0
    for f in "${BREWS[@]}"; do
      if brew list --formula --versions "$f" >/dev/null 2>&1; then printf '%s\n' "  ${GREEN}✔${R} ${DIM}$f${R}"
      else printf '%s\n' "  ${YELLOW}○${R} $f ${DIM}(würde installiert)${R}"; miss=$((miss+1)); fi
    done
    for f in "${CASKS[@]}"; do
      if brew list --cask --versions "$f" >/dev/null 2>&1; then printf '%s\n' "  ${GREEN}✔${R} ${DIM}$f${R}"
      else printf '%s\n' "  ${YELLOW}○${R} $f ${DIM}(cask, würde installiert)${R}"; miss=$((miss+1)); fi
    done
    printf '%s\n' "  ${CYAN}$miss fehlen, $((TOTAL-miss)) vorhanden${R}"
  else warn "Homebrew noch nicht da — Paket-Check erst nach Erstlauf."; fi
  step "Repos, die geklont würden"
  grep -vE '^[[:space:]]*(#|$)' "$REPO_DIR/repos.txt" | while read -r u; do
    nm="$(basename "$u" .git)"; { [ -d "$HOME/dev/$nm" ] && printf '%s\n' "  ${GREEN}✔${R} ${DIM}$nm${R}"; } || printf '%s\n' "  ${YELLOW}○${R} $nm"
  done
  step "Trockenlauf fertig — Log: $LOG"; exit 0
fi

# ---- Umgebung ----
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_ENV_HINTS=1
export GIT_TERMINAL_PROMPT=0
caffeinate -dimsu & CAFF_PID=$!

# ---- 1. Xcode CLT (Gate) ----
if ! xcode-select -p >/dev/null 2>&1; then
  step "Xcode Command Line Tools installieren…"
  xcode-select --install 2>/dev/null || true
  warn "CLT-Installation abschließen, dann ./setup.sh erneut ausführen."; exit 0
fi

# ---- 2. sudo cachen + still am Leben halten ----
step "Adminrechte einmalig (nur für App-/Cask-Installer)…"
sudo -v || warn "Ohne sudo scheitern evtl. einzelne Casks — Lauf geht trotzdem weiter."
( while kill -0 "$$" 2>/dev/null; do sudo -n -v 2>/dev/null || true; sleep 50; done ) & SUDO_PID=$!

# ---- 3. Homebrew (Gate) ----
if ! command -v brew >/dev/null 2>&1; then
  step "Homebrew installieren…"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if   [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew   ]; then eval "$(/usr/local/bin/brew shellenv)"
else die "brew nach Installation nicht gefunden."; fi
if [ "$ARCH" = "arm64" ] && ! /usr/bin/pgrep -q oahd; then
  step "Rosetta 2…"; softwareupdate --install-rosetta --agree-to-license >/dev/null 2>&1 || warn "Rosetta übersprungen."
fi

# ---- Funktionen: parallele Subsysteme ----
setup_omz() {
  export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
  [ -d "$ZSH" ] || RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  local C="${ZSH_CUSTOM:-$ZSH/custom}"
  [ -d "$C/themes/powerlevel10k" ]            || git clone -q --depth=1 https://github.com/romkatv/powerlevel10k            "$C/themes/powerlevel10k"
  [ -d "$C/plugins/zsh-autosuggestions" ]     || git clone -q --depth=1 https://github.com/zsh-users/zsh-autosuggestions     "$C/plugins/zsh-autosuggestions"
  [ -d "$C/plugins/zsh-syntax-highlighting" ] || git clone -q --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$C/plugins/zsh-syntax-highlighting"
}

# Kernstück: EINZELNE Paketinstallation mit Fehler-Isolation.
# Gibt EINE saubere Zeile pro Paket auf stdout aus (-> Live-Log-Stream). Der
# laute brew-Output landet separat in install.log. install.status treibt das
# Panel (aktuelles Paket), install.fail/.rc sind die Sentinels.
install_packages() {
  set +eu
  local d=0 f
  : > "$LOGD/install.fail"
  for f in "${BREWS[@]}"; do
    d=$((d+1)); printf '%s %s formula %s\n' "$d" "$TOTAL" "$f" > "$LOGD/install.status"
    if brew list --formula --versions "$f" >/dev/null 2>&1; then
      printf '  OK  [%s/%s] %s  (vorhanden)\n'   "$d" "$TOTAL" "$f"
    elif brew install --formula "$f" >>"$LOGD/install.log" 2>&1; then
      printf '  OK  [%s/%s] %s  (installiert)\n' "$d" "$TOTAL" "$f"
    else echo "$f (formula)" >> "$LOGD/install.fail"; printf '  X   [%s/%s] %s  FEHLGESCHLAGEN -> uebersprungen\n' "$d" "$TOTAL" "$f"; fi
  done
  for f in "${CASKS[@]}"; do
    d=$((d+1)); printf '%s %s cask %s\n' "$d" "$TOTAL" "$f" > "$LOGD/install.status"
    if brew list --cask --versions "$f" >/dev/null 2>&1; then
      printf '  OK  [%s/%s] %s  (vorhanden)\n'   "$d" "$TOTAL" "$f"
    elif brew install --cask "$f" >>"$LOGD/install.log" 2>&1; then
      printf '  OK  [%s/%s] %s  (installiert)\n' "$d" "$TOTAL" "$f"
    else echo "$f (cask)" >> "$LOGD/install.fail"; printf '  X   [%s/%s] %s  FEHLGESCHLAGEN -> uebersprungen\n' "$d" "$TOTAL" "$f"; fi
  done
  printf '%s %s done -\n' "$d" "$TOTAL" > "$LOGD/install.status"
  [ -s "$LOGD/install.fail" ] && return 1 || return 0
}

# ---- Dashboard (Fallout-Amber, scroll-region-stabil) --------------------------
# Architektur: EIN Zeichner (dieser Loop) ist der einzige TTY-Schreiber. Oben ein
# Scroll-Fenster mit dem Live-Log der Paketinstallation, unten ein FESTES Panel
# (Balken/Zähler/Fails + Job-Status). Kein "N Zeilen hoch"-Raten mehr: eine echte
# DECSTBM-Scroll-Region hält das Panel unten stabil, egal wie viel oben scrollt.
# Alle Farb-/Zustandsvariablen defensiv mit ${var:-} (Subshells unter set -u).
# ASCII-Balken (kein Multibyte!). Loop-gebaute Blockzeichen wurden unter macOS-
# bash-3.2 beim $(...)+read-Durchreichen zerlegt -> "??"/Replacement-Chars.
# '#'/'-' sind byte-sicher, rendern überall und passen zum Terminal-Look.
mkbar() { local d=${1:-0} t=${2:-1} w=12 f i s; [ "${t:-0}" -gt 0 ] 2>/dev/null || t=1; f=$(( d*w/t )); [ "$f" -gt "$w" ] && f=$w; [ "$f" -lt 0 ] && f=0
  s="${DIM:-}[${GREEN:-}"; i=0; while [ "$i" -lt "$f" ]; do s="$s#"; i=$((i+1)); done
  s="$s${DIM:-}"; while [ "$i" -lt "$w" ]; do s="$s-"; i=$((i+1)); done; printf '%s%s' "$s]" "${R:-}"; }
sym_pkg() { local rc
  if [ -f "$LOGD/install.rc" ]; then rc=$(cat "$LOGD/install.rc" 2>/dev/null||echo 0)
    [ "${rc:-0}" = 0 ] && printf '%s' "${GREEN:-}✔${R:-}" || printf '%s' "${YELLOW:-}▲${R:-}"
  else printf '%s' "${CYAN:-}${FR[${_fri:-0}]:-}${R:-}"; fi; }
sym_job() { local n="${1:-}" rc
  if [ -f "$LOGD/$n.rc" ]; then rc=$(cat "$LOGD/$n.rc" 2>/dev/null||echo 1)
    [ "${rc:-1}" = 0 ] && printf '%s' "${GREEN:-}✔${R:-}" || printf '%s' "${YELLOW:-}▲${R:-}"
  else printf '%s' "${CYAN:-}${FR[${_fri:-0}]:-}${R:-}"; fi; }
panel_job() { local label="${1:-}" name="${2:-}" s line
  s="$(sym_job "$name")"
  line="$(tail -n1 "$LOGD/$name.log" 2>/dev/null | tr -d '\r' | tr -dc '[:print:]' | cut -c1-28)"
  printf '%s\n' "${DIM:-}║${R:-} $s ${CYAN:-}${label}${R:-}  ${DIM:-}${line:-}${R:-}"; }
# Baut die 6 Panel-Zeilen als reine Strings (KEINE Cursorbewegung hier).
panel_lines() {
  local d=0 t=${TOTAL:-1} kind cur="…" fails=0 bar
  [ -r "$LOGD/install.status" ] && { read -r d t kind cur < "$LOGD/install.status" 2>/dev/null || true; }
  [ -s "$LOGD/install.fail" ] && fails=$(wc -l < "$LOGD/install.fail" 2>/dev/null | tr -d ' ')
  bar="$(mkbar "${d:-0}" "${t:-${TOTAL:-1}}")"; cur="$(printf '%s' "${cur:-}" | cut -c1-18)"
  printf '%s\n' "${DIM:-}╔══ ${CYAN:-}CYBERDECK SUBSYSTEMS${DIM:-} ══════════════════════════╗${R:-}"
  printf '%s\n' "${DIM:-}║${R:-} $(sym_pkg) ${CYAN:-}PACKAGES${R:-} ${bar:-} ${GREEN:-}${d:-0}/${t:-0}${R:-} ${DIM:-}${cur:-}${R:-}$([ "${fails:-0}" -gt 0 ] && printf ' %s' "${RED:-}✖${fails}${R:-}")"
  panel_job "SHELL " omz
  panel_job "CLONES" repos
  panel_job "SYSTEM" macos
  printf '%s\n' "${DIM:-}╚═════════════════════════════════════════════════╝${R:-}"
}
# Kippt neue Stream-Zeilen ins Log-Fenster (auf Breite gekürzt -> kein Umbruch).
# Nutzt/aktualisiert das globale _seen; druckt direkt auf die TTY.
_flush_stream() {
  local cols="${1:-80}" total
  total=$(wc -l < "$LOGD/stream" 2>/dev/null | tr -d ' '); total=${total:-0}
  if [ "$total" -gt "${_seen:-0}" ]; then
    sed -n "$(( ${_seen:-0} + 1 )),${total}p" "$LOGD/stream" 2>/dev/null \
      | while IFS= read -r ln; do printf '%s%s%s\n' "${DIM:-}" "$(printf '%s' "$ln" | cut -c1-$(( cols - 1 )))" "${R:-}"; done
    _seen=$total
  fi
}
_all_done() { [ -f "$LOGD/install.rc" ] && [ -f "$LOGD/omz.rc" ] && [ -f "$LOGD/repos.rc" ] && [ -f "$LOGD/macos.rc" ]; }
# Fallback ohne Cursor-Tricks (kleines/unbekanntes Terminal): einfach streamen.
dashboard_plain() {
  local i=0 max=${DASH_MAX_ITERS:-60000} t0=$SECONDS to=${DASH_TIMEOUT:-5400}; _seen=0
  while :; do
    _flush_stream 200
    if _all_done; then _flush_stream 200; break; fi
    i=$((i+1)); { [ "$i" -ge "$max" ] || [ $(( SECONDS - t0 )) -ge "$to" ]; } && break
    sleep 0.2
  done
}
dashboard() {
  local rows cols; rows=$(tput lines 2>/dev/null || echo 0); cols=$(tput cols 2>/dev/null || echo 0)
  # Fähigkeits-Check: zu klein / kein tput -> robuster Streaming-Fallback.
  if [ "${rows:-0}" -lt 12 ] || [ "${cols:-0}" -lt 64 ]; then dashboard_plain; return; fi
  local PH=6 top logbot i=0 max=${DASH_MAX_ITERS:-60000} t0=$SECONDS to=${DASH_TIMEOUT:-5400} nf=${NF:-1} k=0
  [ "$nf" -gt 0 ] 2>/dev/null || nf=1
  logbot=$(( rows - PH )); top=$(( rows - PH + 1 )); _seen=0
  printf '\033[?25l'                                   # Cursor aus
  while [ "$k" -lt "$PH" ]; do printf '\n'; k=$((k+1)); done   # Platz fürs Panel reservieren
  printf '\033[1;%dr' "$logbot"                        # Scroll-Region = 1..logbot
  printf '\033[%d;1H' "$logbot"                        # Cursor an Log-Unterkante
  while :; do
    _flush_stream "$cols"                              # 1) neue Log-Zeilen (scrollen oben)
    printf '\0337'; _draw_panel "$top"; printf '\0338' # 2) Panel unten (Cursor sichern/zurück)
    if _all_done; then
      _flush_stream "$cols"; printf '\0337'; _draw_panel "$top"; printf '\0338'; break
    fi
    i=$((i+1))
    { [ "$i" -ge "$max" ] || [ $(( SECONDS - t0 )) -ge "$to" ]; } && break
    _fri=$(( ( ${_fri:-0} + 1 ) % nf )); sleep 0.12
  done
  # Panel-Zeilen löschen bevor Scroll-Region zurückgesetzt wird — sonst bleibt
  # ein "Geist-Panel" das über nachfolgendem Output liegt und ihn optisch löscht.
  local j=0
  while [ "$j" -lt "$PH" ]; do
    printf '\033[%d;1H\033[2K' "$(( top + j ))"
    j=$(( j + 1 ))
  done
  printf '\033[r'                                      # Scroll-Region zurücksetzen
  printf '\033[%d;1H\033[?25h' "$logbot"               # Cursor ans Log-Ende, sichtbar
}
# Zeichnet die 6 Panel-Zeilen ABSOLUT positioniert (kein \n -> kein Fremd-Scroll).
_draw_panel() {
  local top="${1:-1}" j=0 pl
  panel_lines | while IFS= read -r pl; do
    printf '\033[%d;1H\033[2K%s' "$(( top + j ))" "$pl"; j=$((j+1))
  done
}

# ---- 4. PARALLEL-PHASE (Fehler hier sind nie fatal) ----
# WICHTIG: set +eu (NICHT nur +e). Die UI-/Draw-Funktionen laufen in Subshells;
# unter set -u würde eine ungebundene Variable dort die Subshell killen und den
# Dashboard-Loop endlos Fehler spammen lassen. Die gesamte Phase ist best-effort.
step "Subsysteme starten — Pakete einzeln, Rest parallel"
# gh credential helper vorab einhängen (falls gh schon installiert, z.B. Re-Run):
# GIT_TERMINAL_PROMPT=0 weiter unten verhindert interaktive Auth; ohne setup-git
# können auch bereits authentifizierte gh-Sessions nicht an git weitergegeben werden.
command -v gh >/dev/null 2>&1 && gh auth setup-git >/dev/null 2>&1 || true
set +eu
rm -f "$LOGD"/*.rc "$LOGD/install.status"; : > "$LOGD/install.log"; : > "$LOGD/stream"
# Job-Bodies zusätzlich in `set +eu` kapseln (Defense-in-depth): so wird die
# .rc-Sentinel-Datei IMMER geschrieben — auch wenn eine Funktion unter set -e/-u
# vorzeitig stürbe. Ohne die .rc bliebe der dashboard()-Loop hängen.
( set +eu; setup_omz                                  >"$LOGD/omz.log"   2>&1; echo $? >"$LOGD/omz.rc"   ) & P_OMZ=$!
( set +eu; bash "$REPO_DIR/scripts/clone-repos.sh"    >"$LOGD/repos.log" 2>&1; echo $? >"$LOGD/repos.rc" ) & P_REPOS=$!
( set +eu; bash "$REPO_DIR/scripts/macos-defaults.sh" >"$LOGD/macos.log" 2>&1; echo $? >"$LOGD/macos.rc" ) & P_MAC=$!
if [ "$TUI" = 1 ]; then
  # Fortschrittszeilen -> stream (Live-Log); brew-Rauschen bleibt in install.log.
  # echo $? im äußeren Subshell: Sentinel auch dann geschrieben, wenn install_packages
  # vor dem internen return abstürzt (z.B. durch OOM-Kill vor Schleifenende).
  ( set +eu; install_packages >"$LOGD/stream" 2>&1; echo $? >"$LOGD/install.rc" ) & P_INS=$!
  dashboard
  wait "$P_OMZ" "$P_REPOS" "$P_MAC" "$P_INS" 2>/dev/null
else
  install_packages
  wait "$P_OMZ" "$P_REPOS" "$P_MAC" 2>/dev/null
fi
set -eu

# ---- 5. Parallel-Phase: Status sammeln ----
step "Ergebnis"
if [ -s "$LOGD/install.fail" ]; then
  _NF=$(wc -l < "$LOGD/install.fail" | tr -d ' ')
  warn "${_NF} Paket(e) übersprungen — der Rest wurde installiert:"
  while IFS= read -r x; do printf '%s\n' "      ${DIM}· $x${R}"; done < "$LOGD/install.fail"
  { echo "== UEBERSPRUNGENE PAKETE =="; cat "$LOGD/install.fail"; } >> "$LOG"
  _SPKG_V="▲ Pakete $(( TOTAL - _NF ))/${TOTAL}  (${_NF} übersprungen)"
  _SPKG_C="${YELLOW}▲ Pakete $(( TOTAL - _NF ))/${TOTAL}${R}  ${DIM}(${_NF} übersprungen)${R}"
else
  ok "Alle $TOTAL Pakete installiert"
  _SPKG_V="✔ Pakete ${TOTAL}/${TOTAL}"; _SPKG_C="${GREEN}✔ Pakete ${TOTAL}/${TOTAL}${R}"
fi

RC=$(cat "$LOGD/omz.rc"   2>/dev/null||echo 1)
if [ "$RC" = 0 ]; then ok "Shell (oh-my-zsh)";
  _SOMZ_V="✔ Shell (oh-my-zsh)";          _SOMZ_C="${GREEN}✔${R} Shell  ${DIM}(oh-my-zsh)${R}"
else warn "oh-my-zsh — Fehler (Log: $LOGD/omz.log)";
  _SOMZ_V="▲ Shell (oh-my-zsh — Fehler)"; _SOMZ_C="${YELLOW}▲${R} Shell  ${DIM}(oh-my-zsh — Fehler)${R}"; fi

RC=$(cat "$LOGD/repos.rc" 2>/dev/null||echo 1)
_RFAIL=$(grep -c "^  FAIL  " "$LOGD/repos.log" 2>/dev/null | tr -d ' ' || echo 0)
if [ "$RC" = 0 ] && [ "${_RFAIL:-0}" = 0 ]; then ok "Repo-Klone (~/dev)";
  _SREP_V="✔ Repos (~/dev)";              _SREP_C="${GREEN}✔${R} Repos  ${DIM}(~/dev geklont)${R}"
else warn "Repo-Klone — ${_RFAIL:-?} Fehler (privat? gh auth login, dann ./scripts/clone-repos.sh)";
  _SREP_V="▲ Repos (${_RFAIL:-?} Fehler)"; _SREP_C="${YELLOW}▲${R} Repos  ${DIM}(${_RFAIL:-?} Fehler → gh auth login)${R}"; fi

RC=$(cat "$LOGD/macos.rc" 2>/dev/null||echo 1)
if [ "$RC" = 0 ]; then ok "macOS-Defaults";
  _SMAC_V="✔ macOS-Defaults";             _SMAC_C="${GREEN}✔${R} macOS-Defaults"
else warn "macOS-Defaults — Fehler (Log: $LOGD/macos.log)";
  _SMAC_V="▲ macOS-Defaults — Fehler";    _SMAC_C="${YELLOW}▲${R} macOS-Defaults  ${DIM}(Fehler)${R}"; fi

# ---- 6. Dotfiles (chezmoi) ----
step "Dotfiles anwenden (chezmoi)…"
if chezmoi init --apply --source "$REPO_DIR" >>"$LOG" 2>&1; then
  ok "Dotfiles (chezmoi)"
  _SCHE_V="✔ Dotfiles (chezmoi)";         _SCHE_C="${GREEN}✔${R} Dotfiles  ${DIM}(chezmoi)${R}"
else warn "chezmoi — Fehler (Ausgabe im Log).";
  _SCHE_V="▲ Dotfiles (chezmoi — Fehler)"; _SCHE_C="${YELLOW}▲${R} Dotfiles  ${DIM}(chezmoi — Fehler)${R}"; fi

# ---- 6b. Runtimes (mise install) ----
# mise.toml ist jetzt durch chezmoi vorhanden; mise install lädt node/python/ruby.
# Ohne diesen Schritt schlägt `mise exec -- npm install …` (Step 7) fehl.
step "Runtimes installieren (mise install)…"
_SMIS_V="▲ Runtimes (mise nicht gefunden)"; _SMIS_C="${YELLOW}▲${R} Runtimes  ${DIM}(mise install manuell)${R}"
if command -v mise >/dev/null 2>&1; then
  if mise install >>"$LOG" 2>&1; then
    ok "Runtimes (node · python · ruby)"
    _SMIS_V="✔ Runtimes (mise)"; _SMIS_C="${GREEN}✔${R} Runtimes  ${DIM}(node · python · ruby)${R}"
  else warn "mise install — Fehler (Log: $LOG)"
    _SMIS_V="▲ Runtimes (mise — Fehler)"; _SMIS_C="${YELLOW}▲${R} Runtimes  ${DIM}(mise install manuell)${R}"; fi
else warn "mise nicht gefunden — brew install mise, dann mise install"; fi

# ---- 7. Claude Code ----
step "Claude Code (npm via mise)…"
if mise exec -- npm install -g @anthropic-ai/claude-code >>"$LOG" 2>&1; then
  ok "Claude Code"
  _SCLA_V="✔ Claude Code";                _SCLA_C="${GREEN}✔${R} Claude Code"
else warn "Claude Code separat installieren: docs.claude.com/claude-code";
  _SCLA_V="▲ Claude Code — manuell";      _SCLA_C="${YELLOW}▲${R} Claude Code  ${DIM}(manuell nachinstallieren)${R}"; fi

# ---- 8. Interaktive Anmeldungen ----
# Überspringen komplett: SETUP_NO_LOGIN=1 ./setup.sh
_SGH_V="· GitHub (übersprungen)"; _SGH_C="${DIM}· GitHub (übersprungen)${R}"; _OPEN_GH=1
_STS_V="· Tailscale (übersprungen)"; _STS_C="${DIM}· Tailscale (übersprungen)${R}"; _OPEN_TS=1

if [ -t 0 ] && [ -t 1 ] && [ "${SETUP_NO_LOGIN:-0}" != 1 ]; then
  step "Anmeldungen (optional — jetzt erledigen erspart die Nachher-Checkliste)"
  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
      ok "GitHub bereits angemeldet"
      _SGH_V="✔ GitHub (angemeldet)"; _SGH_C="${GREEN}✔${R} GitHub  ${DIM}(bereits angemeldet)${R}"; _OPEN_GH=0
      gh auth setup-git >/dev/null 2>&1 || true
      if [ "${_RFAIL:-0}" -gt 0 ]; then
        step "Private Repos klonen (mit Auth, ${_RFAIL} vorher fehlgeschlagen)…"
        if bash "$REPO_DIR/scripts/clone-repos.sh" 2>&1 | tee -a "$LOG"; then
          _RFAIL=0
          _SREP_V="✔ Repos (~/dev)"; _SREP_C="${GREEN}✔${R} Repos  ${DIM}(~/dev geklont)${R}"
        else warn "Repo-Klone teils fehlgeschlagen."; fi
      fi
    elif ask_yn "Jetzt bei GitHub anmelden (gh auth login)?"; then
      if gh auth login; then
        _SGH_V="✔ GitHub (angemeldet)"; _SGH_C="${GREEN}✔${R} GitHub  ${DIM}(angemeldet)${R}"; _OPEN_GH=0
        gh auth setup-git >/dev/null 2>&1 || true
        step "Private Repos klonen (mit Auth)…"
        if bash "$REPO_DIR/scripts/clone-repos.sh" 2>&1 | tee -a "$LOG"; then
          _RFAIL=0
          _SREP_V="✔ Repos (~/dev)"; _SREP_C="${GREEN}✔${R} Repos  ${DIM}(~/dev geklont)${R}"
        else warn "Repo-Klone teils fehlgeschlagen."; fi
      else warn "gh-Login fehlgeschlagen."; fi
    fi
  fi
  if command -v tailscale >/dev/null 2>&1; then
    if ask_yn "Tailscale jetzt verbinden (sudo tailscale up)?"; then
      if sudo tailscale up; then
        _STS_V="✔ Tailscale (verbunden)"; _STS_C="${GREEN}✔${R} Tailscale  ${DIM}(verbunden)${R}"; _OPEN_TS=0
      else warn "tailscale up fehlgeschlagen."
        _STS_V="▲ Tailscale (Fehler)"; _STS_C="${YELLOW}▲${R} Tailscale  ${DIM}(tailscale up fehlgeschlagen)${R}"; fi
    fi
  else _OPEN_TS=0; _STS_V="· Tailscale (n/a)"; _STS_C="${DIM}· Tailscale (nicht installiert)${R}"; fi
  if command -v pass >/dev/null 2>&1 && [ -d "${PASSWORD_STORE_DIR:-$HOME/.password-store}" ]; then
    if pass ls motion/api-key >/dev/null 2>&1; then ok "Motion-API-Key bereits in pass"
    elif ask_yn "Motion-API-Key jetzt in pass hinterlegen (für \`morgen\`)?"; then
      pass insert motion/api-key || warn "Motion-Key nicht gesetzt — später: pass insert motion/api-key"
    fi
  fi
fi

# ---- Abschluss: Job-Logs archivieren ----
{ echo "== JOB-LOGS =="; for l in "$LOGD"/*.log; do echo "--- $l ---"; cat "$l" 2>/dev/null; done; } >> "$LOG" 2>/dev/null || true
S=$(( $(date +%s) - START ))

# ---- Summary-Box (79 Zeichen breit) ----
# _bl "sichtbarer Text" "gefärbter Text"
# Breite: ║(1) + ··(2) + Inhalt(73) + ··(2) + ║(1) = 79
_bl() {
  local vis="$1" col="${2:-$1}" pad
  pad=$(( 73 - ${#vis} )); [ "$pad" -lt 0 ] && pad=0
  printf '%s  %s%*s  %s\n' "${DIM}║${R}" "$col" "$pad" "" "${DIM}║${R}"
}
_bsep() { printf '%s\n' "${DIM}╠═══════════════════════════════════════════════════════════════════════════╣${R}"; }
_bemp() { _bl ""; }

# Titelzeile (Breite ohne ANSI exakt berechnen)
_TTXT="  S Y S T E M   O N L I N E  ·  ${BRAND}  ·  ${S}s"
# +2: printf format hat nach %*s noch 2 Leerzeichen vor ║, die nicht in _TTXT stehen.
_TPAD=$(( 75 - ${#_TTXT} )); [ "$_TPAD" -lt 0 ] && _TPAD=0

printf '\n'
printf '%s\n' "${PINK}╔═══════════════════════════════════════════════════════════════════════════╗${R}"
printf '%s  %s  ·  %s  ·  %s%*s  %s\n' \
  "${PINK}║${R}" \
  "${CYAN}S Y S T E M   O N L I N E${R}" \
  "${GREEN}${BRAND}${R}" \
  "${YELLOW}${S}s${R}" \
  "$_TPAD" "" \
  "${PINK}║${R}"
_bsep
_bemp
_bl "  E R L E D I G T" "  ${PURPLE}E R L E D I G T${R}"
_bemp
_bl "  ${_SPKG_V}" "  ${_SPKG_C}"
_bl "  ${_SOMZ_V}" "  ${_SOMZ_C}"
_bl "  ${_SREP_V}" "  ${_SREP_C}"
_bl "  ${_SMAC_V}" "  ${_SMAC_C}"
_bl "  ${_SCHE_V}" "  ${_SCHE_C}"
_bl "  ${_SMIS_V}" "  ${_SMIS_C}"
_bl "  ${_SCLA_V}" "  ${_SCLA_C}"
_bl "  ${_SGH_V}"  "  ${_SGH_C}"
_bl "  ${_STS_V}"  "  ${_STS_C}"
_bemp
_bsep
_bemp
_bl "  N O C H   O F F E N" "  ${BLUE}N O C H   O F F E N${R}"
_bemp
_bl "  ▸  Apple-ID · iCloud · Citrix-Store · claude Abo-Login" \
    "  ${BLUE}▸${R}  Apple-ID ${DIM}·${R} iCloud ${DIM}·${R} Citrix-Store ${DIM}·${R} claude Abo-Login"
_bl "  ▸  GPG-Key importieren  →  pass init  →  pass insert motion/api-key" \
    "  ${BLUE}▸${R}  GPG-Key importieren  ${DIM}→${R}  pass init  ${DIM}→${R}  pass insert motion/api-key"
_bl "  ▸  morgen (Terminal-Briefing) liegt in ~/.local/bin — braucht nur den Key" \
    "  ${BLUE}▸${R}  ${CYAN}morgen${R} ${DIM}(Briefing in ~/.local/bin — braucht nur den Motion-Key)${R}"
[ "$_OPEN_GH" = 1 ] && \
  _bl "  ▸  gh auth login" "  ${BLUE}▸${R}  ${CYAN}gh auth login${R}"
[ "$_OPEN_TS" = 1 ] && \
  _bl "  ▸  sudo tailscale up" "  ${BLUE}▸${R}  ${CYAN}sudo tailscale up${R}"
_bl "  ▸  FileVault aktivieren  (Systemeinstellungen)" \
    "  ${BLUE}▸${R}  FileVault aktivieren  ${DIM}(Systemeinstellungen)${R}"
_bl "  ▸  Chrome-Extensions:  ./scripts/chrome-extensions.sh" \
    "  ${BLUE}▸${R}  Chrome-Extensions:  ${DIM}./scripts/chrome-extensions.sh${R}"
_bl "  ▸  nvim :checkhealth  (Plugins vorgebaut)  ·  p10k vorkonfiguriert" \
    "  ${BLUE}▸${R}  nvim :checkhealth  ${DIM}(Plugins vorgebaut)${R}  ${DIM}·${R}  p10k vorkonfiguriert"
_bemp
printf '%s\n' "${PINK}╚═══════════════════════════════════════════════════════════════════════════╝${R}"
printf '  %s %s\n' "${DIM}Log:${R}" "$LOG"
[ -s "$LOGD/install.fail" ] && printf '  %s\n' "${YELLOW}Übersprungene Pakete nachinstallieren: brew install <name>${R}"

# dotfiles

Meine macOS-Umgebung: terminal-nativ, `nvim` + `tmux` + Claude Code, verwaltet
mit [chezmoi](https://chezmoi.io). Ein Skript setzt einen frischen Mac komplett auf.

## Frischer Mac — in drei Zeilen

```sh
xcode-select --install                                   # falls noch nicht da
git clone https://github.com/ur-grue/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./setup.sh
```

`setup.sh` installiert Homebrew + alle Pakete (Brewfile), oh-my-zsh + p10k,
wendet alle Configs via chezmoi an (inkl. Secrets aus `pass`, mise-Runtimes,
tmux-Plugins), setzt macOS-Defaults und klont die aktiven Repos nach `~/dev`.
Danach: **manuelle Restschritte** in [`docs/cheatsheet.md`](docs/cheatsheet.md) → „Nach dem Setup".

## Bestehendes System (iMac) — ein System auf allen Macs

`setup.sh` ist für einen **frischen** Mac gebaut. Auf einem schon genutzten Mac
(iMac im Alltag) stattdessen mit `--existing` laufen — **nicht-destruktiv**:

```sh
cd ~/dotfiles && ./setup.sh --existing        # oder --production / --merge
```

- **Backup vor jedem Überschreiben** — jede bereits vorhandene, von chezmoi
  verwaltete Datei landet vorher in `~/.dotfiles-backup-<zeit>/`.
- **Diff + Nachfrage** — `chezmoi diff` zeigt alles Geplante; erst nach `[y/N]`
  wird angewendet.
- **`~/.gitconfig` bleibt** — Identität, `signingkey`, Arbeits-`includeIf`,
  credential.helper unangetastet. Die geteilten git-Aliase/-Tools kommen via
  `~/.config/git/config` dazu (Git liest beide Dateien; lokale `~/.gitconfig`-Keys
  haben Vorrang — schon gesetzte Keys aus `~/.gitconfig` entfernen, wenn sie mit
  der geteilten Config konvergieren sollen).
- **Bleibt lokal**: globale mise-Runtime-Pins, jrnl-Journal-Index, newsboat-Feeds.
- **macOS-Defaults & Caps Lock**: werden NICHT angefasst. Bei Bedarf später
  `./scripts/macos-defaults.sh` (schreibt vorher ein Restore-Skript).
- **Casks über bereits vorhandenen Apps: skip** — kein Reinstall über ein schon
  vorhandenes Citrix/Teams/Tailscale (schützt IT-Installationen).

Rückgängig machen: `./scripts/restore-backup.sh` (nimmt das neueste Backup).

## Was drin ist

| Bereich      | Tools |
|--------------|-------|
| Terminal     | Ghostty (Rosé Pine, Hell/Dunkel folgt macOS) |
| Multiplexer  | tmux (+ resurrect/continuum, vim-tmux-navigator) |
| Editor       | Neovim (lazy.nvim, Rosé Pine, Claude Code integriert) |
| KI-Coding    | Claude Code CLI (`claude`) + `claudecode.nvim` · gstack-Skills · globale `~/.claude/CLAUDE.md` |
| Shell        | zsh + oh-my-zsh + Powerlevel10k |
| CLI          | eza, bat, ripgrep, fd, zoxide, fzf, atuin, delta, lazygit, yazi … |
| Runtimes     | mise (node, python, ruby) |
| Notizen      | zk (Zettelkasten), jrnl |
| Lesen        | newsboat (rose-pine, nach Topic gruppiert), w3m |
| Medien       | Spotify (`spotify_player`), YouTube (`yt`/yewtube), Web-Radio (`pyradio`), mpv |

## Täglicher chezmoi-Workflow (einfach)

```sh
chezmoi edit ~/.zshrc      # Datei über die Repo-Quelle bearbeiten
chezmoi apply              # Änderungen ins $HOME übernehmen
chezmoi cd                 # in die Repo-Quelle wechseln -> git add/commit/push
```

Kurzform: `chezmoi edit` → `chezmoi apply` → committen. Fertig.

## Secrets

Kommen **nie** ins Repo. `~/.config/zsh/secrets.zsh` ist gitignored; nur
`secrets.zsh.example` ist getrackt. Keys optional aus `pass` ziehen.
Für Claude Code brauchst du **keinen** API-Key (Abo-Login).

## Struktur

```
setup.sh            Orchestrator (frischer Mac  ·  --existing für bestehende)
Brewfile            alle Pakete
repos.txt           aktive Repos -> ~/dev
scripts/            clone-repos · macos-defaults · restore-backup · pre-wipe-backup
docs/               Cheat Sheet, Claude-Code-Workflow, Theming
home/               chezmoi-Quelle (.chezmoiroot zeigt hierher)
  dot_*             -> ~/.*
  dot_config/*      -> ~/.config/*
  dot_config/git/config   geteilte git-Config (Identität bleibt in ~/.gitconfig)
```

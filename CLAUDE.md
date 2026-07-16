# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A macOS dotfiles repo managed with [chezmoi](https://chezmoi.io). One script
(`setup.sh`) turns a fresh Mac into a full terminal-native dev environment
(nvim + tmux + Claude Code, zsh/oh-my-zsh/p10k, a modern CLI stack, mise
runtimes). Comments and user-facing output are in **German** — keep new
contributions consistent with that.

## The one thing that will trip you up: `.chezmoiroot`

`.chezmoiroot` contains `home`, so **the chezmoi source tree is `home/`, not the
repo root.** Consequences:

- `chezmoi edit ~/.zshrc` opens `home/dot_zshrc`. Editing `~/.zshrc` in `$HOME`
  directly is wrong — `chezmoi apply` overwrites it from the source.
- To change any deployed config, edit the file under `home/`, then run
  `chezmoi apply`.

chezmoi encodes target state in **filename prefixes/suffixes** (there is no
separate manifest):

| Source name                     | Target / meaning                                  |
|---------------------------------|---------------------------------------------------|
| `dot_zshrc`                     | `~/.zshrc`                                         |
| `dot_config/mise/config.toml`   | `~/.config/mise/config.toml`                       |
| `*.tmpl`                        | Go-templated (e.g. `dot_gitconfig.tmpl`)          |
| `executable_morgen`            | deployed with the executable bit set              |
| `run_once_after_NN-*.sh`        | hook run once after `apply`, in numeric order     |

## Commands

There is no test suite and no compiled build. The workflow is chezmoi + shell.

```sh
# Daily loop: edit source, preview, apply
chezmoi edit ~/.zshrc          # edit the source under home/
chezmoi diff                   # preview what apply would change
chezmoi apply                  # write changes into $HOME
chezmoi cd                     # cd into the source repo to git add/commit/push

# Debug templates / target state
chezmoi cat ~/.gitconfig       # render a template to stdout
chezmoi execute-template < home/.chezmoi.toml.tmpl
chezmoi verify                 # exit non-zero if $HOME differs from source

# Force a run_once_* hook to run again (they are gated by content hash)
chezmoi state delete-bucket --bucket=scriptState

# Fresh-Mac bootstrap (the big orchestrator)
./setup.sh                     # full run (TTY dashboard)
./setup.sh --check             # dry run: shows what's missing, changes nothing
./setup.sh --existing          # EXISTING machine (non-destructive; see below)
./setup.sh --plain             # no animations (pipes/CI)
./setup.sh --no-input          # no interactive prompts (CI/automated)

# Restore dotfiles from an --existing backup (~/.dotfiles-backup-<ts>/)
./scripts/restore-backup.sh              # newest backup, interactive
./scripts/restore-backup.sh --list       # show what would be restored

# Lint (the only "CI" here): all scripts are #!/usr/bin/env bash
shellcheck setup.sh scripts/*.sh home/run_once_after_*.sh home/dot_local/bin/executable_morgen
```

Note: `shellcheck` cannot lint the zsh files (`home/dot_zshrc`, `dot_z*`,
`dot_p10k.zsh`) — it hard-errors on zsh. Use `zsh -n <file>` for a syntax check.

## Architecture

**`setup.sh` (~620 lines) is the orchestrator** and the most complex file. Read
it before touching bootstrap behavior. Structure and constraints that aren't
obvious from any single line:

- **bash 3.2 compatible** — macOS ships bash 3.2 as `/bin/bash`. No `${var^^}`,
  guard empty-array expansion under `set -u` with `${arr[@]+"${arr[@]}"}`.
- **Per-package isolation**: `install_packages` installs each Brewfile entry
  individually; a failure is logged and skipped so the rest continues. Skipped
  packages are reported at the end.
- **Parallel phase**: oh-my-zsh setup, repo cloning, and macOS defaults run as
  background jobs while packages install; a live TTY dashboard (DECSTBM
  scroll-region, `.rc` sentinel files per job) renders progress. Runs under
  `set +eu` because the draw functions execute in subshells.
- **Security ordering**: git identity is prompted in step 1b **before the first
  `sudo`**, with the stdin buffer flushed, so terminal type-ahead around the
  password prompt cannot leak a password into `~/.gitconfig`.
- **chezmoi invocation** (step 6) passes `--promptString name=/email=` collected
  earlier and `--promptDefaults`, and self-heals a stale chezmoi state-lock left
  by an interrupted prior run.

**Two install modes.** The default path assumes a fresh Mac. `--existing`
(aliases `--production`, `--merge`) makes the run non-destructive for a machine
already in daily use, and is the intended way to converge a second Mac onto this
config. It sets `EXISTING=1` and exports `DOTFILES_EXISTING=1`; the differences:

- **Backup + diff + confirm**: instead of a blind `chezmoi init --apply`, it runs
  `chezmoi init` (no apply), copies every existing managed target into
  `~/.dotfiles-backup-<ts>/`, shows `chezmoi diff`, and asks before `chezmoi apply`
  (`_cz_existing` in setup.sh). `restore-backup.sh` rolls it back.
- **Preserved-not-clobbered**: `--existing` persists `existing = true` into
  `~/.config/chezmoi/chezmoi.toml` (via `home/.chezmoi.toml.tmpl`, seeded from
  `DOTFILES_EXISTING` at `chezmoi init`). The **templated** `home/.chezmoiignore`
  then keys off `.existing` (the persisted data var, **not** the transient env), so
  it excludes `.gitconfig`, `.config/mise/config.toml`, `.config/jrnl/jrnl.yaml`,
  `.config/newsboat/urls` on **every** future `chezmoi apply`, not just the setup run.
  This is the fix for the obvious bug: keying protection on a one-shot env var would
  let the next routine `chezmoi apply` re-clobber those files.
- **Git layering** (why `.gitconfig` can be excluded): shared git settings live in
  `home/dot_config/git/config` → `~/.config/git/config`, which Git reads *in addition
  to* `~/.gitconfig` (the latter wins conflicts). `dot_gitconfig.tmpl` is now
  identity-only. So the machine keeps its own identity/signing/`includeIf` while the
  aliases/delta/pull settings converge on every Mac. This applies to fresh Macs too.
- **Cask guard**: `cask_app_present()` skips a cask if its app is already on disk
  (even IT-installed) — pkg-casks like `citrix-workspace`/`microsoft-teams`/
  `tailscale-app` would otherwise `sudo installer` straight over a running work app.
- **Also**: macOS defaults skipped (opt in via `./scripts/macos-defaults.sh`, which
  now snapshots prior values + writes a restore script); nvim hook uses `Lazy! install`
  not `sync` (`DOTFILES_EXISTING`); `tailscale up` skipped if the node is already up.

**`run_once_after_*.sh` hooks** run during `chezmoi apply` (which `setup.sh`
triggers), in numeric order, each best-effort (failures never abort setup):

1. `10-mise` — install language runtimes (node/python/ruby)
2. `20-tmux-plugins` — clone tpm, install tmux plugins
3. `30-ani-cli` — install ani-cli (no Homebrew formula; git-clone into brew bin)
4. `40-nvim-plugins` — headless `Lazy! sync` + synchronous treesitter parser build
5. `50-extras` — `zk init` notebook, `pyradio` via pipx
6. `60-claude-plugins` — clone + set up gstack Claude-Code skills (needs `claude` + `bun`)

**Shell config layering** (source order matters):

- `dot_zshenv` — every zsh invocation. XDG base dirs, `EDITOR=nvim`, and sources
  local secrets. Keep it lean.
- `dot_zprofile` — login shells. Detects Homebrew prefix (Apple Silicon vs Intel)
  and prepends `~/.local/bin` to PATH.
- `dot_zshrc` — interactive shells. oh-my-zsh + Powerlevel10k, lazy tool init
  (mise/zoxide/atuin/fzf), classic→modern aliases (eza/bat/lazygit).

**Package + repo manifests**: `Brewfile` (46 formulae, 11 casks; `brew bundle`
format, categorized by comment sections). `repos.txt` (one URL per line) →
cloned in parallel to `~/dev` by `scripts/clone-repos.sh` (private repos need
`gh auth login` first; idempotent, re-runnable).

**Claude Code integration**: `home/dot_claude/CLAUDE.md` is a *deployed artifact*
(global user guidelines → `~/.claude/CLAUDE.md`), distinct from this file. Don't
confuse the two: this file guides working *on* the repo; that one is content
shipped *to* the machine.

## Secrets

Never committed. `home/dot_config/zsh/secrets.zsh` is in both `.gitignore` and
`home/.chezmoiignore`; only `secrets.zsh.example` is tracked. It's sourced from
`dot_zshenv`. Keys are pulled optionally from `pass` (GPG). Claude Code itself
needs no API key (subscription login).

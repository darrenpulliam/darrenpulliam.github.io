# Phase 0 kit: read-only inventory of CrystalBull

Phase 0 must run on the Windows machine. The cloud session cannot see `C:\CrystalBull\CB_v4.0`. Two ways to run it; the script is the fast one.

## Option 1: PowerShell script (about 1 minute)

1. Download `phase0-inventory.ps1` from this folder to the Desktop.
2. Open PowerShell (not as Administrator) and run:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\phase0-inventory.ps1"
```

   If CrystalBull lives somewhere other than `C:\CrystalBull\CB_v4.0`, add `-Root "D:\path\to\CB_v4.0"`.

3. It writes `cb_v4_inventory_<date>.md` to the Desktop. It never writes inside the CrystalBull directory and records only *where* credentials appear to live, never their values. Skim it, then paste it into this session or attach it.

What it collects: OS and hardware, versions and install paths of `claude`, `codex`, `node`, `git`, `python`, `ollama`, WSL state, PowerShell 7 build source (Store vs MSI), the CrystalBull tree, file counts, version markers, generator and engine counts, test and dependency manifests, existing `CLAUDE.md` or `AGENTS.md`, git status, scheduled tasks and processes touching CrystalBull, secret-store file names, how secrets are loaded, live-trading and order-placement references, brokerage SDK imports, and presence of Claude Code, Codex, and ChatGPT desktop configuration.

## Option 2: local Claude Code session

Open a terminal in `C:\CrystalBull\CB_v4.0`, start `claude`, and paste:

```
Read-only task, change nothing. Produce a Phase 0 inventory of this CrystalBull installation and save it OUTSIDE this directory at %USERPROFILE%\Desktop\cb_v4_inventory.md. Cover: version markers; top-level and second-level tree; counts of signal generators and engines with the directories they live in; test suite presence and whether it runs offline; dependency manifests; existing CLAUDE.md/AGENTS.md/.claude/.codex files; whether this tree is a git repo and any nested .git dirs; scheduled tasks and scripts (daily.ps1) that reference this path; where credentials and brokerage keys are loaded from (report file paths and variable names only, never values); every code path that can place an order or touch live brokerage settings and what guards it; stop-loss rule locations. Also record claude, codex, node, git, python, ollama versions and whether PowerShell 7 is the Store or MSI build. Finish with the five open questions from the collaboration assessment and leave blanks for me to answer.
```

## Then

Reply in the cloud session with the report plus answers to:

1. Darvis's ChatGPT plan (Plus, Pro, Business).
2. The Claude plan behind Claude Code (Pro, Max, Team).
3. Whether CB_v4.0 is already under git anywhere.
4. Where brokerage credentials live today.
5. Whether a test suite exists and runs without live market data.

Phase 1 (private repo, secrets externalized, CI, branch protection) starts after those answers.

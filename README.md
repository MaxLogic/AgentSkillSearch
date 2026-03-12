# Agent Skill Search

Agent Skill Search is a Windows desktop app that helps us find local `SKILL.md` files fast.

It scans paths from `Sources.lst`, indexes content into a local SQLite cache, and supports:
- lexical search (FTS5 + ranking)
- optional semantic rerank (Ollama embeddings)
- script-aware filtering (`has:scripts`, `ext:`)
- keyboard-first navigation with full markdown preview and diagnostics
- related-skill suggestions in the preview pane
- recent-query history, in-memory result sorting, and markdown export
- tag browser, external tool actions, in-app `Sources.lst` editing, and tray restore support

## What We Need

- Windows x64
- `bin/AgentSkillSearch.exe`
- `bin/sqlite3.dll`
- `bin/settings.ini` and `bin/Sources.lst`
- `bin/excludes.lst` (optional path exclusions for scan/index)
- Git installed and available as `git.exe` (for pull/update stage)

Everything is portable and runs from the `bin/` folder.

## Quick Start

1. Edit `bin/Sources.lst` and add one local path per line.
2. The app auto-attempts to start the configured Ollama Docker stack on launch; the `Start GPU` button lets us retry manually if needed.
3. Run `bin/AgentSkillSearch.exe`.
4. If auto-start does not bring Ollama up, use `Start GPU` to retry the configured Docker GPU stack command.
5. Press `F5` (`Scan/Update`) to discover repos and index skills (an indeterminate progress bar is shown during scan).
6. If `Sources.lst` needs editing, use `Edit Sources...` inside the app instead of editing the file manually.
7. When semantic indexing is enabled, the status bar shows embedding progress for newly indexed skills.
8. Use the search box to query skills.

## First 5 Minutes Example

1. Open `bin/Sources.lst` and set it to:

```text
# Demo source
F:\projects\3rdParty\AI-Related
```

2. Start `bin/AgentSkillSearch.exe`.
3. If Ollama is still unavailable after startup, click `Start GPU` to retry the configured Docker command.
4. Press `F5` and wait for scan/index to finish (watch the scan progress bar and status bar).
5. In search, try:
   - `embedding`
   - `"rate limit" has:scripts`
   - `name:ollama tag:docker`
   - `(retry OR backoff) ext:py`
6. Select a result and verify:
   - full markdown preview is shown with highlights
   - related skills appear when semantic vectors are available
   - `Enter` opens `SKILL.md`
   - `Ctrl+Enter` opens containing folder

## Start Required Docker (Ollama)

Semantic rerank (`[Semantic] Enabled=1` in `settings.ini`) expects Ollama at `http://localhost:11434`.

CPU container:

```powershell
docker run -d --name ollama `
  -p 11434:11434 `
  -v ollama:/root/.ollama `
  ollama/ollama
```

NVIDIA GPU container:

```powershell
docker run -d --name ollama `
  --gpus=all `
  -p 11434:11434 `
  -v ollama:/root/.ollama `
  ollama/ollama
```

Pull default embedding model:

```powershell
docker exec -it ollama ollama pull mxbai-embed-large
```

Quick health check:

```powershell
curl http://localhost:11434/api/tags
```

If Ollama is down, search still works with lexical ranking (no crash).

## How to Use the App

- `Ctrl+L`: focus search box
- `Syntax` button near search box: opens quick query syntax help
- `Enter`: open selected `SKILL.md`
- `Ctrl+Enter`: open containing folder
- `F5`: scan/update
- `Esc`: cancel active search
- `Shift+F10` or `Apps`: result context menu
- `Recent`: reopen recent queries
- `Sort: ...`: re-order the current in-memory results without re-running search
- `Edit Sources...`: add/remove scan roots inside the app
- close window: hide to tray instead of exiting
- Status bar counters: `Found`, `Valid`, `Unique`, `Results`
- With semantic enabled, the status bar also shows embedding warm-up progress for newly indexed skills

Supported query syntax:
- words: `retry backoff`
- `OR` / grouping: `(retry OR backoff) timeout`
- phrase: `"rate limit"`
- exclusion: `-jwt`
- filters: `name:`, `tag:`, `path:`, `has:scripts`, `-has:scripts`, `ext:`
- limit: `limit:200`

Other UI behaviors:
- The tag sidebar appends `tag:<value>` to the query when clicked.
- The preview pane shows duplicate-location details and, when semantic data exists, up to 3 related skills.
- The results context menu can export the current results as a markdown list and can expose custom external tool actions from `settings.ini`.

## Count Semantics

Diagnostics and UI counters use the same definitions:
- `Found`: `SKILL.md` files discovered during the latest scan run.
- `Written`: skills inserted/updated in DB during the latest scan run.
- `Valid`: indexed rows with non-empty `name`, `skill_file`, and `body_md`.
- `Unique`: valid skills after deduplication by `body_hash`.
- `Results`: rows currently visible for the active query.

Why visible results can be lower than `Valid`/`Unique`:
- active query filters (`name:`, `tag:`, `path:`, `has:scripts`, excluded terms)
- query scope limit (`limit:` in query, otherwise `[Search] MaxResults`)
- duplicate collapse by `body_hash`

## Configuration

Main file: `bin/settings.ini`

Important keys:
- `[General] SourcesListPath`, `ExcludesListPath`, `CacheDbPath`, `LogPath`
- `[Git] PullEnabled`, `MinPullIntervalMinutes`, `GitPullTimeoutSeconds`
- `[Docker] StartGpuCommand`, `HealthCheckCommand`
- `[Search] SearchDebounceMs`, `MaxResults`, `SnippetMaxChars`, `RecentQueryLimit`
- `[Semantic] Enabled`, `OllamaBaseUrl`, `Model`, `CandidateRerankCount`
- `[UI] ShowPreviewPane`, `OpenFileOnEnter`, `TrayHotkey`
- `[ExternalTools] Name=command {path}`

Defaults are auto-created for missing keys.

`bin/excludes.lst` supports case-insensitive substring and wildcard (`*`, `?`) rules against full scanned paths.
Use it to skip test harness fixtures before git/indexing.

Examples:

```ini
[UI]
TrayHotkey=Win+Shift+K

[ExternalTools]
Code=code {path}
Explorer=explorer.exe {path}
```

## Reference Repo List

`skill-repos-list.txt` is a small reference list of repositories that contain at least one `SKILL.md`, stored as `<repo_path>	<remote_url>`.
Use it as a seed set when we want known skill-bearing repos without rescanning the full source tree.

## Troubleshooting

- Open `Diagnostics` in the app to see last scan summary, exclusion notices, and recent errors.
- Docker status is polled every 10 seconds; the health label updates automatically.
- Check log file from `[General] LogPath` (default `bin/logs/AgentSkillSearch.log`).
- If semantic results do not appear, verify Ollama container and model availability.
- If related skills do not appear, verify `[Semantic] Enabled=1` and that embeddings were computed during scan.
- If the tray hotkey does not work, verify `UI.TrayHotkey` uses at least one modifier such as `Win+Shift+K`.
- If no items are found, verify `Sources.lst` paths are valid and reachable.

## Build From Source (Delphi 12)

From WSL:

```bash
bash projects/build-win64.sh
```

This builds and packages a Release runtime into `bin/`.
Existing `bin/settings.ini`, `bin/Sources.lst`, and `bin/excludes.lst` are preserved so local portable configuration is not overwritten.

Output layout:
- app runtime: `bin/` (`AgentSkillSearch.exe`, `sqlite3.dll`, runtime templates)
- shared test/runtime support files: `tests/bin/`
- `settings.ini`, `Sources.lst`, `excludes.lst`, help image, and `sqlite3.dll` are staged into `tests/bin/` for the console test projects

This keeps `bin/` focused on day-to-day app usage instead of test executables.

Win32 is intentionally unsupported (x64 SQLite runtime only):

```bash
bash projects/build-win32.sh
```

Expected outcome: Win32 build fails with an explicit fatal message.

RAD Studio:
- open `projects/AgentSkillSearch.dproj`
- build target `Win64`
- packaged runtime assets are staged by `projects/build-win64.sh`; an IDE build alone compiles the EXE but does not perform the portable-runtime packaging step

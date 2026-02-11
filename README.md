# Agent Skill Search

Agent Skill Search is a Windows desktop app that helps us find local `SKILL.md` files fast.

It scans paths from `Sources.lst`, indexes content into a local SQLite cache, and supports:
- lexical search (FTS5 + ranking)
- optional semantic rerank (Ollama embeddings)
- script-aware filtering (`has:scripts`)
- keyboard-first navigation with preview and diagnostics

## What We Need

- Windows x64
- `bin/AgentSkillSearch.exe`
- `bin/sqlite3.dll` and `bin/vec0.dll`
- `bin/settings.ini` and `bin/Sources.lst`
- `bin/excludes.lst` (optional path exclusions for scan/index)
- Git installed and available as `git.exe` (for pull/update stage)

Everything is portable and runs from the `bin/` folder.

## Quick Start

1. Edit `bin/Sources.lst` and add one local path per line.
2. (Optional but recommended) Start Ollama Docker for semantic rerank (see next section).
3. Run `bin/AgentSkillSearch.exe`.
4. Use `Start GPU` (optional) to launch the configured Docker GPU stack from the app.
5. Press `F5` (`Scan/Update`) to discover repos and index skills (an indeterminate progress bar is shown during scan).
6. Use the search box to query skills.

## First 5 Minutes Example

1. Open `bin/Sources.lst` and set it to:

```text
# Demo source
F:\projects\3rdParty\AI-Related
```

2. Start `bin/AgentSkillSearch.exe`.
3. Optional: click `Start GPU` to launch Ollama docker stack from configured command.
4. Press `F5` and wait for scan/index to finish (watch the scan progress bar and status bar).
5. In search, try:
   - `embedding`
   - `"rate limit" has:scripts`
   - `name:ollama tag:docker`
6. Select a result and verify:
   - preview snippet is shown with highlights
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
- `Enter`: open selected `SKILL.md`
- `Ctrl+Enter`: open containing folder
- `F5`: scan/update
- `Esc`: cancel active search
- `Shift+F10` or `Apps`: result context menu
- Status bar counters: `Found`, `Valid`, `Unique`, `Results`

Supported query syntax:
- words: `retry backoff`
- phrase: `"rate limit"`
- exclusion: `-jwt`
- filters: `name:`, `tag:`, `path:`, `has:scripts`, `-has:scripts`
- limit: `limit:200`

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
- `[Search] SearchDebounceMs`, `MaxResults`, `SnippetMaxChars`
- `[Semantic] Enabled`, `OllamaBaseUrl`, `Model`, `CandidateRerankCount`

Defaults are auto-created for missing keys.

`bin/excludes.lst` supports case-insensitive substring and wildcard (`*`, `?`) rules against full scanned paths.
Use it to skip test harness fixtures before git/indexing.

## Troubleshooting

- Open `Diagnostics` in the app to see last scan summary and recent errors.
- Open `Diagnostics` in the app to see last scan summary, exclusion notices, and recent errors.
- Docker status is polled every 10 seconds; the health label updates automatically.
- Check log file from `[General] LogPath` (default `bin/logs/AgentSkillSearch.log`).
- If semantic results do not appear, verify Ollama container and model availability.
- If no items are found, verify `Sources.lst` paths are valid and reachable.

## Build From Source (Delphi 12)

From WSL:

```bash
bash projects/build-win64.sh
```

This builds and packages runtime templates into `bin/`.

Output layout:
- app runtime: `bin/` (`AgentSkillSearch.exe`, SQLite DLLs, runtime templates)
- tests/check binaries: `tests/bin/`
- test runtime dependencies (`sqlite3.dll`, `vec0.dll`, `settings.ini`, `Sources.lst`) are copied to `tests/bin/`

This keeps `bin/` focused on day-to-day app usage instead of test executables.

Win32 is intentionally unsupported (x64 SQLite runtime only):

```bash
bash projects/build-win32.sh
```

Expected outcome: Win32 build fails with an explicit fatal message.

RAD Studio:
- open `projects/AgentSkillSearch.dproj`
- build target `Win64`

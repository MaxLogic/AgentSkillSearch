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
- Git installed and available as `git.exe` (for pull/update stage)

Everything is portable and runs from the `bin/` folder.

## Quick Start

1. Edit `bin/Sources.lst` and add one local path per line.
2. (Optional but recommended) Start Ollama Docker for semantic rerank (see next section).
3. Run `bin/AgentSkillSearch.exe`.
4. Press `F5` (`Scan/Update`) to discover repos and index skills.
5. Use the search box to query skills.

## First 5 Minutes Example

1. Open `bin/Sources.lst` and set it to:

```text
# Demo source
F:\projects\3rdParty\AI-Related
```

2. Start `bin/AgentSkillSearch.exe`.
3. Press `F5` and wait for scan/index to finish (watch the status bar).
4. In search, try:
   - `embedding`
   - `"rate limit" has:scripts`
   - `name:ollama tag:docker`
5. Select a result and verify:
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

Supported query syntax:
- words: `retry backoff`
- phrase: `"rate limit"`
- exclusion: `-jwt`
- filters: `name:`, `tag:`, `path:`, `has:scripts`, `-has:scripts`
- limit: `limit:200`

## Configuration

Main file: `bin/settings.ini`

Important keys:
- `[General] SourcesListPath`, `CacheDbPath`, `LogPath`
- `[Git] PullEnabled`, `MinPullIntervalMinutes`, `GitPullTimeoutSeconds`
- `[Search] SearchDebounceMs`, `MaxResults`, `SnippetMaxChars`
- `[Semantic] Enabled`, `OllamaBaseUrl`, `Model`, `CandidateRerankCount`

Defaults are auto-created for missing keys.

## Troubleshooting

- Open `Diagnostics` in the app to see last scan summary and recent errors.
- Check log file from `[General] LogPath` (default `bin/logs/AgentSkillSearch.log`).
- If semantic results do not appear, verify Ollama container and model availability.
- If no items are found, verify `Sources.lst` paths are valid and reachable.

## Build From Source (Delphi 12)

From WSL:

```bash
bash projects/build-win64.sh
```

This builds and packages runtime templates into `bin/`.

Win32 is intentionally unsupported (x64 SQLite runtime only):

```bash
bash projects/build-win32.sh
```

Expected outcome: Win32 build fails with an explicit fatal message.

RAD Studio:
- open `projects/AgentSkillSearch.dproj`
- build target `Win64`

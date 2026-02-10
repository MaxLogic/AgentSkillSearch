# Agent Skill Search

Agent Skill Search is a Delphi 12 Win64 VCL desktop app for scanning skill repositories,
indexing `SKILL.md` files into SQLite FTS5, and searching with lexical and semantic ranking.

## Repository layout

- `src/` application source units
- `tests/` test projects and fixtures
- `projects/` Delphi project files (`.dpr`, `.dproj`, `.groupproj`) and build helpers
- `docs/` reference docs, ADRs, and focused spec slices
- `bin/` runtime dependencies (`sqlite3.dll`, `vec0.dll`)
- `cache/` local SQLite cache output
- `logs/` runtime logs
- `assets/` non-code assets

## Build (Delphi 12)

The project references shared units directly from sibling repo `..\..\MaxLogicFoundation`
(resolved from `projects/*.dproj` search paths).

From WSL, use the helper scripts in `projects/`:

```bash
bash projects/build-win64.sh
```

The build script also packages runtime templates beside the EXE in `bin/`:
- `settings.ini`
- `Sources.lst`

Win32 is intentionally unsupported because our bundled SQLite runtime is x64-only:

```bash
bash projects/build-win32.sh
```

Expected result: build fails with a fatal message that Win64 is mandatory.

## Open in RAD Studio

Open `projects/AgentSkillSearch.dproj` and build `Win64`.

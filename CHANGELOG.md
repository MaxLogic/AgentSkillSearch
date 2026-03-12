# Changelog

## [Unreleased]

### Added
- Initial project skeleton with Delphi 12 Win64 build setup and mandatory Win64 guard (`T-001`).
- SQLite bootstrap layer with required WAL/PRAGMA configuration and initial schema migration (`T-002`).
- UTF-8 `Sources.lst` parser with comment filtering, path normalization, and invalid-path reporting covered by executable tests (`T-003`).
- Bounded multi-thread scan engine for recursive folder traversal with repo/`SKILL.md` discovery and skip-folder enforcement (`T-004`).
- Non-interactive git pull worker with per-repo throttling/timeout and persisted pull status/output/duration/head metadata (`T-005`).
- Deterministic `SKILL.md` indexing with frontmatter-aware name/description/tags parsing, SHA-256 body hashing, FTS refresh, and unchanged-file reindex skipping (`T-006`).
- Script-asset detection during indexing with persisted `has_scripts`, `scripts_count`, and `scripts_exts` metadata (`T-007`).
- Search query parser and FTS5 execution with support for phrases, exclusions, field filters (`name:`, `tag:`, `path:`), `has:scripts`, `limit:`, and bm25-based lexical ranking (`T-008`).
- Main VCL UI with search bar, filters row, results `TListView`, TMS FNC web preview pane, duplicate-info side area, status bar, context menu actions, and keyboard shortcuts (`T-011`).
- Debounced asynchronous search controller with generation-based stale-result discard and Esc cancellation safety (`T-012`).
- Diagnostics logging with per-run scan summaries, surfaced pipeline/index/git failures, and an in-app diagnostics dialog (`T-013`).
- Deterministic runtime packaging for Win64 output with template `settings.ini`/`Sources.lst` beside the EXE and portable-folder startup checks (`T-014`).
- Query-aware FTS snippets with configurable character caps plus sanitized preview rendering with match highlighting (`T-018`).
- Duplicate suppression in result lists using `body_hash`, with duplicate counts and duplicate-path details surfaced in preview (`T-019`).
- Semantic chunk/vector persistence with heading-aware chunking and incremental vector refresh only for changed chunk hashes (`T-010`).
- Hybrid semantic rerank via Ollama embeddings over cached chunk vectors, with graceful lexical fallback when Ollama is unavailable (`T-009`).
- Strongly typed portable `settings.ini` loader that creates defaults, repairs missing keys, and logs key restoration events (`T-015`).
- Worktree-aware git repo discovery with `.git` file/directory handling and persisted repo roots for pull scheduling (`T-016`).
- Multi-stage scan/git/index pipeline coordinator with cancellable processing and single-writer batched DB commits (`T-017`).
- Enforced Win64-only build/runtime path for bundled SQLite with explicit Win32 fatal guard and verified FTS5 runtime checks (`T-020`).
- Configured all project builds to resolve shared units directly from sibling `MaxLogicFoundation` search paths (`T-021`).
- Scan/index path exclusions via configurable `excludes.lst`, including seeded OpenClaw fixture rules and diagnostics notices for excluded paths (`T-023`).

### Changed
- Unified count semantics across diagnostics/search (`Found`, `Written`, `Valid`, `Unique`, `Results`) and aligned default query scope to `[Search] MaxResults` (`T-025`).
- Expanded the bottom status bar with live `Found`, `Valid`, `Unique`, and `Results` counters while keeping scan totals stable across query changes (`T-026`).
- Scan now runs with a visible indeterminate progress bar and supports safe cancellation requests via `Esc` while in progress (`T-027`).
- Added Docker operations in UI: configurable `Start GPU` action with diagnostics/log feedback and a 10-second background health indicator updated via `TThread.Queue` (`T-028`, `T-029`).
- Added a `Syntax` help button next to search input with concise query examples (`"phrase"`, `-exclude`, `name:`, `tag:`, `path:`, `has:scripts`, `limit:`) (`T-030`).
- Expanded query syntax with boolean `OR`/grouping support and `ext:` script-extension filtering, including updated in-app syntax help (`T-037`, `T-038`).
- Preview pane now renders full markdown bodies with headings, lists, fenced code blocks, inline emphasis, and highlighted matches while blocking remote image loads (`T-034`).
- Search UI now persists window/layout state, restores the last query and search-as-you-type preference, and exposes a recent-query dropdown backed by persisted history in `settings.ini` (`T-035`, `T-045`).
- Results can now be re-sorted in memory by score, name, path, or indexed date, and the result context menu can copy the current list as markdown links (`T-039`, `T-042`).
- Results context menus can now expose configurable external tool actions from `settings.ini`, including PATH-resolved launch support for commands such as `code {path}` (`T-040`).
- Documented the app’s Ollama auto-start behavior and updated Win64 packaging to build a Release runtime without overwriting existing portable config files in `bin/` (`T-032`).

### Fixed
- Scan/index runs now honor `[Index]` script-detection settings from `settings.ini`, including `ComputeHasScripts`, `ScriptExtensions`, `HasScriptsMaxFilesToScan`, and `HasScriptsSkipFolders` (`T-046`).
- Serialized asynchronous search execution and dropped queued Docker health callbacks after `Stop`, preventing stale completion delivery in those paths (`T-032`).
- Pipeline cancellation now stops before DB batch writes once the cancel token is set, and scan summary count queries no longer read a freed DB manager (`T-032`).
- Scan start now blocks immediately when `Sources.lst` has no usable source directories and prompts us to edit the file before retrying (`T-031`).
- Diagnostics modal now closes on `Esc` via standard cancel-button behavior, restoring expected keyboard dismiss flow (`T-022`).
- Indexing now repairs missing frontmatter closing fences at file start (within defined scope) and records a non-fatal diagnostics notice (`T-024`).

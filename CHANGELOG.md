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
- Strongly typed portable `settings.ini` loader that creates defaults, repairs missing keys, and logs key restoration events (`T-015`).
- Worktree-aware git repo discovery with `.git` file/directory handling and persisted repo roots for pull scheduling (`T-016`).
- Multi-stage scan/git/index pipeline coordinator with cancellable processing and single-writer batched DB commits (`T-017`).
- Enforced Win64-only build/runtime path for bundled SQLite with explicit Win32 fatal guard and verified FTS5 runtime checks (`T-020`).
- Configured all project builds to resolve shared units directly from sibling `MaxLogicFoundation` search paths (`T-021`).

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
- **UI redesign (Clean Dashboard)**: compact search header, dedicated filter bar, flexible results panel, tag browser sidebar, preview panel with structured card header, consolidated 4-panel status bar, and animated Lottie scan indicator.
- **SVG button icons**: main-toolbar actions now use DFM-wired SVG assets through `TAdvSVGImageCollection` and `TVirtualImageList`, replacing the old runtime Skia string-constant pipeline while keeping DPI-safe vector rendering.
- **Tag filter** now uses `MaxLogic.StrUtils.TFilterEx` (Everything-style syntax: space=AND, `!` negate, `|` OR, wildcard `*`/`?`) with 300 ms debounce and a background thread; stale results are discarded via a generation counter.
- **Application icon** regenerated with Gemini AI (magnifying-glass + neural-network motif, 7 sizes 16–256 px) and injected into the project resource.
- **Config dialog** (`ConfigDlg`) now exposes both tray-close behaviour and the persisted search-as-you-type preference, and the main toolbar includes a visible `Settings` button alongside the tray-menu entry point.
- Published form component names cleaned up (removed `f` prefix; used by VCL forms infrastructure).
- `QueueToMain` helper added to implementation section to eliminate TMS-induced `TThread.Queue` overload ambiguity.
- Preview pane now renders full markdown bodies with headings, lists, fenced code blocks, inline emphasis, and highlighted matches while blocking remote image loads (`T-034`).
- Search UI now persists window/layout state, restores the last query and search-as-you-type preference, and exposes a recent-query dropdown backed by persisted history in `settings.ini` (`T-035`, `T-045`).
- Results can now be re-sorted in memory by score, name, path, or indexed date, and the result context menu can copy the current list as markdown links (`T-039`, `T-042`).
- Results context menus can now expose configurable external tool actions from `settings.ini`, including PATH-resolved launch support for commands such as `code {path}` (`T-040`).
- The main window now includes a collapsible tag browser with per-tag skill counts, click-to-filter behavior, and automatic refresh after scans (`T-041`).
- Semantic-enabled scans now surface embedding warm-up progress and unavailable notices in the status bar, and the preview pane shows a Related list of cosine-ranked similar skills with click-to-select or open behavior (`T-043`, `T-044`).
- MainForm now exposes an in-app `Edit Sources...` dialog that filters invalid existing entries, supports browse/add/remove/save, and writes `Sources.lst` for the next scan without restarting (`T-036`).
- Main, settings, and sources dialogs now use flatter panel-based layout composition with `TBitBtn` actions, consistent spacing, and less coordinate-heavy toolbar wiring (`T-048`).
- Main-form header polish rebalanced the search trailing controls, made the syntax-help affordance icon-only, enlarged the scan animation/progress area, and swapped the Settings glyph for a simpler preferences icon that reads better at small sizes (`T-049`).
- The main form now keeps sort/settings/diagnostics as compact icon actions, moves Sources editing into Settings, replaces the old left tag browser with a modal multi-select tag dialog, and uses balloon-hint formatting for icon-heavy controls (`T-050`).
- Header layout polish made the Recent action a compact icon button, reduced the Search and Scan button heights, moved Settings and Diagnostics into the right-side primary action cluster, and added more breathing room before the first settings checkbox (`T-051`).
- Search-header layout now keeps the Recent / Syntax / Tags buttons evenly spaced, anchors Search / Scan / Settings / Diagnostics to the search-input row without vertical stretching, and gives the preview browser proper inner margins (`T-052`).
- Docker/Ollama health now sits in the bottom status bar, startup failures surface through a dedicated `Start now` alert strip under the search area, and the scan/search progress moved into its own independent activity panel so those strips disappear again when idle (`T-053`).
- The scan activity strip now uses a large left-side Lottie, a centered progress bar, and a live summary with repo/skill counts, elapsed time, and current stage; ordinary searches no longer open that large panel (`T-054`).
- Header utility buttons now use DFM-wired `TSpeedButton` image-list icons instead of runtime glyph assignment, and scan completion no longer floods the VCL thread with queued progress callbacks before the final UI refresh (`T-056`).
- The search caption now shows the real `Ctrl+L` focus shortcut so it is easier to discover while navigating the main form (`T-057`).
- The main form now also supports `Ctrl+R` to move focus to the results list, and the results caption shows that shortcut for easier recall (`T-058`).
- The preview browser now shows a designed empty-state page after initialization and when no result is selected, using a casual prompt, keyboard hints, and animated Lottie placeholders sourced from a dedicated Delphi HTML-constant unit (`T-059`).
- The duplicate-details panel now stays hidden unless the selected skill actually has duplicate paths to show, which frees preview space for the common non-duplicate case (`T-060`).
- The settings dialog now includes a startup update-check preference, and the app can quietly check GitHub releases on startup in the background before showing a dedicated update-available dialog with a direct GitHub action when a newer build exists (`T-062`).
- Closing the app window now hides it to a tray icon with Show/Exit actions, and an optional `UI.TrayHotkey` setting can restore/focus the window globally when configured with a modifier-backed shortcut (`T-033`).
- Documented the app’s Ollama auto-start behavior and updated Win64 packaging to build a Release runtime without overwriting existing portable config files in `bin/` (`T-032`).

### Fixed
- Tray hotkey registration now follows the form window-handle lifecycle instead of forcing early `HandleNeeded` during startup, preventing the `TCustomForm.SetActiveControl` / `DestroyHandle` launch crash on some systems (`T-047`).
- Scan/index runs now honor `[Index]` script-detection settings from `settings.ini`, including `ComputeHasScripts`, `ScriptExtensions`, `HasScriptsMaxFilesToScan`, and `HasScriptsSkipFolders` (`T-046`).
- Serialized asynchronous search execution and dropped queued Docker health callbacks after `Stop`, preventing stale completion delivery in those paths (`T-032`).
- Pipeline cancellation now stops before DB batch writes once the cancel token is set, and scan summary count queries no longer read a freed DB manager (`T-032`).
- Scan start now blocks immediately when `Sources.lst` has no usable source directories and prompts us to edit the file before retrying (`T-031`).
- Diagnostics modal now closes on `Esc` via standard cancel-button behavior, restoring expected keyboard dismiss flow (`T-022`).
- Indexing now repairs missing frontmatter closing fences at file start (within defined scope) and records a non-fatal diagnostics notice (`T-024`).

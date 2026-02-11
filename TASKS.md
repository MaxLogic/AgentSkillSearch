# Tasks

Next task ID: T-031

## Summary
Open tasks: 8 (In Progress: 0, Next Today: 8, Next This Week: 0, Next Later: 0, Blocked: 0)
Done tasks: 22

## In Progress

## Next – Today

### T-023 [SCAN] Add excludes list for scan/index pipeline
Outcome: Add exclude-list support so scan/index skips obvious test-harness skill paths, and ship a ready-to-use `excludes.lst` seeded from the latest diagnostics failures.
Proof:
- Command: Add one known fixture/test-harness path from `excludes.lst` under a scanned source and run Scan.
- Expect: The path is skipped before git/index work, and diagnostics/logs show it as excluded instead of failed.
Touches: excludes.lst, src/Scanner/*.pas, src/Settings.pas, README.md
Notes: Seed patterns from scan report dated 2026-02-11 (OpenClaw test fixtures and similar harness paths).

### T-024 [IDX] Best-effort repair for missing frontmatter closing fence
Outcome: Improve SKILL.md parsing with a best-effort recovery path that repairs missing YAML frontmatter closing fences and continues indexing with a warning.
Proof:
- Command: Index a fixture SKILL.md that starts frontmatter but omits the closing `---`.
- Expect: The skill is indexed via repaired parse path, and diagnostics record a non-fatal "frontmatter repaired" warning.
Touches: src/Indexer/*.pas, tests/IndexerTests.pas, docs/spec-slices/
Notes: Recovery scope is limited to missing closing fence at file start; malformed content beyond that remains a parse error.

### T-025 [SEARCH] Reconcile diagnostics totals with visible results
Outcome: Define and implement clear count semantics so diagnostics totals (written/failed) and UI visible results are explainable, including the "many indexed vs 178 shown" case.
Proof:
- Command: Run a large scan and then leave query empty on the main screen.
- Expect: We can account for displayed count using documented rules (validity filters, dedup, and query scope) without ambiguity.
Touches: src/Search/*.pas, src/UI/MainForm.pas, src/Db/*.pas, README.md
Notes: Add explicit terminology for found, written, valid, unique, and current query result counts.

### T-026 [UI] Add status bar counters for found, valid, unique, and results
Outcome: Extend the bottom status bar to show four counters: skills found, valid skills, unique (post-dedup) skills, and current query results.
Proof:
- Command: Complete a scan and execute at least one filtered search query.
- Expect: All four counters are visible, scan totals stay stable, and only query results counter changes as filters change.
Touches: src/UI/MainForm.pas, src/UI/MainForm.dfm
Deps: T-025

### T-027 [UI] Show scan progress bar as documented
Outcome: Implement or restore a visible progress bar during scan so runtime behavior matches README expectations.
Proof:
- Command: Start a scan on a medium or large source list.
- Expect: A progress bar is visible during scan, updates throughout work, and resets/hides correctly when scan completes or is canceled.
Touches: src/UI/MainForm.pas, src/UI/MainForm.dfm, README.md
Notes: If exact totals are unknown, use an explicit indeterminate mode with phase text.

### T-028 [OPS] Add button to start Docker GPU stack
Outcome: Add a UI button that starts the configured Docker GPU stack from the app and surfaces command success/failure in diagnostics/log output.
Proof:
- Command: Click the new Docker GPU start button with Docker installed and daemon running.
- Expect: The configured docker command is launched non-interactively and UI feedback confirms start request success or failure.
Touches: src/UI/MainForm.pas, src/UI/MainForm.dfm, src/Docker/*.pas, README.md
Notes: Keep command configurable and aligned with README setup instructions.

### T-029 [OPS] Add Docker health indicator with 10s polling thread
Outcome: Add a Docker health indicator refreshed every 10 seconds by a background thread, with all VCL updates marshaled through `TThread.Queue`.
Proof:
- Command: Run app with Docker stopped, then start Docker while app is open.
- Expect: Indicator shows unhealthy first, then flips to healthy within one polling interval, with no cross-thread VCL access errors.
Touches: src/UI/MainForm.pas, src/Docker/*.pas, src/Logging.pas
Deps: T-028
Notes: Polling thread must stop cleanly on app shutdown or scan cancel.

### T-030 [UI] Add search syntax help button near search box
Outcome: Add a help button beside the search bar that displays concise query syntax guidance consistent with README examples.
Proof:
- Command: Click the search help button on the main form.
- Expect: A help dialog/popup opens and explains supported syntax (`"phrase"`, `-exclude`, `name:`, `tag:`, `path:`, `has:scripts`, `limit:`).
Touches: src/UI/MainForm.pas, src/UI/MainForm.dfm, README.md
Notes: Keep text short and directly actionable for first-time users.

## Next – This Week

## Next – Later

## Blocked

## Done

### T-022 [UI] Close diagnostics dialog on Esc
Outcome: Make the Diagnostics dialog close immediately when Esc is pressed, matching standard modal dialog keyboard behavior.
Proof:
- Command: Open Diagnostics from the main form and press Esc.
- Expect: The dialog closes without errors and focus returns to the main form.
Touches: src/UI/DiagnosticsForm.pas, src/UI/DiagnosticsForm.dfm
Notes: Maintainer request from diagnostics review.

### T-009 [SEM] Ollama client + embeddings rerank (hybrid)
Outcome: Add local-first semantic rerank via Ollama (/api/embeddings): embed query, rerank top CandidateRerankCount candidates using cosine similarity over chunk vectors, and combine lex+sem into final score.
Proof:
- Command: With Ollama running, run a synonym query that lexical search ranks poorly.
- Expect: With semantic enabled, relevant skills move up; if Ollama is down, fallback to lexical without crash.
Touches: src/Semantic/*.pas, src/Search/*.pas, src/Db/*.pas, settings.ini
Deps: T-008, T-010
Notes:
- Deferred until lexical query pipeline and chunk/vector persistence are complete.
- Proof requires local Ollama runtime availability.

### T-010 [SEM] Chunking + vector storage + incremental re-embed
Outcome: Implement chunking by headings/paragraphs, store chunks + vectors in DB, and update vectors only when chunk_hash changes; use max-chunk similarity per skill.
Proof:
- Command: Change one section of SKILL.md and reindex.
- Expect: Only affected chunks get new vectors; semantic rerank uses updated content.
Touches: src/Semantic/Chunker.pas, src/Db/*.pas
Deps: T-006
Notes:
- Deferred until core index upsert flow is finalized.

### T-019 [IDX] Detect duplicate skills by body_hash
Outcome: Detect duplicate skill bodies using `body_hash`, keep all rows indexed in DB, collapse duplicate rows from the main results list, and expose duplicate count with a compact duplicate-path list in preview.
Proof:
- Command: Index two different skill roots with identical SKILL.md content.
- Expect: DB keeps both rows; search list shows one canonical row; preview shows duplicate count > 1 plus duplicate locations.
Touches: src/Indexer/*.pas, src/Db/*.pas, src/UI/MainForm.pas
Deps: T-006, T-008, T-011
Notes:
- Deferred until index upsert/search list rendering pipeline is complete.

### T-018 [SEARCH] Add snippets + sanitized preview rendering
Outcome: Generate query-aware snippets (`snippet()` or fallback extractor), cap by `SnippetMaxChars`, and render sanitized HTML in preview with match highlighting.
Proof:
- Command: Search for a term present in markdown with inline HTML and long body text.
- Expect: Snippet is truncated to configured max length, dangerous markup is escaped, and highlighted matches are visible in preview.
Touches: src/Search/*.pas, src/UI/MainForm.pas, src/UI/Preview*.pas
Deps: T-008, T-011
Notes:
- Deferred until core search query execution and UI preview host are in place.

### T-014 [PKG] Runtime packaging (sqlite dll, settings template)
Outcome: Package EXE with sqlite3.dll (FTS5) and vec0.dll in `bin\`, default settings.ini and Sources.lst beside the EXE, and ensure relative paths work in portable mode.
Proof:
- Command: Copy output folder to another machine/user profile and run.
- Expect: App starts; can create DB; scan works.
Touches: installer scripts or build output layout
Notes: Spec sections 3.2, 5, 16

### T-013 [OPS] Logging, diagnostics, and error surfacing
Outcome: Add robust logging and a simple diagnostics dialog showing last scan summary + last errors (git failures, index parse errors).
Proof:
- Command: Force a git failure (bad credential) and a malformed SKILL.md.
- Expect: Errors logged and visible in diagnostics; app continues.
Touches: src/Logging.pas, src/UI/DiagnosticsForm.pas
Notes: Spec section 13

### T-012 [SEARCH] Search-as-you-type debounce + cancellation safety
Outcome: Implement threaded search with debounce (SearchDebounceMs) and generation-id logic so outdated searches discard results; cancellation on Esc.
Proof:
- Command: Type quickly; trigger multiple searches.
- Expect: UI updates only from latest search; no flicker; previous threads exit or discard.
Touches: src/Search/SearchController.pas, src/UI/MainForm.pas
Notes: Spec section 9.3, 10

### T-011 [UI] Main UI (ListView + preview pane + actions)
Outcome: Build MainForm: search bar, results list view, status bar, preview pane in TMS FNC Edge Browser (simple sanitized snippet rendering, no full markdown renderer), duplicate-info side area in preview, Enter/double-click open, context menu open folder/copy path, and keyboard shortcuts.
Proof:
- Command: Operate only via keyboard and NVDA.
- Expect: NVDA reads list rows; preview updates on selection; shortcuts work (Ctrl+L, Enter, Ctrl+Enter, F5, Esc, Apps/Shift+F10).
Touches: src/UI/MainForm.pas, src/UI/*.dfm
Notes: Spec sections 11.1–11.3

### T-008 [SEARCH] FTS query parser + BM25 ranking
Outcome: Implement query syntax (phrases, -exclude, name:, tag:, path:, has:scripts, limit:) and execute FTS5 search with bm25 field weights; return sorted results with lex_score.
Proof:
- Command: Run a set of scripted searches on a fixture DB.
- Expect: Filters work; name matches outrank body-only matches; excluded terms remove items.
Touches: src/Search/*.pas, tests/SearchTests.pas
Notes: Spec sections 10.1, 10.2

### T-007 [IDX] HasScripts detection + filter flag
Outcome: During indexing, detect scripts under the skill root by extension list and store has_scripts/scripts_count/scripts_exts; add UI filter + query syntax support.
Proof:
- Command: Search with 'has:scripts' and without.
- Expect: Filter returns only skills with scripts; count matches expectations on known fixture.
Touches: src/Indexer/*.pas, src/Search/QueryParser.pas, src/UI/MainForm.pas
Notes: Spec sections 8.4, 10.1, 11

### T-006 [IDX] Skill indexer + FTS upsert
Outcome: Read SKILL.md, extract name/description/tags deterministically, compute body_hash, upsert into skills + skills_fts, and skip reindex if unchanged.
Proof:
- Command: Modify a SKILL.md and re-run Index.
- Expect: DB row updates and search results reflect change; unchanged skills are skipped.
Touches: src/Indexer/*.pas, src/Db/*.pas
Notes: Spec sections 8, 7.3

### T-005 [GIT] Git pull worker with throttling + timeout
Outcome: Implement git pull pipeline: detect repo roots, consult DB for last_pull_utc, skip if within MinPullIntervalMinutes, else run git pull with GitPullTimeoutSeconds in non-interactive mode; store status/output/duration/head_commit.
Proof:
- Command: Scan twice within interval.
- Expect: Second scan shows "skipped (throttled)" and does not run git; DB updated correctly on first scan.
- Command: Force one repo pull to fail (for example invalid remote URL) and run scan on multiple repos.
- Expect: Failed repo is reported, while other repos and skill indexing continue successfully.
- Command: Run scan against a repo that would require terminal credential prompt.
- Expect: Worker does not block waiting for prompt; repo is marked failed with logged non-interactive/auth error.
Touches: src/Git/*.pas, src/Db/*.pas
Notes: Spec sections 6.1, 7, 5[Git]

### T-004 [SCAN] Multi-thread scanner with bounded queue
Outcome: Implement recursive directory scan using MaxScanThreads with a work-queue of directories; discover repo roots and SKILL.md files; apply skip folder rules.
Proof:
- Command: Run Scan on a source with known repo + skills.
- Expect: Correct counts: repos discovered, SKILL.md discovered; skip folders are not entered.
Touches: src/Scanner/*.pas, src/Settings.pas
Notes: Spec sections 6, 9.1

### T-021 [BUILD] Add MaxLogicFoundation via project search path
Outcome: Configure project/library search path to reference MaxLogicFoundation directly and reuse shared units by reference instead of copying them into this repo.
Proof:
- Command: Build Win64 from a clean checkout without copying foundation units into this repo.
- Expect: Compilation resolves referenced MaxLogicFoundation units from configured search paths and build succeeds.
Touches: projects/*.dproj, projects/*.groupproj, README.md
Notes: Maintainer decision, spec sections 3.5, 15

### T-020 [BUILD] Enforce Win64 target for SQLite runtime compatibility
Outcome: Make Win64 the required runtime target for app builds that consume bundled SQLite DLLs, and fail fast for unsupported Win32 builds with a clear message.
Proof:
- Command: Build Win32.
- Expect: Build or startup fails with explicit message that Win64 is required.
- Command: Build Win64 and start app with bundled DLLs.
- Expect: App starts, SQLite library loads successfully, and FTS5 capability check passes.
Touches: projects/*.dproj, projects/*.dpr, src/Db/*.pas, bin/
Notes: Maintainer requirement (Win64 for SQLite DLL consumption), spec section 3.2

### T-017 [PIPE] Implement 3-pool pipeline coordinator + single DB writer
Outcome: Add a coordinator that wires scan/git/index pools with bounded queues and a single DB writer thread that batches transactions for `repos`, `skills`, and `skills_fts`.
Proof:
- Command: Run scan/index against a large source set and cancel midway.
- Expect: No DB lock/write contention errors; cancellation drains safely; partial progress is committed atomically per batch.
Touches: src/Pipeline/*.pas, src/Db/*.pas, src/Scanner/*.pas, src/Git/*.pas, src/Indexer/*.pas
Notes: Spec sections 9.1, 9.2, 9.4; reuse candidates in MaxLogicFoundation (CancelToken/maxAsync)

### T-016 [SCAN] Add worktree-aware Git repo detection
Outcome: Detect repo roots for both `.git` directory and `.git` file pointer formats, respect `TreatWorktreesAsRepos`, and persist stable repo roots for pull scheduling.
Proof:
- Command: Run scan on a fixture containing one normal repo and one git worktree.
- Expect: Both repos are discovered when TreatWorktreesAsRepos=1; worktree repo is skipped when TreatWorktreesAsRepos=0.
Touches: src/Scanner/*.pas, src/Git/*.pas, tests/ScannerTests.pas
Notes: Spec section 6.1; reference pattern in RepoPulse src/UGitClient.pas

### T-015 [CFG] Implement settings.ini contract + defaults loader
Outcome: Implement strongly-typed settings loading for all required sections/keys, using portable EXE-folder settings only (`.\settings.ini`, `.\Sources.lst` in our `bin` layout), and persist defaults for missing keys.
Proof:
- Command: Start the app with no settings.ini present.
- Expect: A valid settings.ini is created beside the EXE with required keys from [General], [Git], [Index], [Search], [Semantic], and [UI].
- Command: Delete one required key (for example GitPullTimeoutSeconds) and restart.
- Expect: Startup does not crash; the missing key is restored with default value and logged.
Touches: src/Settings.pas, src/Config/*.pas, settings.ini
Notes: Spec sections 4.2, 5

### T-003 [IDX] Implement Sources.lst parser
Outcome: Parse Sources.lst (UTF-8), ignoring comments (#, ;, //) and empty lines, returning normalized absolute/UNC paths.
Proof:
- Command: Run unit tests for parser.
- Expect: Comments ignored, valid lines returned, invalid paths reported but do not crash.
Touches: src/SourcesList.pas, tests/SourcesListTests.pas
Notes: Spec section 4.1

### T-002 [DB] Bundle SQLite with FTS5 + WAL configuration
Outcome: Bundle an SQLite DLL with FTS5 enabled and implement a DB layer that opens the cache DB, applies required PRAGMAs (WAL, synchronous NORMAL, temp_store MEMORY, foreign_keys ON), and runs migrations.
Proof:
- Command: Run app first time with empty cache.
- Expect: cache\SkillCache.db created; PRAGMA journal_mode reports "wal"; schema tables exist.
Touches: src/Db/*.pas, bin/sqlite3.dll, bin/vec0.dll, cache/
Notes: Spec sections 3.2, 7

### T-001 [DOC] Create repo skeleton + build script
Outcome: Create the project folder structure (src/, tests/, docs/, assets/, cache/, logs/) and a build script/instructions so a fresh checkout can compile in Delphi 12.
Proof:
- Command: Open the .dproj in Delphi 12 and Build Win64.
- Expect: Build succeeds with no missing unit/package errors.
- Command: Try to build Win32.
- Expect: Build fails with explicit fatal message that Win64 is mandatory.
Touches: README.md, AgentSkillSearch.dproj, src/, tests/
Notes: Spec sections 3, 16

# Agent Skill Search (Windows, Delphi VCL) — spec.md

## 0. Goal

Build a personal Windows desktop tool (Delphi 12, VCL) that:

1. Reads `Sources.lst` (list of local paths).
2. Recursively scans sources to discover:
   - Git repositories (auto `git pull` with throttling).
   - `SKILL.md` files (index into a local SQLite cache).
3. Provides fast search:
   - Primary: SQLite FTS5 + BM25 ranking (field-weighted).
   - **Included in v1**: local-first semantic rerank using **Ollama embeddings** (Docker Desktop), with settings toggle and lexical fallback.
4. Displays results in a screen-reader friendly UI:
   - `TListView` columns: Skill name, Rating, Description, Path.
   - Preview pane (HTML snippet) in **TMS FNC Edge Browser**.
   - Double-click / Enter opens `SKILL.md`.
   - Context menu: open file, open containing folder, copy path, etc.
5. Supports filtering by whether a skill contains scripts (`*.py`, `*.ps1`, `*.bat`, `*.sh`, …).

This spec is meant to be actionable for implementation without follow-up.

---

## 1. Non-goals

- Cross-platform (Windows only).
- File watchers / live reindexing (explicitly not required).
- Storing or editing skills content via LLM (indexing must be deterministic).

---

## 2. Terms

- **Skill root**: folder that contains a `SKILL.md`.
- **Repo root**: folder that is the root of a Git repository.
- **Cache DB**: SQLite database file (FTS5 enabled) with all indexed skills and metadata.
- **FTS**: Full Text Search (SQLite FTS5).
- **Semantic rerank**: Reorder top-N lexical results by vector similarity to an embedding of the query.

---

## 3. Environment & dependencies

### 3.1 Delphi / UI
- Delphi 12, VCL.
- TMS FNC Edge Browser (WebView2 based) for HTML snippet preview.
- Must remain NVDA-friendly: avoid owner-draw list controls and non-standard accessibility hacks.

### 3.2 SQLite with FTS5
We **must** use an SQLite build with **FTS5 enabled**.

- Use bundled runtime DLLs from the app `bin\` directory:
  - `sqlite3.dll` (FTS5-enabled)
  - `vec0.dll` (bundled runtime dependency from reference project set)
- Access strategy (fixed): **FireDAC + external sqlite3.dll** (VendorLib/custom client library path).
- Architecture requirement: keep DB code behind our own repository/service units so the backend can be swapped later if needed.
- Runtime/target requirement: app is **Win64-only** and must fail compilation for non-Win64 targets.
  Recommended guard:
  ```delphi
  {$IFNDEF WIN64}
    {$MESSAGE FATAL 'AgentSkillSearch requires Win64. Build target Win64 is mandatory because our SQLite runtime is x64-only.'}
  {$ENDIF}
  ```

**Important:** Set `PRAGMA journal_mode=WAL;` and `PRAGMA synchronous=NORMAL;` for performance.

### 3.3 Git
- Use system `git.exe` (prefer `PATH`, allow override in settings).
- Pull policy must be throttled per repo (configurable).
- Git worker must run **non-interactive** (no credential prompts; prompt-required repos are treated as failed pulls).
- Use non-interactive env flags for git child process (for example `GIT_TERMINAL_PROMPT=0`, `GCM_INTERACTIVE=Never`).
- Pull execution policy is still `pull --ff-only` on discovered repos (even if repo is dirty), with failure isolated to that repo.

### 3.4 Reuse policy
- Reuse existing units from `MaxLogicFoundation` by adding that project path to the Delphi search path.
- Do not duplicate reusable foundation units in this repo unless there is a hard coupling reason.

### 3.5 Local semantic embeddings (Ollama, included in v1)
- Run Ollama locally using **Docker Desktop (WSL2 backend)**.
- The app calls Ollama via HTTP (localhost) to obtain embeddings.

References (for implementer) — URLs in code blocks:
```text
Docker Desktop GPU prerequisites (WSL2 GPU paravirtualization):
https://docs.docker.com/desktop/features/gpu/

Ollama Docker docs (image + GPU flags):
https://docs.ollama.com/docker

Ollama embeddings endpoint examples:
https://ollama.com/library/mxbai-embed-large
https://ollama.com/library/nomic-embed-text
https://ollama.com/library/bge-m3
```

---

## 4. Inputs

### 4.1 `Sources.lst`

* UTF-8 text file.
* One path per line.
* Ignore:

  * empty lines
  * comments starting with `#`, `;`, or `//` (after optional leading whitespace)
* Treat paths as Windows filesystem paths (absolute, UNC allowed).

### 4.2 Settings file

Use `settings.ini` (UTF-8) in the same folder as the EXE (portable mode only; this is the canonical behavior for v1).

---

## 5. Settings.ini (required keys)

Example (defaults are suggestions, change as you like):

```ini
[General]
SourcesListPath=Sources.lst
CacheDbPath=cache\SkillCache.db
LogPath=logs\AgentSkillSearch.log
MaxScanThreads=6
MaxGitPullThreads=3
MaxIndexThreads=6
MaxSearchThreads=1

[Git]
GitExePath=git.exe
PullEnabled=1
MinPullIntervalMinutes=1440
GitPullTimeoutSeconds=1800
GitPullArgs=pull --ff-only
SkipFolders=.git;node_modules;bin;obj;.vs;.idea;dist;build;.venv;__pycache__
TreatWorktreesAsRepos=1

[Index]
SkillFileName=SKILL.md
MaxSkillFileBytes=2000000
ComputeHasScripts=1
ScriptExtensions=py;ps1;bat;cmd;sh;js;ts;lua;rb;pl;go;rs;java;cs;cpp;c;h;pas
HasScriptsMaxFilesToScan=5000
HasScriptsSkipFolders=.git;node_modules;bin;obj;dist;build;.venv;__pycache__
NormalizeLineEndings=1

[Search]
SearchAsYouType=0
SearchDebounceMs=2000
MaxResults=500
SnippetMaxChars=600

[Semantic]
Enabled=1
Provider=ollama
OllamaBaseUrl=http://localhost:11434
Model=mxbai-embed-large
CandidateRerankCount=300
MinScoreToShow=0.0
EmbeddingCache=1

[UI]
ShowPreviewPane=1
OpenFileOnEnter=1
```

Notes:

* `MinPullIntervalMinutes` throttles per-repo pulls.
* `GitPullTimeoutSeconds` must be generous and configurable.
* `MaxScanThreads`: multi-thread folder enumeration is allowed (fast SSD).
* Relative paths in settings are resolved against the EXE folder (`.\bin\` in our build layout).

---

## 6. Discovery rules

### 6.1 Git repo detection

A directory is a repo root if:

* It contains `.git\` directory, OR
* It contains `.git` file (worktree pointer format).

If `TreatWorktreesAsRepos=1`, treat such roots as repos.
When a repo is found, record it in DB and enqueue for pull (unless throttled).

### 6.2 Skill detection

If a directory contains `SKILL.md` (case-insensitive on Windows), it is a skill root.
Index the skill.

### 6.3 Skip rules

Skip directories matching any entry in `SkipFolders` / `HasScriptsSkipFolders`.

---

## 7. Cache database design (SQLite)

### 7.1 Pragmas (required)

On DB open (once per process):

* `PRAGMA journal_mode=WAL;`
* `PRAGMA synchronous=NORMAL;`
* `PRAGMA temp_store=MEMORY;`
* `PRAGMA foreign_keys=ON;`

### 7.2 Schema (v1)

```sql
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sources (
  id INTEGER PRIMARY KEY,
  path TEXT NOT NULL UNIQUE,
  enabled INTEGER NOT NULL DEFAULT 1,
  last_scan_utc TEXT
);

CREATE TABLE IF NOT EXISTS repos (
  id INTEGER PRIMARY KEY,
  root_path TEXT NOT NULL UNIQUE,
  last_pull_utc TEXT,
  last_pull_status TEXT,
  last_pull_output TEXT,
  last_pull_duration_ms INTEGER,
  head_commit TEXT,
  last_seen_utc TEXT
);

CREATE TABLE IF NOT EXISTS skills (
  id INTEGER PRIMARY KEY,
  source_id INTEGER NOT NULL,
  repo_id INTEGER,
  skill_root TEXT NOT NULL UNIQUE,
  skill_file TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  tags TEXT,
  body_md TEXT NOT NULL,
  body_hash TEXT NOT NULL,
  file_mtime_utc TEXT NOT NULL,
  indexed_utc TEXT NOT NULL,
  has_scripts INTEGER NOT NULL DEFAULT 0,
  scripts_count INTEGER NOT NULL DEFAULT 0,
  scripts_exts TEXT,
  FOREIGN KEY(source_id) REFERENCES sources(id),
  FOREIGN KEY(repo_id) REFERENCES repos(id)
);

-- FTS5 table (contentless is OK; we store canonical data in skills).
CREATE VIRTUAL TABLE IF NOT EXISTS skills_fts USING fts5(
  name,
  description,
  tags,
  body_md,
  content='',
  tokenize='unicode61'
);

-- Maintain FTS rows via triggers OR manual upsert from the DB writer thread.
```

### 7.3 FTS upsert strategy

Prefer **manual upsert** from the DB writer thread:

* On insert/update `skills`, do:

  * `INSERT INTO skills_fts(rowid, name, description, tags, body_md) VALUES(?, ?, ?, ?, ?)
     ON CONFLICT(rowid) DO UPDATE SET ...` (if supported)
  * If SQLite version lacks that for FTS tables, use:

    * `DELETE FROM skills_fts WHERE rowid=?;` then `INSERT ...`.

### 7.4 Duplicates

Detect duplicates by `body_hash`:

* Keep all rows in DB for traceability.
* In search result list, show only one canonical row per `body_hash` to avoid duplicate pollution.
* In preview pane, show duplicate count and a compact side list of duplicate skill paths.
* Optional v2: add explicit `canonical_skill_id` linkage for faster grouping.

---

## 8. Indexing strategy

### 8.1 Parsing name/description/tags (deterministic)

For `SKILL.md`:

1. If YAML frontmatter exists (starts with `---` at top):

   * Parse `name`, `description`, optional `tags`.
2. Else:

   * `name`: first `# Heading` text, else folder name.
   * `description`: first non-empty paragraph after title (cap to 200–300 chars).
3. `tags`: optional:

   * from frontmatter
   * or from a `Tags:` line (optional; implementer choice)

### 8.2 Content normalization (for hashing & stable index)

* Read as UTF-8 (fallback to ANSI if needed; record warning in logs).
* If `NormalizeLineEndings=1`: normalize to LF (`\n`) for hashing.
* Compute `body_hash` as SHA-256 over normalized bytes.

### 8.3 Change detection

Reindex a skill only if:

* file mtime changed OR
* `body_hash` differs from DB.

### 8.4 “Has scripts” attribute

If `ComputeHasScripts=1`:

* Scan under skill root (recursive) excluding `HasScriptsSkipFolders`.
* Count files whose extension matches `ScriptExtensions`.
* Stop scanning early if:

  * scanned files exceeds `HasScriptsMaxFilesToScan` (record partial)
  * or count is already > 0 and we only need boolean (configurable optimization).
* Store:

  * `has_scripts` (0/1)
  * `scripts_count`
  * `scripts_exts` (unique extensions found, semicolon-separated)

---

## 9. Concurrency & pipeline

We need robust, bounded concurrency with cancelation.

### 9.1 Thread pools

Use 3 independent bounded pools:

1. **Scan pool** (`MaxScanThreads`):

   * Multi-thread directory enumeration using a work queue of folders.
2. **Git pull pool** (`MaxGitPullThreads`):

   * Performs throttled `git pull` with timeouts.
3. **Index pool** (`MaxIndexThreads`):

   * Reads/parses SKILL.md and produces normalized records.

### 9.2 DB writer (single thread)

Even with WAL, simplest correctness is:

* Exactly one DB writer thread that:

  * writes `repos`, `skills`, `skills_fts`
  * uses transactions to batch commits

This avoids tricky multi-writer contention.

### 9.3 Cancellation

* Global cancellation token.
* Search-as-you-type spawns background searches; each search has:

  * `SearchGenerationId` increment (atomic)
  * worker checks canceled flag
  * on finish: if its id != current id => discard results (do not touch UI)

### 9.4 Work ordering

* Scan produces:

  * repo roots -> enqueue pull (if not throttled)
  * skill roots -> enqueue indexing
* If a repo pull completes and HEAD changed:

  * enqueue re-index for skills inside that repo (optional optimization)
  * minimal approach: mark repo “dirty” and let next scan reindex changed skills

---

## 10. Search behavior

### 10.1 Query syntax

Support simple tokens + filters:

* Words: `http retry backoff`
* Phrase: `"rate limit"`
* Exclude: `-jwt`
* Field filters:

  * `name:foo`
  * `tag:bar`
  * `path:MaxLogic`
  * `has:scripts` or `-has:scripts`
* Limit:

  * `limit:200` (optional)

Implementation:

* Parse into:

  * FTS query string + filter predicates (SQL WHERE)
* For `path:` filters:

  * `skill_root LIKE '%...%'` (escape)
* For `has:scripts`:

  * `has_scripts=1`

### 10.2 FTS ranking

Use FTS5 `bm25()` with field weights (example):

* name: 10.0
* description: 5.0
* tags: 4.0
* body_md: 1.0

Compute:

* `lex_score = -bm25(...)` (because smaller bm25 is better; convert to higher-is-better)

### 10.3 Snippets

Generate a snippet for preview:

* Use FTS5 `snippet()` if available, else do manual context extraction.
* Cap to `SnippetMaxChars`.

### 10.4 Semantic rerank (local-first, Ollama)

Semantic rerank is part of v1. If `[Semantic].Enabled=1`:

1. Run FTS to get top `CandidateRerankCount` rowids + `lex_score`.
2. Embed the user query via Ollama embeddings endpoint.
3. For each candidate:

   * Use (cached) embeddings for the skill (see 10.5)
   * Compute cosine similarity `sem_score` in Delphi.
4. Combine into a final score:

   * `final = (0.35 * norm_lex) + (0.65 * norm_sem)`
   * normalization: min/max over candidates to [0..1]
5. Sort by `final DESC`.

If Ollama is unavailable/unreachable, fallback to lexical FTS results without failing the search request.

### 10.5 Embedding storage strategy (recommended)

We want good quality without heavy infra.

**Chunking**

* Because some embedding models have small context windows (e.g. mxbai embed large tagged at 512 context),
  chunk skill markdown into chunks roughly 300–450 tokens worth of text.
* Chunk boundaries:

  * Prefer splitting by headings (`#`, `##`, `###`)
  * If a section is too large, split by paragraphs.

**Vectors**
Store vectors in DB (new tables):

```sql
CREATE TABLE IF NOT EXISTS skill_chunks (
  id INTEGER PRIMARY KEY,
  skill_id INTEGER NOT NULL,
  chunk_index INTEGER NOT NULL,
  chunk_text TEXT NOT NULL,
  chunk_hash TEXT NOT NULL,
  FOREIGN KEY(skill_id) REFERENCES skills(id)
);

CREATE TABLE IF NOT EXISTS chunk_vec (
  chunk_id INTEGER PRIMARY KEY,
  model TEXT NOT NULL,
  dim INTEGER NOT NULL,
  vec BLOB NOT NULL,
  updated_utc TEXT NOT NULL,
  FOREIGN KEY(chunk_id) REFERENCES skill_chunks(id)
);
```

**Similarity**

* For a skill, define `sem_score = max(sim(query_vec, chunk_vec_i))` over its chunks.
* Cache `query_vec` per search.

**Embedding caching**

* If skill content didn’t change (`body_hash` same), keep vectors.
* If `[Semantic].EmbeddingCache=0`, recompute (not recommended).

### 10.6 Recommended Ollama model choice

Default: `mxbai-embed-large` (strong retrieval performance, widely used in Ollama).
Alternatives:

* `nomic-embed-text`: smaller, often faster; generally good and popular.
* `bge-m3`: multi-lingual and multi-function (but you said English-only; still works fine).

Model pages:

```text
https://ollama.com/library/mxbai-embed-large
https://ollama.com/library/nomic-embed-text
https://ollama.com/library/bge-m3
```

**Pragmatic recommendation for your use case**

* Start with `mxbai-embed-large` as default.
* Keep model configurable; if speed matters more, switch to `nomic-embed-text`.

---

## 11. UI/UX requirements

### 11.1 Layout

* Search bar (edit + button + “search as you type” toggle).
* Filters row:

  * checkbox “Has scripts”
  * optional tag/path quick filters (later)
* Results `TListView` (Report):

  * Skill name
  * Rating
  * Description
  * Path
* Preview pane:

  * TMS FNC Edge Browser showing HTML snippet (sanitized).
  * Keep rendering simple: escaped text + lightweight highlight markup (no full markdown renderer in v1).
  * Show duplicate summary/list in a compact side area of the preview, not in the main result columns.
* Status bar:

  * Scan/index state and counters
  * last scan time
  * last cache update time

### 11.2 Accessibility / keyboard

Required shortcuts:

* `Ctrl+L`: focus search
* `Enter`: open selected skill file
* `Ctrl+Enter`: open containing folder
* `F5`: scan/update
* `Esc`: cancel scan/search
* `Apps` key or `Shift+F10`: context menu on results

Avoid:

* custom-drawn list items
* hidden focus

### 11.3 Open actions

* Open `SKILL.md` with associated application: `ShellExecute`.
* Open folder: `explorer.exe /select,"<skillfile>"` or `ShellExecute` folder and select file.

---

## 12. Docker Desktop + Ollama (implementation recipe)

### 12.1 Prereqs

* Docker Desktop installed with WSL2 backend enabled.
* Windows + NVIDIA driver that supports WSL2 GPU paravirtualization.
* Update WSL kernel:

  * `wsl --update`

### 12.2 Run Ollama (CPU or GPU)

Persist models in a volume, expose port 11434.

CPU:

```powershell
docker run -d --name ollama ^
  -p 11434:11434 ^
  -v ollama:/root/.ollama ^
  ollama/ollama
```

GPU (NVIDIA):

```powershell
docker run -d --name ollama ^
  --gpus=all ^
  -p 11434:11434 ^
  -v ollama:/root/.ollama ^
  ollama/ollama
```

Pull a model once:

```powershell
docker exec -it ollama ollama pull mxbai-embed-large
```

Test embeddings endpoint:

```powershell
curl http://localhost:11434/api/embeddings -d "{ \"model\": \"mxbai-embed-large\", \"prompt\": \"test\" }"
```

---

## 13. Logging & diagnostics

* Log to file (append).
* Track per-run summary:

  * sources scanned
  * repos found / pulled / skipped due to throttle / failed
  * skills found / indexed / skipped / errors
* Provide a “Diagnostics” view inside the app (optional v1) showing last errors.

---

## 14. Acceptance criteria

### 14.1 Indexing

* Given a `Sources.lst` with valid paths, the tool scans recursively and indexes all found `SKILL.md`.
* If a skill file changes, reindex updates name/description/body and FTS row.
* HasScripts detection works and is queryable and filterable.

### 14.2 Git throttling

* Repo pulls do not occur more often than `MinPullIntervalMinutes` per repo.
* Pull timeout is configurable; large repos do not fail due to short defaults.
* Pull failures do not break scanning/indexing of other paths.
* Git runs non-interactive; prompt-required pulls fail fast and are logged.

### 14.3 Search

* Search returns results sorted by rating.
* Field filters work (`name:`, `path:`, `has:scripts`).
* If semantic enabled and Ollama reachable:

  * results are reranked (visible impact on synonymy queries).
* If Ollama is not reachable:

  * tool falls back to lexical FTS search (no crash).

### 14.4 UI

* Keyboard-only operation is possible.
* NVDA reads list view rows and preview text reasonably.
* Enter opens SKILL.md; context menu opens folder.
* Duplicate skills do not pollute the main results list (single canonical row per duplicate content set).

### 14.5 Build/runtime

* Win64 build is mandatory; non-Win64 targets fail at compile time.
* App loads bundled SQLite runtime from `bin\sqlite3.dll` (and `bin\vec0.dll` is present in output).

---

## 15. Implementation notes (Delphi suggestions)

* Use `TThreadPool`/`TTask` with bounded semaphores for worker limits.
* Use a cancellation token pattern (atomic boolean + generation counters).
* Keep DB operations confined to the DB writer thread.
* Use FireDAC with explicit external SQLite VendorLib path.
* Configure project SearchPath to reuse `MaxLogicFoundation` units directly.
* For cosine similarity:

  * store vectors as Float32; compute dot/(norms).
* For HTML preview:

  * sanitize (escape) and highlight matches.
  * no remote resources; use inline CSS minimal.

---

## 16. Deliverables

* `AgentSkillSearch.exe`
* `settings.ini` template (stored beside EXE in portable mode)
* `Sources.lst` template (stored beside EXE in portable mode)
* `bin\sqlite3.dll` (FTS5-enabled, x64)
* `bin\vec0.dll` (x64)
* `cache\SkillCache.db` created on first run
* `logs\...`


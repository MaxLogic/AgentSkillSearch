# Frontmatter Repair Scope

## Goal
Allow indexing to continue when `SKILL.md` starts with YAML frontmatter (`---`) but the closing fence is missing.

## Supported Recovery
- Recovery applies only when frontmatter starts at file top.
- If no explicit closing `---` is found, we infer the end of frontmatter at the first non-frontmatter-like line.
- Recovery is non-fatal and emits a diagnostics notice containing `frontmatter repaired`.

## Out of Scope
- Files that contain only an opening fence plus key/value lines (no body start marker) remain parse errors.
- Broader YAML validation/repair is intentionally not attempted.

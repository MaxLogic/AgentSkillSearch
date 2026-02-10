# Changelog

## [Unreleased]

### Added
- Initial project skeleton with Delphi 12 Win64 build setup and mandatory Win64 guard (`T-001`).
- SQLite bootstrap layer with required WAL/PRAGMA configuration and initial schema migration (`T-002`).
- UTF-8 `Sources.lst` parser with comment filtering, path normalization, and invalid-path reporting covered by executable tests (`T-003`).
- Strongly typed portable `settings.ini` loader that creates defaults, repairs missing keys, and logs key restoration events (`T-015`).

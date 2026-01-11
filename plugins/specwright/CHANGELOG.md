# Changelog

All notable changes to Specwright will be documented in this file.

## [1.3.0] - 2026-01-11

### Added

- **Dependency management detection**: Discovery agent now checks if dependency management files exist (`pyproject.toml`, `requirements.txt`, `package.json`, etc.) and reports `dependency_management.exists` in `dependencies.yaml`.

- **Infrastructure task generation**: Design phase now creates a "Project infrastructure" task (TASK-001) when dependency management is missing or new packages are needed. All other tasks depend on it.

- **Task schema `new_dependencies` field**: Tasks can now declare packages they introduce (e.g., `new_dependencies: ["pydantic>=2.0"]`).

### Changed

- **Indexing agent model upgraded to opus**: Changed from `haiku` to `opus` for better instruction adherence. Added explicit prohibition against creating helper scripts—agent must use `ast-grep` only.

- **Index staleness detection for `/build`**: The `/build` command now checks if the symbol index is stale before refreshing, matching the behavior of `/resume`. Previously, `/build` always performed a full re-index even when running immediately after `/design`. This eliminates redundant indexing when running the standard `/define` → `/design` → `/build` workflow.

- **Hook invocation method**: Changed hooks.json to invoke shell scripts via `/bin/sh` explicitly (`/bin/sh script.sh`) rather than relying on execute permissions. This fixes "Permission denied" errors caused by the plugin cache not preserving file permissions.

- **Port/migration handling**: For ports or migrations, dependency files are always created fresh—never assumes old project dependencies exist.

### Fixed

- **PostToolUse:Bash hook error**: Resolved "Permission denied" error for `log-commands.sh` and `restrict-agents.sh` hooks when running from the plugin cache.

## [1.2.0]

- Initial tracked version

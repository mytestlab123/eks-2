# Working Issues (KISS)

TODO
- Move `.env` out of repo and into `~/.env`; add SSM Parameters for secrets.
- Rotate any Docker/Quay tokens already committed; ensure `.env` is gitignored.
- Create per-pipeline `just` shims at root (optional convenience).

DOING
- Add minimal repo helpers (justfile, smoke test, docs).

DONE
- Initial scaffolding: top-level `justfile`, `docs/TASKS.md`, `tests/smoke.sh`.


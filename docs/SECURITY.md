# Security Notes (High-Level)

- Never commit secrets. Use `~/.env` or AWS SSM Parameter Store.
- `.env` is gitignored; use `.env.example` for non-sensitive defaults.
- If any tokens were committed in the past, rotate them immediately.
- Prefer offline-first in PROD; no Docker Hub; use ECR/Nexus/Quay mirrors.
- For SSM patching, default `RebootOption=NoReboot`.


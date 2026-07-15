# AI recovery drill evidence

This directory stores redacted recovery-drill reports only. Backup archives, database files,
Qdrant snapshots, MinIO objects and secret files belong under ignored `backups/ai/` or an
encrypted external backup system and must never be committed.

Use `backup-ai-state.sh` for a clean-shutdown Langfuse PostgreSQL/ClickHouse/Redis/MinIO
archive plus an online Qdrant snapshot. Use `restore-ai-state-drill.sh` to restore into an
isolated Compose project and a temporary Qdrant collection, validate counts and API health,
then remove all temporary resources.

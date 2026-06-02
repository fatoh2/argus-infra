#!/bin/bash
# =============================================================================
# PostgreSQL Restore Script — Argus Infra
# =============================================================================
# Usage:
#   ./restore-db.sh <backup-file>         # Restore from a local file
#   ./restore-db.sh s3://bucket/path      # Restore from S3-compatible storage
#   ./restore-db.sh latest                # Restore the latest backup from S3
#
# Prerequisites:
#   - kubectl configured with cluster access
#   - AWS CLI installed (for S3 restore)
#   - pg_restore available (postgres client tools)
#
# This script restores a PostgreSQL database from a custom-format dump
# created by the postgres-backup CronJob.
# =============================================================================

set -euo pipefail

# --- Configuration (override via env vars) ---
NAMESPACE="${NAMESPACE:-databases}"
PG_POD_LABEL="${PG_POD_LABEL:-app.kubernetes.io/name=postgresql}"
PG_USER="${PG_USER:-argus_admin}"
PG_DATABASE="${PG_DATABASE:-argus_db}"
S3_ENDPOINT="${S3_ENDPOINT:-}"
S3_BUCKET="${S3_BUCKET:-argus-backups}"

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- Help ---
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<HELP
Usage: $0 <backup-source>

Backup source can be:
  - Path to a local .dump file (e.g., ./backup.dump)
  - S3 URI (e.g., s3://bucket/postgres-argus-db-2024-01-01.dump)
  - "latest" — fetches the latest backup from S3

Environment variables:
  NAMESPACE       K8s namespace (default: databases)
  PG_POD_LABEL    Label selector for PostgreSQL pod (default: app.kubernetes.io/name=postgresql)
  PG_USER         Database user (default: argus_admin)
  PG_DATABASE     Database name (default: argus_db)
  S3_ENDPOINT     S3-compatible endpoint URL
  S3_BUCKET       S3 bucket name (default: argus-backups)

Examples:
  # Restore from local file
  $0 /tmp/backup.dump

  # Restore latest backup from S3
  S3_ENDPOINT=https://s3.eu-central-1.amazonaws.com S3_BUCKET=argus-backups $0 latest

  # Restore specific S3 backup
  $0 s3://argus-backups/postgres-argus-db-2024-01-01T02-00-00Z.dump
HELP
  exit 0
fi

BACKUP_SOURCE="${1:-latest}"

# --- Step 1: Locate the backup file ---
BACKUP_FILE=""

if [ "$BACKUP_SOURCE" = "latest" ]; then
  info "Fetching latest backup from S3..."
  if [ -z "$S3_ENDPOINT" ]; then
    error "S3_ENDPOINT must be set when using 'latest' or S3 URIs"
    exit 1
  fi
  LATEST=$(aws s3 ls "s3://${S3_BUCKET}/" --endpoint-url="${S3_ENDPOINT}" \
    | grep 'postgres-argus-db-' \
    | sort -k1,2 \
    | tail -n1 \
    | awk '{print $4}')
  if [ -z "$LATEST" ]; then
    error "No backups found in s3://${S3_BUCKET}/"
    exit 1
  fi
  info "Found latest backup: ${LATEST}"
  BACKUP_FILE="/tmp/restore-${LATEST}"
  aws s3 cp "s3://${S3_BUCKET}/${LATEST}" "${BACKUP_FILE}" --endpoint-url="${S3_ENDPOINT}"
  info "Downloaded to ${BACKUP_FILE}"

elif [[ "$BACKUP_SOURCE" == s3://* ]]; then
  info "Downloading backup from ${BACKUP_SOURCE}..."
  BACKUP_FILE="/tmp/restore-$(basename "${BACKUP_SOURCE}")"
  aws s3 cp "${BACKUP_SOURCE}" "${BACKUP_FILE}" --endpoint-url="${S3_ENDPOINT}"
  info "Downloaded to ${BACKUP_FILE}"

else
  BACKUP_FILE="${BACKUP_SOURCE}"
  if [ ! -f "${BACKUP_FILE}" ]; then
    error "Backup file not found: ${BACKUP_FILE}"
    exit 1
  fi
  info "Using local backup file: ${BACKUP_FILE}"
fi

# --- Step 2: Verify the backup file ---
info "Verifying backup file integrity..."
if ! file "${BACKUP_FILE}" | grep -q "PostgreSQL"; then
  warn "File does not appear to be a PostgreSQL dump format"
  warn "Proceeding anyway..."
fi

BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
info "Backup size: ${BACKUP_SIZE}"

# --- Step 3: Find the PostgreSQL pod ---
info "Finding PostgreSQL pod in namespace ${NAMESPACE}..."
PG_POD=$(kubectl get pods -n "${NAMESPACE}" -l "${PG_POD_LABEL}" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -z "${PG_POD}" ]; then
  error "No running PostgreSQL pod found in namespace ${NAMESPACE}"
  error "Ensure the database is running with: kubectl get pods -n ${NAMESPACE}"
  exit 1
fi
info "Found PostgreSQL pod: ${PG_POD}"

# --- Step 4: Confirm restore ---
echo ""
warn "=============================================="
warn "  RESTORE IN PROGRESS"
warn "  Database: ${PG_DATABASE}"
warn "  Pod: ${PG_POD}"
warn "  File: ${BACKUP_FILE} (${BACKUP_SIZE})"
warn "=============================================="
warn "  This will OVERWRITE the current database!"
warn "=============================================="
echo ""

# --- Step 5: Copy backup to pod ---
info "Copying backup file to pod..."
kubectl cp "${BACKUP_FILE}" "${NAMESPACE}/${PG_POD}:/tmp/restore.dump"

# --- Step 6: Run pg_restore inside the pod ---
info "Running pg_restore (this may take a while)..."
kubectl exec -n "${NAMESPACE}" "${PG_POD}" -- \
  pg_restore \
    --dbname="${PG_DATABASE}" \
    --username="${PG_USER}" \
    --no-password \
    --clean \
    --if-exists \
    --verbose \
    /tmp/restore.dump 2>&1 | tail -20

# --- Step 7: Clean up temp files ---
info "Cleaning up temporary files..."
kubectl exec -n "${NAMESPACE}" "${PG_POD}" -- rm -f /tmp/restore.dump
rm -f "${BACKUP_FILE}"

# --- Step 8: Verify ---
echo ""
info "Verifying restore..."
kubectl exec -n "${NAMESPACE}" "${PG_POD}" -- \
  psql -U "${PG_USER}" -d "${PG_DATABASE}" -c \
  "SELECT count(*) AS total_tables FROM information_schema.tables WHERE table_schema = 'public';"

echo ""
info "${GREEN}Restore completed successfully!${NC}"
info "Verify data integrity by querying the database:"
info "  kubectl exec -n ${NAMESPACE} ${PG_POD} -- psql -U ${PG_USER} -d ${PG_DATABASE} -c 'SELECT count(*) FROM ...'"

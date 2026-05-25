#!/usr/bin/env sh
set -eu

echo "Waiting for MinIO at ${MINIO_URL}..."
until mc alias set local "${MINIO_URL}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" >/dev/null 2>&1; do
  sleep 1
done

mc mb --ignore-existing "local/${MINIO_BUCKET}"
echo "MinIO bucket ready: ${MINIO_BUCKET}"

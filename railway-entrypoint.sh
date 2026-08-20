#!/bin/sh
set -eu

DATA_DIR="${STRAPI_DATA_DIR:-/data}"
UPLOAD_DIR="$DATA_DIR/uploads"
APP_UID=1000
APP_GID=1000

if [ -z "${STRAPI_ADMIN_PASSWORD:-}" ]; then
  echo "[entrypoint] STRAPI_ADMIN_PASSWORD is empty. Refusing to boot: a Strapi instance with" >&2
  echo "[entrypoint] no administrator can be claimed by the first visitor to the public URL." >&2
  exit 1
fi
if [ -z "${STRAPI_ADMIN_EMAIL:-}" ]; then
  echo "[entrypoint] STRAPI_ADMIN_EMAIL is empty. Refusing to boot." >&2
  exit 1
fi

# Railway mounts volumes owned by uid 0 while this image runs the app as uid 1000.
mkdir -p "$UPLOAD_DIR"
chown -R "$APP_UID:$APP_GID" "$DATA_DIR"
echo "[entrypoint] volume $DATA_DIR owner=$(stat -c %u:%g "$DATA_DIR")"

# Point Strapi's local upload provider at the volume. A symlink is used rather than moving
# the mount, because the upload path is derived from the app root and is not configurable.
if [ ! -L /app/public/uploads ]; then
  if [ -d /app/public/uploads ]; then
    cp -a /app/public/uploads/. "$UPLOAD_DIR/" 2>/dev/null || true
    rm -rf /app/public/uploads
  fi
  ln -s "$UPLOAD_DIR" /app/public/uploads
fi
chown -h "$APP_UID:$APP_GID" /app/public/uploads
echo "[entrypoint] uploads -> $(readlink -f /app/public/uploads)"

# Seed (or re-apply) the administrator BEFORE the server binds the public port, so the
# first request the URL ever serves is against a claimed instance.
setpriv --reuid="$APP_UID" --regid="$APP_GID" --init-groups node /app/bin/seed-admin.js

exec setpriv --reuid="$APP_UID" --regid="$APP_GID" --init-groups npm run start

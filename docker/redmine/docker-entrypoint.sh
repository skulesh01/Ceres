#!/bin/bash
set -e

echo "[DEPRECATED] This wrapper entrypoint is no longer used."
echo "Use the upstream /docker-entrypoint.sh from redmine:5.1 instead (it handles database.yml, bundler, and migrations)."
echo "If this script is invoked directly, it will forward to the upstream entrypoint."

exec /docker-entrypoint.sh "$@"

#!/bin/bash
# Wrapper for db.sh restore command
# Kept for backwards compatibility

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/db.sh" restore "$@"

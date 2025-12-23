#!/bin/bash
# Wrapper for db.sh backup command
# Kept for backwards compatibility

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/db.sh" backup "$@"

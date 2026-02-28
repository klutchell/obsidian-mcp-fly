#!/bin/bash
set -eu

EXIT_CODE=1

shutdown() {
    echo "entrypoint: shutting down" >&2
    # shellcheck disable=SC2046
    kill $(jobs -p) 2>/dev/null || true
    wait
    exit "$EXIT_CODE"
}

# --- Oneshots (sequential, dependency order) ---

# init-data
mkdir -p /data/vault /data/.vault-sync
ln -sfn /data/.vault-sync "$HOME/.vault-sync"

# ob-setup (idempotent)
if [ ! -f /data/vault/.obsidian/sync.json ] && [ -n "${OBSIDIAN_VAULT_NAME:-}" ]; then
    echo "ob-setup: running sync-setup for vault '${OBSIDIAN_VAULT_NAME}'"
    set -- --vault "$OBSIDIAN_VAULT_NAME" --path /data/vault
    if [ -n "${OBSIDIAN_VAULT_PASSWORD:-}" ]; then
        set -- "$@" --password "$OBSIDIAN_VAULT_PASSWORD"
    fi
    ob sync-setup "$@"
fi

# --- Longruns (background, exit if either dies) ---

trap 'EXIT_CODE=0; shutdown' TERM INT

ob sync --path /data/vault --continuous &
vault-sync &

wait -n || true
echo "entrypoint: process exited unexpectedly" >&2
shutdown

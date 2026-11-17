#!/usr/bin/env bash
set -euo pipefail

# Sync OrcaSlicer user presets and app configuration between the local Flatpak
# directory and this repository's orcaslicer/ folder.
#
# Usage:
#   ./scripts/sync_orcaslicer.sh status          # Show diffs between local config and repo
#   ./scripts/sync_orcaslicer.sh local-to-repo   # Copy local OrcaSlicer config -> repo orcaslicer/
#   ./scripts/sync_orcaslicer.sh repo-to-local   # Copy repo orcaslicer/ -> local OrcaSlicer config
#   ./scripts/sync_orcaslicer.sh repo-to-local --force  # Apply even if OrcaSlicer appears open

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ORCA="${REPO_ROOT}/orcaslicer"

LOCAL_ORCA="${ORCASLICER_CONFIG_DIR:-${HOME}/.var/app/com.orcaslicer.OrcaSlicer/config/OrcaSlicer}"
LEGACY_ORCA="${HOME}/.var/app/io.github.softfever.OrcaSlicer/config/OrcaSlicer"

SUBDIRS=("machine" "filament" "process")

validate_json_dir() {
    local dir="$1"
    while IFS= read -r -d '' jf; do
        python3 -m json.tool "$jf" > /dev/null || {
            echo "ERROR: Invalid JSON in $jf" >&2
            exit 1
        }
    done < <(find "$dir" -type f \( -name "*.json" -o -name "OrcaSlicer.conf" \) -print0)
}

cmd="${1:-status}"
force="${2:-}"

if [[ ! -d "$LOCAL_ORCA" ]]; then
    echo "ERROR: Local OrcaSlicer directory not found at: $LOCAL_ORCA" >&2
    exit 1
fi

case "$cmd" in
    status)
        echo "=== Comparing Local ($LOCAL_ORCA) <-> Repo ($REPO_ORCA) ==="
        if [[ -f "${REPO_ORCA}/OrcaSlicer.conf" ]]; then
            diff -u "${REPO_ORCA}/OrcaSlicer.conf" "${LOCAL_ORCA}/OrcaSlicer.conf" || true
        else
            echo "OrcaSlicer.conf not yet in repo."
        fi
        for sub in "${SUBDIRS[@]}"; do
            if [[ -d "${REPO_ORCA}/user/default/${sub}" ]]; then
                diff -ruN "${REPO_ORCA}/user/default/${sub}" "${LOCAL_ORCA}/user/default/${sub}" || true
            else
                echo "user/default/${sub} not yet in repo."
            fi
        done
        ;;

    local-to-repo)
        mkdir -p "${REPO_ORCA}/user/default"
        cp -f "${LOCAL_ORCA}/OrcaSlicer.conf" "${REPO_ORCA}/OrcaSlicer.conf"
        for sub in "${SUBDIRS[@]}"; do
            rm -rf "${REPO_ORCA}/user/default/${sub}"
            mkdir -p "${REPO_ORCA}/user/default/${sub}"
            if [[ -d "${LOCAL_ORCA}/user/default/${sub}" ]]; then
                cp -a "${LOCAL_ORCA}/user/default/${sub}/." "${REPO_ORCA}/user/default/${sub}/"
            fi
        done
        validate_json_dir "$REPO_ORCA"
        echo "Synced local OrcaSlicer config -> ${REPO_ORCA}"
        ;;

    repo-to-local)
        if [[ "$force" != "--force" ]] && pgrep -fa "orca-slicer" > /dev/null 2>&1; then
            echo "ERROR: OrcaSlicer appears to be running. Close OrcaSlicer first so it does not overwrite files on exit, or pass --force." >&2
            exit 1
        fi
        validate_json_dir "$REPO_ORCA"
        cp -f "${REPO_ORCA}/OrcaSlicer.conf" "${LOCAL_ORCA}/OrcaSlicer.conf"
        for sub in "${SUBDIRS[@]}"; do
            mkdir -p "${LOCAL_ORCA}/user/default/${sub}"
            cp -a "${REPO_ORCA}/user/default/${sub}/." "${LOCAL_ORCA}/user/default/${sub}/"
            if [[ -d "${LEGACY_ORCA}/user/default/${sub}" ]]; then
                cp -a "${REPO_ORCA}/user/default/${sub}/." "${LEGACY_ORCA}/user/default/${sub}/"
            fi
        done
        echo "Synced ${REPO_ORCA} -> ${LOCAL_ORCA}"
        ;;

    *)
        echo "Usage: $0 {status|local-to-repo|repo-to-local [--force]}" >&2
        exit 1
        ;;
esac

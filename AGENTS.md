# Agent Instructions (`3d_printers`)

This repository tracks firmware/printer configurations and slicer profiles for `llpamies`'s 3D printers using **Jujutsu (`jj`)** and GitHub (`llpamies/3d_printers`).

## Repository Layout & Tooling

- `voron2.4/` — Klipper, Moonraker, Mainsail, KAMP, StealthBurner LEDs, and BedFans configuration for the Voron 2.4 (300mm, FYSETC Spider + BTT EBB SB CAN v1.0 + Galileo 2 + Sensorless Homing + Voron Tap).
- `orcaslicer/` — Tracked OrcaSlicer global settings (`OrcaSlicer.conf`) and custom user presets (`user/default/{machine,filament,process}/`).
- `scripts/sync_orcaslicer.sh` — Two-way diff & sync helper between the local OrcaSlicer installation and `orcaslicer/`.
- **VCS / CLI paths on this machine**:
  - Jujutsu (`jj`): `/home/llpamies/.cargo/bin/jj` (colocated Git repo)
  - GitHub CLI (`gh`): `/home/llpamies/.local/bin/gh`

---

## Syncing OrcaSlicer Between Local Config and GitHub

### 1. Local OrcaSlicer Locations

- **Active OrcaSlicer directory (source of truth — Flatpak `com.orcaslicer.OrcaSlicer`, v2.5+)**:
  `/home/llpamies/.var/app/com.orcaslicer.OrcaSlicer/config/OrcaSlicer/`
- **Legacy inactive Flatpak directory (`io.github.softfever.OrcaSlicer`)**:
  `/home/llpamies/.var/app/io.github.softfever.OrcaSlicer/config/OrcaSlicer/`
  *(Never read from the legacy path; `scripts/sync_orcaslicer.sh repo-to-local` mirrors `user/default/` presets there automatically only as a fallback.)*

### 2. What Is Synced vs. Excluded

- **Tracked in `orcaslicer/`**:
  - `OrcaSlicer.conf`
  - `user/default/machine/*.{json,info}`
  - `user/default/filament/*.{json,info}`
  - `user/default/process/*.{json,info}`
- **NEVER commit to `orcaslicer/`** *(this is a public GitHub repository)*:
  - Cloud tokens, LAN access codes, API keys, host IPs, or `.orcaslicer_machine_id`
  - Runtime/vendor/cache folders: `cache/`, `log/`, `ota/`, `orca_plugins/`, `printers/`, `python/`, `system/` (`*.opc`), `user_backup-*`, `*.lock`, `hints.cereal`
  - Always scan `jj diff` before pushing to verify no credentials or tokens were added to `OrcaSlicer.conf`.

### 3. Workflow A: Local OrcaSlicer → Repository / GitHub

When the user edits presets in OrcaSlicer locally and wants them backed up or uploaded to GitHub:

1. Fetch latest remote changes first so you base on `origin/main`:
   ```bash
   /home/llpamies/.cargo/bin/jj git fetch --remote origin
   /home/llpamies/.cargo/bin/jj new main@origin
   ```
2. Preview differences, then pull local OrcaSlicer files into `orcaslicer/`:
   ```bash
   ./scripts/sync_orcaslicer.sh status
   ./scripts/sync_orcaslicer.sh local-to-repo
   ```
3. Inspect `/home/llpamies/.cargo/bin/jj diff`:
   - Note that `OrcaSlicer.conf` frequently records benign UI state churn (`window_layout`, `window_mainframe`, `last_backup_path`, `recent_projects`). If the user only asked to sync preset changes under `user/default/`, you can restore `orcaslicer/OrcaSlicer.conf` (`jj restore orcaslicer/OrcaSlicer.conf`) to keep the commit focused.
   - Ensure no secrets/tokens appear in the diff.
4. Commit and push (either directly to `main` or via a PR bookmark):
   ```bash
   /home/llpamies/.cargo/bin/jj describe -m "Sync OrcaSlicer presets from local config"
   /home/llpamies/.cargo/bin/jj bookmark set main -r @
   /home/llpamies/.cargo/bin/jj git push --remote origin -b main
   /home/llpamies/.cargo/bin/jj new
   ```

### 4. Workflow B: GitHub / Repository → Local OrcaSlicer

When pulling changes from GitHub or applying agent edits in `orcaslicer/` to the local OrcaSlicer installation:

1. **Check if OrcaSlicer is currently open**:
   - A running OrcaSlicer instance caches presets in memory and overwrites `OrcaSlicer.conf` when closed.
   - Ask the user to close OrcaSlicer before syncing to local (or remind them to restart OrcaSlicer immediately afterward if only preset `.json` files were updated).
2. **When editing a preset `.json` file directly**:
   - Validate JSON syntax (`python3 -m json.tool <file.json> > /dev/null`).
   - Bump `updated_time = <current_unix_epoch>` in the matching `.info` file alongside the `.json` file.
3. Pull from GitHub (if needed) and sync to the local Flatpak directory:
   ```bash
   /home/llpamies/.cargo/bin/jj git fetch --remote origin
   /home/llpamies/.cargo/bin/jj new main@origin
   ./scripts/sync_orcaslicer.sh status
   ./scripts/sync_orcaslicer.sh repo-to-local
   ```

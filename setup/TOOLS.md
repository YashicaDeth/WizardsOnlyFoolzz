# Verified tools and connection

Verified 2026-09-09 Australia/Hobart.

| Tool | Location | Verification |
| --- | --- | --- |
| Godot 4.7.2 | P:/GameDev/Tools/Godot-4.7.2 | Official release checksum and executable signature; project import and technical scene completed successfully. |
| Node 24.20.0 | P:/GameDev/Tools/node-v24.20.0-win-x64 | Official checksum, executable signature and version output. |
| Godot MCP 4.1.11 | P:/GameDev/Tools/godot-mcp | Pinned npm install with lifecycle scripts disabled; 21 tools advertised; live project identity, editor state, matching addon version and no editor errors confirmed. |
| Blender 5.2.1 LTS | C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe | Existing installation starts in background; bpy and glTF export operator available. No artwork created or altered by this check. |

## Using the project

Open P:/GameDev/AllusionsTooGrandeur as the Codex project folder. Open game/project.godot with the portable Godot executable, or use Start-Editor.ps1. The desktop Godot shortcut points directly at the same project. Start-Blender.ps1 opens the existing Blender. Author .blend files in art/blender and exchange exported assets through art/exports and game/assets.

Codex's global MCP entry is named `allusions-godot`. It runs the pinned package's dist/cli.js through the P: Node executable. The index.js file only exports the server function and must not be used as the executable entry point.

The editor addon listens on 127.0.0.1:6550. Keep one editor for this project on that port. The tool-list and live connection checks were performed by a separate MCP test client; they do not prove the current Codex conversation has refreshed its native tool list. Reconnect the server through MCP settings, or restart Codex if needed.

The temporary headless editor used during setup is stopped when setup completes. Open the project normally before working with the bridge. No background game-production goal or recurring automation was started during setup.

## Storage

Godot portable/self-contained mode keeps editor settings and cache beside its executable on P:. Launcher processes use P:/GameDev/Temp for TEMP/TMP. npm's package cache is P:/GameDev/Cache/npm. Godot's game user-data directory still defaults to C:/Users/Greg/AppData/Roaming/Godot/app_userdata/AllusionsTooGrandeur; only the tiny setup-game log was written there. Changing game-save placement can be designed explicitly when persistence is implemented.

## Reproducing the development bridge

The bridge package is recorded in P:/GameDev/Tools/godot-mcp/package.json and package-lock.json. The local addon is deliberately not tracked as authored game source. To restore a missing addon, run Node with the pinned package's dist/cli.js and `--install-addon P:/GameDev/AllusionsTooGrandeur/game`, then enable Godot MCP in Godot's plugin settings. Re-check versions after any update.

The addon adds an MCPGameBridge autoload for development. Remove the development autoload and plugin, and exclude the addon from shipping builds. No shipping export is configured yet.

## Evidence

setup-state.json in P:/GameDev records verified executable paths. This folder contains mcp-verification.json, mcp-schemas.json, blender-verification.json and logs. The before-change Codex configuration backup is under P:/GameDev/Backups; it is local configuration data, not game content.

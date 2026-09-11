# Game tool installation - 9 September 2026

## Installed and verified

| Tool | Version / location | Verification |
| --- | --- | --- |
| Blender MCP | Python package 1.9.1; P:/GameDev/Tools/blender-mcp | Enabled in Blender 5.2.1 preferences; MCP advertises 28 tools; live startup scene read succeeded. Telemetry disabled in Codex server configuration. |
| Context7 MCP | 4.0.6; P:/GameDev/Tools/web-mcp | Tool handshake and public Godot documentation lookup succeeded without an API key. |
| Playwright MCP | npm package 0.0.80; P:/GameDev/Tools/web-mcp | 24 tools advertised. Chromium v1243 and helper binaries installed under P:/GameDev/Cache/playwright. Configured headless with an isolated browser session. No website interaction test performed in this installation run. |
| LimboAI | 1.8.1 GDExtension release for Godot 4.6+ | Godot 4.7.2 import and Blackboard state-storage test passed. |
| Dialogue Manager | 4.1.0 | Enabled with its required DialogueManager autoload; script compilation test passed. |
| gdUnit4 | 6.2.1 | Ran all three installation tests: zero errors, failures, skipped tests or orphans. |
| Terrain3D | 1.0.2-stable | Enabled; native Terrain3D and Terrain3DData registration tests passed. Terrain rendering has not been tested. |
| Proton Scatter | 4.2.0, upstream commit 2ced25f1ebef13648e94d3cc6a643da92a7e33d8 | Current upstream revision imports and compiles. Older 4.0 release was rejected for a Godot 4.7 parse error. Demo assets were excluded from the game install. |
| Git LFS | Existing 3.7.0 | Local game-repository hooks initialized and asset/native-binary patterns added to .gitattributes. No commits, pushes or history migration performed. |

Godot add-ons are under P:/GameDev/AllusionsTooGrandeur/game/addons. The existing technical startup scene still runs and prints ALLUSIONS_SETUP_OK. This verifies installation, not completion of game mechanics.

## Installed with limits

- **FMOD Godot integration 6.1.0-4.5.0:** installed; native runtime initializes and releases successfully. Its editor plugin stays disabled because the shipped editor panel calls a nonexistent `FmodServer.get_all_banks` method. FMOD Studio and sound banks are not installed; the user has no FMOD account yet. Do not enable the panel until this mismatch is resolved.
- **Figma and Google Drive:** existing Codex plugins confirmed installed and enabled. Their connector tools were not available in this task, so connector account access was not verified. Google Drive browser access was verified through the user's signed-in Brave Work profile.
- **Trello:** official server configured at https://mcp.trello.com/v1. OAuth reaches the signed-in Atlassian consent page, but it reports "No workspace available" and disables Accept. Create or join the intended Trello workspace, then run `codex mcp login trello` and choose it. No account token was copied from the browser.
- **Aseprite:** not installed. User confirmed they do not own it; no purchase was made. Official binary download: https://www.aseprite.org/buy/ .
- **FMOD Studio:** not installed. Account/download workflow: https://www.fmod.com/download .

## Using the connections

Codex server names: allusions-blender, context7, playwright, trello. The existing allusions-godot connection is preserved. Refresh MCP connections or restart Codex to load newly configured tools into a conversation. Blender must be running for interactive modelling; its enabled add-on starts the local bridge. P:/GameDev/AllusionsTooGrandeur/Start-Blender.ps1 opens the existing Blender installation.

Godot animation, navigation and profiling tools are included with the existing engine; no additional install is needed. Additional third-party model/asset services exposed by Blender MCP still require their own accounts and were not activated.

## Reproducibility and recovery

- npm versions and dependencies: P:/GameDev/Tools/web-mcp/package.json and package-lock.json.
- Python dependencies: P:/GameDev/Tools/blender-mcp/requirements-lock.txt.
- Release archives: P:/GameDev/Downloads/PluginSetup. Published GitHub release digests were checked when provided; source archive hashes were recorded in the installation output.
- Config and planning-document backups: P:/GameDev/Backups/plugin-install. Keep that folder private; configuration backups may contain local settings.
- Godot test: game/tests/tooling/plugin_installation_test.gd; reports: game/reports (ignored by Git).
- Installation evidence and scripts: this plugin-setup folder. Temporary validation project and engine logs: P:/GameDev/Temp.

## Latest design clarification

Fallout-like third-person play with a player-controlled first-person toggle replaces the old forced-perspective-by-world rule. Combat, loot, economies and distinct factions are central pillars alongside persistent bounty/rival characters. This clarification is recorded at the top of DESIGN.md, MECHANICS.md, PLAN.md and BOUNTY_SYSTEM.md. Earlier exported PDFs predate this clarification.

## Official / upstream sources

- https://github.com/ahujasid/blender-mcp
- https://github.com/upstash/context7
- https://github.com/microsoft/playwright-mcp
- https://github.com/limbonaut/limboai
- https://github.com/nathanhoad/godot_dialogue_manager
- https://github.com/godot-gdunit-labs/gdUnit4
- https://github.com/TokisanGames/Terrain3D
- https://github.com/HungryProton/scatter
- https://github.com/utopia-rise/fmod-gdextension
- https://github.com/atlassian/trello-mcp-server
- https://learn.chatgpt.com/docs/extend/mcp?surface=cli

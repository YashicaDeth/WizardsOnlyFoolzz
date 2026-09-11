# AllusionsTooGrandeur

Working title. A single-player experimental action RPG, with one character crossing between two worlds. This folder is the source of truth for development.

## Setup status

The initial scene is a technical connection test. It is not the game's final visual direction or a combat prototype.

- `DESIGN.md`: confirmed preferences, inspirations, proposals and open questions.
- `MECHANICS.md`: the complete 25-part mechanics recap.
- `PLAN.md`: proposed build sequence and open decisions.
- `game/project.godot`: Godot project.
- `Start-Editor.ps1`: opens the project using the portable Godot installation on P:.
- `Start-Game.ps1`: runs the connection scene.
- `Start-Blender.ps1`: opens the existing Blender installation.
- `setup/`: tool configuration and verification records.

Godot, Node, the MCP package, editor caches and setup logs are under `P:\GameDev`. Godot's default small game-save directory is currently under the Windows user profile on C:. Use the existing Blender 5.2.1 LTS installation through Steam for authored assets and scripted asset processing.

Godot 4.7.2 imported and ran the technical scene. The Godot MCP 4.1.11 addon and server passed a live identity/state/error check and are registered in Codex as `allusions-godot`. Reconnect that server in Codex or restart Codex if its tools are absent. Keep this Godot project open while using the bridge. See `setup/TOOLS.md` for details.

Keep this repository and project open for long sessions. The next gameplay milestone is proposed in `DESIGN.md`; it has not been implemented yet.

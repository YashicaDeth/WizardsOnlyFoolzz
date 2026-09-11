# Active game tool profile

The live project at `P:\GameDev\AllusionsTooGrandeur\game` has the following editor integrations enabled:

- Godot MCP bridge for editor-assisted inspection only; it is excluded from release builds.
- Dialogue Manager for authored conversations.
- gdUnit4 for gameplay and regression tests.
- Terrain3D for the environment production pipeline.
- Proton Scatter for efficient authored set dressing.

LimboAI is installed as a runtime extension for character behaviour. FMOD is installed as a runtime integration, but its editor panel remains disabled until its upstream API mismatch is fixed and FMOD Studio/banks are available. This is intentional: enabling a broken panel would make the editor less reliable.

The remaster showcase does not require these dependencies, so it runs in the workspace copy and remains easy to validate. When promoted to the live project, retain the existing add-on settings instead of duplicating plug-ins.

# Project instructions

Read `DESIGN.md` before changing gameplay or creative direction. Keep user requirements distinct from assistant proposals and open decisions.

This is a Godot project with a technical startup scene, not an implemented game. Prefer GDScript and normal scene/resource files. Use Blender for authored assets and scripted processing when useful. Preserve Greg's artwork and preference for intentional content over generic generated imagery.

Keep dependencies pinned, avoid overlapping editor bridges, and verify changes in the engine. Use small, relevant automated checks plus visual/interaction checks where needed. Report actual validation and unresolved limits.

Keep large tool, temporary, cache and build files under `P:\GameDev`. Do not move or delete unrelated personal files. Do not change global machine or Codex permissions as a shortcut around the current sandbox.

Do not install project development bridges into release builds. Keep design notes updated as user decisions arrive.

Project skills live in `.claude/skills/` (Agent Skills format; each is a folder with a `SKILL.md`). Read the matching one before working: `wof-lane-hygiene` before any edit or commit, `wof-verify-by-looking` for anything visual, `wof-wire-before-polish` before improving a system, `wof-agent-brief` when dispatching work to another agent, `wof-combat-fx` for any fighting visual or sound.

# Planning and build sequence

## Latest user direction - 9 September 2026

This clarification supersedes earlier forced-camera rules below: the game should feel Fallout-like in third person, with a player-controlled switch to first person and back. Combat and loot systems are central pillars alongside economies, distinct factions, and the persistent bounty/rival system. Keep one protagonist and the two-world concept unless the user changes them; camera choice is no longer tied to a realm. Exact faction names, economy rules, weapon balance and loot progression remain design decisions, not approved implementations.

Current state: concept planning and local tool setup. A technical test scene is not a gameplay prototype.

1. **Establish the world rules.** Review MECHANICS.md with Greg. Set realm identity, transition rules, death, consequences and the level of survival pressure. Pick a repeatable short player loop.
2. **Movement and perspective trial.** One player traverses two small spaces with forced first- and third-person controls. Decide camera, accessibility, transition behaviour and which state carries across.
3. **Combat and body trial.** One weapon and one enemy, accurate contact and readable reactions. Then one persistent injury. Tune the feel before expanding anatomy or visual gore.
4. **Persistent character trial.** Give that opponent an identity, relationship history, a rivalry/bounty rule and save/load. Make the shared world history reliable before simulating many people.
5. **Home and relief.** A small safe space, one decoration interaction and one friendly character. Test whether the violent world still feels welcoming to return to.
6. **Blender art pass.** Keep editable .blend sources under art/blender; export reusable assets under art/exports; import approved exports into game/assets. Begin with a small environment kit and a simple character/weapon set once the visual direction is chosen. Use Greg's work to drive materials, shapes and iconography.
7. **A compact vertical slice.** Connect exploration, combat, a rival, one discovery in the book and returning home. Measure frame time, save correctness and playability on this machine.
8. **Separate feasibility studies.** Driving/crash damage, larger follower groups, economy simulation and future multiplayer each need their own bounded experiment before committing the main game to them.

The sequence is an assistant proposal for review. It preserves the large design while giving each session an achievable result. No automatic long-running game-production goal has been started by this document.

## Tools

- Godot 4.7.2 portable and Node 24.20.0 live under P:/GameDev/Tools.
- Blender is already installed through Steam; use its verified local executable rather than downloading another copy.
- Blender can be operated through authored Python scripts for repeatable modelling/export work. That does not imply general desktop control.
- Godot MCP 4.1.11 is installed, enabled in this project, registered in Codex as allusions-godot and verified through a live protocol client. The current Codex conversation may still need an MCP reconnect before those tools appear natively.

## Bounty-centred planning update - 2026-09-09

Use BOUNTY_SYSTEM.md as the organising design for the existing build sequence. Define a target's stable identity and event history alongside the two-world movement trial, then connect combat to one persistent injury and a return encounter. The first full Hunt slice should demonstrate one issuer, one target, one friendly witness, one contract, one changed artwork and correct save/load. These scope details remain proposals; the user has confirmed that bounties and persistent rivals are the game's centre.

The full economy, large follower groups, derby physics and multiplayer remain separate later studies. Do not treat installed tools or this roadmap as proof that the game has been implemented.

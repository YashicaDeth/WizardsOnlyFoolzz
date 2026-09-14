# Inventory architecture — surviving field notes

Written 2026-09-14. These are the raw findings of a read-only survey run before
any inventory code was written, so that the new inventory consumes what already
exists instead of inventing a parallel item model beside it.

**Provenance, stated honestly:** a thirteen-agent survey was dispatched (seven
subsystem readers, three competing architectures, three adversarial judges).
Twelve of the thirteen died on a session rate limit. Exactly one reader returned
— the one covering *what a carried thing actually is*. What follows is that
reader's map, preserved verbatim rather than paraphrased, because it is accurate
and expensively obtained. It is NOT a complete architecture: the carry page, the
device shell, the body inspector, input/HUD layering, the substance use-chain and
the save schema were never surveyed, and no design was chosen or judged.

**Do not treat this as a plan.** It is ground truth about one corner. The
remaining six readers and the design/judge passes still need to run.

**The single most important rule it establishes**, quoted from
`implant_catalog.gd`'s own docstring: *"Names are identifiers, never parsing
input: nothing guesses a zone from the words 'jaw', 'arm' or 'lung' anymore."*
An inventory that parses item names to decide what they are would reintroduce a
bug this project already deleted once, and `body_inspector_test.gd` asserts
against it.

---

## SUBSYSTEM

Item identity: what a carried thing IS (implant_catalog / wound_catalog / gore_chunks / extraction, plus the carry.gd model they feed and the handheld page that draws it)

## FILES READ

- P:\GameDev\AllusionsTooGrandeur\game\systems\implant_catalog.gd
- P:\GameDev\AllusionsTooGrandeur\game\systems\wound_catalog.gd
- P:\GameDev\AllusionsTooGrandeur\game\systems\gore_chunks.gd
- P:\GameDev\AllusionsTooGrandeur\game\systems\extraction.gd
- P:\GameDev\AllusionsTooGrandeur\game\systems\carry.gd
- P:\GameDev\AllusionsTooGrandeur\game\systems\part_viewer.gd
- P:\GameDev\AllusionsTooGrandeur\game\systems\anatomy_component.gd (lines 1-120, 270-360, 425-455)
- P:\GameDev\AllusionsTooGrandeur\game\systems\handheld_device.gd (lines 380-420, 920-1145)
- P:\GameDev\AllusionsTooGrandeur\game\systems\substances.gd (lines 1-120)
- P:\GameDev\AllusionsTooGrandeur\game\systems\world_history.gd (lines 390-500, signature scan)
- P:\GameDev\AllusionsTooGrandeur\game\systems\body_inspector.gd (lines 180-290)
- P:\GameDev\AllusionsTooGrandeur\game\systems\run_lifecycle.gd
- P:\GameDev\AllusionsTooGrandeur\game\bone_yard_hunt.gd (lines 1990-2020, 2120-2245, 2270-2340)
- P:\GameDev\AllusionsTooGrandeur\game\tests\chunk_test.gd (lines 80-180)
- P:\GameDev\AllusionsTooGrandeur\game\tests\extraction_test.gd (via grep)
- P:\GameDev\AllusionsTooGrandeur\game\tests\body_inspector_test.gd (via grep)

## WHAT IT DOES

Four files define what a carried thing IS, and they are deliberately layered so that identity never has to be guessed from text.

IMPLANT_CATALOG (`extends RefCounted`, no class_name — every consumer does `const ImplantCatalog := preload("res://systems/implant_catalog.gd")`) is the authored hardware table. 21 `ENTRIES` keyed by the lowercase piece of hardware's own name ("rangefinder eye", "blackbox liver", "ashline industrial arm", "scrying ball"…), each `{zone, profile, armor, max_condition, tint}`. Its docstring is the subsystem's law: "Names are identifiers, never parsing input: nothing guesses a zone from the words 'jaw', 'arm' or 'lung' anymore." `resolve()` on an unknown name returns the generic salvage entry at `forced_zone` or torso — it does NOT sniff the string. `body_inspector_test.gd:36` locks this in: `ImplantCatalog.resolve("mystery arm words").zone == "torso"` — "unknown hardware does not regain the deleted keyword guesser."

WOUND_CATALOG is the same pattern for legacy prose wounds (14 `ENTRIES` keyed by lowercase prose: "missing left eye", "spore-burned right lung"), `{zone, type, severity, optional organ, optional bone}`. Combat wounds already arrive as dictionaries from AnatomyComponent; this table only migrates authored/story strings. Wounds are NOT carryable — they live on bodies — but they are what the subject a carried part came off is described by, so an inventory that names a provenance subject goes through `WoundCatalog.label()`, never through raw text.

GORE_CHUNKS (`class_name GoreChunks`) is the physical identified object. A hit does not spray generic red; it reaches a `Layer` and sheds one chunk per layer it went through, each a `RigidBody3D` carrying a `"chunk"` meta dictionary that says its layer, its zone, the `subject_id` it came off, and — only if the body actually had one there — which organ or which implant. `_make_chunk` returns null for `Layer.ORGAN` with an empty `organ_id` and for `Layer.CYBERNETIC` with an empty `implant`, with the comment: "Inventing an organ or a piece of hardware that was never installed would make every downstream system — loot, rituals, the economy — lie." A severed whole limb registers through the same contract with `layer: -1, layer_name: "limb", whole_limb: true`.

EXTRACTION (`class_name Extraction`) is the deliberate counterpart: robbing a part off a body that has not shed it. It is a pure function library — "Nothing here touches the scene. It is handed a snapshot and a delta and hands back numbers, plus — on completion — a dictionary in exactly the shape `Carry.take_chunk()` already accepts." It ranks what is worth opening, prices the dig in layers × seconds ÷ tool speed, damages what comes out by tool, and attaches the `lien`.

CARRY (`class_name Carry`) is where those become inventory items. `handheld_device.gd` already draws them (`_draw_carry` / `_draw_carried`) as objects in a sagging bag, sized by mass, tinted by freshness, ringed gold when liened, with a paper tag on a string bearing the previous owner's name.

## PUBLIC API

- ImplantCatalog.resolve(raw: Variant, forced_zone := "") -> Dictionary  # returns {id, name, zone, profile, armor, max_condition, condition, tint, ...supplied}
- ImplantCatalog.list(raw: Variant) -> Array[Dictionary]  # Array -> resolve each; Dict with id/name -> one; Dict otherwise -> zone->part map, key passed as forced_zone
- ImplantCatalog.by_zone(raw: Variant) -> Dictionary  # zone_id -> resolved implant
- ImplantCatalog.label(raw: Variant) -> String
- ImplantCatalog.ENTRIES  # 21 authored, keyed lowercase name
- WoundCatalog.resolve(raw: Variant) -> Dictionary  # Dict passthrough shapes label/zone/severity; String -> catalog lookup + id + label
- WoundCatalog.list(raw: Variant) -> Array[Dictionary]  # Array ONLY; anything else returns []
- WoundCatalog.label(raw: Variant) -> String
- GoreChunks.enum Layer {SKIN=0, FAT, MUSCLE, BONE, ORGAN, CYBERNETIC=5}
- GoreChunks.LAYER_NAMES := ["skin","fat","muscle","bone","organ","cybernetic"]
- GoreChunks.LAYER_TINTS: Layer -> bare hex String (no '#'); GoreChunks.ORGAN_TINTS: organ_id -> hex
- GoreChunks.identify(node: Node) -> Dictionary  # {} for anything that is not a chunk, so a raycast hit can be tested without a class check
- GoreChunks.take(node: Node) -> Dictionary  # returns identity, frees node, one-shot via the 'taken' flag. THIS is the pick-up seam
- GoreChunks.register_whole_limb(node: RigidBody3D, zone: String, subject_id: String) -> Dictionary
- GoreChunks.burst(host: Node3D, origin: Vector3, heading: Vector3, info: Dictionary, detail: float = 1.0) -> Array
- GoreChunks.depth_for(damage: float, damage_type: String, health_ratio: float) -> int
- GoreChunks.from_subject(subject_id: String) -> Array  # everything on the floor off one person; calls prune()
- GoreChunks.rot_ratio(node: Node) -> float  # 0..1 over ROT_SECONDS := 240.0
- GoreChunks.scent_sources() -> Array[Dictionary]  # [{position: Vector3, strength: float}] for ratio > 0.5
- GoreChunks.impact_profile(layer: int) -> Dictionary  # {freq, noise, decay, gain, character: slap|crack|burst|fault}
- GoreChunks.impact_sample(profile: Dictionary, t: float, noise: float) -> float
- GoreChunks.play_impact(host: Node3D, at: Vector3, layer: int) -> void
- GoreChunks.hold() / release() / prune() / clear() / live_count() -> int ; static var live: Array[Node3D]; MAX_CHUNKS := 90
- Extraction.profile(tool: String) -> Dictionary  # {speed, damage, label}
- Extraction.tool_for(weapon_id: String, carried: Array) -> String  # "surgical" | "blade" | "hands"
- Extraction.robbable_zones(anatomy: Dictionary, exposure: Dictionary = {}) -> Array[Dictionary]  # [{zone, kind, label, worth, organ_id?}] richest first
- Extraction.target_layer(anatomy: Dictionary, zone_id: String, organ_id := "") -> int  # -1 = nothing there, not diggable
- Extraction.required_seconds(anatomy, zone_id, tool, already_open := 0, organ_id := "") -> float
- Extraction.begin(subject_id, anatomy, zone_id, tool, already_open := 0, organ_id := "") -> Dictionary  # the session
- Extraction.dig(session: Dictionary, delta: float) -> Dictionary  # mutates in place, returns it so a meter needs no second call
- Extraction.reached_layer(session: Dictionary) -> int
- Extraction.extract(session: Dictionary, anatomy: Dictionary) -> Dictionary  # Carry.take_chunk()'s exact shape, with lien
- Extraction.strip_from_rig(rig: Node, extracted: Dictionary) -> void
- Extraction.notice(ledger: WitnessLedger, extracted: Dictionary, at: Vector3, candidates: Array, owner_alive: bool, location := "") -> Dictionary  # {witnesses: Array, stolen: bool}
- Carry.take_chunk(info: Dictionary) -> Dictionary  # the ONLY funnel from piece-of-a-person to inventory item
- Carry.take_substance(substance_id: String, stolen := false) -> Dictionary
- Carry.take_from_subject(subject_id: String) -> Dictionary  # lifts a subject's carried_substance, always stolen
- Carry.sale_value(item: Dictionary, buyer_faction: String = "") -> int  # 0 means worthless OR refused
- Carry.sell(index: int, buyer_faction: String = "") -> Dictionary  # {} | {refused, faction, disposition} | {item, price, wallet, faction, disposition}
- Carry.install_into(index: int, rig: BaselineHuman) -> Dictionary
- Carry.damage_item(index: int, amount: float) -> float ; drop(index) -> Dictionary ; first_index(kind: String) -> int
- Carry.total_mass() -> float ; burden() -> float (0..2 against CAPACITY := 28.0)
- Carry.freshness(item) -> float ; condition_label(item) -> String  # KEEPS | FRESH | TURNING | SPOILED | ROTTEN
- Carry.age(delta: float) -> void  # driven externally; time must not pass inside a menu
- Carry.debt_to(lender_faction) -> int ; borrow(amount, lender) -> Dictionary ; repay(amount, lender) -> Dictionary
- Carry.items: Array  # public, mutable, plain Array of Dictionaries
- AnatomyComponent.pull_part(zone_id: String, confirmed := false) -> Dictionary  # {ok, reason, warning} | {ok, info:{subject_id, zone, implant, condition, lien:"celloutz"}}
- AnatomyComponent.install_part(zone_id: String, part_data: Dictionary) -> Dictionary
- AnatomyComponent.implant_condition_ratio(part: Dictionary) -> float ; implant_condition(zone_id) -> float
- AnatomyComponent.snapshot() -> Dictionary  # {dose, worn, blood, zones, organs, wounds, cybernetics, ...} — what Extraction is handed
- PartViewer(SubViewport).show_part(part: Dictionary, state: float) -> void  # part = {kind, id, zone}, kind in {organ, bone, limb, implant}; state = condition 0..1
- BaselineHuman.exposed_layer(zone_id: String) -> int ; mark_opened(zone_id: String, layer: int) -> int ; var zone_depth: Dictionary

## DATA SHAPES

A. GORE CHUNK meta, `node.get_meta("chunk")` — TWO shapes, and the difference matters:

  normal chunk (`_make_chunk`, gore_chunks.gd:209):
    {"layer": int 0-5, "layer_name": String, "zone": String, "subject_id": String,
     "organ_id": String ("" unless layer==ORGAN), "implant": String ("" unless layer==CYBERNETIC),
     "taken": false, "spawn_msec": int}
    -> NO "condition", NO "lien", NO "whole_limb".

  whole limb (`register_whole_limb`, gore_chunks.gd:69):
    {"layer": -1, "layer_name": "limb", "whole_limb": true, "zone": String, "subject_id": String,
     "organ_id": "", "implant": "", "condition": 1.0, "taken": false, "spawn_msec": int}

B. EXTRACTED PART, `Extraction.extract()` return (extraction.gd:202) — "in Carry.take_chunk()'s shape":
    {"layer": int, "layer_name": String, "zone": String, "subject_id": String,
     "organ_id": String, "implant": String,
     "condition": float 0..1  (already condition_ratio MINUS tool_profile.damage),
     "lien": String (== subject_id),
     "tool": String, "taken": true, "spawn_msec": int}
    -> NO "stolen". The caller adds it from Extraction.notice().

C. PULLED FACTORY PART, `AnatomyComponent.pull_part().info` (anatomy_component.gd:322):
    {"subject_id", "zone", "implant": name-or-id, "condition": float 0..1, "lien": "celloutz"}

D. CARRY ITEM from `take_chunk` (carry.gd:79) — the shape an inventory renders:
    {"label": String UPPERCASE,      # "SEVERED RIGHT ARM" | "RANGEFINDER EYE" | "LEFT LUNG" | "MUSCLE (TORSO)"
     "kind": String,                 # the LAYER NAME: skin|fat|muscle|bone|organ|cybernetic|limb
     "mass": float,                  # Carry.LAYER_MASS: skin .3 fat .6 muscle 1.4 bone 1.1 organ .9 cybernetic 2.2 limb 5.5
     "perishes": bool,               # Carry.LAYER_PERISHES: bone and cybernetic false, everything else true
     "age": float seconds,
     "from": String subject_id,      # PROVENANCE — whose body
     "zone": String, "organ_id": String, "implant": String, "whole_limb": bool,
     "condition": float 0..1,        # RATIO here, not points
     "lien": String,                 # CLAIM — whose it still legally is ("" for a floor pickup, "celloutz" for factory)
     "stolen": bool}

E. CARRY ITEM from `take_substance` (carry.gd:122):
    {"label": "MARROW DUST — FEMUR CUT (BAGGIE)", "kind": "substance", "substance_id", "form" (baggie|weight|tab),
     "strain": String, "potency": float 0.7-1.3, "mass": 0.2, "perishes": true, "age", "condition": 1.0, "stolen"}

F. LEGACY / UNTYPED item (carry.gd:57, produced when a bare String is found in persisted items):
    {"label", "kind": "goods", "mass": 0.5, "perishes": false, "age": 0.0}
    -> NO from, NO zone, NO condition, NO lien. Worth 0.

G. IMPLANT CATALOG entry / `resolve()` return:
    {"id": lowercase name, "name": String, "zone": String, "profile": String, "armor": float,
     "max_condition": float, "condition": float IN POINTS clamped to max, "tint": bare hex String}
    profiles in use: limb_drive bellows meter jaw_nail bone_rail spine_cage digit_tool optic chest_plate
    optic_spool joint_dial filter_stack regulator joint_anchor surgical_crown organ_box pulse_cage
    industrial_limb orb scrap_limb salvage(fallback)

H. WOUND record / `WoundCatalog.resolve()` return:
    {"id": lowercase, "label": original-case String, "zone", "type" (chemical|blunt|cut|sever|graft|puncture|burn|legacy),
     "severity": float 0..1, optional "organ", optional "bone"}

I. EXTRACTION SESSION (`begin()`):
    {"subject_id", "zone", "organ_id", "tool", "progress": float, "required": float seconds,
     "target": int Layer, "opened_from": int, "complete": bool}
    bone_yard_hunt also stuffs "display_name" in afterwards.

J. ROBBABLE TARGET (`robbable_zones()` element):
    {"zone", "kind": "cybernetic"|"organ", "label", "worth": float, "organ_id": present only for organs}
    worth = 24.0 * condition_ratio for hardware, 12.0 * health_ratio for an organ.

K. PERSISTED INVENTORY, `WorldHistory.subject("inventory")`:
    {"items": Array of D/E/F, "rust_scrip": int, "player_debt": {faction_id: int}}

## INTEGRATION POINTS

- `Carry.take_chunk(info)` is the single funnel. Anything entering the bag goes through it — never append to `Carry.items` directly. `bone_yard_hunt.gd:2007` (floor pickup) and `:2224` (extraction) both do exactly this.
- `GoreChunks.identify(node)` to ask what a raycast hit is without a class check; `GoreChunks.take(node)` to lift it. `take()` returns the dictionary rather than the node on purpose — that IS the B5 seam.
- `handheld_device.gd` owns the live `Carry` instance as `carry` and drives it: `carry.age(delta)` at line 511, `step_carry(by)` moves `carry_index`, `pin_selected_part()` emits `pin_requested.emit("part:%s@%s" % [label, from], "cutting", label)`. A replacement inventory page slots in at `_draw_carry(rect, alpha)` and inherits `carry_index` and `MODES`.
- `part_viewer.gd` (`SubViewport`) already renders one part in real authored 3D: `show_part({kind, id, zone}, condition)`. This is the honest per-item renderer and it is currently only used by `body_inspector.gd`. Reusing it from the inventory is the obvious upgrade — but note the vocabulary gap: PartViewer wants `kind == "implant"` and an `id`, while Carry stores `kind == "cybernetic"` and the name under `implant`. `body_inspector_test.gd:107` shows the adapter: `ImplantCatalog.resolve(name).merged({"kind": "implant"}, true)`.
- `Extraction.tool_for(weapon_id, carry.items)` reads `str(entry.get("label", entry)).to_lower()` and substring-matches it against `SURGICAL_GOODS`. Carried item LABELS are therefore load-bearing gameplay data, not decoration.
- `Carry.first_index(kind)` is how the hunt finds things: `bone_yard_hunt.gd:2275` `first_index("limb")` to wield a limb as a weapon; `:2329-2333` falls through limb -> organ -> cybernetic for the quick-sell key. A new inventory that lets the player pick explicitly should route to `sell(index, faction)` / `install_into(index, rig)` with a real index.
- `Carry.sale_value(item, buyer_faction)` and `sell()` — display price must be per-buyer. `sell()` distinguishes worthless (`{}`) from refused (`{"refused": true, "faction", "disposition"}`) and an honest UI must show that difference.
- `Carry.install_into(index, rig)` is the put-it-in-your-own-body verb; it re-resolves through `ImplantCatalog` to convert the 0..1 ratio back into points and calls `rig.install_prosthetic(zone, {name, condition})`.
- `WorldHistory.update_subject("inventory", {...}, event_type)` / `WorldHistory.subject("inventory")` — the only persistence path. `WorldHistory.record_event(type, details)` for the log.
- `AnatomyComponent.pull_part(zone_id, confirmed)` already returns a `take_chunk`-shaped `info` with a lien, and gates locked factory parts behind `LOCKED_WARNING := "you don't want to go rogue yet, do you"` — a first call only warns, the caller must ask again with `confirmed`. Any inventory that offers 'remove my own hardware' must honor the two-step.
- `BaselineHuman.exposed_layer(zone)` / `zone_depth` feed `Extraction`'s exposure tiebreak and the dig's `already_open`. `rig.mark_opened(zone, Extraction.reached_layer(session))` is called every dig tick so a half-finished rob is visible on the body.

## GOTCHAS

- NAMES ARE IDENTITIES AND ARE NEVER PARSED. `implant_catalog.gd` line 3: 'Names are identifiers, never parsing input: nothing guesses a zone from the words "jaw", "arm" or "lung" anymore.' A keyword guesser was deleted and a test guards the grave (`body_inspector_test.gd:36`). Never infer zone, layer, organ or kind from an item's label — read `zone`/`organ_id`/`implant`/`kind` off the dictionary. The ONE substring match left in the subsystem is `Extraction.tool_for()` matching carried labels against `SURGICAL_GOODS`/`BLADE_WEAPONS`, and that is a goods lookup, not anatomy inference — but it does mean renaming item labels silently breaks surgical-tool detection.
- CONDITION HAS TWO UNITS. On an installed implant (`AnatomyComponent.installed_parts`, `ImplantCatalog` entries) `condition` is ABSOLUTE POINTS against `max_condition` (up to 180.0 for the ashline industrial arm). On a carried item it is a RATIO 0..1. `Extraction.extract()` does the division; `Carry.install_into()` multiplies back by `catalogue.max_condition`. Show a raw implant `condition` in a carried-item slot and you print '145%'.
- A FLOOR CHUNK HAS NO CONDITION AND NO LIEN. `_make_chunk` writes neither, so `Carry.take_chunk` defaults `condition` to 1.0 and `lien` to "". Only `Extraction.extract()` (lien = the victim's subject_id) and `AnatomyComponent.pull_part()` (lien = "celloutz") ever set one. `from` (who it came off) and `lien` (whose claim survives) are genuinely different facts and must be displayed as two different things — the handheld already does: a paper tag on a string for `from`, a gold ring plus 'OWED' for `lien`.
- `Extraction.extract()` DOES NOT SET `stolen`. The caller must: `bone_yard_hunt.gd:2222` does `extracted["stolen"] = bool(seen.get("stolen", false))` from `Extraction.notice()`. And `notice()` computes `stolen = not witnesses.is_empty() or owner_alive` — robbing a LIVING downed person is always stolen even with nobody watching. `Carry.sale_value` reads it as a flat 0.62 heat multiplier.
- `ImplantCatalog.resolve()` does `result.merge(supplied, true)` — SUPPLIED DATA OVERRIDES THE CATALOG. A saved dictionary with a stale `zone` or `armor` wins over the authored entry. Only `id`, `name`, `zone` fallback and the condition clamp are re-forced after the merge.
- MOST OF THE BAG IS WORTH NOTHING. `Carry.sale_value` base table is `{limb: 7, organ: 12, cybernetic: 24, substance: 3}` and returns 0 immediately for skin, fat, muscle, bone and goods — before condition or freshness is even consulted. An inventory must say 'no price' rather than quoting 1 scrip.
- TWO ROT CLOCKS THAT DO NOT TALK. `GoreChunks.ROT_SECONDS := 240.0` runs on the floor; `Carry.SPOIL_SECONDS := 420.0` runs in the bag; `take_chunk` sets `age: 0.0`. A fully rotted chunk with flies on it becomes FRESH loot the moment you pick it up. Real honesty gap, currently unaddressed.
- `GoreChunks.live` IS STATIC AND OUTLIVES SCENES. The AG1.6 comment (gore_chunks.gd:222) documents the crash: leaving the derby freed every chunk and the Hunt Grounds inherited dangling entries, then the first thing to walk the list handed a freed object to a typed parameter and threw. Everything that walks `live` must call `prune()` first. `scent_sources()` also has a load-bearing ordering comment: validity is checked BEFORE calling `rot_ratio`, because GDScript rejects a freed object at the typed call site so a guard inside the callee never runs.
- STALE COMMENT IN THE EXISTING UI. `handheld_device.gd` line ~1013 says 'Carry files layer names as kinds, so a severed arm arrives as "muscle" with whole_limb set' and then forces `kind = "limb"`. That is no longer true — `register_whole_limb` writes `layer_name: "limb"`, so `take_chunk` already produces `kind == "limb"` and the branch is a no-op. Do not propagate the comment.
- A BYPASS EXISTS. `bone_yard_hunt.gd:2143-2146` (the substance station) appends a raw String straight into `WorldHistory.subject("inventory").items`, skipping `Carry` entirely. Those come back through `load_from_history()` as `{kind: "goods", mass: 0.5, perishes: false}` with no provenance and no condition. Any inventory will encounter these — handle shape F.
- `Carry._init()` calls `load_from_history()`, so constructing a `Carry` reads the persisted list. There is no single-owner guarantee: `run_lifecycle.record_death()` news up a second `Carry` just to read labels. `handheld_device.carry` is the de facto real instance. Two instances will drift.
- `WorldHistory._normalise_body_records()` migrates `wounds` and `anatomy`/`anatomy_state` on load but NOT `items`. Inventory items are re-read as raw JSON — no typed arrays survive, and no catalog normalization is applied to a carried implant name.
- `Carry.age()` is driven externally by whoever owns the carry (`handheld_device.gd:511`) 'because time should not pass inside a menu'. It throttles persistence to `_since_save >= 30.0`. An earlier attempt keyed the interval off `items[0]`, which crashed the moment nothing perishable was carried — noted in the file.
- `WorldHistory._save_history()` no-ops when `OS.get_environment("ATG_TEST_MODE") == "1"`. `MAX_EVENTS := 500`, and `Carry._market_glut()` walks `WorldHistory.events` backwards for the last 40 `carried_part_sold` events to compute a real glut discount (floors at 0.5).
- `part_viewer.gd` has two load-bearing comments: `transparent_bg = false` is deliberate because a transparent SubViewport disables subsurface scattering in Godot and made a correct wet material render like lacquered plastic; and `_pivot` children are `remove_child`'d BEFORE `queue_free()` because queue_free is deferred and the outgoing part was still being measured by `_fit()` (a heart swapped in after a torso rendered at a third of its proper size).
- `Extraction.strip_from_rig()` reaches through untyped `rig.get("anatomy")` and `(anatomy.get("installed_parts") as Dictionary).erase(zone_id)`. It silently no-ops on a rig without an `anatomy` property.
- Tints throughout are BARE HEX with no leading '#' ("9c7446", "cfc2a4") — passed to `Color(str(...))`.
- `Extraction.robbable_zones()` sorting is deliberately three-tiered: worth desc, then already-open depth desc, then `zone` string asc — the last is explicitly there 'so the order is stable run to run rather than however the dictionary happened to be built.' An inventory or loot list that re-sorts must not throw that away.
- `Extraction.target_layer()` returning -1 is load-bearing: 'An empty zone is not diggable at all, which is what stops this becoming a generic hold-E-on-a-corpse resource button.'

## PERSISTENCE

Everything persists through the `WorldHistory` autoload to `user://world_history.json`.

SUBJECT: `WorldHistory.subject("inventory")` holds `{"items": Array, "rust_scrip": int, "player_debt": {faction_id: int}}`.
- `Carry.save_to_history()` -> `WorldHistory.update_subject("inventory", {"items": items.duplicate(true)}, "carry_changed")`, called from `take_chunk`, `take_substance`, `damage_item`, `install_into`, `drop`, and throttled from `age()` every 30s.
- `sell()` writes items and wallet together under event type `"carried_part_sold"`; `borrow()`/`repay()` write `rust_scrip` + `player_debt` under `"player_borrowed"` / `"player_repaid"`.
- `update_subject()` calls `_save_history()` on every invocation and emits `subject_changed`.

EVENTS recorded by this subsystem (`WorldHistory.record_event(type, details)`, ring-buffered at `MAX_EVENTS := 500`):
- `"carried_part"` {subject, part}  — on pickup
- `"carried_part_sold"` {part: full item dict, price, currency, buyer_faction} — read back by `Carry._market_glut()`
- `"implant_installed"` {implant, zone, condition, lien}
- `"part_extracted"` {subject_id, part, zone, tool, owner_alive, location} — via `WitnessLedger.record()` when a ledger exists, else straight to WorldHistory
- `"implant_pulled"` {subject_id, zone, implant, was_locked}
- `"player_borrowed"` / `"player_repaid"` {lender_faction, amount, owed_after}
- `"substance_lifted"` / `"substance_stolen"`
- `"permanent_death"` {…, carried: Array of bare label Strings}

SIDE-EFFECT on the victim: `Extraction.notice()` bumps `WorldHistory.update_subject(owner, {"grudge": +26 capped 100, "memory": "The Hunter cut %s out of me while I was on the ground."}, "robbed_while_down")` when the owner is still alive. `bone_yard_hunt.gd:2225` also re-saves the robbed body's `anatomy_state`.

NOT persisted: `GoreChunks.live` (static, in-memory, scene-lifetime, must be `prune()`d across scene swaps) and the extraction session dictionary.

## REUSE OR REPLACE

KEEP ALL FOUR AS INFRASTRUCTURE. `implant_catalog.gd`, `wound_catalog.gd`, `gore_chunks.gd` and `extraction.gd` are the identity spine, not presentation. They contain no drawing code, they are pure/static almost throughout, they are covered by `chunk_test.gd`, `extraction_test.gd`, `body_inspector_test.gd` and `combat_integration_test.gd`, and their central design commitment (names are identities, never parsed; never invent an organ or implant a body did not have) is exactly what an honest inventory needs. Build against them; do not rewrite them.

`carry.gd` is 90% infrastructure and should also be kept — it is the model, the wallet, the spoil clock, the pricing and the persistence. Two small warts a new inventory will rub against: (1) `take_chunk()` composes the display `label` by string formatting at intake, and (2) `Extraction.tool_for()` then substring-matches that label, so the label is quietly gameplay state. If the new inventory wants its own naming, add a separate `display_label` rather than changing `label`, or move `tool_for` onto a real `implant`/`substance_id` check first.

REPLACE/UPGRADE: `handheld_device.gd::_draw_carry` + `_draw_carried` (lines ~934-1145). This is genuinely good, I0-compliant prototype presentation — objects in a sagging bag, sized by real mass, grouped when the bag fills ('a bag with fourteen skin chunks in it is not fourteen things to a person carrying it — it is "skin, fourteen of them"'), stained by spoilage, ringed gold and tagged 'OWED' for a lien, with the previous owner's name on a paper tag tied to the object. Preserve every one of those ideas. But it is flat 2D silhouettes with a five-case `match` on `kind`, while `part_viewer.gd` already renders the exact same objects as real authored 3D geometry from the same `ImplantCatalog` profiles and the same `BodyMesh` the rig builds bodies from — including rupture cavities and per-implant identity ports. The honest inventory is the handheld's bag staging with `PartViewer` doing the objects, not the 2D blob library.

One structural note for whoever designs next: the four things an item is are `from` (whose body), `lien` (whose claim), `condition` (how much is left) and `freshness` (how long it lasts), and they are four independent axes. The current page shows all four. Any redesign that collapses them into one 'quality' number is a regression, not a simplification.

class_name AshbloomSeals
extends RefCounted

## E2.3. Marks that belong to Ashbloom rather than to a borrowed occult
## catalogue. These are deliberately ordinary data: their origin tells a later
## screen where the mark came from, but grants no effect, rank, rite, or cost.
##
## Every stroke was authored for this project on CellOutzType's centred -1..1
## seal grid. There are no scanned assets, external correspondences, or runtime
## generated lookalikes here; a caller can pass `strokes` straight to
## `CellOutzType.draw_seal()` when a presentation layer is ready.

const ROSTER: Array[Dictionary] = [
	{
		"id": "marrow_saint", "label": "MARROW SAINT", "origin_id": "choir_of_marrow", "kind": "saint",
		"strokes": [
			[[-0.74, -0.72], [-0.38, -0.46], [-0.50, 0.02], [-0.25, 0.76]],
			[[0.62, -0.80], [0.25, -0.36], [0.48, 0.17], [0.17, 0.80]],
			[[-0.27, 0.00], [-0.06, -0.18], [0.20, -0.08], [0.07, 0.32], [-0.10, 0.47]],
			[[-0.51, 0.18], [-0.18, 0.11], [0.36, 0.20]],
			[[-0.16, 0.60], [0.04, 0.73], [0.26, 0.60]],
		],
	},
	{
		"id": "unsewn_joint", "label": "UNSEWN JOINT", "origin_id": "choir_of_marrow", "kind": "body",
		"strokes": [
			[[-0.70, -0.46], [-0.28, -0.70], [0.18, -0.55], [0.53, -0.71]],
			[[-0.71, -0.44], [-0.42, -0.07], [-0.51, 0.38], [-0.18, 0.68]],
			[[0.53, -0.71], [0.32, -0.26], [0.51, 0.12], [0.21, 0.68]],
			[[-0.29, -0.25], [-0.04, -0.06], [0.27, -0.23]],
			[[-0.08, 0.02], [-0.22, 0.28], [0.03, 0.43], [0.25, 0.22]],
			[[-0.86, 0.12], [-0.61, 0.12]],
			[[0.59, 0.06], [0.83, 0.06]],
		],
	},
	{
		"id": "soft_rot_cap", "label": "SOFT ROT CAP", "origin_id": "soft_rot", "kind": "cap",
		"strokes": [
			[[-0.78, -0.18], [-0.49, -0.53], [-0.08, -0.64], [0.37, -0.48], [0.74, -0.12]],
			[[-0.62, -0.05], [-0.26, 0.03], [0.18, -0.01], [0.60, -0.10]],
			[[-0.11, -0.01], [-0.25, 0.29], [-0.16, 0.71]],
			[[0.16, -0.01], [0.31, 0.26], [0.21, 0.70]],
			[[-0.31, 0.36], [0.02, 0.51], [0.35, 0.35]],
			[[-0.60, 0.33], [-0.78, 0.56]],
			[[0.60, 0.29], [0.80, 0.49]],
		],
	},
	{
		"id": "spore_bell", "label": "SPORE BELL", "origin_id": "soft_rot", "kind": "spore",
		"strokes": [
			[[-0.50, -0.72], [-0.12, -0.84], [0.31, -0.69], [0.55, -0.33], [0.42, 0.18]],
			[[0.42, 0.18], [0.15, 0.47], [-0.23, 0.39], [-0.54, 0.06], [-0.61, -0.37], [-0.50, -0.72]],
			[[-0.46, -0.12], [-0.11, -0.28], [0.27, -0.15]],
			[[-0.04, 0.40], [-0.10, 0.74], [0.11, 0.87]],
			[[-0.74, 0.40], [-0.52, 0.58]],
			[[0.48, 0.49], [0.69, 0.67]],
			[[-0.19, -0.51], [-0.05, -0.40]],
		],
	},
	{
		"id": "reset_mast", "label": "RESET MAST", "origin_id": "reset", "kind": "relic",
		"strokes": [
			[[-0.13, -0.87], [0.07, -0.42], [-0.04, 0.12], [0.13, 0.82]],
			[[-0.61, 0.67], [-0.04, 0.12], [0.62, 0.59]],
			[[-0.68, -0.28], [-0.43, -0.42], [-0.25, -0.36]],
			[[0.26, -0.34], [0.48, -0.47], [0.73, -0.32]],
			[[-0.82, 0.10], [-0.55, 0.02]],
			[[0.53, 0.01], [0.81, 0.10]],
			[[-0.24, 0.86], [0.16, 0.86]],
		],
	},
	{
		"id": "buried_window", "label": "BURIED WINDOW", "origin_id": "reset", "kind": "relic",
		"strokes": [
			[[-0.68, -0.61], [0.12, -0.77], [0.61, -0.37]],
			[[-0.68, -0.61], [-0.57, 0.47], [-0.12, 0.74]],
			[[0.61, -0.37], [0.54, 0.50], [0.11, 0.78]],
			[[-0.35, -0.38], [-0.10, -0.20], [0.23, -0.31]],
			[[-0.39, -0.02], [-0.03, 0.08], [0.32, -0.02]],
			[[-0.29, 0.32], [0.01, 0.51], [0.27, 0.29]],
			[[-0.84, 0.23], [-0.65, 0.23]],
			[[0.63, 0.18], [0.84, 0.18]],
		],
	},
	{
		"id": "gate_lantern", "label": "GATE LANTERN", "origin_id": "gate_lanterns", "kind": "waymark",
		"strokes": [
			[[-0.64, -0.79], [-0.64, 0.42], [-0.32, 0.75], [0.20, 0.75], [0.63, 0.39], [0.63, -0.62]],
			[[-0.64, -0.79], [-0.27, -0.52], [0.14, -0.72], [0.63, -0.62]],
			[[-0.28, -0.28], [0.02, -0.41], [0.29, -0.19], [0.13, 0.16], [-0.20, 0.13], [-0.28, -0.28]],
			[[-0.06, 0.18], [-0.05, 0.49]],
			[[-0.84, -0.03], [-0.65, -0.03]],
			[[0.64, -0.04], [0.84, -0.04]],
		],
	},
	{
		"id": "kept_promise", "label": "KEPT PROMISE", "origin_id": "gate_lanterns", "kind": "promise",
		"strokes": [
			[[-0.75, -0.53], [-0.45, -0.76], [-0.10, -0.49], [0.20, -0.72], [0.67, -0.42]],
			[[-0.75, -0.53], [-0.54, -0.03], [-0.67, 0.49], [-0.35, 0.75]],
			[[0.67, -0.42], [0.51, 0.03], [0.62, 0.49], [0.24, 0.77]],
			[[-0.35, 0.75], [-0.01, 0.39], [0.24, 0.77]],
			[[-0.36, -0.08], [-0.04, 0.02], [0.32, -0.10]],
			[[-0.10, -0.46], [-0.02, -0.23]],
		],
	},
	{
		"id": "signal_ladder", "label": "SIGNAL LADDER", "origin_id": "wizardsonlyfoolz", "kind": "call",
		"strokes": [
			[[-0.62, 0.79], [-0.43, 0.39], [-0.31, -0.03], [-0.11, -0.44], [0.08, -0.83]],
			[[0.58, 0.75], [0.37, 0.34], [0.26, -0.10], [0.42, -0.51], [0.30, -0.84]],
			[[-0.43, 0.39], [0.37, 0.34]],
			[[-0.31, -0.03], [0.26, -0.10]],
			[[-0.11, -0.44], [0.42, -0.51]],
			[[-0.76, 0.10], [-0.55, 0.10]],
			[[0.54, 0.08], [0.75, 0.08]],
		],
	},
	{
		"id": "unheard_reply", "label": "UNHEARD REPLY", "origin_id": "wizardsonlyfoolz", "kind": "reply",
		"strokes": [
			[[-0.77, -0.57], [-0.35, -0.79], [0.07, -0.60], [0.46, -0.79], [0.76, -0.48]],
			[[-0.77, -0.57], [-0.60, -0.12], [-0.77, 0.34], [-0.39, 0.72], [0.08, 0.56], [0.52, 0.74], [0.78, 0.37]],
			[[-0.38, -0.28], [-0.10, -0.08], [0.21, -0.24]],
			[[-0.51, 0.13], [-0.13, 0.25], [0.28, 0.11]],
			[[-0.23, 0.51], [0.07, 0.39], [0.38, 0.52]],
			[[0.07, -0.60], [0.06, -0.34]],
		],
	},
]


## Returns deep copies so a presentation or save layer cannot mutate the
## authored catalogue for the rest of the session.
static func all() -> Array[Dictionary]:
	var seals: Array[Dictionary] = []
	for entry in ROSTER:
		seals.append(entry.duplicate(true))
	return seals


static func find(seal_id: String) -> Dictionary:
	for entry in ROSTER:
		if str(entry.get("id", "")) == seal_id:
			return entry.duplicate(true)
	return {}


## A source filter lets a future ritual or dossier page display marks from a
## place without granting any mechanics to that origin.
static func from_origin(origin_id: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for entry in ROSTER:
		if str(entry.get("origin_id", "")) == origin_id:
			matches.append(entry.duplicate(true))
	return matches


static func strokes_for(seal_id: String) -> Array:
	var seal := find(seal_id)
	if seal.is_empty():
		return []
	var strokes: Array = seal.get("strokes", [])
	return strokes.duplicate(true)

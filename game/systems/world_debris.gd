class_name WorldDebris
extends RefCounted

## AB1.3/AB1.4. Physical debris as an identified, capped, persistent object —
## the same contract `gore_chunks.gd` already proved for bodies (identified
## via metadata, capped by recycling the oldest piece, no fixed-lifetime
## despawn) generalised for anything that is not a body: a barricade's
## fragments, a car's detached panel.
##
## Two things gore_chunks does not need to solve, this does:
## - It is not about bodies, so there is no layer/organ/subject contract to
##   reuse literally, only the pattern.
## - Different callers want different budgets (a barricade fragment and a
##   detached car door do not cost the same frame). Each caller names its own
##   pool and its own budget, so a full pool of wrecked cars cannot evict a
##   barricade's fragments just because they happen to share this file.

## pool name -> Array[Node3D], the live pieces in that pool.
static var _pools: Dictionary = {}


## Tags `node` as identified debris and tracks it in `pool`, recycling the
## oldest piece in that pool if it is already at `budget`. There is
## deliberately no timer here — a piece that fits inside its budget stays
## until something displaces it, which is what "persists" means.
static func register(node: Node3D, info: Dictionary, pool: String, budget: int) -> void:
	if node == null or not is_instance_valid(node):
		return
	var live: Array = _pools.get(pool, [])
	_prune(live)
	while live.size() >= maxi(0, budget) and not live.is_empty():
		var oldest: Node3D = live.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	info["pool"] = pool
	info["taken"] = false
	info["spawn_msec"] = Time.get_ticks_msec()
	node.set_meta("debris", info)
	live.append(node)
	_pools[pool] = live


## What this piece is. Empty for anything that was never registered, so a
## caller can test a raycast hit without checking the class first.
static func identify(node: Node) -> Dictionary:
	if node == null or not is_instance_valid(node) or not node.has_meta("debris"):
		return {}
	return node.get_meta("debris")


## Pick it up. Removes the piece from its pool and hands back its identity.
static func take(node: Node) -> Dictionary:
	var info := identify(node)
	if info.is_empty() or bool(info.get("taken", false)):
		return {}
	info["taken"] = true
	var pool := str(info.get("pool", ""))
	var live: Array = _pools.get(pool, [])
	live.erase(node)
	_pools[pool] = live
	if is_instance_valid(node):
		node.queue_free()
	return info


## How many pieces a pool is actually holding right now — cheap enough for a
## caller to ask "is there room" before it spawns another one.
static func pool_count(pool: String) -> int:
	var live: Array = _pools.get(pool, [])
	_prune(live)
	_pools[pool] = live
	return live.size()


static func _prune(live: Array) -> void:
	var kept: Array = []
	for node in live:
		if is_instance_valid(node):
			kept.append(node)
	live.clear()
	live.append_array(kept)


## A scene swap frees every piece in a pool without this class hearing about
## it one at a time — call this at the same seam that frees the scene, or
## `pool_count()` will keep counting nodes that no longer exist until the
## next `register()` happens to prune them.
static func clear_pool(pool: String) -> void:
	var live: Array = _pools.get(pool, [])
	for node in live:
		if is_instance_valid(node):
			node.queue_free()
	_pools.erase(pool)

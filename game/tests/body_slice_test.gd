extends Node

## Cutting a limb somewhere the zone table never agreed to.
##
## The check that matters here is volume. A slicer that drops the cap, or winds
## it inside out, still returns two plausible-looking meshes -- the hole only
## shows when you walk round the far side of a severed thigh and see daylight
## through it. Signed volume catches exactly that: it is only meaningful on a
## closed mesh, and the two halves only add up to the whole if both cut faces
## are present and facing outward.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## Signed volume by the divergence theorem: a sixth of the sum of the scalar
## triple products of each triangle's corners. Positive and stable for a closed
## mesh wound outward, and wrong the moment there is a hole in it.
func volume_of(mesh: Mesh) -> float:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0.0
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in vertices.size():
			indices.append(i)
	var total := 0.0
	var triangle := 0
	while triangle + 2 < indices.size():
		var a := vertices[indices[triangle]]
		var b := vertices[indices[triangle + 1]]
		var c := vertices[indices[triangle + 2]]
		triangle += 3
		total += a.dot(b.cross(c))
	return total / 6.0


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# Profiles are normalised -1..1 and `scaled()` takes half-height, so a leg
	# of length 0.84 spans y -0.42..+0.42 about the origin. Cuts are placed
	# against that, not against an assumed 0..length.
	var thigh := BodyMesh.leg(0.84)
	var whole := volume_of(thigh)
	print("-- the limb we are cutting --")
	check(whole > 0.0, "a generated leg is closed and wound outward (volume %.5f)" % whole)

	print("-- a straight cut across the middle --")
	var flat := Plane(Vector3.UP, Vector3(0.0, 0.0, 0.0))
	var halves := BodySlice.split(thigh, flat)
	check(halves.above != null, "the cut produced an upper half")
	check(halves.below != null, "the cut produced a lower half")
	check(halves.section.size() >= 6, "the cut face has a boundary (%d points)" % int(halves.section.size()))
	check(float(halves.area) > 0.0, "the cut face has area (%.5f)" % float(halves.area))

	var upper := volume_of(halves.above)
	var lower := volume_of(halves.below)
	check(upper > 0.0, "the upper half is closed (%.5f)" % upper)
	check(lower > 0.0, "the lower half is closed (%.5f)" % lower)
	# The whole point. Both caps present and outward, or this does not hold.
	var drift := absf((upper + lower) - whole)
	check(drift < whole * 0.02, "the halves add back up to the limb (drift %.6f of %.5f)" % [drift, whole])

	print("-- a diagonal cut, which is the thing the zone table could not do --")
	var angled := Plane(Vector3(0.45, 1.0, 0.2).normalized(), Vector3(0.0, 0.08, 0.0))
	var slanted := BodySlice.split(thigh, angled)
	check(slanted.above != null and slanted.below != null, "an off-axis plane still cuts")
	var slant_drift := absf((volume_of(slanted.above) + volume_of(slanted.below)) - whole)
	check(slant_drift < whole * 0.02, "a diagonal cut stays watertight (drift %.6f)" % slant_drift)

	print("-- a swing that misses --")
	var missed := BodySlice.split(thigh, Plane(Vector3.UP, Vector3(0.0, 40.0, 0.0)))
	check(missed.above == null, "nothing above a plane the limb is entirely below")
	check(missed.below != null, "the limb comes back whole on the side it is on")
	check(missed.section.is_empty(), "a miss reports no cut face")

	print("-- the plane a blade actually describes --")
	# Edge along X, swinging down: the cut should separate top from bottom, so
	# its normal wants to be horizontal-perpendicular, not along the swing.
	var swing := BodySlice.plane_from_swing(Vector3(0.0, 0.05, 0.0), Vector3.RIGHT, Vector3.DOWN)
	check(absf(swing.normal.dot(Vector3.RIGHT)) < 0.01, "the cut plane contains the blade's edge")
	check(absf(swing.normal.dot(Vector3.DOWN)) < 0.01, "the cut plane contains the swing's travel")
	var swung := BodySlice.split(thigh, swing)
	check(swung.above != null and swung.below != null, "a swing-derived plane cuts the limb in two")

	# A draw cut -- edge and travel parallel -- has no single plane implied by
	# the motion. It must still return a usable one rather than a zero normal.
	var draw := BodySlice.plane_from_swing(Vector3(0.0, 0.05, 0.0), Vector3.RIGHT, Vector3.RIGHT)
	check(draw.normal.is_normalized(), "a draw cut still yields a real plane")

	print("-- a torso, which is the wide case --")
	var torso := BodyMesh.torso(0.72)
	var torso_whole := volume_of(torso)
	var torso_cut := BodySlice.split(torso, Plane(Vector3(1.0, 0.6, 0.0).normalized(), Vector3(0.0, 0.05, 0.0)))
	check(torso_cut.above != null and torso_cut.below != null, "a torso cuts on the diagonal")
	var torso_drift := absf((volume_of(torso_cut.above) + volume_of(torso_cut.below)) - torso_whole)
	check(torso_drift < torso_whole * 0.02, "the torso halves add back up (drift %.6f of %.5f)" % [torso_drift, torso_whole])

	print("BODY_SLICE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

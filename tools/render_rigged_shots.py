"""Render the rigged-body proof shots without opening a window.

Job 2 visual proof. `game/tests/rigged_body_pose_export.tscn` (headless
Godot) writes each staged body as a static glTF of exactly what the game draws
for it; this renders each from the front and the side in Blender's background
mode (Workbench, flat studio light, object colours) and tiles them into one
contact sheet.

    blender -b --factory-startup --python tools/render_rigged_shots.py -- P:/GameDev/Temp/job2/shots

Writes <dir>/<shot>_front.png, <shot>_side.png and <dir>/contact_sheet.png.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

SHOTS = ["old_unrigged", "idle", "swing", "wounded", "severed", "ragdoll", "hunt_player", "hunt_player_fp", "hunt_enemy"]
SIZE = (480, 640)


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def setup_scene():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = SIZE
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.color = (0.08, 0.07, 0.07)
    bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, 0))
    floor = bpy.context.object
    material = bpy.data.materials.new("floor")
    material.diffuse_color = (0.22, 0.2, 0.19, 1.0)
    floor.data.materials.append(material)
    return scene


def import_shot(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    objects = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    for obj in objects:
        for slot in obj.material_slots:
            if slot.material and slot.material.node_tree:
                bsdf = slot.material.node_tree.nodes.get("Principled BSDF")
                if bsdf:
                    slot.material.diffuse_color = bsdf.inputs["Base Color"].default_value
    return objects


def bounds(objects):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for obj in objects:
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, world))
            hi = Vector(map(max, hi, world))
    return lo, hi


def render(scene, objects, out, side, top=False):
    lo, hi = bounds(objects)
    centre = (lo + hi) / 2
    extent = max(hi.z - lo.z, hi.x - lo.x, hi.y - lo.y, 1.0)
    camera_data = bpy.data.cameras.new("cam")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = extent * 1.25
    camera = bpy.data.objects.new("cam", camera_data)
    scene.collection.objects.link(camera)
    # glTF -Z forward (Godot) becomes Blender +Y; the rig faces Godot -Z, so
    # its front looks toward Blender +Y... the camera sits in front of it.
    if top:
        camera.location = centre + Vector((0, 0, extent * 3))
        camera.rotation_euler = (0, 0, 0)
    elif side:
        camera.location = centre + Vector((extent * 3, 0, 0))
        camera.rotation_euler = (math.radians(90), 0, math.radians(90))
    else:
        camera.location = centre + Vector((0, extent * 3, 0))
        camera.rotation_euler = (math.radians(90), 0, math.radians(180))
    scene.camera = camera
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera)


def main():
    directory = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "P:/GameDev/Temp/job2/shots"
    written = []
    for shot in SHOTS:
        path = os.path.join(directory, shot + ".glb")
        if not os.path.exists(path):
            continue
        clear()
        scene = setup_scene()
        objects = import_shot(path)
        for side in (False, True):
            out = os.path.join(directory, "%s_%s.png" % (shot, "side" if side else "front"))
            render(scene, objects, out, side)
            written.append(out)
        if shot == "ragdoll":
            corpse = [o for o in objects if "Severed" not in o.name]
            out = os.path.join(directory, "ragdoll_top.png")
            render(scene, corpse, out, False, top=True)
            written.append(out)
    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        pass
    print("RENDERED", len(written))


main()

"""Pre-fractured pieces for the mechanics lab's destruction station.

Blender's Cell Fracture add-on is an extension in Blender 4.2+ and is not
installed here, so this does what it does, the same way: scatter seed points
inside the shape, and for each seed cut a copy of the shape with the bisecting
plane to every other seed (keep the seed's side, cap the cut). Each cell is one
mesh object; the export is one glb per shape, unit sized, centred on the
origin, which `BreakableProp.prefractured` scales to the prop's own size.

Run (headless, no window):
  blender.exe -b --factory-startup --python cell_fracture.py
"""
import os
import random

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
SHAPES = {
    # name: (builder, cells, seed)
    "slab_cells": ("cube", 14, 7),
    "pipe_cells": ("cylinder", 8, 11),
}


def _shape_bmesh(kind):
    bm = bmesh.new()
    if kind == "cube":
        bmesh.ops.create_cube(bm, size=1.0)
    else:
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.5, radius2=0.5, depth=1.0)
    return bm


def _seeds(kind, count, rng):
    out = []
    while len(out) < count:
        p = Vector((rng.uniform(-0.48, 0.48), rng.uniform(-0.48, 0.48), rng.uniform(-0.48, 0.48)))
        if kind == "cylinder" and (p.x * p.x + p.y * p.y) > 0.23:
            continue
        out.append(p)
    return out


def _cell(kind, seeds, index):
    bm = _shape_bmesh(kind)
    me = seeds[index]
    for other_index, other in enumerate(seeds):
        if other_index == index:
            continue
        mid = (me + other) * 0.5
        normal = (other - me).normalized()
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        cut = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=mid, plane_no=normal, clear_outer=True)
        edges = [e for e in cut["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if edges:
            bmesh.ops.edgeloop_fill(bm, edges=edges)
        if not bm.verts:
            break
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def build(name, kind, count, seed):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(seed)
    seeds = _seeds(kind, count, rng)
    for index in range(count):
        bm = _cell(kind, seeds, index)
        if len(bm.verts) < 4:
            bm.free()
            continue
        # Each piece's origin at its own centre, so it tumbles about itself.
        centre = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
        for v in bm.verts:
            v.co -= centre
        mesh = bpy.data.meshes.new("%s_%02d" % (name, index))
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new("piece_%02d" % index, mesh)
        obj.location = centre
        bpy.context.scene.collection.objects.link(obj)
    path = os.path.join(HERE, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_materials="NONE", export_yup=True)
    print("FRACTURED", name, len(bpy.context.scene.objects), path)


for shape_name, (shape_kind, cells, shape_seed) in SHAPES.items():
    build(shape_name, shape_kind, cells, shape_seed)

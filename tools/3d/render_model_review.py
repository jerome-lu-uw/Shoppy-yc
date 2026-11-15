"""Render orthographic review views of a GLB garment with Blender."""

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args():
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("model", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser.parse_args(arguments)


def bounds(objects):
    points = [
        item.matrix_world @ Vector(corner)
        for item in objects
        for corner in item.bound_box
    ]
    minimum = Vector(tuple(min(point[index] for point in points) for index in range(3)))
    maximum = Vector(tuple(max(point[index] for point in points) for index in range(3)))
    return minimum, maximum


def render_view(scene, center, scale, direction, destination):
    data = bpy.data.cameras.new(destination.stem)
    data.type = "ORTHO"
    data.ortho_scale = scale * 1.25
    camera = bpy.data.objects.new(destination.stem, data)
    scene.collection.objects.link(camera)
    camera.location = center + Vector(direction).normalized() * scale * 3
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.filepath = str(destination)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)


def main():
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.model))
    meshes = [item for item in bpy.context.scene.objects if item.type == "MESH"]
    if not meshes:
        raise SystemExit(f"No mesh objects found in {args.model}")

    minimum, maximum = bounds(meshes)
    center = (minimum + maximum) / 2
    scale = max(maximum - minimum)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.render.resolution_x = 800
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.05, 0.05, 0.05)

    views = {
        "front": (0, -1, 0),
        "back": (0, 1, 0),
        "left": (-1, 0, 0),
        "right": (1, 0, 0),
        "three-quarter": (1, -1, 0.25),
    }
    for name, direction in views.items():
        render_view(scene, center, scale, direction, args.output_dir / f"{name}.png")


if __name__ == "__main__":
    main()

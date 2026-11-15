import bpy, bmesh, math
import numpy as np
from mathutils import Vector, Matrix

D = "/Users/jerome/.capy/work/shoppy/3d"
TARGET_HEIGHT = 1.86

def load_scan():
    """Imports the original scan. Returns (object, coords, original_usd_coords).
    coords are in the app frame: Blender Z up, feet on z=0, centred on the feet, front facing -Y, scaled to TARGET_HEIGHT."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.usd_import(filepath=D + "/scan-original.usdz")
    ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
    Mw = ob.matrix_world.copy()
    co = np.array([tuple(Mw @ v.co) for v in ob.data.vertices])
    orig_usd = np.stack([co[:, 0], co[:, 2], -co[:, 1]], axis=1)
    s = TARGET_HEIGHT / (co[:, 2].max() - co[:, 2].min())
    out = np.empty_like(co)
    out[:, 0] = co[:, 1]
    out[:, 1] = -co[:, 0]
    out[:, 2] = co[:, 2] - co[:, 2].min()
    out *= s
    feet = out[out[:, 2] < 0.05]
    out[:, 0] -= (feet[:, 0].min() + feet[:, 0].max()) / 2
    out[:, 1] -= (feet[:, 1].min() + feet[:, 1].max()) / 2
    ob.parent = None
    ob.matrix_world = Matrix.Identity(4)
    ob.data.vertices.foreach_set("co", out.ravel())
    ob.data.update()
    ob.name = "Scan"
    return ob, out, orig_usd

def to_usd(p):
    return np.stack([p[:, 0], p[:, 2], -p[:, 1]], axis=1)

def vertex_colors(ob):
    """Mean diffuse texture colour (sRGB 0-1) per vertex."""
    me = ob.data
    img = [i for i in bpy.data.images if 'tex0' in i.name][0]
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[:, :, :3]
    n = len(me.loops)
    uv = np.empty(n * 2, dtype=np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(n, 2)
    vi = np.empty(n, dtype=np.int32)
    me.loops.foreach_get("vertex_index", vi)
    x = np.clip((uv[:, 0] % 1.0) * w, 0, w - 1).astype(int)
    y = np.clip((uv[:, 1] % 1.0) * h, 0, h - 1).astype(int)
    c = px[y, x]
    acc = np.zeros((len(me.vertices), 3))
    cnt = np.zeros(len(me.vertices))
    np.add.at(acc, vi, c)
    np.add.at(cnt, vi, 1)
    return acc / np.maximum(cnt, 1)[:, None]

def is_skin(col):
    r, g, b = col[:, 0], col[:, 1], col[:, 2]
    return (r > 0.40) & (r > g * 1.10) & (g > b * 1.02) & (r - b > 0.10)

def setup_render(res=(700, 1100)):
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.82, 0.80, 0.76)
    scene.view_settings.view_transform = 'Standard'
    return scene

def shoot(name, direction, height=TARGET_HEIGHT, target_z=None, ortho=None):
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new(name)
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = ortho or height * 1.08
    cam = bpy.data.objects.new(name, cam_data)
    scene.collection.objects.link(cam)
    target = Vector((0, 0, height / 2 if target_z is None else target_z))
    cam.location = target + Vector(direction).normalized() * 5
    cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam
    scene.render.filepath = D + "/out/" + name + ".png"
    bpy.ops.render.render(write_still=True)

VIEWS = {"front": (0, -1, 0), "back": (0, 1, 0), "left": (-1, 0, 0), "right": (1, 0, 0), "q": (0.7, -0.7, 0.15)}

#!/usr/bin/env python3
"""Fit a standalone garment onto the scanned avatar and package a dressed look.

Run headless with Blender 3.6 or newer:

    /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/3d/fit_garment.py -- \
        --garment Shoppy/Resources/Models/garment-smooth-spacer-quarter-zip.usdz \
        --look look-smooth-spacer-quarter-zip --install

The garment keeps the real-world scale it arrives with. It is placed on the
avatar's shoulders, each long sleeve hangs in one straight line along the
avatar's arm and stops at the pocket when the hand is in one, a short sleeve
lies along the upper arm, the cloth comes out only where the body would stand
well proud of it, and the scan faces it covers are hidden. Where the garment
leaves the top the avatar was scanned in on view, at a neckline, below a short
sleeve or through an armhole, that cloth is drawn in to the body and shown as
skin. The result is a style preview, not a cloth simulation and not a
statement about fit.
"""

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

PIPELINE_VERSION = "fit-4"
REPO = Path(__file__).resolve().parents[2]

OUTER_CLEARANCE = 0.006
POKE_TOLERANCE = 0.03
RIM_BAND = 0.08
MAX_PUSH = 0.08
PUSH_RADIUS = 0.05
PUSH_ROUNDS = 4
ARM_WIDTH = 0.075
ARM_REACH = 0.12
ARM_MARGIN = 0.03
CUFF_TRIM = 0.05
SHOULDER_HALF_WIDTH = 0.15
SHOULDER_SINK = 0.02
NECK_DROP = 0.17
NECK_REACH = 0.18
NECK_CLEAR = 0.01
COLLAR_DEPTH = 0.025
NECK_ROUNDS = 30
SLEEVE_MARGIN = 0.014
MASK_REACH = 0.15
MASK_POKE = 0.05
MASK_ISLAND = 80
MASK_CONE = np.radians(40)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--garment", type=Path, required=True)
    parser.add_argument("--look", required=True, help="Name of the dressed-look asset, without extension")
    parser.add_argument("--avatar", type=Path, default=REPO / "Shoppy/Resources/Models/scan.usdz")
    parser.add_argument("--dimensions-file", type=Path)
    parser.add_argument("--output-root", type=Path, default=Path(__file__).parent / "generated" / "fits")
    parser.add_argument("--install", action="store_true", help="Copy the look into the app's model resources")
    parser.add_argument("--force", action="store_true", help="Rebuild even when the cache key matches")
    return parser.parse_args(argv)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


# ---------------------------------------------------------------- import

def material_textures(ob):
    textures = {}
    material = ob.data.materials[0] if ob.data.materials else None
    if material is None or not material.use_nodes:
        return textures
    bsdf = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return textures
    for slot, socket in (("basecolor", "Base Color"), ("roughness", "Roughness"), ("metallic", "Metallic"), ("normal", "Normal")):
        channel = "rgb" if slot in ("basecolor", "normal") else "r"
        sock = bsdf.inputs[socket]
        while sock.is_linked:
            link = sock.links[0]
            node = link.from_node
            if node.type == "TEX_IMAGE" and node.image:
                image = node.image
                data = image.packed_file.data if image.packed_file else Path(bpy.path.abspath(image.filepath)).read_bytes()
                textures[slot] = {"data": bytes(data), "ext": ".jpg" if image.file_format == "JPEG" else ".png", "channel": channel}
                break
            if node.type in ("SEPARATE_COLOR", "SEPRGB"):
                channel = link.from_socket.name[0].lower()
                sock = node.inputs[0]
            elif node.type == "NORMAL_MAP":
                sock = node.inputs["Color"]
            else:
                break
    return textures


def vertex_colours(ob, vertex_count, faces, uv):
    """Mean base-colour texel per vertex, used to tell bare skin from clothing on the scan."""
    bsdf = next(n for n in ob.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    image = bsdf.inputs["Base Color"].links[0].from_node.image
    width, height = image.size
    pixels = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)[:, :, :3]
    flat = uv.reshape(-1, 2)
    x = np.clip((flat[:, 0] % 1.0) * width, 0, width - 1).astype(int)
    y = np.clip((flat[:, 1] % 1.0) * height, 0, height - 1).astype(int)
    total = np.zeros((vertex_count, 3))
    np.add.at(total, faces.reshape(-1), pixels[y, x])
    return total / np.maximum(np.bincount(faces.reshape(-1), minlength=vertex_count), 1)[:, None]


def is_skin(colour):
    r, g, b = colour[:, 0], colour[:, 1], colour[:, 2]
    return (r > 0.40) & (r > g * 1.10) & (g > b * 1.02) & (r - b > 0.10)


def is_cloth(colour):
    """Scanned clothing, hair and untextured dark: whatever is not skin, lit or in shadow. Skin keeps its red well above its blue."""
    return ~is_skin(colour) & (colour[:, 0] - colour[:, 2] < 0.05)


def import_asset(path, colours=False):
    """Loads a GLB or USD asset as welded triangles in Blender's frame: Z up, front facing -Y, metres."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.suffix.lower() in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(path))
    else:
        bpy.ops.wm.usd_import(filepath=str(path))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit(f"No mesh found in {path}")
    ob = max(meshes, key=lambda o: len(o.data.vertices))
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.transform(ob.matrix_world)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=2e-6)
    bm.verts.index_update()
    uv_layer = bm.loops.layers.uv.active
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    asset = {
        "co": np.array([v.co[:] for v in bm.verts], dtype=np.float64),
        "faces": np.array([[v.index for v in f.verts] for f in bm.faces], dtype=np.int64),
        "uv": np.array([[l[uv_layer].uv[:] for l in f.loops] for f in bm.faces], dtype=np.float64),
        "textures": material_textures(ob),
    }
    bm.free()
    if colours:
        asset["colour"] = vertex_colours(ob, len(asset["co"]), asset["faces"], asset["uv"])
        asset["skin"], asset["cloth"] = is_skin(asset["colour"]), is_cloth(asset["colour"])
        asset["dark"] = asset["colour"].max(axis=1) < 0.06
    return asset


# ---------------------------------------------------------------- geometry helpers

def vertex_normals(co, faces):
    a, b, c = co[faces[:, 0]], co[faces[:, 1]], co[faces[:, 2]]
    face_normals = np.cross(b - a, c - a)
    normals = np.zeros_like(co)
    for k in range(3):
        np.add.at(normals, faces[:, k], face_normals)
    return normals / np.maximum(np.linalg.norm(normals, axis=1), 1e-12)[:, None]


def unique_edges(faces):
    edges = np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]])
    edges.sort(axis=1)
    return np.unique(edges, axis=0)


def cross_section(co, faces, height):
    """Points where the mesh crosses the horizontal plane z = height."""
    z = co[:, 2][faces]
    above = z > height
    count = above.sum(1)
    crossing = (count == 1) | (count == 2)
    f, ab = faces[crossing], above[crossing]
    if not len(f):
        return np.empty((0, 3))
    lone = np.where(ab.sum(1) == 1, ab.argmax(1), (~ab).argmax(1))
    row = np.arange(len(f))
    i0, i1, i2 = f[row, lone], f[row, (lone + 1) % 3], f[row, (lone + 2) % 3]

    def cut(a, b):
        t = (height - co[a, 2]) / (co[b, 2] - co[a, 2])
        return co[a] + (co[b] - co[a]) * t[:, None]

    return np.concatenate([cut(i0, i1), cut(i0, i2)])


def signed_distance(bvh, points):
    """Distance to the body surface (negative inside), the nearest surface point and the outward direction there."""
    n = len(points)
    distance, nearest, outward = np.empty(n), np.empty((n, 3)), np.empty((n, 3))
    for i, p in enumerate(points):
        location, normal, _, d = bvh.find_nearest(Vector(p))
        offset = Vector(p) - location
        inside = offset.dot(normal) < 0
        distance[i] = -d if inside else d
        nearest[i] = location
        outward[i] = (-offset if inside else offset).normalized() if d > 1e-6 else normal
    return distance, nearest, outward


def smooth(values, window=5):
    padded = np.pad(values, window // 2, mode="edge")
    return np.convolve(padded, np.ones(window) / window, mode="valid")


def fill_gaps(values):
    known = ~np.isnan(values)
    index = np.arange(len(values))
    return np.interp(index, index[known], values[known])


# ---------------------------------------------------------------- placement

def body_landmarks(body):
    """Chin and neck of the avatar, read from horizontal cross-sections."""
    co, faces = body["co"], body["faces"]
    stature = co[:, 2].max()
    rows = []
    for h in np.arange(0.80 * stature, 0.93 * stature, 0.004):
        pts = cross_section(co, faces, h)
        rows.append((h, pts[:, 0].min(), pts[:, 0].max(), pts[:, 1].min(), pts[:, 1].max()))
    rows = np.array(rows)
    jaw = rows[(rows[:, 2] - rows[:, 1]).argmin()]
    below = rows[rows[:, 0] < jaw[0]][::-1]
    receded = below[below[:, 3] > jaw[3] + 0.03]
    chin = receded[0, 0] if len(receded) else jaw[0]
    base = rows[np.abs(rows[:, 0] - (chin - 0.01)).argmin()]
    return {"stature": stature, "chin": chin, "neck_x": (base[1] + base[2]) / 2, "neck_y": (base[3] + base[4]) / 2}


def place(garment, body, bvh):
    """Rigid placement: collar around the neck, shoulders resting on the avatar's, collar below the chin."""
    co, faces = garment["co"], garment["faces"]
    height = co[:, 2].max()
    marks = body_landmarks(body)
    ring = cross_section(co, faces, height - 0.05)
    cx, cy = (ring[:, 0].min() + ring[:, 0].max()) / 2, (ring[:, 1].min() + ring[:, 1].max()) / 2
    front = (np.abs(co[:, 0] - cx) < 0.035) & (co[:, 1] < cy - 0.02) & (co[:, 2] > height - 0.2)
    collar_front_top = co[front, 2].max()
    tx, ty = marks["neck_x"] - cx, marks["neck_y"] - cy
    below_chin = marks["chin"] - 0.004 - collar_front_top

    seam = (np.abs(vertex_normals(co, faces)[:, 2]) > 0.5) & (co[:, 2] > height - 0.18) & (np.abs(np.abs(co[:, 0] - cx) - 0.14) < 0.05)
    lands = []
    for p in co[seam]:
        hit = bvh.ray_cast(Vector((p[0] + tx, p[1] + ty, marks["chin"])), Vector((0, 0, -1)))[0]
        if hit is not None:
            lands.append(hit.z - p[2])
    resting = np.percentile(lands, 90) - SHOULDER_SINK if lands else below_chin
    dz = min(resting, below_chin)
    print(f"placement: neck ({marks['neck_x']:.3f}, {marks['neck_y']:.3f}) chin {marks['chin']:.3f} "
          f"collar front top {collar_front_top:.3f} resting dz {resting:.3f} below-chin dz {below_chin:.3f} -> dz {dz:.3f}")
    return np.array([tx, ty, dz]), {"midline_x": cx + tx, "chin": marks["chin"], "neck_x": marks["neck_x"], "neck_y": marks["neck_y"], "resting_dz": resting, "below_chin_dz": below_chin}


# ---------------------------------------------------------------- sleeves

def components(n, edges):
    parent = list(range(n))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for a, b in edges.tolist():
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb
    return np.array([find(i) for i in range(n)])


def find_cuffs(co, edges, midline):
    """The part of each sleeve that hangs free of the torso, found by cutting the garment at falling heights.

    A free piece narrower than a wrist is a fold or a tag, not a sleeve."""
    floor, top = co[:, 2].min(), co[:, 2].max()

    def split(cut):
        below = co[:, 2] < cut
        roots = components(len(co), edges[below[edges[:, 0]] & below[edges[:, 1]]])
        ids, counts = np.unique(roots[below], return_counts=True)
        sides = {}
        for root in ids[counts > 150]:
            part = co[below & (roots == root)]
            if min(np.ptp(part[:, 0]), np.ptp(part[:, 1])) < 0.04:
                continue
            x = part[:, 0]
            if x.max() < midline - 0.02:
                sides.setdefault(-1, below & (roots == root))
            elif x.min() > midline + 0.02:
                sides.setdefault(1, below & (roots == root))
        return sides if len(sides) == 2 else None

    for cut in np.arange(top - 0.15, floor + 0.02, -0.02):
        found = split(cut)
        if found:
            return cut, found
    return None, {}


def harmonic_weights(n, edges, fixed, values, rounds=600):
    degree = np.bincount(edges[:, 0], minlength=n) + np.bincount(edges[:, 1], minlength=n)
    w = np.where(fixed, values, 0.5)
    for _ in range(rounds):
        total = np.bincount(edges[:, 0], w[edges[:, 1]], minlength=n) + np.bincount(edges[:, 1], w[edges[:, 0]], minlength=n)
        w = np.where(fixed, values, total / np.maximum(degree, 1))
    return w


def straight(heights, offsets, along, shoulder):
    """The straight line through the shoulder that best fits the offsets along the sleeve."""
    pin_height, pin = heights[shoulder].mean(), offsets[shoulder].mean()
    reach = heights[along] - pin_height
    slope = (reach * (offsets[along] - pin)).sum() / (reach ** 2).sum()
    return pin + slope * (heights - pin_height), slope


def shoulder_line(co, faces, midline):
    """The height at which the garment has widened from its collar into its shoulders."""
    top = co[:, 2].max()
    for height in np.arange(top - 0.005, top - 0.30, -0.005):
        ring = cross_section(co, faces, height)
        if len(ring) and np.abs(ring[:, 0] - midline).max() >= SHOULDER_HALF_WIDTH:
            return height
    return top - 0.10


def align_sleeves(co, faces, edges, body, midline):
    """Poses each sleeve as one straight piece along the avatar's arm, and finds that arm on the scan.

    A long sleeve tilts as one line from the shoulder and never bends to follow an elbow. Where the bare
    arm stops above its cuff's end, as it does at a pocket with a hand in it, the sleeve is drawn up by at
    most CUFF_TRIM so its end sits on that line instead of hanging past a hand nobody sees. A short sleeve,
    whether it hangs free or widens straight out of the garment's side, is set the same way on the upper
    arm the scan hides.

    What comes back with the posed garment describes the avatar's arms. The limb never pushes cloth, and
    the bare part of it is never hidden. The arm is the part of it a long sleeve covers, which the mask
    hides. Where the garment leaves the upper arm in view and the scan has it inside a sleeve, the tube is
    that sleeve drawn in to the arm, drawn is where its vertices go, and gone is the slack beside it,
    which is dropped."""
    floor = co[:, 2].min()
    crown = shoulder_line(co, faces, midline)
    heights = np.arange(floor + 0.005, crown, 0.01)
    shoulder = heights > crown - 0.10
    yoke = heights[shoulder].mean()
    cut, cuffs = find_cuffs(co, edges, midline)
    out = co.copy()
    limb, bare, arm, tube, gone = (np.zeros(len(body["co"]), dtype=bool) for _ in range(5))
    drawn = body["co"].copy()
    stats = {"free_cuff_height": None if cut is None else round(float(cut - floor), 3)}
    hem = floor if cut is None else co[~(cuffs[-1] | cuffs[1]), 2].min()
    skin = body["co"][body["skin"]]
    for side in (-1, 1):
        name = "minus_x" if side < 0 else "plus_x"
        edge, body_edge, centre, dx, dy, lobe_y = (np.full(len(heights), np.nan) for _ in range(6))
        forearm = np.zeros(len(heights), dtype=bool)
        for k, h in enumerate(heights):
            mine = cross_section(co, faces, h)
            theirs = cross_section(body["co"], body["faces"], h)
            if not len(mine) or not len(theirs):
                continue
            edge[k], body_edge[k] = (mine[:, 0] * side).max(), (theirs[:, 0] * side).max()
            lobe = mine[mine[:, 0] * side > edge[k] - ARM_WIDTH]
            part = skin[(np.abs(skin[:, 2] - h) < 0.02) & ((skin[:, 0] - midline) * side > 0.06)]
            forearm[k] = len(part) >= 5
            if not forearm[k]:
                part = theirs[theirs[:, 0] * side > body_edge[k] - ARM_WIDTH]
            centre[k] = (part[:, 1].min() + part[:, 1].max()) / 2
            dx[k] = ((part[:, 0] * side).max() + SLEEVE_MARGIN - edge[k]) * side
            lobe_y[k] = (lobe[:, 1].min() + lobe[:, 1].max()) / 2
            dy[k] = centre[k] - lobe_y[k]
        wrist = forearm.argmax()
        elbow = heights[forearm].max() if forearm.any() else hem
        dx[:wrist], dy[:wrist] = dx[wrist], dy[wrist]
        edge, body_edge, centre, dx, dy, lobe_y = (smooth(fill_gaps(v)) for v in (edge, body_edge, centre, dx, dy, lobe_y))
        x, z = body["co"][:, 0] * side, body["co"][:, 2]
        out_there = x - midline * side
        low = None if cut is None else co[cuffs[side], 2].min()
        if low is None:
            wing = np.where(edge[3:] - edge[:-3] > 0.025)[0]
            low = heights[wing[-1]] + 0.015 if len(wing) and heights[wing[-1]] > (floor + crown) / 2 else None

        if low is None or low > (floor + crown) / 2:
            line, on, slack, placed, info = upper_arm(body, midline, side, heights, body_edge, centre, elbow)
            drawn[on] = placed[on]
            tube |= on
            gone |= slack
            flesh = ~body["cloth"] & (out_there > 0.10) & (z > hem) & (z < crown)
            shade = np.where(body["dark"] & (out_there > 0.08) & (z > hem) & (z < elbow + 0.02))[0]
            if flesh.any() and len(shade):
                tree = KDTree(int(flesh.sum()))
                for i, p in enumerate(body["co"][flesh]):
                    tree.insert(p, i)
                tree.balance()
                flesh[shade[[tree.find(body["co"][i])[2] < 0.03 for i in shade]]] = True
            flesh &= z > hem + ARM_MARGIN
            limb |= on | slack | flesh
            bare |= flesh
            stats[name] = {"upper_arm": info}
            if low is not None and line is not None:
                along_arm = line(heights)
                upper = (heights > elbow) & (heights < info["to_m"] - 0.03)
                dx = np.where(upper, (along_arm[:, 0] * side + info["radius_m"] + SLEEVE_MARGIN - edge) * side, dx)
                dy = np.where(upper, along_arm[:, 1] - lobe_y, dy)
                along = ~shoulder & (heights >= low)
                (dx, lean), (dy, pitch) = straight(heights, dx, along, shoulder), straight(heights, dy, along, shoulder)
                inset = np.interp(co[:, 2], heights, edge) - co[:, 0] * side
                moves = inset < 0.07
                stays = (inset > 0.13) | (co[:, 2] > crown) | (np.abs(co[:, 0] - midline) < 0.09)
                free = co[:, 2] < (low if cut is None else cut) - 0.02
                moves = np.where(free, False if cut is None else cuffs[side], moves)
                stays = np.where(free, True if cut is None else ~cuffs[side], stays)
                moves &= ~stays
                weight = harmonic_weights(len(co), edges, moves | stays, moves.astype(float))
                out[:, 0] += weight * np.interp(co[:, 2], heights, dx)
                out[:, 1] += weight * np.interp(co[:, 2], heights, dy)
                stats[name]["lean_degrees"] = round(float(np.degrees(np.arctan(lean * side))), 1)
                stats[name]["pitch_degrees"] = round(float(np.degrees(np.arctan(pitch))), 1)
                stats[name]["sleeve_end_m"] = round(float(low), 3)
            print(f"sleeve {side:+d}: {stats[name]}")
            continue

        skin_out = body["skin"] & (out_there > 0.10)
        inset = np.interp(co[:, 2], heights, edge) - co[:, 0] * side
        moves = inset < 0.07
        stays = (inset > 0.13) | (co[:, 2] > crown) | (np.abs(co[:, 0] - midline) < 0.09)
        free = co[:, 2] < cut - 0.02
        moves = np.where(free, cuffs[side], moves)
        stays = np.where(free, ~cuffs[side], stays)
        moves &= ~stays
        weight = harmonic_weights(len(co), edges, moves | stays, moves.astype(float))
        sleeve = weight > 0.5
        along = ~shoulder & (heights >= low)
        (dx, lean), (dy, pitch) = straight(heights, dx, along, shoulder), straight(heights, dy, along, shoulder)
        ends = np.sort(skin[((skin[:, 0] - midline) * side > 0.06) & (np.abs(skin[:, 2] - heights[wrist]) < 0.03), 2])
        trim = float(np.clip(ends[2] - low, 0, CUFF_TRIM)) if len(ends) > 2 else 0.0
        out[:, 0] += weight * np.interp(co[:, 2], heights, dx)
        out[:, 1] += weight * np.interp(co[:, 2], heights, dy)
        out[:, 2] += weight * trim * np.clip((yoke - co[:, 2]) / (yoke - low), 0, 1)
        bottom = low + trim
        pose = {
            "lean_degrees": round(float(np.degrees(np.arctan(lean * side))), 1),
            "pitch_degrees": round(float(np.degrees(np.arctan(pitch))), 1),
            "cuff_shift_m": [round(float(dx[0]), 3), round(float(dy[0]), 3)],
            "cuff_raised_m": round(trim, 3),
        }
        mine = (skin_out | (x > np.interp(z, heights, body_edge) - ARM_WIDTH)) & (z > bottom + ARM_MARGIN) & (z < crown)
        limb |= mine
        bare |= mine & ~body["cloth"]
        tree = KDTree(int(sleeve.sum()))
        for i, p in enumerate(out[sleeve]):
            tree.insert(p, i)
        tree.balance()
        for i in np.where(mine)[0]:
            arm[i] = tree.find(body["co"][i])[2] < ARM_REACH
        stats[name] = {**pose, "arm_vertices_hidden": int((arm & (x > midline * side)).sum())}
        print(f"sleeve {side:+d}: {pose}")
    return out, {"limb": limb, "bare": bare, "arm": arm, "tube": tube, "gone": gone, "drawn": drawn}, stats


def upper_arm(body, midline, side, heights, body_edge, centre, elbow):
    """The upper arm inside the sleeve the avatar was scanned in: a straight tube from the bare elbow to the shoulder.

    The tube starts where the arm's skin first shows below that sleeve, a little thicker than the arm is
    there, and ends under the point of the shoulder, where the avatar's outline turns in towards the neck.
    Returns the tube's centre line, the scan vertices on that sleeve, the slack sleeve cloth between arm
    and torso, and where every vertex goes when the sleeve is drawn in to the tube."""
    co = body["co"]
    skin = co[body["skin"]]
    base = elbow - 0.03
    ring = skin[(np.abs(skin[:, 2] - base) < 0.02) & ((skin[:, 0] - midline) * side > 0.06)]
    if len(ring) < 10:
        nothing = np.zeros(len(co), dtype=bool)
        return None, nothing, nothing, co, {"note": "no bare arm shows below the scanned sleeve"}
    low, high = ring.min(0), ring.max(0)
    radius = float(np.clip(1.1 * (high[0] - low[0] + high[1] - low[1]) / 4, 0.04, 0.05))
    start = (low[:2] + high[:2]) / 2
    steep = np.where((heights[:-2] > elbow + 0.15) & (body_edge[:-2] - body_edge[2:] > 0.018))[0]
    top = heights[steep[0]] if len(steep) else heights[-1]
    joint = np.abs(heights - (top - 0.05)).argmin()
    lean = (np.array([(body_edge[joint] - radius) * side, centre[joint]]) - start) / (heights[joint] - base)

    def line(height):
        return start + lean * (np.atleast_1d(height)[:, None] - base)

    z = co[:, 2]
    offset = co[:, :2] - line(z)
    r = np.linalg.norm(offset, axis=1)
    across = offset[:, 0] * side
    sleeve = (z > base) & (z < top) & ((z > elbow - 0.01) | body["cloth"] | ((z > elbow - 0.025) & (r > radius + 0.015)))
    on = sleeve & (across > -radius - 0.02) & ((r < radius + 0.02) | ((across > -0.5 * radius) & (r < radius + 0.14)))
    pull = np.clip((top - z) / 0.06, 0, 1)
    placed = co.copy()
    placed[:, :2] -= offset * (pull * np.clip(1 - radius / np.maximum(r, 1e-9), 0, None))[:, None]
    slack = sleeve & ~on & (z < top - 0.12) & (across > -radius - 0.08) & (np.abs(offset[:, 1]) < radius + 0.14)
    info = {
        "radius_m": round(radius, 3),
        "from_m": round(float(base), 3),
        "to_m": round(float(top), 3),
        "lean_degrees": round(float(np.degrees(np.arctan(-lean[0] * side))), 1),
        "pitch_degrees": round(float(np.degrees(np.arctan(lean[1]))), 1),
        "vertices_drawn_in": int(on.sum()),
        "slack_vertices_dropped": int(slack.sum()),
    }
    return line, on, slack, placed, info


def neck_base(body, placement):
    """Draws the base of the neck where the avatar was scanned in a collar.

    The scanned collar and yoke sink just under where they were and are smoothed into one sheet from the
    bare neck out to the shoulders, so a neckline that leaves them in view shows a neck and not a collar."""
    co, faces, drawn = body["co"], body["faces"], body["drawn"]
    reach = np.hypot(co[:, 0] - placement["neck_x"], co[:, 1] - placement["neck_y"])
    zone = body["cloth"] & (co[:, 2] > placement["chin"] - NECK_DROP) & (co[:, 2] < placement["chin"] - NECK_CLEAR) & (reach < NECK_REACH)
    bare = np.where(~body["cloth"] & (co[:, 2] > placement["chin"] - NECK_DROP - 0.05))[0]
    if not zone.any() or not len(bare):
        return zone
    tree = KDTree(len(bare))
    for k, i in enumerate(bare):
        tree.insert(co[i], k)
    tree.balance()
    index = np.where(zone)[0]
    away = np.array([tree.find(co[i])[2] for i in index])
    depth = COLLAR_DEPTH * np.clip(away / 0.02, 0, 1) * np.clip((NECK_REACH - reach[index]) / 0.04, 0, 1)
    drawn[index] -= vertex_normals(co, faces)[index] * depth[:, None]
    edges = unique_edges(faces)
    edges = edges[zone[edges].any(axis=1)]
    degree = np.bincount(edges.reshape(-1), minlength=len(co))
    for _ in range(NECK_ROUNDS):
        total = np.stack([np.bincount(edges[:, 0], drawn[edges[:, 1], k], minlength=len(co)) + np.bincount(edges[:, 1], drawn[edges[:, 0], k], minlength=len(co)) for k in range(3)], axis=1)
        drawn[index] += 0.5 * (total[index] / degree[index, None] - drawn[index])
    return zone


def neck_opening(body, garment_co, placement, sectors=48):
    """Scan vertices that stand above the garment's neckline, read by direction around the neck.

    The garment does not reach them, so they neither push it nor count as poking through it."""
    centre = np.array([placement["neck_x"], placement["neck_y"]])

    def around(points):
        offset = points[:, :2] - centre
        return ((np.arctan2(offset[:, 1], offset[:, 0]) + np.pi) / (2 * np.pi) * sectors).astype(int) % sectors, np.hypot(offset[:, 0], offset[:, 1])

    sector, reach = around(garment_co)
    rim = np.full(sectors, -np.inf)
    np.maximum.at(rim, sector[reach < NECK_REACH], garment_co[reach < NECK_REACH, 2])
    sector, reach = around(body["co"])
    return (reach < NECK_REACH) & (body["co"][:, 2] > rim[sector] - 0.005)


# ---------------------------------------------------------------- collision

def neighbours(co, radius):
    tree = KDTree(len(co))
    for i, p in enumerate(co):
        tree.insert(p, i)
    tree.balance()
    rows, cols, dist = [], [], []
    for i, p in enumerate(co):
        found = tree.find_range(p, radius)
        rows.extend([i] * len(found))
        cols.extend(f[1] for f in found)
        dist.extend(f[2] for f in found)
    return np.array(rows), np.array(cols), np.array(dist)


def body_samples(body, low, high):
    """Points on the body surface between the heights the garment spans, their outward normals, and whether they are bare skin or scanned clothing.

    The avatar's arms are left out: a sleeve stands in for the arm it covers and must not chase it, and an
    arm that hangs outside the garment is not something for the cloth to wrap. So is everything above the
    neckline, which the garment does not reach."""
    co, faces = body["co"], body["faces"]
    corners = co[faces]
    face_normals = np.cross(corners[:, 1] - corners[:, 0], corners[:, 2] - corners[:, 0])
    face_normals /= np.maximum(np.linalg.norm(face_normals, axis=1), 1e-12)[:, None]
    points = np.concatenate([co, corners.mean(1)])
    normals = np.concatenate([vertex_normals(co, faces), face_normals])
    skin = np.concatenate([body["skin"], body["skin"][faces].all(axis=1)])
    cloth = np.concatenate([body["cloth"], body["cloth"][faces].all(axis=1)])
    apart = body["limb"] | body["open"]
    apart = np.concatenate([apart, apart[faces].any(axis=1)])
    inside = (points[:, 2] > low) & (points[:, 2] < high) & ~apart
    return points[inside], normals[inside], skin[inside], cloth[inside]


def required_push(co, faces, points, normals, tolerance):
    """Finds where the body shows through and how far the cloth just under it has to come out.

    Only the first wall under an exposed body point is asked to move, so linings and walls buried
    deeper never get pulled through the surface that hides them."""
    cloth = BVHTree.FromPolygons(co.tolist(), faces.tolist())
    need = np.zeros(len(co))
    direction = np.zeros((len(co), 3))
    for point, normal, allowed in zip(points, normals, tolerance):
        p, n = Vector(point), Vector(normal)
        if cloth.ray_cast(p + n * 1e-4, n, MASK_REACH)[0] is not None:
            continue
        _, _, face, depth = cloth.ray_cast(p - n * 1e-4, -n, MAX_PUSH)
        if face is None or depth <= allowed:
            continue
        amount = depth - allowed + OUTER_CLEARANCE
        for v in faces[face]:
            if amount > need[v]:
                need[v] = amount
                direction[v] = normal
    return need, direction


def push_out(co, faces, body):
    """Brings the garment out where the body would stand well proud of it.

    At the hem and cuffs the cloth must clear the body, and at the collar it must clear bare skin.
    Elsewhere the garment keeps its own shape while the body sits up to POKE_TOLERANCE outside it,
    and the mask hides that part of the scan. Above the reach of the hem the clothing the avatar
    was scanned in never pushes at all: the garment replaces it, slack and all, so its bulk is not
    the body's. The avatar's arms never push, so a sleeve keeps its line and the body of the
    garment stays between the arm and the torso. Each push drags its neighbourhood along, so
    folds survive."""
    n = len(co)
    low, high = co[:, 2].min(), co[:, 2].max()
    points, normals, skin, cloth = body_samples(body, low, high)
    above_hem = np.clip((points[:, 2] - low - RIM_BAND) / RIM_BAND, 0, 1)
    below_collar = np.clip((high - points[:, 2] - RIM_BAND) / RIM_BAND, 0, 1)
    replaced = np.where(cloth, MAX_PUSH * np.clip((points[:, 2] - low - 2 * RIM_BAND) / RIM_BAND, 0, 1), 0)
    tolerance = POKE_TOLERANCE * np.minimum(above_hem, np.where(skin, below_collar, 1)) + replaced
    rows, cols, dist = neighbours(co, PUSH_RADIUS)
    falloff = (1 - (dist / PUSH_RADIUS) ** 2) ** 2
    count = np.bincount(rows, falloff, minlength=n)
    start = co.copy()
    co = co.copy()
    for round_index in range(PUSH_ROUNDS):
        need, outward = required_push(co, faces, points, normals, tolerance)
        print(f"push round {round_index}: {int((need > 0).sum())} vertices to bring out, furthest {need.max() * 100:.1f} cm")
        if need.max() < 0.001:
            break
        reach = need[cols] * falloff
        size = np.zeros(n)
        np.maximum.at(size, rows, reach)
        direction = np.stack([np.bincount(rows, reach * outward[cols, k], minlength=n) for k in range(3)], axis=1)
        direction /= np.maximum(np.linalg.norm(direction, axis=1), 1e-12)[:, None]
        move = direction * size[:, None]
        co += np.stack([np.bincount(rows, falloff * move[cols, k], minlength=n) for k in range(3)], axis=1) / count[:, None]
    return co, np.linalg.norm(co - start, axis=1)


# ---------------------------------------------------------------- body mask

def mask_body(body, garment_co, garment_faces, ceiling):
    """Drops the scan faces the garment hides or that sit just outside it, so the garment reads as the outer layer.

    Of the avatar's arms, only the part a long sleeve covers goes: bare skin outside the garment stays whole,
    and so does whatever stands above the neckline unless cloth lies over it.
    Between the garment's hem band and the ceiling the garment replaces the clothing the avatar was scanned
    in. There that clothing goes wherever the garment's cloth lies under it, however far it pokes through,
    and the rest of it, which the garment leaves in view, is marked in the second mask to be shown as skin."""
    co, faces = body["drawn"], body["faces"]
    normals = vertex_normals(co, faces)
    cloth = BVHTree.FromPolygons(garment_co.tolist(), garment_faces.tolist())
    low, high = garment_co[:, 2].min(), garment_co[:, 2].max()
    candidates = np.where((co[:, 2] > low) & (co[:, 2] < high))[0]
    covered = np.zeros(len(co), dtype=bool)
    spin = np.linspace(0, 2 * np.pi, 6, endpoint=False)
    for i in candidates:
        normal = Vector(normals[i])
        side = normal.orthogonal().normalized()
        other = normal.cross(side)
        origin = Vector(co[i]) + normal * 0.001
        rays = [normal] + [normal * np.cos(MASK_CONE) + (side * np.cos(a) + other * np.sin(a)) * np.sin(MASK_CONE) for a in spin]
        hits = sum(cloth.ray_cast(origin, ray, MASK_REACH)[0] is not None for ray in rays)
        beneath = cloth.ray_cast(Vector(co[i]) - normal * 0.001, -normal, MASK_POKE)[0] is not None
        covered[i] = (beneath and not body["open"][i]) or hits >= len(rays) - 1
    covered = (covered & ~body["bare"]) | body["arm"]
    keep = ~covered[faces].all(axis=1) & ~body["gone"][faces].any(axis=1)

    fabric = body["cloth"] | body["tube"]
    height = co[faces][:, :, 2].mean(axis=1)
    replaced = fabric[faces].any(axis=1) & (height > low + RIM_BAND) & (height < ceiling)
    scan = BVHTree.FromPolygons(co.tolist(), faces.tolist())
    for i in np.unique(faces[keep & replaced]):
        if body["tube"][i] or body["open"][i] or not body["cloth"][i]:
            continue
        normal = Vector(normals[i])
        origin = Vector(co[i]) - normal * 0.001
        depth = cloth.ray_cast(origin, -normal, MASK_REACH)[3]
        if depth is not None:
            through = scan.ray_cast(origin, -normal, MASK_REACH)[3]
            covered[i] |= through is None or depth < through
    keep &= ~(replaced & covered[faces].any(axis=1))
    bared = keep & replaced

    kept = faces[keep]
    island = components(len(co), unique_edges(kept))[kept[:, 0]]
    ids, counts = np.unique(island, return_counts=True)
    inside = (co[kept][:, :, 2].min(1) > low) & (co[kept][:, :, 2].max(1) < high)
    stray = np.isin(island, ids[counts < MASK_ISLAND]) & inside
    keep[np.where(keep)[0][stray]] = False
    return keep, bared & keep


def skin_texels(body, bared):
    """Texture coordinates that show the bared faces as skin.

    Each patch of them takes one texel of real bare skin from the scan's own texture: the one closest in
    colour to the skin that borders the patch."""
    co, faces, colour, bare = body["drawn"], body["faces"], body["colour"], body["skin"]
    uv = body["uv"].copy()
    if not bared.any():
        return uv
    tone = colour[faces]
    spread = np.abs(tone - tone.mean(axis=1, keepdims=True)).max(axis=(1, 2))
    a, b = uv[:, 1] - uv[:, 0], uv[:, 2] - uv[:, 0]
    area = np.abs(a[:, 0] * b[:, 1] - a[:, 1] * b[:, 0])
    clean = bare[faces].all(axis=1)
    usable = clean & (area >= np.median(area[clean]))
    skin_index = np.where(bare)[0]
    tree = KDTree(len(skin_index))
    for k, i in enumerate(skin_index):
        tree.insert(co[i], k)
    tree.balance()
    index = np.where(bared)[0]
    patch = components(len(co), unique_edges(faces[index]))[faces[index, 0]]
    for root in np.unique(patch):
        mine = index[patch == root]
        near = sorted({k for p in co[np.unique(faces[mine])][::25] for _, k, _ in tree.find_range(p, 0.15)})
        target = np.median(colour[skin_index[near]] if near else colour[bare], axis=0)
        best = np.where(usable, np.linalg.norm(tone.mean(axis=1) - target, axis=1) + spread, np.inf).argmin()
        uv[mine] = body["uv"][best].mean(axis=0)
    return uv


# ---------------------------------------------------------------- export

def to_usd(points):
    return np.stack([points[:, 0], points[:, 2], -points[:, 1]], axis=1)


def usd_tuples(values, digits):
    template = "(" + ", ".join([f"%.{digits}f"] * values.shape[1]) + ")"
    return "[" + ", ".join(template % tuple(row) for row in values.tolist()) + "]"


def mesh_usda(co, faces, uv, material):
    used, compact = np.unique(faces, return_inverse=True)
    points = to_usd(co[used])
    normals = to_usd(vertex_normals(co, faces)[used])
    st, st_index = np.unique(np.round(uv.reshape(-1, 2), 6), axis=0, return_inverse=True)
    return f"""    def Mesh "Mesh" (
        prepend apiSchemas = ["MaterialBindingAPI"]
    )
    {{
        uniform bool doubleSided = 1
        float3[] extent = {usd_tuples(np.stack([points.min(0), points.max(0)]), 5)}
        int[] faceVertexCounts = [{", ".join(["3"] * len(faces))}]
        int[] faceVertexIndices = [{", ".join(map(str, compact.reshape(-1).tolist()))}]
        rel material:binding = <{material}>
        normal3f[] normals = {usd_tuples(normals, 4)} (
            interpolation = "vertex"
        )
        point3f[] points = {usd_tuples(points, 5)}
        texCoord2f[] primvars:st = {usd_tuples(st, 6)} (
            interpolation = "faceVarying"
        )
        int[] primvars:st:indices = [{", ".join(map(str, st_index.reshape(-1).tolist()))}]
        uniform token subdivisionScheme = "none"
    }}
"""


def layer_usda(name, materials, mesh):
    return f"""#usda 1.0
(
    defaultPrim = "{name}"
    metersPerUnit = 1
    upAxis = "Y"
)

def Xform "{name}"
{{
    def Scope "Materials"
    {{
{materials}    }}

{mesh}}}
"""


def garment_material(textures, build):
    root = "/Garment/Materials/Fabric"
    lines = [f'        def Material "Fabric"\n        {{\n            token outputs:surface.connect = <{root}/Surface.outputs:surface>\n']
    surface = ['            def Shader "Surface"\n            {\n                uniform token info:id = "UsdPreviewSurface"\n']
    shaders = [f'            def Shader "St"\n            {{\n                uniform token info:id = "UsdPrimvarReader_float2"\n                string inputs:varname = "st"\n                float2 outputs:result\n            }}\n']
    inputs = {"basecolor": ("color3f", "diffuseColor"), "roughness": ("float", "roughness"), "metallic": ("float", "metallic"), "normal": ("normal3f", "normal")}
    (build / "textures").mkdir(exist_ok=True)
    for slot, (kind, name) in inputs.items():
        texture = textures.get(slot)
        if texture is None:
            if slot == "roughness":
                surface.append("                float inputs:roughness = 0.85\n")
            continue
        file = f"textures/garment_{slot}{texture['ext']}"
        (build / file).write_bytes(texture["data"])
        if texture["ext"] == ".png" and shutil.which("sips"):
            subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "90", str(build / file), "--out", str(build / file).replace(".png", ".jpg")], check=True, capture_output=True)
            (build / file).unlink()
            file = file.replace(".png", ".jpg")
        channel = texture["channel"]
        output = "float3 outputs:rgb" if channel == "rgb" else f"float outputs:{channel}"
        extra = ""
        if slot == "normal":
            extra = '                float4 inputs:bias = (-1, -1, -1, 1)\n                float4 inputs:scale = (2, 2, 2, 1)\n'
        color_space = "sRGB" if slot == "basecolor" else "raw"
        shaders.append(
            f'            def Shader "{slot.capitalize()}"\n            {{\n                uniform token info:id = "UsdUVTexture"\n'
            f'                asset inputs:file = @{file}@\n{extra}                token inputs:sourceColorSpace = "{color_space}"\n'
            f'                float2 inputs:st.connect = <{root}/St.outputs:result>\n                token inputs:wrapS = "repeat"\n'
            f'                token inputs:wrapT = "repeat"\n                {output}\n            }}\n')
        surface.append(f"                {kind} inputs:{name}.connect = <{root}/{slot.capitalize()}.outputs:{channel}>\n")
    surface.append("                token outputs:surface\n            }\n")
    return "".join(lines + surface + shaders) + "        }\n"


def package(build, body, keep, garment, fitted, out_path, avatar_path):
    avatar_dir = build / "avatar"
    with zipfile.ZipFile(avatar_path) as archive:
        archive.extractall(avatar_dir)
        root_layer = archive.namelist()[0]
    root_path = avatar_dir / root_layer
    text = subprocess.run(["usdcat", str(root_path)], check=True, capture_output=True, text=True).stdout
    text = text.replace("token inputs:frame:stPrimvarName", "string inputs:frame:stPrimvarName")
    text = text.replace("token inputs:varname", "string inputs:varname")
    patched_layer = Path(root_layer).with_name(f"{Path(root_layer).stem}-arkit.usda")
    patched_path = avatar_dir / patched_layer
    patched_path.parent.mkdir(parents=True, exist_ok=True)
    patched_path.write_text(text)
    binding = text.split("rel material:binding = <", 1)[1].split(">", 1)[0]
    body_material = f'        def Material "Scan" (\n            prepend references = @avatar/{patched_layer.as_posix()}@<{binding}>\n        )\n        {{\n        }}\n'
    (build / "body.usda").write_text(layer_usda("Body", body_material, mesh_usda(body["drawn"], body["faces"][keep], body["painted"][keep], "/Body/Materials/Scan")))
    (build / "garment.usda").write_text(layer_usda("Garment", garment_material(garment["textures"], build), mesh_usda(fitted, garment["faces"], garment["uv"], "/Garment/Materials/Fabric")))
    (build / "look.usda").write_text("""#usda 1.0
(
    defaultPrim = "Look"
    metersPerUnit = 1
    upAxis = "Y"
)

def Xform "Look" (
    kind = "component"
)
{
    def "Body" (
        prepend references = @body.usda@
    )
    {
    }

    def "Garment" (
        prepend references = @garment.usda@
    )
    {
    }
}
""")
    out_path.unlink(missing_ok=True)
    subprocess.run(["usdzip", "--arkitAsset", "look.usda", str(out_path)], check=True, cwd=build)


# ---------------------------------------------------------------- review

REVIEW_SHOTS = {
    "front": ((0, -1, 0), (0, 0, 0.93), 2.0),
    "back": ((0, 1, 0), (0, 0, 0.93), 2.0),
    "left": ((-1, 0, 0), (0, 0, 0.93), 2.0),
    "right": ((1, 0, 0), (0, 0, 0.93), 2.0),
    "quarter": ((0.7, -0.7, 0.15), (0, 0, 0.93), 2.0),
    "torso-front": ((0, -1, 0.05), (0, 0, 1.27), 0.95),
    "torso-back": ((0, 1, 0.05), (0, 0, 1.27), 0.95),
    "torso-left": ((-1, 0, 0.05), (0, 0, 1.27), 0.95),
    "torso-right": ((1, 0, 0.05), (0, 0, 1.27), 0.95),
    "collar": ((0.25, -1, 0.45), (0, 0, 1.6), 0.5),
    "collar-back": ((-0.25, 1, 0.3), (0, 0.05, 1.6), 0.5),
    "cuff-minus-x": ((-1, -0.7, 0.1), (-0.2, 0, 0.97), 0.5),
    "cuff-plus-x": ((1, -0.7, 0.1), (0.2, 0, 0.97), 0.5),
    "hem-from-below": ((0.3, -1, -0.4), (0, 0, 0.95), 0.7),
}


def render_review(usdz, folder):
    """Renders the packaged file itself, so the review shows what the app will load."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.usd_import(filepath=str(usdz))
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_specular_highlight = False
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 800, 800
    scene.world = bpy.data.worlds.new("review")
    scene.world.color = (0.82, 0.80, 0.76)
    scene.view_settings.view_transform = "Standard"
    folder.mkdir(parents=True, exist_ok=True)
    for name, (direction, target, span) in REVIEW_SHOTS.items():
        data = bpy.data.cameras.new(name)
        data.type = "ORTHO"
        data.ortho_scale = span
        camera = bpy.data.objects.new(name, data)
        scene.collection.objects.link(camera)
        camera.location = Vector(target) + Vector(direction).normalized() * 6
        camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.camera = camera
        scene.render.filepath = str(folder / f"{name}.png")
        bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- main

def source_scale(garment, dimensions_file):
    """Uniform scale that makes the mesh match the one measurement the source dimensions manifest enforces.

    A manifest with an automatic scale names no garment measurement, so the asset keeps the size it arrives with."""
    if dimensions_file is None:
        return 1.0, None
    manifest = json.loads(dimensions_file.read_text())
    rule = manifest["meshy_scale"]
    if rule["mode"] == "auto":
        return 1.0, manifest
    metres = manifest["measurements"][rule["measurement"]] * {"cm": 0.01, "in": 0.0254, "m": 1}[manifest["units"]]
    size = garment["co"].max(0) - garment["co"].min(0)
    current = size[2] if rule["mode"] == "height" else size.max()
    return metres / current, manifest


def main():
    args = parse_args()
    started = time.time()
    out_dir = args.output_root / args.look
    usdz = out_dir / f"{args.look}.usdz"
    report_path = out_dir / "fit-report.json"
    key = {
        "pipeline": PIPELINE_VERSION,
        "avatar": sha256(args.avatar),
        "garment": sha256(args.garment),
        "dimensions": sha256(args.dimensions_file) if args.dimensions_file else None,
    }
    if not args.force and usdz.exists() and report_path.exists() and json.loads(report_path.read_text()).get("cache_key") == key:
        print(f"cache hit: {usdz}")
    else:
        build = out_dir / "build"
        shutil.rmtree(build, ignore_errors=True)
        build.mkdir(parents=True)
        body = import_asset(args.avatar, colours=True)
        garment = import_asset(args.garment)
        scale, manifest = source_scale(garment, args.dimensions_file)
        garment["co"] *= scale
        garment["co"][:, 2] -= garment["co"][:, 2].min()
        size = garment["co"].max(0) - garment["co"].min(0)
        print(f"avatar {len(body['co'])} vertices, stature {body['co'][:, 2].max():.3f} m; garment {len(garment['co'])} vertices, {size[0]:.3f} x {size[1]:.3f} x {size[2]:.3f} m, scale applied {scale:.4f}")

        bvh = BVHTree.FromPolygons(body["co"].tolist(), body["faces"].tolist())
        edges = unique_edges(garment["faces"])
        offset, placement = place(garment, body, bvh)
        placed = garment["co"] + offset
        posed, arms, sleeves = align_sleeves(placed, garment["faces"], edges, body, placement["midline_x"])
        body.update(arms)
        body["neck"] = neck_base(body, placement)
        body["open"] = neck_opening(body, posed, placement)
        fitted, moved = push_out(posed, garment["faces"], body)
        print(f"push: furthest {moved.max() * 100:.1f} cm at {np.round(fitted[moved.argmax()], 3).tolist()}, {int((moved > 0.05).sum())} vertices over 5 cm")
        keep, bared = mask_body(body, fitted, garment["faces"], placement["chin"] - NECK_CLEAR)
        body["painted"] = skin_texels(body, bared)
        package(build, body, keep, garment, fitted, usdz, args.avatar)
        checker = subprocess.run(["usdchecker", "--arkit", str(usdz)], capture_output=True, text=True)
        complaints = [line for line in (checker.stdout + checker.stderr).splitlines() if line.startswith("Error")]

        shown = np.concatenate([body["drawn"][np.unique(body["faces"][keep])], fitted])
        report = {
            "cache_key": key,
            "look": args.look,
            "avatar": str(args.avatar),
            "garment": str(args.garment),
            "kind": "style preview",
            "note": "A geometric drape for visualisation. It is not a cloth simulation and makes no claim about fit.",
            "garment_size_m": [round(float(v), 4) for v in size],
            "scale_applied": round(float(scale), 5),
            "scale_source": manifest["source"] if manifest else "none: the asset's own scale was trusted",
            "scale_rule": manifest["meshy_scale"] if manifest else None,
            "placement": {"offset_m": [round(float(v), 4) for v in offset], **{k: round(float(v), 4) for k, v in placement.items()}},
            "sleeves": sleeves,
            "pushed": {
                "vertices_moved_over_5mm": int((moved > 0.005).sum()),
                "vertex_count": int(len(moved)),
                "median_m": round(float(np.median(moved)), 4),
                "p95_m": round(float(np.percentile(moved, 95)), 4),
                "max_m": round(float(moved.max()), 4),
            },
            "body_faces_hidden": int((~keep).sum()),
            "body_faces_total": int(len(keep)),
            "scanned_clothing_shown_as_skin": {
                "faces": int(bared.sum()),
                "upper_arm_vertices_drawn_in": int(body["tube"].sum()),
                "neck_base_vertices_drawn_in": int(body["neck"].sum()),
                "note": "Where the garment leaves the top the avatar was scanned in on view, that cloth is drawn in to the body and shown in the colour of the skin beside it. It is drawn, not scanned.",
            },
            "usdchecker_arkit": {"passed": checker.returncode == 0, "errors": complaints},
            "bounds_m": {"min": [round(float(v), 4) for v in shown.min(0)], "max": [round(float(v), 4) for v in shown.max(0)]},
            "review": sorted(f"review/{name}.png" for name in REVIEW_SHOTS),
            "seconds": round(time.time() - started, 1),
        }
        report_path.write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2))
        render_review(usdz, out_dir / "review")
    if args.install:
        target = REPO / "Shoppy/Resources/Models" / f"{args.look}.usdz"
        shutil.copy2(usdz, target)
        print(f"installed: {target}")
    print(f"look: {usdz}")


if __name__ == "__main__":
    main()

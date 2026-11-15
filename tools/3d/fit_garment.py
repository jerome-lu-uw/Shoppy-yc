#!/usr/bin/env python3
"""Fit a standalone garment onto the scanned avatar and package a dressed look.

Run headless with Blender 3.6 or newer:

    /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/3d/fit_garment.py -- \
        --garment Shoppy/Resources/Models/garment-smooth-spacer-quarter-zip.usdz \
        --look look-smooth-spacer-quarter-zip --install

The garment keeps the real-world scale it arrives with. It is placed on the
avatar's shoulders, each sleeve hangs in one straight line along the avatar's
arm, the cloth comes out only where the body would stand well proud of it, and
the scan faces it covers are hidden. The result is a style preview, not a cloth
simulation and not a statement about fit.
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

PIPELINE_VERSION = "fit-2"
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
        asset["skin"] = is_skin(vertex_colours(ob, len(asset["co"]), asset["faces"], asset["uv"]))
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
    """Rigid placement: collar around the neck, yoke resting on the shoulders, collar below the chin."""
    co, faces = garment["co"], garment["faces"]
    height = co[:, 2].max()
    marks = body_landmarks(body)
    ring = cross_section(co, faces, height - 0.05)
    cx, cy = (ring[:, 0].min() + ring[:, 0].max()) / 2, (ring[:, 1].min() + ring[:, 1].max()) / 2
    front = (np.abs(co[:, 0] - cx) < 0.035) & (co[:, 1] < cy - 0.02) & (co[:, 2] > height - 0.2)
    collar_front_top = co[front, 2].max()
    tx, ty = marks["neck_x"] - cx, marks["neck_y"] - cy
    below_chin = marks["chin"] - 0.004 - collar_front_top

    yoke = (co[:, 2] > height - 0.20) & (co[:, 2] < height - 0.07) & (np.abs(co[:, 0] - cx) < 0.15)
    resting = below_chin + 0.05
    for dz in np.arange(below_chin + 0.05, below_chin - 0.12, -0.005):
        depth = np.maximum(-signed_distance(bvh, co[yoke] + [tx, ty, dz])[0], 0)
        if np.percentile(depth, 90) > 0.01:
            break
        resting = dz
    dz = min(resting, below_chin)
    print(f"placement: neck ({marks['neck_x']:.3f}, {marks['neck_y']:.3f}) chin {marks['chin']:.3f} "
          f"collar front top {collar_front_top:.3f} resting dz {resting:.3f} below-chin dz {below_chin:.3f} -> dz {dz:.3f}")
    return np.array([tx, ty, dz]), {"midline_x": cx + tx, "chin": marks["chin"], "resting_dz": resting, "below_chin_dz": below_chin}


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
    """The part of each sleeve that hangs free of the torso, found by cutting the garment at falling heights."""
    floor, top = co[:, 2].min(), co[:, 2].max()

    def split(cut):
        below = co[:, 2] < cut
        roots = components(len(co), edges[below[edges[:, 0]] & below[edges[:, 1]]])
        ids, counts = np.unique(roots[below], return_counts=True)
        sides = {}
        for root in ids[counts > 150]:
            x = co[below & (roots == root), 0]
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


def align_sleeves(co, faces, edges, body, midline):
    """Tilts each sleeve, as one straight line from the shoulder, to run along the avatar's arm.

    A sleeve never bends to follow an elbow. It stands in for the arm it covers, so the arm is returned
    for the mask to hide: the outer ARM_WIDTH of the body beside a sleeve, and any bare skin beside one."""
    floor, top = co[:, 2].min(), co[:, 2].max()
    heights = np.arange(floor + 0.005, top - 0.10, 0.01)
    shoulder = heights > top - 0.20
    cut, cuffs = find_cuffs(co, edges, midline)
    out = co.copy()
    arm = np.zeros(len(body["co"]), dtype=bool)
    stats = {"free_cuff_height": None if cut is None else round(float(cut - floor), 3)}
    skin = body["co"][body["skin"]]
    for side in (-1, 1):
        edge, body_edge, dx, dy = (np.full(len(heights), np.nan) for _ in range(4))
        forearm = np.zeros(len(heights), dtype=bool)
        for k, h in enumerate(heights):
            mine = cross_section(co, faces, h)
            theirs = cross_section(body["co"], body["faces"], h)
            if not len(mine) or not len(theirs):
                continue
            edge[k], body_edge[k] = (mine[:, 0] * side).max(), (theirs[:, 0] * side).max()
            lobe = mine[mine[:, 0] * side > edge[k] - ARM_WIDTH]
            limb = skin[(np.abs(skin[:, 2] - h) < 0.02) & ((skin[:, 0] - midline) * side > 0.06)]
            forearm[k] = len(limb) >= 5
            if not forearm[k]:
                limb = theirs[theirs[:, 0] * side > body_edge[k] - ARM_WIDTH]
            dx[k] = ((limb[:, 0] * side).max() + SLEEVE_MARGIN - edge[k]) * side
            dy[k] = (limb[:, 1].min() + limb[:, 1].max()) / 2 - (lobe[:, 1].min() + lobe[:, 1].max()) / 2
        if forearm.any():
            wrist = forearm.argmax()
            dx[:wrist], dy[:wrist] = dx[wrist], dy[wrist]
        edge, body_edge, dx, dy = (smooth(fill_gaps(v)) for v in (edge, body_edge, dx, dy))
        low = co[cuffs[side], 2].min() if cut is not None else floor
        along = ~shoulder & (heights >= low)
        (dx, lean), (dy, pitch) = straight(heights, dx, along, shoulder), straight(heights, dy, along, shoulder)

        inset = np.interp(co[:, 2], heights, edge) - co[:, 0] * side
        moves = inset < 0.07
        stays = (inset > 0.13) | (co[:, 2] > top - 0.10) | (np.abs(co[:, 0] - midline) < 0.09)
        if cut is not None:
            free = co[:, 2] < cut - 0.02
            moves = np.where(free, cuffs[side], moves)
            stays = np.where(free, ~cuffs[side], stays)
        moves &= ~stays
        weight = harmonic_weights(len(co), edges, moves | stays, moves.astype(float))
        out[:, 0] += weight * np.interp(co[:, 2], heights, dx)
        out[:, 1] += weight * np.interp(co[:, 2], heights, dy)

        cloth = out[weight > 0.5]
        if cut is not None and len(cloth):
            tree = KDTree(len(cloth))
            for i, p in enumerate(cloth):
                tree.insert(p, i)
            tree.balance()
            x, z = body["co"][:, 0] * side, body["co"][:, 2]
            hem = co[stays, 2].min()
            outer = (x > np.interp(z, heights, body_edge) - ARM_WIDTH) & (z > max(low, hem) + ARM_MARGIN) & (z < heights[-1])
            bare = body["skin"] & (x - midline * side > 0.10) & (z > low + ARM_MARGIN)
            for i in np.where(outer | bare)[0]:
                arm[i] = tree.find(body["co"][i])[2] < ARM_REACH
        stats["minus_x" if side < 0 else "plus_x"] = {
            "lean_degrees": round(float(np.degrees(np.arctan(lean * side))), 1),
            "pitch_degrees": round(float(np.degrees(np.arctan(pitch))), 1),
            "cuff_shift_m": [round(float(dx[0]), 3), round(float(dy[0]), 3)],
            "arm_vertices_hidden": int((arm & ((body["co"][:, 0] - midline) * side > 0)).sum()),
        }
        print(f"sleeve {side:+d}: straight, lean {np.degrees(np.arctan(lean * side)):+.1f} deg, pitch {np.degrees(np.arctan(pitch)):+.1f} deg, cuff shift {dx[0]:+.3f} {dy[0]:+.3f}")
    return out, arm, stats


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
    """Points on the body surface between the heights the garment spans, their outward normals, and whether they are bare skin.

    The arm beside a sleeve is left out: the sleeve stands in for it and must not chase it."""
    co, faces = body["co"], body["faces"]
    corners = co[faces]
    face_normals = np.cross(corners[:, 1] - corners[:, 0], corners[:, 2] - corners[:, 0])
    face_normals /= np.maximum(np.linalg.norm(face_normals, axis=1), 1e-12)[:, None]
    points = np.concatenate([co, corners.mean(1)])
    normals = np.concatenate([vertex_normals(co, faces), face_normals])
    skin = np.concatenate([body["skin"], body["skin"][faces].all(axis=1)])
    arm = np.concatenate([body["arm"], body["arm"][faces].any(axis=1)])
    inside = (points[:, 2] > low) & (points[:, 2] < high) & ~arm
    return points[inside], normals[inside], skin[inside]


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
    and the mask hides that part of the scan. The arm beside a sleeve never pushes, so the sleeve
    keeps its line. Each push drags its neighbourhood along, so folds survive."""
    n = len(co)
    low, high = co[:, 2].min(), co[:, 2].max()
    points, normals, skin = body_samples(body, low, high)
    above_hem = np.clip((points[:, 2] - low - RIM_BAND) / RIM_BAND, 0, 1)
    below_collar = np.clip((high - points[:, 2] - RIM_BAND) / RIM_BAND, 0, 1)
    tolerance = POKE_TOLERANCE * np.minimum(above_hem, np.where(skin, below_collar, 1))
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

def mask_body(body, garment_co, garment_faces):
    """Drops the scan faces the garment hides or that sit just outside it, and the arm beside a sleeve, so the garment reads as the outer layer."""
    co, faces = body["co"], body["faces"]
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
        covered[i] = beneath or hits >= len(rays) - 1
    covered |= body["arm"]
    keep = ~covered[faces].all(axis=1)
    kept = faces[keep]
    island = components(len(co), unique_edges(kept))[kept[:, 0]]
    ids, counts = np.unique(island, return_counts=True)
    inside = (co[kept][:, :, 2].min(1) > low) & (co[kept][:, :, 2].max(1) < high)
    stray = np.isin(island, ids[counts < MASK_ISLAND]) & inside
    keep[np.where(keep)[0][stray]] = False
    return keep


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
    text = subprocess.run(["usdcat", str(avatar_dir / root_layer)], check=True, capture_output=True, text=True).stdout
    binding = text.split("rel material:binding = <", 1)[1].split(">", 1)[0]
    body_material = f'        def Material "Scan" (\n            prepend references = @avatar/{root_layer}@<{binding}>\n        )\n        {{\n        }}\n'
    (build / "body.usda").write_text(layer_usda("Body", body_material, mesh_usda(body["co"], body["faces"][keep], body["uv"][keep], "/Body/Materials/Scan")))
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
    """Uniform scale that makes the mesh match the one measurement the source dimensions manifest enforces."""
    if dimensions_file is None:
        return 1.0, None
    manifest = json.loads(dimensions_file.read_text())
    rule = manifest["meshy_scale"]
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
        posed, body["arm"], sleeves = align_sleeves(placed, garment["faces"], edges, body, placement["midline_x"])
        fitted, moved = push_out(posed, garment["faces"], body)
        keep = mask_body(body, fitted, garment["faces"])
        package(build, body, keep, garment, fitted, usdz, args.avatar)
        checker = subprocess.run(["usdchecker", "--arkit", str(usdz)], capture_output=True, text=True)
        complaints = [line for line in (checker.stdout + checker.stderr).splitlines() if line.startswith("Error")]

        shown = np.concatenate([body["co"][np.unique(body["faces"][keep])], fitted])
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

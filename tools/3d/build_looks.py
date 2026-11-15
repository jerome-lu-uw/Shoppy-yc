"""Builds the calibrated scan and the dressed looks as USDZ files.
Run: Blender -b --python build_looks.py
Garments are offset shells authored over the scan: a style preview, not a cloth simulation."""
import sys, os, subprocess, shutil, json
sys.path.insert(0, "/Users/jerome/.capy/work/shoppy/3d")
from common import *
from mathutils.bvhtree import BVHTree

HEM_TOP = 0.86
WAIST = 0.96
ANKLE = 0.085
MIDLINE_X = 0.03

LOOKS = json.load(open(D + "/looks.json"))

ob, co, orig_usd = load_scan()
me = ob.data
nv = len(co)
col = vertex_colors(ob)
skin = is_skin(col)
tris = np.empty(len(me.polygons) * 3, dtype=np.int64)
me.polygons.foreach_get("vertices", tris)
tris = tris.reshape(-1, 3)
vn = np.empty(nv * 3)
me.vertices.foreach_get("normal", vn)
vn = vn.reshape(nv, 3)
x, y, z = co[:, 0], co[:, 1], co[:, 2]

def edges_of(t):
    e = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
    e.sort(axis=1)
    return np.unique(e, axis=0)

def smooth(val, edges, iters, lam=1.0):
    val = val.astype(float).copy()
    for _ in range(iters):
        acc = np.zeros_like(val)
        cnt = np.zeros(len(val))
        np.add.at(acc, edges[:, 0], val[edges[:, 1]])
        np.add.at(acc, edges[:, 1], val[edges[:, 0]])
        np.add.at(cnt, edges[:, 0], 1)
        np.add.at(cnt, edges[:, 1], 1)
        mean = acc / np.maximum(cnt, 1)[(...,) + (None,) * (val.ndim - 1)]
        val = val + lam * (mean - val)
    return val

E = edges_of(tris)
sn = smooth(vn, E, 6)
sn /= np.linalg.norm(sn, axis=1, keepdims=True) + 1e-9
scan_bvh = BVHTree.FromPolygons(co.tolist(), tris.tolist())

def push_out(p, bvh, clearance):
    moved = 0
    for i in range(len(p)):
        hit = bvh.find_nearest(Vector(p[i]))
        if hit[0] is None:
            continue
        if hit[3] > 0.04:
            continue
        loc, nrm = np.array(hit[0]), np.array(hit[1])
        sd = float(np.dot(p[i] - loc, nrm))
        if sd < clearance:
            p[i] = p[i] + nrm * (clearance - sd)
            moved += 1
    return moved

def make_shell(name, mask, offset, cuts, clearance, smooth_iters=12, extra=None, thickness=0.003, post=None):
    f = tris[mask[tris].all(axis=1)]
    used = np.unique(f)
    remap = -np.ones(nv, dtype=np.int64)
    remap[used] = np.arange(len(used))
    f = remap[f]
    d = smooth(offset, E, 8)[used]
    p = co[used] + sn[used] * d[:, None]
    e = edges_of(f)
    for rounds in range(3):
        p = smooth(p, e, smooth_iters // 3, lam=0.5)
        push_out(p, scan_bvh, clearance)
        if extra is not None:
            push_out(p, extra[0], extra[1])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(p.tolist(), [], f.tolist())
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    for plane_co, plane_no in cuts:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=plane_co, plane_no=plane_no, clear_outer=True)
    # keep the largest connected piece
    bm.verts.ensure_lookup_table()
    seen, best = set(), []
    for v in bm.verts:
        if v in seen:
            continue
        stack, comp = [v], []
        seen.add(v)
        while stack:
            a = stack.pop()
            comp.append(a)
            for ed in a.link_edges:
                b = ed.other_vert(a)
                if b not in seen:
                    seen.add(b)
                    stack.append(b)
        if len(comp) > len(best):
            best = comp
    keep = set(best)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v not in keep], context='VERTS')
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if post is not None:
        pts = np.array([tuple(v.co) for v in bm.verts])
        post(pts)
        for v, q in zip(bm.verts, pts):
            v.co = q
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(o)
    outer = np.array([tuple(v.co) for v in mesh.vertices])
    outer_f = [tuple(pl.vertices) for pl in mesh.polygons]
    mod = o.modifiers.new("solid", 'SOLIDIFY')
    mod.thickness = thickness
    mod.offset = 1
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier="solid")
    for pl in o.data.polygons:
        pl.use_smooth = True
    o.data.update()
    print("SHELL", name, "verts", len(o.data.vertices), "faces", len(o.data.polygons))
    return o, BVHTree.FromPolygons(outer.tolist(), outer_f)

# ---- pants: shorts plus bare legs, widened toward the ankle for a straight leg
leg = (z < 0.74)
pants_off = np.full(nv, 0.007)
leg_off = 0.024 + 0.022 * np.clip(1 - z / 0.74, 0, 1)
medial = np.clip(-sn[:, 0] * np.sign(x - MIDLINE_X), 0, 1)
leg_off = leg_off * (1 - 0.7 * medial)
pants_off[leg] = leg_off[leg]
pants_mask = (z > 0.105) & (z < WAIST + 0.04) & ~(skin & (z > 0.84))
def drop_hem(p):
    low = p[:, 2] < 0.25
    p[low, 2] = 0.25 - (0.25 - p[low, 2]) * (0.25 - ANKLE) / (0.25 - 0.115)
PANTS_CUTS = [(Vector((0, 0, WAIST)), Vector((0, 0, 1))), (Vector((0, 0, 0.115)), Vector((0, 0, -1)))]
pants, pants_bvh = make_shell("Pants", pants_mask, pants_off, PANTS_CUTS, clearance=0.005, smooth_iters=30, post=drop_hem)

wide_off = np.full(nv, 0.007)
wide_leg = (0.030 + 0.075 * np.clip(1 - z / 0.74, 0, 1)) * (1 - 0.85 * medial)
wide_off[leg] = wide_leg[leg]
pants_wide, _ = make_shell("PantsWide", pants_mask, wide_off, PANTS_CUTS, clearance=0.005, smooth_iters=36, post=drop_hem)
PANTS = {"straight": pants, "wide": pants_wide}

# ---- top: the shirt plus forearms and the open collar, cut to a crew neck and a straight hem
top_off = np.full(nv, 0.014)
arm = skin & (z > 0.84) & (z < 1.32) & (np.abs(x - MIDLINE_X) > 0.12)
top_off[arm] = 0.030
top_mask = (z > HEM_TOP - 0.04) & (z < 1.66)
neck_no = Vector((0, -0.32, 1)).normalized()
top, _ = make_shell("Top", top_mask, top_off,
    [(Vector((0, -0.05, 1.548)), neck_no), (Vector((0, 0, HEM_TOP)), Vector((0, 0, -1)))], clearance=0.010, smooth_iters=30, extra=(pants_bvh, 0.006))

def mesh_data(o):
    m = o.data
    m.calc_loop_triangles()
    pts = np.array([tuple(v.co) for v in m.vertices])
    nrm = np.array([tuple(v.normal) for v in m.vertices])
    f = np.array([tuple(t.vertices) for t in m.loop_triangles])
    return pts, nrm, f

def fmt3(a):
    return "[" + ", ".join("(%.5f, %.5f, %.5f)" % tuple(r) for r in a) + "]"

def mesh_usda(name, o, material):
    pts, nrm, f = mesh_data(o)
    up, un = to_usd(pts), to_usd(nrm)
    return '''
    def Mesh "%s" (
        apiSchemas = ["MaterialBindingAPI"]
    )
    {
        uniform bool doubleSided = 1
        float3[] extent = [(%.5f, %.5f, %.5f), (%.5f, %.5f, %.5f)]
        int[] faceVertexCounts = [%s]
        int[] faceVertexIndices = [%s]
        rel material:binding = </Look/Materials/%s>
        normal3f[] normals = %s (
            interpolation = "vertex"
        )
        point3f[] points = %s
        uniform token subdivisionScheme = "none"
    }
''' % (name, *up.min(0), *up.max(0), ", ".join(["3"] * len(f)), ", ".join(str(i) for i in f.ravel()), material, fmt3(un), fmt3(up))

def material_usda(name, rgb, roughness=0.9):
    return '''
        def Material "%s"
        {
            token outputs:surface.connect = </Look/Materials/%s/surfaceShader.outputs:surface>

            def Shader "surfaceShader"
            {
                uniform token info:id = "UsdPreviewSurface"
                color3f inputs:diffuseColor = (%.4f, %.4f, %.4f)
                float inputs:roughness = %.2f
                float inputs:metallic = 0
                token outputs:surface
            }
        }
''' % (name, name, *rgb, roughness)

# scan placement: affine map from the original USD coordinates to the app frame, in USD row-vector form
A = np.hstack([orig_usd, np.ones((nv, 1))])
B = to_usd(co)
X, *_ = np.linalg.lstsq(A, B, rcond=None)
M = np.zeros((4, 4)); M[:, :3] = X; M[3, 3] = 1
matrix = "( " + ", ".join("(" + ", ".join("%.8f" % v for v in row) + ")" for row in M) + " )"

def srgb_to_linear(c):
    return [((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c]

def hex_rgb(h):
    h = h.lstrip('#')
    return srgb_to_linear([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])

build = D + "/build"
shutil.rmtree(build, ignore_errors=True)
os.makedirs(build + "/0")
src = D + "/src"
scan_usda = subprocess.run(["usdcat", src + "/baked_mesh.usdc"], capture_output=True, text=True, check=True).stdout
scan_usda = scan_usda.replace(".png@", ".jpg@")
open(build + "/body.usda", "w").write(scan_usda)
for n in ("tex0", "norm0", "ao0"):
    subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "88", "-Z", "2048", src + "/0/baked_mesh_%s.png" % n, "--out", build + "/0/baked_mesh_%s.jpg" % n], check=True, capture_output=True)

HEADER = '''#usda 1.0
(
    defaultPrim = "Look"
    metersPerUnit = 1
    upAxis = "Y"
)

def Xform "Look" (
    kind = "component"
)
{
    def Xform "Scan" (
        prepend references = @body.usda@</ObjectCapture>
    )
    {
        matrix4d xformOp:transform = %s
        uniform token[] xformOpOrder = ["xformOp:transform"]
    }
''' % matrix

os.makedirs(D + "/dist", exist_ok=True)
def package(name, body):
    path = build + "/" + name + ".usda"
    open(path, "w").write(HEADER + body + "}\n")
    out = D + "/dist/" + name + ".usdz"
    if os.path.exists(out):
        os.remove(out)
    r = subprocess.run(["usdzip", "--arkitAsset", name + ".usda", out], cwd=build, capture_output=True, text=True)
    print("PACKAGE", name, r.returncode, (r.stdout + r.stderr).strip()[:300], os.path.getsize(out) if os.path.exists(out) else "missing")

package("scan", "")
for look in LOOKS:
    body = "\n    def Scope \"Materials\"\n    {" + material_usda("TopFabric", hex_rgb(look["top"])) + material_usda("PantsFabric", hex_rgb(look["pants"])) + "    }\n"
    if look.get("show_top", True):
        body += mesh_usda("Top", top, "TopFabric")
    if look.get("show_pants", True):
        body += mesh_usda("Pants", PANTS[look.get("leg", "straight")], "PantsFabric")
    package(look["name"], body)

# preview renders of the first look
setup_render()
for look in LOOKS:
    chosen = PANTS[look.get("leg", "straight")]
    for o in PANTS.values():
        o.hide_render = o is not chosen
    for o, key in ((top, "top"), (chosen, "pants")):
        mat = bpy.data.materials.new(key)
        h = look[key].lstrip('#')
        mat.diffuse_color = (*[int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], 1)
        o.data.materials.clear()
        o.data.materials.append(mat)
    for n in (("front", "back", "left", "q") if look is LOOKS[0] else ("front",)):
        shoot(look["name"] + "-" + n, VIEWS[n])

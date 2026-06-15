extends SceneTree
## Validate the trimesh city collision GEOMETRY directly (no physics server, which
## is unreliable in --headless --script): build the collision faces and intersect a
## vertical ray against the triangles, reporting every up-facing floor height per
## column. Proves drive-under (two floors stacked in one cell) deterministically.
##   godot --headless --path . --script res://tests/trimesh_test.gd -- [x y ...]
func _init() -> void:
	var map := GTA1Map.load_file("res://data/NYC.CMP")
	var body := MapBuilder.build_collision(map)
	var shape: ConcavePolygonShape3D = body.get_child(0).shape
	var f := shape.get_faces()
	print("collision triangles: ", f.size() / 3)

	var probes := [Vector2i(20, 53), Vector2i(8, 150), Vector2i(8, 151), Vector2i(130, 132)]
	var a := OS.get_cmdline_user_args()
	if a.size() >= 2:
		probes = []
		var i := 0
		while i + 1 < a.size():
			probes.append(Vector2i(int(a[i]), int(a[i + 1]))); i += 2

	for p in probes:
		var floors := _floors_at(f, p.x + 0.5, p.y + 0.5)
		var blocks := ""
		var n := map.get_num_blocks(p.x, p.y)
		for z in n:
			var b := map.get_block(p.x, p.y, z)
			if b == null or b.is_empty(): blocks += "."
			elif b.is_flat(): blocks += "f"
			elif b.slope_type() != 0: blocks += "s"
			else: blocks += "#"
		print("(%d,%d) %-7s drivable floors (Y, low->high): %s" % [p.x, p.y, blocks, str(floors)])
	quit(0)


## All up-facing-triangle Y heights a vertical ray through (x,z) crosses, sorted.
## "Up-facing" = the floors a car could rest on (skips vertical walls / undersides).
func _floors_at(f: PackedVector3Array, x: float, z: float) -> Array:
	var ys: Array = []
	var t := 0
	while t < f.size():
		var a := f[t]; var b := f[t + 1]; var c := f[t + 2]; t += 3
		var n := (b - a).cross(c - a)
		if n.length() < 1e-9 or absf(n.normalized().y) < 0.3:
			continue  # near-vertical wall (winding-independent; ramps face up OR down)
		var y := _ray_tri_y(x, z, a, b, c)
		if y != -INF:
			ys.append(snappedf(y, 0.01))
	ys.sort()
	# Collapse near-duplicates (shared edges).
	var out: Array = []
	for y in ys:
		if out.is_empty() or absf(out[-1] - y) > 0.02:
			out.append(y)
	return out


## Y where a vertical (downward) line at (x,z) meets triangle abc, or -INF if outside.
func _ray_tri_y(x: float, z: float, a: Vector3, b: Vector3, c: Vector3) -> float:
	# Barycentric in the XZ plane.
	var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(d) < 1e-9:
		return -INF
	var w0 := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / d
	var w1 := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / d
	var w2 := 1.0 - w0 - w1
	if w0 < -0.001 or w1 < -0.001 or w2 < -0.001:
		return -INF
	return w0 * a.y + w1 * b.y + w2 * c.y

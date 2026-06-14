class_name SlopeData
extends RefCounted

## Per-slope-type face geometry, ported from OpenGTA slope1_data.h (DMA cds.doc).
## faces[slope_type][face] = PackedVector3Array of 4 corners (x, y_up, z_depth) in [0,1].
## face order: 0=LID(+Y top) 1=NORTH(+Z) 2=SOUTH(-Z) 3=WEST(-X) 4=EAST(+X)

static var faces: Array = _reflect(_build())

## OpenGTA's slope1_data.h local-Z runs opposite to how we place map-Y into world-Z,
## so every N-S ramp came out mirrored (each cell tilted the wrong way -> a sawtooth
## that's invisible in GTA1's top-down view but obvious in 3D). Reflect each slope's
## local Z (z -> 1-z), keeping the vertex order so the lid's texture mapping is
## preserved (reversing the winding instead rotated the road texture 90 degrees).
## Faces 1/2 (the +Z/-Z sides) swap because the reflection swaps which side they
## describe. The reflection flips face normals; _emit_slope re-orients them outward.
## E-W ramps and flat lids are unchanged by this (their Z edges are level).
static func _reflect(src: Array) -> Array:
	var order := [0, 2, 1, 3, 4]   # lid, then swap NORTH<->SOUTH, keep WEST/EAST
	var out: Array = []
	for tf: Array in src:
		var nf: Array = []
		for fi in 5:
			var v: PackedVector3Array = tf[order[fi]]
			nf.append(PackedVector3Array([
				Vector3(v[0].x, v[0].y, 1.0 - v[0].z),
				Vector3(v[1].x, v[1].y, 1.0 - v[1].z),
				Vector3(v[2].x, v[2].y, 1.0 - v[2].z),
				Vector3(v[3].x, v[3].y, 1.0 - v[3].z),
			]))
		out.append(nf)
	return out

static func _build() -> Array:
	return [
		[ # slope 0
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 1.00, 0.00), Vector3(0.00, 1.00, 0.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 1.00), Vector3(0.00, 1.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 0.00), Vector3(1.00, 1.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(0.00, 1.00, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 0.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 1
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 1.00), Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.00, 0.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 2
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 0.50, 0.00), Vector3(0.00, 0.50, 0.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 1.00), Vector3(0.00, 1.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 0.00), Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(0.00, 0.50, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 0.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 3
			PackedVector3Array([Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.50, 0.00), Vector3(0.00, 0.50, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 0.00), Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.00, 1.00), Vector3(0.00, 0.50, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 4
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 1.00, 0.00), Vector3(0.00, 1.00, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 1.00), Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 0.00), Vector3(1.00, 1.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(0.00, 1.00, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 0.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 5
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.50, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.00, 1.00), Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.50, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.00, 0.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 6
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.50, 0.00), Vector3(0.00, 1.00, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 1.00), Vector3(0.00, 1.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 0.00), Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(0.00, 1.00, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 7
			PackedVector3Array([Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.50, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.00, 0.00), Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.00, 1.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 8
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 1.00, 0.00), Vector3(0.00, 0.50, 0.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 1.00), Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 0.00), Vector3(1.00, 1.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.50, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 0.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 9
			PackedVector3Array([Vector3(0.00, 0.13, 1.00), Vector3(1.00, 0.13, 1.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.13, 1.00), Vector3(0.00, 0.13, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.13, 1.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.00, 0.00), Vector3(1.00, 0.13, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 10
			PackedVector3Array([Vector3(0.00, 0.25, 1.00), Vector3(1.00, 0.25, 1.00), Vector3(1.00, 0.13, 0.00), Vector3(0.00, 0.13, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.25, 1.00), Vector3(0.00, 0.25, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.13, 0.00), Vector3(1.00, 0.13, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.25, 1.00), Vector3(0.00, 0.13, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.13, 0.00), Vector3(1.00, 0.25, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 11
			PackedVector3Array([Vector3(0.00, 0.38, 1.00), Vector3(1.00, 0.38, 1.00), Vector3(1.00, 0.25, 0.00), Vector3(0.00, 0.25, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.38, 1.00), Vector3(0.00, 0.38, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.25, 0.00), Vector3(1.00, 0.25, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.38, 1.00), Vector3(0.00, 0.25, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.25, 0.00), Vector3(1.00, 0.38, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 12
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.38, 0.00), Vector3(0.00, 0.38, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 1.00), Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.38, 0.00), Vector3(1.00, 0.38, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.38, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.38, 0.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 13
			PackedVector3Array([Vector3(0.00, 0.63, 1.00), Vector3(1.00, 0.63, 1.00), Vector3(1.00, 0.50, 0.00), Vector3(0.00, 0.50, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.63, 1.00), Vector3(0.00, 0.63, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 0.00), Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.63, 1.00), Vector3(0.00, 0.50, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.63, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 14
			PackedVector3Array([Vector3(0.00, 0.75, 1.00), Vector3(1.00, 0.75, 1.00), Vector3(1.00, 0.63, 0.00), Vector3(0.00, 0.63, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.75, 1.00), Vector3(0.00, 0.75, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.63, 0.00), Vector3(1.00, 0.63, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.75, 1.00), Vector3(0.00, 0.63, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.63, 0.00), Vector3(1.00, 0.75, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 15
			PackedVector3Array([Vector3(0.00, 0.88, 1.00), Vector3(1.00, 0.88, 1.00), Vector3(1.00, 0.75, 0.00), Vector3(0.00, 0.75, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.88, 1.00), Vector3(0.00, 0.88, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.75, 0.00), Vector3(1.00, 0.75, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.88, 1.00), Vector3(0.00, 0.75, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.75, 0.00), Vector3(1.00, 0.88, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 16
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 0.88, 0.00), Vector3(0.00, 0.88, 0.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 1.00), Vector3(0.00, 1.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.88, 0.00), Vector3(1.00, 0.88, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(0.00, 0.88, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.88, 0.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 17
			PackedVector3Array([Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.13, 0.00), Vector3(0.00, 0.13, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.13, 0.00), Vector3(1.00, 0.13, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.00, 1.00), Vector3(0.00, 0.13, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.13, 0.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 18
			PackedVector3Array([Vector3(0.00, 0.13, 1.00), Vector3(1.00, 0.13, 1.00), Vector3(1.00, 0.25, 0.00), Vector3(0.00, 0.25, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.13, 1.00), Vector3(0.00, 0.13, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.25, 0.00), Vector3(1.00, 0.25, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.13, 1.00), Vector3(0.00, 0.25, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.25, 0.00), Vector3(1.00, 0.13, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 19
			PackedVector3Array([Vector3(0.00, 0.25, 1.00), Vector3(1.00, 0.25, 1.00), Vector3(1.00, 0.38, 0.00), Vector3(0.00, 0.38, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.25, 1.00), Vector3(0.00, 0.25, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.38, 0.00), Vector3(1.00, 0.38, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.25, 1.00), Vector3(0.00, 0.38, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.38, 0.00), Vector3(1.00, 0.25, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 20
			PackedVector3Array([Vector3(0.00, 0.38, 1.00), Vector3(1.00, 0.38, 1.00), Vector3(1.00, 0.50, 0.00), Vector3(0.00, 0.50, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.38, 1.00), Vector3(0.00, 0.38, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 0.00), Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.38, 1.00), Vector3(0.00, 0.50, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.38, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 21
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.63, 0.00), Vector3(0.00, 0.63, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 1.00), Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.63, 0.00), Vector3(1.00, 0.63, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.63, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.63, 0.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 22
			PackedVector3Array([Vector3(0.00, 0.63, 1.00), Vector3(1.00, 0.63, 1.00), Vector3(1.00, 0.75, 0.00), Vector3(0.00, 0.75, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.63, 1.00), Vector3(0.00, 0.63, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.75, 0.00), Vector3(1.00, 0.75, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.63, 1.00), Vector3(0.00, 0.75, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.75, 0.00), Vector3(1.00, 0.63, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 23
			PackedVector3Array([Vector3(0.00, 0.75, 1.00), Vector3(1.00, 0.75, 1.00), Vector3(1.00, 0.88, 0.00), Vector3(0.00, 0.88, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.75, 1.00), Vector3(0.00, 0.75, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.88, 0.00), Vector3(1.00, 0.88, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.75, 1.00), Vector3(0.00, 0.88, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.88, 0.00), Vector3(1.00, 0.75, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 24
			PackedVector3Array([Vector3(0.00, 0.88, 1.00), Vector3(1.00, 0.88, 1.00), Vector3(1.00, 1.00, 0.00), Vector3(0.00, 1.00, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.88, 1.00), Vector3(0.00, 0.88, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 0.00), Vector3(1.00, 1.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.88, 1.00), Vector3(0.00, 1.00, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 0.00), Vector3(1.00, 0.88, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 25
			PackedVector3Array([Vector3(0.00, 0.13, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.13, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.00, 1.00), Vector3(0.00, 0.13, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.13, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.13, 1.00), Vector3(0.00, 0.13, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.00, 0.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 26
			PackedVector3Array([Vector3(0.00, 0.25, 1.00), Vector3(1.00, 0.13, 1.00), Vector3(1.00, 0.13, 0.00), Vector3(0.00, 0.25, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.13, 1.00), Vector3(0.00, 0.25, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.25, 0.00), Vector3(1.00, 0.13, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.25, 1.00), Vector3(0.00, 0.25, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.13, 0.00), Vector3(1.00, 0.13, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 27
			PackedVector3Array([Vector3(0.00, 0.38, 1.00), Vector3(1.00, 0.25, 1.00), Vector3(1.00, 0.25, 0.00), Vector3(0.00, 0.38, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.25, 1.00), Vector3(0.00, 0.38, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.38, 0.00), Vector3(1.00, 0.25, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.38, 1.00), Vector3(0.00, 0.38, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.25, 0.00), Vector3(1.00, 0.25, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 28
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(1.00, 0.38, 1.00), Vector3(1.00, 0.38, 0.00), Vector3(0.00, 0.50, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.38, 1.00), Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 0.00), Vector3(1.00, 0.38, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.50, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.38, 0.00), Vector3(1.00, 0.38, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 29
			PackedVector3Array([Vector3(0.00, 0.63, 1.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.50, 0.00), Vector3(0.00, 0.63, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 1.00), Vector3(0.00, 0.63, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.63, 0.00), Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.63, 1.00), Vector3(0.00, 0.63, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 30
			PackedVector3Array([Vector3(0.00, 0.75, 1.00), Vector3(1.00, 0.63, 1.00), Vector3(1.00, 0.63, 0.00), Vector3(0.00, 0.75, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.63, 1.00), Vector3(0.00, 0.75, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.75, 0.00), Vector3(1.00, 0.63, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.75, 1.00), Vector3(0.00, 0.75, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.63, 0.00), Vector3(1.00, 0.63, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 31
			PackedVector3Array([Vector3(0.00, 0.88, 1.00), Vector3(1.00, 0.75, 1.00), Vector3(1.00, 0.75, 0.00), Vector3(0.00, 0.88, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.75, 1.00), Vector3(0.00, 0.88, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.88, 0.00), Vector3(1.00, 0.75, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.88, 1.00), Vector3(0.00, 0.88, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.75, 0.00), Vector3(1.00, 0.75, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 32
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(1.00, 0.88, 1.00), Vector3(1.00, 0.88, 0.00), Vector3(0.00, 1.00, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.88, 1.00), Vector3(0.00, 1.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 0.00), Vector3(1.00, 0.88, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(0.00, 1.00, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.88, 0.00), Vector3(1.00, 0.88, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 33
			PackedVector3Array([Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.13, 1.00), Vector3(1.00, 0.13, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.13, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.00, 0.00), Vector3(1.00, 0.13, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.00, 1.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.13, 0.00), Vector3(1.00, 0.13, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 34
			PackedVector3Array([Vector3(0.00, 0.13, 1.00), Vector3(1.00, 0.25, 1.00), Vector3(1.00, 0.25, 0.00), Vector3(0.00, 0.13, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.25, 1.00), Vector3(0.00, 0.13, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.13, 0.00), Vector3(1.00, 0.25, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.13, 1.00), Vector3(0.00, 0.13, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.25, 0.00), Vector3(1.00, 0.25, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 35
			PackedVector3Array([Vector3(0.00, 0.25, 1.00), Vector3(1.00, 0.38, 1.00), Vector3(1.00, 0.38, 0.00), Vector3(0.00, 0.25, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.38, 1.00), Vector3(0.00, 0.25, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.25, 0.00), Vector3(1.00, 0.38, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.25, 1.00), Vector3(0.00, 0.25, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.38, 0.00), Vector3(1.00, 0.38, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 36
			PackedVector3Array([Vector3(0.00, 0.38, 1.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.50, 0.00), Vector3(0.00, 0.38, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 1.00), Vector3(0.00, 0.38, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.38, 0.00), Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.38, 1.00), Vector3(0.00, 0.38, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.50, 0.00), Vector3(1.00, 0.50, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 37
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(1.00, 0.63, 1.00), Vector3(1.00, 0.63, 0.00), Vector3(0.00, 0.50, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.63, 1.00), Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 0.00), Vector3(1.00, 0.63, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.50, 1.00), Vector3(0.00, 0.50, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.63, 0.00), Vector3(1.00, 0.63, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 38
			PackedVector3Array([Vector3(0.00, 0.63, 1.00), Vector3(1.00, 0.75, 1.00), Vector3(1.00, 0.75, 0.00), Vector3(0.00, 0.63, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.75, 1.00), Vector3(0.00, 0.63, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.63, 0.00), Vector3(1.00, 0.75, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.63, 1.00), Vector3(0.00, 0.63, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.75, 0.00), Vector3(1.00, 0.75, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 39
			PackedVector3Array([Vector3(0.00, 0.75, 1.00), Vector3(1.00, 0.88, 1.00), Vector3(1.00, 0.88, 0.00), Vector3(0.00, 0.75, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.88, 1.00), Vector3(0.00, 0.75, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.75, 0.00), Vector3(1.00, 0.88, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.75, 1.00), Vector3(0.00, 0.75, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.88, 0.00), Vector3(1.00, 0.88, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 40
			PackedVector3Array([Vector3(0.00, 0.88, 1.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 1.00, 0.00), Vector3(0.00, 0.88, 0.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 1.00), Vector3(0.00, 0.88, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.88, 0.00), Vector3(1.00, 1.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.88, 1.00), Vector3(0.00, 0.88, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 0.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 41
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 1.00), Vector3(0.00, 1.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 0.00), Vector3(1.00, 1.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 0.00, 0.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 42
			PackedVector3Array([Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 1.00, 0.00), Vector3(0.00, 1.00, 0.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 1.00), Vector3(0.00, 1.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 0.00), Vector3(1.00, 1.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 0.00, 1.00), Vector3(0.00, 1.00, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 0.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 43
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 1.00, 0.00)]),
			PackedVector3Array([Vector3(1.00, 0.00, 1.00), Vector3(0.00, 1.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(0.00, 1.00, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 0.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
		[ # slope 44
			PackedVector3Array([Vector3(0.00, 0.00, 1.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 1.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(0.00, 0.00, 1.00), Vector3(1.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(0.00, 0.00, 0.00), Vector3(1.00, 1.00, 0.00), Vector3(1.00, 0.00, 0.00), Vector3(0.00, 0.00, 0.00)]),
			PackedVector3Array([Vector3(0.00, 1.00, 1.00), Vector3(0.00, 1.00, 0.00), Vector3(0.00, 0.00, 0.00), Vector3(0.00, 0.00, 1.00)]),
			PackedVector3Array([Vector3(1.00, 1.00, 0.00), Vector3(1.00, 1.00, 1.00), Vector3(1.00, 0.00, 1.00), Vector3(1.00, 0.00, 0.00)]),
		],
	]

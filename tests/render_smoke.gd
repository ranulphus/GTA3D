extends SceneTree

## Smoke test for offscreen rendering: build a tiny 3D scene, render a few
## frames, save a PNG. Confirms the Xvfb + OpenGL3 software-render pipeline works
## before we invest in the city extruder.
##
## Run with:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tests/render_smoke.gd

const OUT := "res://_dump/render_smoke.png"


func _init() -> void:
	var root := get_root()
	root.size = Vector2i(640, 480)

	var world := Node3D.new()
	root.add_child(world)

	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.7, 0.2)
	mesh.material_override = mat
	world.add_child(mesh)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -40, 0)
	world.add_child(light)

	var cam := Camera3D.new()
	cam.position = Vector3(2.5, 2.0, 3.0)
	cam.look_at_from_position(cam.position, Vector3.ZERO, Vector3.UP)
	world.add_child(cam)
	cam.current = true

	# Let a few frames render, then grab the framebuffer.
	await process_frame
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	var err := img.save_png(OUT)
	print("render_smoke: save_png -> ", error_string(err), "  size=", img.get_size())
	quit(0 if err == OK else 1)

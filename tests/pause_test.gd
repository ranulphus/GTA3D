extends SceneTree
## The real Drive scene: pressing the menu toggle should pause the tree, show the
## menu and free the mouse; resuming should unpause and re-capture (on foot).
func _init(): _go()
func _go():
	var scene: Node = load("res://scenes/Drive.tscn").instantiate()
	get_root().add_child(scene)
	for i in 200: await physics_frame
	var pm = scene._pause
	var ok := true
	print("pre: paused=%s menu_visible=%s mouse=%d" % [paused, pm.visible, Input.mouse_mode])
	ok = ok and not paused and not pm.visible
	# open the menu
	pm.toggle()
	await process_frame
	print("open: paused=%s menu_visible=%s mouse=%d (3=VISIBLE)" % [paused, pm.visible, Input.mouse_mode])
	ok = ok and paused and pm.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	# resume
	pm.toggle()
	await process_frame
	print("resume: paused=%s menu_visible=%s mouse=%d (2=CAPTURED)" % [paused, pm.visible, Input.mouse_mode])
	ok = ok and not paused and not pm.visible
	# buttons present?
	var btns: Array = _buttons(pm)
	print("buttons: ", btns)
	ok = ok and btns.size() == 3
	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
func _buttons(n, acc=null):
	if acc == null: acc = []
	if n is Button: acc.append(n.text + ("(disabled)" if n.disabled else ""))
	for c in n.get_children(): _buttons(c, acc)
	return acc

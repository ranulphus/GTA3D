class_name PauseMenu
extends CanvasLayer

## [Esc] pause overlay: Resume / Quit to Menu (disabled — no menu yet) / Quit Game.
##
## It runs with PROCESS_MODE_ALWAYS so it keeps taking input and button clicks while
## the rest of the tree is paused (get_tree().paused). Toggling pause is all done
## here; it emits `resumed` when it unpauses so the host (drive_world) can put the
## mouse back the way that mode wants it (captured on foot, free in a car).

signal resumed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100              # above the HUD
	visible = false
	_build()


func _build() -> void:
	# Dim the frozen game behind the menu, and swallow clicks that miss the buttons.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(title)
	vb.add_child(_gap(16))

	_button(vb, "Resume", _on_resume)
	var qm := _button(vb, "Quit to Menu", Callable())
	qm.disabled = true
	qm.tooltip_text = "No main menu yet"
	_button(vb, "Quit Game", _on_quit)


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 46)
	b.add_theme_font_size_override("font_size", 20)
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()


## Flip between paused (menu up, mouse free) and playing.
func toggle() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	visible = p
	if p:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		resumed.emit()


func _on_resume() -> void:
	if get_tree().paused:
		toggle()


func _on_quit() -> void:
	get_tree().quit()

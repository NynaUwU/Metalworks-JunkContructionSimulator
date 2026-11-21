class_name KeypadUI
extends Control
## Teclado de senha na tela (E num Teclado de senha). Números do teclado também funcionam.

var player: Player
var node: KeypadNode
var _typed := ""
var _display: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.11, 0.96)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -140
	panel.offset_right = 140
	panel.offset_top = -190
	panel.offset_bottom = 190
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	_display = Label.new()
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_display.add_theme_font_size_override("font_size", 30)
	_display.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	v.add_child(_display)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for t in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"]:
		var b := Button.new()
		b.text = t
		b.custom_minimum_size = Vector2(76, 56)
		b.add_theme_font_size_override("font_size", 22)
		var key: String = t
		b.pressed.connect(func() -> void: _press(key))
		grid.add_child(b)
	var hint := Label.new()
	hint.text = "Enter: confirmar · Esc: sair"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	v.add_child(hint)


func open(p_player: Player, p_node: KeypadNode) -> void:
	player = p_player
	node = p_node
	_typed = ""
	_refresh()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh() -> void:
	_display.text = "•".repeat(_typed.length()) if _typed != "" else "_ _ _ _"


func _press(key: String) -> void:
	match key:
		"⌫":
			_typed = _typed.substr(0, maxi(_typed.length() - 1, 0))
		"OK":
			if node and node.is_alive():
				var ok := node.enter(_typed)
				player.toast("Senha certa" if ok else "Senha errada")
			close()
			return
		_:
			if _typed.length() < 12:
				_typed += key
	_refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		var code := (event as InputEventKey).physical_keycode
		if code >= KEY_0 and code <= KEY_9:
			_press(str(code - KEY_0))
		elif code >= KEY_KP_0 and code <= KEY_KP_9:
			_press(str(code - KEY_KP_0))
		elif code == KEY_BACKSPACE:
			_press("⌫")
		elif code == KEY_ENTER or code == KEY_KP_ENTER:
			_press("OK")
		else:
			return
		get_viewport().set_input_as_handled()

class_name PortMenu
extends Control
## Menu rápido para escolher uma porta (Fiação): clique na opção ou aperte o número.
## Esc ou botão direito cancela.

var _box: VBoxContainer
var _title: Label
var _cb := Callable()
var _count := 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.11, 0.95)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -10
	panel.offset_bottom = 10
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 17)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	v.add_child(_box)
	var hint := Label.new()
	hint.text = "Número ou clique: escolher   ·   Esc / botão direito: cancelar"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	v.add_child(hint)


## items: [{"text": String, "color": Color}, ...]. `cb` recebe o índice (ou -1).
func open(title: String, items: Array, cb: Callable) -> void:
	_title.text = title
	for c in _box.get_children():
		c.queue_free()
	_count = items.size()
	for i in items.size():
		var b := Button.new()
		b.text = "%d · %s" % [i + 1, items[i]["text"]] if i < 9 else str(items[i]["text"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 34)
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", items[i].get("color", Color.WHITE))
		var idx := i
		b.pressed.connect(func() -> void: _choose(idx))
		_box.add_child(b)
	_cb = cb
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _choose(i: int) -> void:
	var cb := _cb
	close()
	if cb.is_valid():
		cb.call(i)


func close() -> void:
	visible = false
	_cb = Callable()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or (event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT):
		_choose(-1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		var code := (event as InputEventKey).physical_keycode
		var n := -1
		if code >= KEY_1 and code <= KEY_9:
			n = code - KEY_1
		elif code >= KEY_KP_1 and code <= KEY_KP_9:
			n = code - KEY_KP_1
		if n >= 0 and n < _count:
			_choose(n)
			get_viewport().set_input_as_handled()
		elif n >= 0:
			get_viewport().set_input_as_handled()

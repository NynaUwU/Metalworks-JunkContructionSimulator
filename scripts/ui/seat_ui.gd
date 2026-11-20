class_name SeatUI
extends Control
## Modo edição do assento (Tab): escolha as teclas/botões do mouse de cada componente
## ligado a este assento e ajuste velocidade, força, ângulo...

signal closed

var _list: VBoxContainer
var _joints: Array[MechJoint] = []
var _labels: Array[Label3D] = []
var _capture: Array = []           ## [MechJoint, "pos"/"neg", Button] enquanto espera uma tecla


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.11, 0.93)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -470
	panel.offset_right = -16
	panel.offset_top = 16
	panel.offset_bottom = -16
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_label("MODO EDIÇÃO DO ASSENTO", 22, Color(1.0, 0.62, 0.2)))
	box.add_child(_label("Clique numa tecla e aperte a tecla (ou botão do mouse) desejada.\nBackspace apaga · Esc cancela · Tab ou Esc fecha", 12, Color(1, 1, 1, 0.6)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)


func open(joints: Array[MechJoint]) -> void:
	_joints = []
	for j in joints:
		if j.is_actuator():
			_joints.append(j)
	for c in _list.get_children():
		c.queue_free()
	if _joints.is_empty():
		_list.add_child(_label("Nenhum motor, servo ou pistão ligado a este assento.\nSolde o assento na mesma estrutura dos componentes.", 14, Color(1, 1, 1, 0.8)))
	for i in _joints.size():
		_list.add_child(_section(i, _joints[i]))
	_make_world_labels()
	visible = true
	Build.seat_keys_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not visible:
		return
	visible = false
	_capture = []
	for l in _labels:
		if is_instance_valid(l):
			l.queue_free()
	_labels.clear()
	Build.seat_keys_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _section(i: int, j: MechJoint) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.16, 0.19)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var title := "%d · %s" % [i + 1, j.display_name()]
	if not j.sources.is_empty():
		title += "   (+%d controle%s por fio)" % [j.sources.size(), "" if j.sources.size() == 1 else "s"]
	v.add_child(_label(title, 17, Color(1.0, 0.85, 0.4)))

	for which in ["pos", "neg"]:
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 8)
		var name_l := _label("Tecla +" if which == "pos" else "Tecla −", 14, Color.WHITE)
		name_l.custom_minimum_size = Vector2(70, 0)
		keys.add_child(name_l)
		for slot in MechJoint.MAX_KEYS:
			keys.add_child(_bind_button(j, which, slot))
		v.add_child(keys)

	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 16)
	var tog := CheckBox.new()
	tog.text = "Alternar (liga/desliga)"
	tog.button_pressed = j.toggle
	tog.toggled.connect(func(on: bool) -> void: j.toggle = on)
	opts.add_child(tog)
	var inv := CheckBox.new()
	inv.text = "Inverter"
	inv.button_pressed = j.invert
	inv.toggled.connect(func(on: bool) -> void: j.invert = on)
	opts.add_child(inv)
	v.add_child(opts)

	match j.type:
		"motor":
			v.add_child(_slider("Velocidade", 1.0, 30.0, 0.5, j.speed, "%.1f rad/s", func(x: float) -> void: j.speed = x))
			v.add_child(_slider("Força", 200.0, 6000.0, 100.0, j.strength, "%d N·m", func(x: float) -> void:
				j.strength = x
				j.apply_strength()))
		"servo":
			v.add_child(_slider("Ângulo máx.", 10.0, 90.0, 5.0, rad_to_deg(j.max_angle), "±%d°", func(x: float) -> void: j.max_angle = deg_to_rad(x)))
			v.add_child(_slider("Velocidade", 0.5, 10.0, 0.5, j.speed, "%.1f rad/s", func(x: float) -> void: j.speed = x))
			v.add_child(_slider("Força", 200.0, 8000.0, 100.0, j.strength, "%d N·m", func(x: float) -> void:
				j.strength = x
				j.apply_strength()))
		"pistao":
			v.add_child(_slider("Velocidade", 0.1, 3.0, 0.1, j.speed, "%.1f m/s", func(x: float) -> void: j.speed = x))
			v.add_child(_slider("Força", 1000.0, 40000.0, 500.0, j.strength, "%d N", func(x: float) -> void:
				j.strength = x
				j.apply_strength()))
	return panel


static func _get_binding(j: MechJoint, which: String, slot: int) -> Dictionary:
	var list: Array = j.bind_pos if which == "pos" else j.bind_neg
	return list[slot] if slot < list.size() else {}


static func _set_binding(j: MechJoint, which: String, slot: int, b: Dictionary) -> void:
	var list: Array = j.bind_pos if which == "pos" else j.bind_neg
	while list.size() <= slot:
		list.append({})
	list[slot] = b
	# Remove buracos vazios no fim
	while not list.is_empty() and (list.back() as Dictionary).is_empty():
		list.pop_back()


func _bind_button(j: MechJoint, which: String, slot: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 32)
	b.text = MechJoint.binding_text(_get_binding(j, which, slot))
	b.pressed.connect(func() -> void:
		if not _capture.is_empty():
			(_capture[2] as Button).text = MechJoint.binding_text(_get_binding(_capture[0], _capture[1], _capture[3]))
		_capture = [j, which, b, slot]
		b.text = "aperte…")
	return b


func _slider(title: String, lo: float, hi: float, step: float, value: float, fmt: String, cb: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_l := _label(title, 13, Color(1, 1, 1, 0.85))
	name_l.custom_minimum_size = Vector2(90, 0)
	row.add_child(name_l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := _label(fmt % (roundi(value) if fmt.contains("%d") else value), 13, Color(1.0, 0.8, 0.4))
	val.custom_minimum_size = Vector2(80, 0)
	row.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		val.text = fmt % (roundi(x) if fmt.contains("%d") else x)
		cb.call(x))
	return row


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _capture.is_empty():
		var j: MechJoint = _capture[0]
		var which: String = _capture[1]
		var b: Button = _capture[2]
		var slot: int = _capture[3]
		var binding = null
		if event is InputEventKey and event.pressed and not event.is_echo():
			var k := event as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			if code == KEY_ESCAPE:
				binding = _get_binding(j, which, slot)
			elif code == KEY_BACKSPACE or code == KEY_DELETE:
				binding = {}
			else:
				binding = {"key": code}
		elif event is InputEventMouseButton and event.pressed:
			var mb := (event as InputEventMouseButton).button_index
			if mb not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
				binding = {"mouse": mb}
		if binding != null:
			_set_binding(j, which, slot, binding)
			b.text = MechJoint.binding_text(binding)
			_capture = []
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("seat_edit") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


## Números flutuando sobre cada componente (iguais aos da lista).
func _make_world_labels() -> void:
	for l in _labels:
		if is_instance_valid(l):
			l.queue_free()
	_labels.clear()
	for i in _joints.size():
		var l := Label3D.new()
		l.text = str(i + 1)
		l.font_size = 96
		l.pixel_size = 0.004
		l.modulate = Color(1.0, 0.85, 0.3)
		l.outline_size = 18
		l.outline_modulate = Color(0, 0, 0, 0.9)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		Build.world_root.add_child(l)
		_labels.append(l)


func _process(_delta: float) -> void:
	if not visible:
		return
	for i in _labels.size():
		if i < _joints.size() and _joints[i].is_valid():
			_labels[i].global_position = _joints[i].part_a.global_position + Vector3.UP * 0.45


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

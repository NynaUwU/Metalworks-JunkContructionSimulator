class_name SeatUI
extends Control
## Modo edição do assento (Tab sentado).
##
## Os componentes configuráveis ligados ao assento ficam destacados (o destaque
## aparece através de tudo). O mouse fica livre: clique num componente para editar
## as teclas dele; segure o botão direito e arraste para girar a câmera.

signal closed

const PICK_MARGIN := 8.0

var player: Player
var _single := false                ## aberto pela Fiação para um componente só
var _joints: Array[MechJoint] = []
var _hover: MechJoint = null
var _selected: MechJoint = null
var _capture: Array = []           ## [MechJoint, "pos"/"neg", Button, slot] enquanto espera uma tecla

var _panel: PanelContainer
var _content: VBoxContainer
var _banner: Label
var _tag: Label
var _mat_idle: StandardMaterial3D
var _mat_hover: StandardMaterial3D
var _mat_selected: StandardMaterial3D


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	_mat_idle = _highlight_mat(Color(1.0, 0.8, 0.15, 0.35))
	_mat_hover = _highlight_mat(Color(1.0, 0.55, 0.1, 0.6))
	_mat_selected = _highlight_mat(Color(0.3, 1.0, 0.45, 0.55))

	_banner = _label("MODO EDIÇÃO · clique num componente destacado para editar · botão direito + arrastar: girar a câmera · Tab: sair", 15, Color(1.0, 0.85, 0.4))
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(-500, 84)
	_banner.size = Vector2(1000, 30)
	_banner.autowrap_mode = TextServer.AUTOWRAP_OFF
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override("outline_size", 5)
	add_child(_banner)

	_tag = _label("", 14, Color.WHITE)
	_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_tag.add_theme_constant_override("outline_size", 5)
	_tag.visible = false
	add_child(_tag)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.11, 0.94)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -480
	_panel.offset_right = -20
	_panel.offset_top = -10
	_panel.offset_bottom = 10   # cresce para cima e para baixo conforme o conteúdo
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	add_child(_panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_panel.add_child(_content)


func _highlight_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true          # aparece através de tudo
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	m.render_priority = 10
	return m


## Ajustes de um componente só (botão direito da Fiação, a pé).
func open_single(p_player: Player, j: MechJoint) -> void:
	player = p_player
	_single = true
	_joints = [j]
	_hover = null
	_capture = []
	visible = true
	_banner.text = "AJUSTES DO COMPONENTE · Esc, Tab ou E: fechar"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_select(j)


func open(p_player: Player, joints: Array[MechJoint]) -> void:
	player = p_player
	_single = false
	_banner.text = "MODO EDIÇÃO · clique num componente destacado para editar · botão direito + arrastar: girar a câmera · Tab: sair"
	_joints = []
	for j in joints:
		if j.is_actuator() and j.is_valid():
			_joints.append(j)
	_hover = null
	_selected = null
	_capture = []
	_panel.visible = false
	visible = true
	Build.seat_keys_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _joints.is_empty():
		player.toast("Nada para configurar: solde motores, servos ou pistões na mesma máquina do assento")
	_refresh_highlights()


func close() -> void:
	if not visible:
		return
	visible = false
	_single = false
	_panel.visible = false
	_capture = []
	_hover = null
	_selected = null
	for j in _joints:
		_set_overlay(j, null)
	_joints.clear()
	_tag.visible = false
	Build.seat_keys_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _set_overlay(j: MechJoint, mat: Material) -> void:
	for p in [j.part_a, j.part_b]:
		if is_instance_valid(p) and (p as Part).mesh_instance:
			(p as Part).mesh_instance.material_overlay = mat


func _refresh_highlights() -> void:
	for j in _joints:
		if not j.is_valid():
			continue
		var m := _mat_idle
		if j == _selected:
			m = _mat_selected
		elif j == _hover:
			m = _mat_hover
		_set_overlay(j, m)


## Componente sob o mouse: usa a caixa de cada peça projetada na tela, então
## funciona mesmo com o componente atrás de outras peças.
func pick(mouse: Vector2) -> MechJoint:
	var cam := player.camera
	var best: MechJoint = null
	var best_depth := INF
	for j in _joints:
		if not j.is_valid():
			continue
		for p: Part in [j.part_a, j.part_b]:
			var rect := _screen_rect(cam, p)
			if rect.size == Vector2.ZERO or not rect.grow(PICK_MARGIN).has_point(mouse):
				continue
			var depth := cam.global_position.distance_to(p.global_position)
			if depth < best_depth:
				best_depth = depth
				best = j
	return best


static func _screen_rect(cam: Camera3D, p: Part) -> Rect2:
	var xf := p.global_transform
	var b := p.bounds
	var rect := Rect2()
	var first := true
	for i in 8:
		var corner := b.position + Vector3(b.size.x * (i & 1), b.size.y * ((i >> 1) & 1), b.size.z * ((i >> 2) & 1))
		var w := xf * corner
		if cam.is_position_behind(w):
			return Rect2()
		var sp := cam.unproject_position(w)
		if first:
			rect = Rect2(sp, Vector2.ZERO)
			first = false
		else:
			rect = rect.expand(sp)
	return rect


func _select(j: MechJoint) -> void:
	_selected = j
	_capture = []
	for c in _content.get_children():
		c.queue_free()
	if j == null:
		_panel.visible = false
	else:
		_content.add_child(_section(_joints.find(j), j))
		var close_b := Button.new()
		close_b.text = "Fechar"
		close_b.custom_minimum_size = Vector2(0, 34)
		close_b.pressed.connect(func() -> void:
			if _single:
				close()
			else:
				_select(null))
		_content.add_child(close_b)
		_panel.visible = true
	_refresh_highlights()


func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	if _single:
		_tag.visible = false
		return
	if not player.is_seated():
		close()
		return
	var mouse := get_viewport().get_mouse_position()
	var over_panel := _panel.visible and _panel.get_global_rect().has_point(mouse)
	var h: MechJoint = null if over_panel else pick(mouse)
	if h != _hover:
		_hover = h
		_refresh_highlights()
	if _hover and _hover != _selected:
		_tag.visible = true
		_tag.text = "%s   + %s   − %s" % [_hover.display_name(), _keys_text(_hover.bind_pos), _keys_text(_hover.bind_neg)]
		_tag.position = mouse + Vector2(18, 12)
	else:
		_tag.visible = false


static func _keys_text(list: Array) -> String:
	var names: Array[String] = []
	for b: Dictionary in list:
		names.append(MechJoint.binding_text(b))
	return "/".join(names) if not names.is_empty() else "—"


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
	if event.is_action_pressed("seat_edit") or event.is_action_pressed("pause") \
			or (_single and event.is_action_pressed("interact")):
		close()
		get_viewport().set_input_as_handled()
		return
	if _single:
		return
	# Botão direito segurado + arrastar: girar a câmera.
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion := event as InputEventMouseMotion
		var sens := Settings.mouse_sensitivity
		player.yaw = clampf(player.yaw - motion.relative.x * sens, deg_to_rad(-160), deg_to_rad(160))
		player.pitch = clampf(player.pitch - motion.relative.y * sens, deg_to_rad(-89), deg_to_rad(89))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse := (event as InputEventMouseButton).position
		if _panel.visible and _panel.get_global_rect().has_point(mouse):
			return   # clique dentro do painel: a interface cuida
		_select(pick(mouse))
		get_viewport().set_input_as_handled()


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

	var title := j.display_name() if _single else "%d · %s" % [i + 1, j.display_name()]
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
			var free := CheckBox.new()
			free.text = "Solto sem comando (gira livre; desmarcado = trava)"
			free.button_pressed = j.free_idle
			free.toggled.connect(func(on: bool) -> void: j.free_idle = on)
			v.add_child(free)
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
		"pistao", "servo_linear":
			if j.type == "pistao":
				var hold_cb := CheckBox.new()
				hold_cb.text = "Ficar parado sem sinal (desmarcado = volta ao início)"
				hold_cb.button_pressed = j.hold
				hold_cb.toggled.connect(func(on: bool) -> void: j.hold = on)
				v.add_child(hold_cb)
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


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

class_name NodeConfigUI
extends Control
## Ajustes de chips, constantes, teclas, teclado de senha, mostradores (e o nome de
## qualquer peça com sinais). Abre no centro da tela (botão direito da Fiação ou do
## Depurador). Esc ou E fecha.

const PANEL_WIDTH := 560.0

var player: Player
var node: SignalNode
var _panel: PanelContainer
var _content: VBoxContainer
var _capture: Array = []         ## [lista ("pos"/"neg"), slot, Button] esperando uma tecla


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.11, 0.95)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -PANEL_WIDTH * 0.5
	_panel.offset_right = PANEL_WIDTH * 0.5
	_panel.offset_top = -10
	_panel.offset_bottom = 10
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_panel.add_child(_content)


func open(p_player: Player, n: SignalNode) -> void:
	player = p_player
	node = n
	_capture = []
	_rebuild()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	_capture = []
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()
	_content.add_child(_label(node.kind_label(), 18, Color(1.0, 0.85, 0.4)))
	var name_row := HBoxContainer.new()
	name_row.add_child(_label("Nome", 14, Color(1, 1, 1, 0.85), 90))
	var name_edit := LineEdit.new()
	name_edit.text = node.node_name
	name_edit.placeholder_text = "(sem nome)"
	name_edit.max_length = 24
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t: String) -> void: node.node_name = t.strip_edges())
	name_row.add_child(name_edit)
	_content.add_child(name_row)
	if node is ChipNode:
		_chip_section(node as ChipNode)
	elif node is ConstNode:
		_const_section(node as ConstNode)
	elif node is KeysNode:
		_keys_section(node as KeysNode)
	elif node is KeypadNode:
		_keypad_section(node as KeypadNode)
	elif node is DisplayNode:
		_display_section(node as DisplayNode)
	elif node is PowerNode:
		_power_section(node as PowerNode)
	elif node is SensorNode:
		_sensor_section(node as SensorNode)
	elif node is DriveNode:
		_drive_section(node as DriveNode)
	_content.add_child(_ports_text())
	var close_b := Button.new()
	close_b.text = "Fechar"
	close_b.custom_minimum_size = Vector2(0, 34)
	close_b.pressed.connect(close)
	_content.add_child(close_b)


func _ports_text() -> Label:
	var ins := ", ".join(node.inputs().map(func(p: Array) -> String: return "%s (%s)" % [p[0], SignalNode.TYPE_NAMES[p[1]]]))
	var outs := ", ".join(node.outputs().map(func(p: Array) -> String: return "%s (%s)" % [p[0], SignalNode.TYPE_NAMES[p[1]]]))
	return _label("Entradas: %s\nSaídas: %s" % [ins if ins != "" else "—", outs if outs != "" else "—"], 13, Color(1, 1, 1, 0.6))


# --- Chip ---------------------------------------------------------------------------

func _chip_section(c: ChipNode) -> void:
	var cat_opt := OptionButton.new()
	for cat in Gates.CATEGORIES:
		cat_opt.add_item(cat)
	var cur_cat: String = Gates.DEFS[c.mode]["cat"]
	cat_opt.selected = Gates.CATEGORIES.find(cur_cat)
	var mode_opt := OptionButton.new()
	var desc := _label("", 13, Color(0.8, 0.9, 1.0))
	var fill := func(cat: String) -> void:
		mode_opt.clear()
		var ids := Gates.modes_in(cat)
		for k in ids.size():
			mode_opt.add_item("%s   %s" % [Gates.DEFS[ids[k]]["sym"], Gates.DEFS[ids[k]]["name"]])
			mode_opt.set_item_metadata(k, ids[k])
		var at := ids.find(c.mode)
		mode_opt.selected = at if at >= 0 else -1
		desc.text = Gates.DEFS[c.mode]["desc"] if at >= 0 else "Escolha um modo."
	fill.call(cur_cat)
	cat_opt.item_selected.connect(func(i: int) -> void:
		fill.call(Gates.CATEGORIES[i])
		if mode_opt.item_count > 0 and mode_opt.selected < 0:
			mode_opt.select(0)
			mode_opt.item_selected.emit(0))
	mode_opt.item_selected.connect(func(i: int) -> void:
		c.set_mode(mode_opt.get_item_metadata(i))
		_rebuild())
	_content.add_child(_row("Categoria", cat_opt))
	_content.add_child(_row("Modo", mode_opt))
	_content.add_child(desc)


# --- Constante ------------------------------------------------------------------------

func _const_section(k: ConstNode) -> void:
	var types := [SignalNode.NUM, SignalNode.VEC, SignalNode.TXT]
	var opt := OptionButton.new()
	for t in types:
		opt.add_item(SignalNode.TYPE_NAMES[t])
	opt.selected = types.find(k.value_type)
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text = _value_text(k)
	edit.placeholder_text = "x; y; z" if k.value_type == SignalNode.VEC else "valor"
	var apply := func(t: String) -> void:
		if k.value_type == SignalNode.VEC:
			var parts := t.replace(",", ".").split(";")
			var v := Vector3.ZERO
			for i in mini(parts.size(), 3):
				v[i] = parts[i].strip_edges().to_float()
			k.set_value(SignalNode.VEC, v)
		else:
			k.set_value(k.value_type, t)
	edit.text_changed.connect(apply)
	opt.item_selected.connect(func(i: int) -> void:
		k.set_value(types[i], SignalNode.zero(types[i]))
		_rebuild())
	_content.add_child(_row("Tipo", opt))
	_content.add_child(_row("Valor", edit))


static func _value_text(k: ConstNode) -> String:
	if k.value is Vector3:
		return "%s; %s; %s" % [SignalNode.format(k.value.x), SignalNode.format(k.value.y), SignalNode.format(k.value.z)]
	if k.value is String:
		return k.value
	return SignalNode.format(k.value)


# --- Teclas ---------------------------------------------------------------------------

func _keys_section(t: KeysNode) -> void:
	for which in ["pos", "neg"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_label("Tecla +" if which == "pos" else "Tecla −", 14, Color.WHITE, 90))
		for slot in MechJoint.MAX_KEYS:
			var list: Array = t.bind_pos if which == "pos" else t.bind_neg
			var b := Button.new()
			b.custom_minimum_size = Vector2(130, 32)
			b.text = MechJoint.binding_text(list[slot] if slot < list.size() else {})
			var w: String = which
			var s: int = slot
			b.pressed.connect(func() -> void:
				_capture = [w, s, b]
				b.text = "aperte…")
			row.add_child(b)
		_content.add_child(row)
	_content.add_child(_check("Alternar (um toque liga, outro desliga)", t.toggle, func(on: bool) -> void: t.toggle = on))
	_content.add_child(_check("Vale a pé também (sem estar sentado na máquina)", t.always, func(on: bool) -> void: t.always = on))
	_content.add_child(_label("Dica: o teclado numérico é bom para usar a pé. Backspace limpa a tecla.", 12, Color(1, 1, 1, 0.55)))


# --- Teclado de senha -------------------------------------------------------------------

func _keypad_section(kp: KeypadNode) -> void:
	var edit := LineEdit.new()
	edit.text = kp.code
	edit.max_length = 12
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(tx: String) -> void:
		var digits := ""
		for ch in tx:
			if ch >= "0" and ch <= "9":
				digits += ch
		kp.code = digits)
	_content.add_child(_row("Senha", edit))
	_content.add_child(_slider("Tempo aberto", 0.5, 10.0, 0.5, kp.hold_time, "%.1f s", func(x: float) -> void: kp.hold_time = x))


# --- Mostradores ------------------------------------------------------------------------

func _display_section(d: DisplayNode) -> void:
	match d.kind:
		"indicador":
			_content.add_child(_row("Mín", _num_edit(d.min_value, func(x: float) -> void: d.min_value = x)))
			_content.add_child(_row("Máx", _num_edit(d.max_value, func(x: float) -> void: d.max_value = x)))
			_content.add_child(_row("Cor no mínimo", _color_btn(d.color_off, func(c: Color) -> void: d.color_off = c)))
			_content.add_child(_row("Cor no máximo", _color_btn(d.color_on, func(c: Color) -> void: d.color_on = c)))
		"mostrador":
			_content.add_child(_slider("Casas decimais", 0, 4, 1, d.decimals, "%d", func(x: float) -> void:
				d.decimals = int(x)
				d._shown = ""))
		"tela":
			_content.add_child(_row("Nome de A", _text_edit(d.name_a, func(t: String) -> void:
				d.name_a = t
				d._shown = "")))
			_content.add_child(_row("Nome de B", _text_edit(d.name_b, func(t: String) -> void:
				d.name_b = t
				d._shown = "")))
		"tela_texto":
			_content.add_child(_row("Texto", _text_edit(d.template, func(t: String) -> void:
				d.template = t
				d._shown = "")))
			_content.add_child(_label("{texto} = entrada Texto · {A} {B} {C} {D} = entradas numéricas. Ex.: Velocidade: {A} km/h", 12, Color(1, 1, 1, 0.55)))
		"pixel":
			_content.add_child(_label("Entrada Cor: vetor (vermelho; verde; azul) de 0 a 255.", 12, Color(1, 1, 1, 0.55)))


# --- Energia ---------------------------------------------------------------------------

func _power_section(pn: PowerNode) -> void:
	match pn.kind:
		"luz", "holofote":
			_content.add_child(_row("Cor", _color_btn(pn.color, func(c: Color) -> void:
				pn.color = c
				pn.update_visual())))
			_content.add_child(_slider("Brilho", 5, 100, 5, pn.brightness * 100.0, "%d %%", func(x: float) -> void: pn.brightness = x / 100.0))
			_content.add_child(_slider("Alcance", 2, 30 if pn.kind == "holofote" else 20, 1, pn.light_range, "%d m", func(x: float) -> void: pn.light_range = x))
			_content.add_child(_check("Acesa sem fio na entrada Liga", pn.always_on, func(on: bool) -> void: pn.always_on = on))
			var watts := (PowerNode.SPOT_W if pn.kind == "holofote" else PowerNode.LIGHT_W)
			_content.add_child(_label("Gasta até %d W (no brilho máximo). A entrada Cor (vetor 0 a 255) troca a cor." % roundi(watts), 12, Color(1, 1, 1, 0.55)))
		"bateria":
			_content.add_child(_label("Capacidade: %s · carga: %s" % [PowerNode._wh(pn.capacity()), PowerNode._wh(pn.charge)], 14, Color(0.6, 1.0, 0.7)))
			_content.add_child(_label("Baterias ligadas pelo mesmo fio de energia dividem a carga.", 12, Color(1, 1, 1, 0.55)))


# --- Sensores ---------------------------------------------------------------------------

func _sensor_section(sn: SensorNode) -> void:
	match sn.kind:
		"ranger":
			_content.add_child(_slider("Alcance", 1, 200, 1, sn.range_m, "%d m", func(x: float) -> void: sn.range_m = x))
			_content.add_child(_check("Mostrar o laser", sn.show_beam, func(on: bool) -> void: sn.show_beam = on))
			_content.add_child(_check("Ignorar a própria máquina", sn.ignore_own, func(on: bool) -> void: sn.ignore_own = on))
			_content.add_child(_label("O laser sai pela face de cima. Acertando um receptor de laser, ele acende.", 12, Color(1, 1, 1, 0.55)))
		"localizador", "sensor_loc":
			_content.add_child(_slider("Canal", 1, 99, 1, sn.channel, "%d", func(x: float) -> void:
				sn.channel = int(x)
				sn.update_label()))
			if sn.kind == "sensor_loc":
				_content.add_child(_slider("Alcance", 5, 500, 5, sn.range_m, "%d m", func(x: float) -> void: sn.range_m = x))
				_content.add_child(_label("Acha o localizador mais perto do mesmo canal. Direção: nos eixos do sensor (frente = -Z).", 12, Color(1, 1, 1, 0.55)))
		"buscador":
			_content.add_child(_slider("Raio", 1, 100, 1, sn.range_m, "%d m", func(x: float) -> void: sn.range_m = x))
			var ob := OptionButton.new()
			for f: String in SensorNode.FILTERS:
				ob.add_item(f)
			ob.selected = sn.filter
			ob.item_selected.connect(func(i: int) -> void: sn.filter = i)
			_content.add_child(_row("Procurar", ob))
			_content.add_child(_check("Ignorar a própria máquina", sn.ignore_own, func(on: bool) -> void: sn.ignore_own = on))
		"zona":
			for i in 3:
				var axis := i
				_content.add_child(_slider("Tamanho " + "XYZ"[i], 0.5, 10, 0.5, sn.zone_size[i], "%.1f m", func(x: float) -> void: sn.zone_size[axis] = x))
			_content.add_child(_check("Mostrar a caixa", sn.show_zone, func(on: bool) -> void: sn.show_zone = on))
			_content.add_child(_check("Ignorar a própria máquina", sn.ignore_own, func(on: bool) -> void: sn.ignore_own = on))


# --- Trem de força -----------------------------------------------------------------------

func _drive_section(d: DriveNode) -> void:
	if d.is_engine():
		var s := d.spec()
		_content.add_child(_label("%d N·m · marcha lenta %d rpm · corte %d rpm · %s" % [roundi(float(s["torque"]) * d.size_scale), roundi(float(s["idle"])),
			roundi(float(s["red"])), {"gasolina": "gasolina", "diesel": "diesel", "eletrico": "bateria"}[s["fuel"]]], 13, Color(1.0, 0.85, 0.4)))
		_content.add_child(_check("Liga sozinho (sem fio na entrada Ligado)", d.auto_start, func(on: bool) -> void: d.auto_start = on))
		_content.add_child(_label("Entrada Acelerador: 0 a 1. Ligue tanque, motor, embreagem, câmbio e cubos com a Transmissão (9), em qualquer ordem.", 12, Color(1, 1, 1, 0.55)))
	elif d.is_gearbox():
		if d.kind != "cvt":
			_content.add_child(_slider("Marchas", 1, 10, 1, d.gears, "%d", func(x: float) -> void: d.gears = int(x)))
			_content.add_child(_slider("1ª marcha", 1.5, 6.0, 0.1, d.first_ratio, "%.1f : 1", func(x: float) -> void: d.first_ratio = x))
			_content.add_child(_slider("Última", 0.5, 2.0, 0.05, d.top_ratio, "%.2f : 1", func(x: float) -> void: d.top_ratio = x))
		_content.add_child(_slider("Diferencial", 1.0, 12.0, 0.5, d.final_drive, "%.1f : 1", func(x: float) -> void: d.final_drive = x))
		if d.kind == "cambio_auto":
			_content.add_child(_slider("Troca a", 50, 95, 5, d.shift_up_frac * 100.0, "%d %% do corte", func(x: float) -> void: d.shift_up_frac = x / 100.0))
		_content.add_child(_check("Esterço de tanque (diferencial duplo: Esq/Dir/Esterço)", d.tank_steer, func(on: bool) -> void: d.tank_steer = on))
		_content.add_child(_label("Freio e Ré: 0 a 1. Manual: Sobe/Desce ou Marcha (-1 = ré, 0 = neutro). A frente e o lado de cada roda se ajustam no cubo (Inverter o giro, Lado).", 12, Color(1, 1, 1, 0.55)))
	elif d.is_clutch():
		_content.add_child(_label("Automática: engata sozinha pelo giro do motor." if d.kind == "embreagem_auto" else "Manual: entrada Pedal (1 = pisada, desengatada; 0 = engatada).", 13, Color(1.0, 0.85, 0.4)))
		_content.add_child(_label("Qualquer lugar no caminho entre o motor e as rodas. Sem embreagem, o motor fica preso às rodas.", 12, Color(1, 1, 1, 0.55)))
	elif d.is_tank():
		_content.add_child(_label("%s: %.1f de %d L. Encha na bomba de combustível (E nela)." % [d.fuel_type().capitalize(), d.fuel, roundi(d.capacity())], 13, Color(1.0, 0.85, 0.4)))


# --- Captura de teclas ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _capture.is_empty() and node is KeysNode:
		var t := node as KeysNode
		var which: String = _capture[0]
		var slot: int = _capture[1]
		var b: Button = _capture[2]
		var list: Array = t.bind_pos if which == "pos" else t.bind_neg
		var binding = null
		if event is InputEventKey and event.pressed and not event.is_echo():
			var k := event as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			if code == KEY_ESCAPE:
				binding = list[slot] if slot < list.size() else {}
			elif code == KEY_BACKSPACE or code == KEY_DELETE:
				binding = {}
			else:
				binding = {"key": code}
		elif event is InputEventMouseButton and event.pressed:
			var mb := (event as InputEventMouseButton).button_index
			if mb not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
				binding = {"mouse": mb}
		if binding != null:
			while list.size() <= slot:
				list.append({})
			list[slot] = binding
			while not list.is_empty() and (list.back() as Dictionary).is_empty():
				list.pop_back()
			b.text = MechJoint.binding_text(binding)
			t.refresh_label()
			_capture = []
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		var focus := get_viewport().gui_get_focus_owner()
		if event.is_action_pressed("interact") and focus is LineEdit:
			return   # digitando: E é letra
		close()
		get_viewport().set_input_as_handled()


# --- Utilidades ------------------------------------------------------------------------

func _label(text: String, size: int, color: Color, min_w := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if min_w > 0.0:
		l.custom_minimum_size = Vector2(min_w, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


func _row(title: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_label(title, 14, Color(1, 1, 1, 0.85), 120))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _check(text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.toggled.connect(cb)
	return c


func _num_edit(v: float, cb: Callable) -> LineEdit:
	var e := LineEdit.new()
	e.text = SignalNode.format(v)
	e.text_changed.connect(func(t: String) -> void: cb.call(t.replace(",", ".").to_float()))
	return e


func _text_edit(v: String, cb: Callable) -> LineEdit:
	var e := LineEdit.new()
	e.text = v
	e.text_changed.connect(cb)
	return e


func _color_btn(c: Color, cb: Callable) -> ColorPickerButton:
	var b := ColorPickerButton.new()
	b.color = c
	b.edit_alpha = false
	b.custom_minimum_size = Vector2(80, 30)
	b.color_changed.connect(cb)
	return b


func _slider(title: String, lo: float, hi: float, step: float, value: float, fmt: String, cb: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_label(title, 13, Color(1, 1, 1, 0.85), 120))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := _label(fmt % (roundi(value) if fmt.contains("%d") else value), 13, Color(1.0, 0.8, 0.4), 60)
	row.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		val.text = fmt % (roundi(x) if fmt.contains("%d") else x)
		cb.call(x))
	return row

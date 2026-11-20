class_name Hud
extends CanvasLayer
## Interface: mira, barra de ferramentas, dicas, mensagens, ajuda e menu de pausa.

const HELP_TEXT := """[b]CONTROLES[/b]

[b]Movimento[/b]
W A S D — andar
Toque duplo (ou Shift) — correr
Espaço — pular

[b]Ferramentas[/b]
1 — Mão (pegar peças)
2 — Solda
3 — Esmerilhadeira (cortar / remover solda)

[b]Mão[/b]
Clique segurado — pegar; a peça flutua
Soltar o clique — a peça FICA flutuando
E — devolve a gravidade à peça
Shift + W/S/A/D/Q/E — girar 15°
T — alinhar à grade do mundo
Roda do mouse — distância
Delete — apagar peça mirada

[b]Solda[/b]
Clique na emenda entre duas peças
(ou entre a peça e o chão = ancorar)

[b]Esmerilhadeira[/b]
Clique — cortar no plano laranja
R — mudar ângulo (reto / 45°)
Ctrl — corte livre (sem grade de 5 cm)
Botão direito — remover solda

H — mostrar/ocultar ajuda
F11 — tela cheia · F3 — FPS
Esc — menu"""

var player: Player

var _hotbar_slots: Array[PanelContainer] = []
var _hint: Label
var _aim_info: Label
var _toast: Label
var _toast_time := 0.0
var _help: PanelContainer
var _pause: Control
var _fps: Label
var _help_tip: Label
var _style_on: StyleBoxFlat
var _style_off: StyleBoxFlat


func setup(p_player: Player) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = p_player
	player.tool_changed.connect(_on_tool_changed)
	player.toast_requested.connect(show_toast)
	Build.message.connect(show_toast)
	_build_ui()
	_on_tool_changed(player.current_tool)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Mira
	var cross := Crosshair.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)

	_aim_info = _label(15, Color(1, 1, 1, 0.85))
	_aim_info.set_anchors_preset(Control.PRESET_CENTER)
	_aim_info.position = Vector2(-300, 22)
	_aim_info.size = Vector2(600, 24)
	_aim_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_aim_info)

	# Barra de ferramentas
	_style_on = StyleBoxFlat.new()
	_style_on.bg_color = Color(0.95, 0.55, 0.12, 0.85)
	_style_on.set_corner_radius_all(8)
	_style_on.set_content_margin_all(10)
	_style_off = StyleBoxFlat.new()
	_style_off.bg_color = Color(0.08, 0.09, 0.1, 0.65)
	_style_off.set_corner_radius_all(8)
	_style_off.set_content_margin_all(10)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.position.y = -16
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)

	_hint = _label(15, Color(1, 1, 1, 0.9))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_hint)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	bottom.add_child(bar)
	for t in player.tools:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(150, 0)
		var l := _label(17, Color.WHITE)
		l.text = "%s   %s" % [t.key_hint, t.tool_name]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(l)
		bar.add_child(slot)
		_hotbar_slots.append(slot)

	# Mensagens
	_toast = _label(20, Color(1, 0.92, 0.75))
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-400, 40)
	_toast.size = Vector2(800, 30)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	# Ajuda
	_help = PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.05, 0.06, 0.07, 0.62)
	hs.set_corner_radius_all(10)
	hs.set_content_margin_all(16)
	_help.add_theme_stylebox_override("panel", hs)
	_help.position = Vector2(16, 16)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(300, 0)
	rt.add_theme_font_size_override("normal_font_size", 13)
	rt.add_theme_font_size_override("bold_font_size", 14)
	rt.text = HELP_TEXT
	_help.add_child(rt)
	root.add_child(_help)

	_help_tip = _label(14, Color(1, 1, 1, 0.6))
	_help_tip.text = "H: ajuda"
	_help_tip.position = Vector2(16, 16)
	_help_tip.visible = false
	root.add_child(_help_tip)

	_fps = _label(14, Color(0.7, 1, 0.7))
	_fps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps.position = Vector2(-120, 12)
	_fps.visible = false
	root.add_child(_fps)

	_build_pause_menu()


func _build_pause_menu() -> void:
	_pause = Control.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause.visible = false
	add_child(_pause)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.1, 0.11, 0.13, 0.95)
	ps.set_corner_radius_all(12)
	ps.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(320, 0)
	panel.add_child(box)

	var title := _label(40, Color(1.0, 0.62, 0.2))
	title.text = "SUCATA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _label(14, Color(1, 1, 1, 0.6))
	sub.text = "sandbox de engenharia · v%s" % ProjectSettings.get_setting("application/config/version")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	box.add_child(_button("Continuar", _resume))
	box.add_child(_button("Recomeçar o mundo", _reset_world))

	var sens_label := _label(14, Color(1, 1, 1, 0.8))
	sens_label.text = "Sensibilidade do mouse"
	box.add_child(sens_label)
	var slider := HSlider.new()
	slider.min_value = 0.0005
	slider.max_value = 0.006
	slider.step = 0.0001
	slider.value = player.mouse_sensitivity
	slider.value_changed.connect(func(v: float) -> void: player.mouse_sensitivity = v)
	box.add_child(slider)

	box.add_child(_button("Sair", func() -> void: get_tree().quit()))


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	return b


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_time = 2.2


func _on_tool_changed(index: int) -> void:
	for i in _hotbar_slots.size():
		_hotbar_slots[i].add_theme_stylebox_override("panel", _style_on if i == index else _style_off)


func _process(delta: float) -> void:
	if player == null:
		return
	_hint.text = player.current().hint_text()
	var part := player.aim_part()
	if part:
		var extra := ""
		if part.assembly().get_parts().size() > 1:
			extra = "   [%d peças]" % part.assembly().get_parts().size()
		if part.assembly().anchored:
			extra += "   [ancorada]"
		_aim_info.text = part.describe() + extra
	else:
		_aim_info.text = ""
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
		_help.visible = not _help.visible
		_help_tip.visible = not _help.visible
	elif event.is_action_pressed("toggle_fps"):
		_fps.visible = not _fps.visible
	elif event.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("pause"):
		if _pause.visible:
			_resume()
		else:
			_open_pause()
	elif event is InputEventMouseButton and event.pressed and not _pause.visible \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _open_pause() -> void:
	_pause.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume() -> void:
	_pause.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _reset_world() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Mira simples desenhada em código.
class Crosshair extends Control:
	func _draw() -> void:
		var c := Color(1, 1, 1, 0.9)
		var o := Color(0, 0, 0, 0.6)
		draw_circle(Vector2.ZERO, 3.2, o)
		draw_circle(Vector2.ZERO, 2.0, c)
		for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(d * 7, d * 13, o, 4.0)
			draw_line(d * 7, d * 13, c, 2.0)

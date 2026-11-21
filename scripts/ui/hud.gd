class_name Hud
extends CanvasLayer
## Interface: mira, barra de ferramentas, dicas, mensagens, ajuda e menu de pausa.

const HELP_TEXT := """[b]CONTROLES[/b]

[b]Movimento[/b]
W A S D — andar
Toque duplo (ou Shift) — correr
Espaço — pular · Ctrl — agachar
E — usar (loja, assento, botão, alavanca, engate)
E segurado num puxador — puxar (portas etc.)

[b]Ferramentas[/b]
1 — Gravitador (pegar peças)
2 — Solda
3 — Esmerilhadeira (cortar / remover solda)
4 — Fiação (ligar uma saída numa entrada)
5 — Depurador (ver os sinais de uma peça)
6 — Trena (medir e marcar)
7 — Alinhador (encaixar um ponto em outro)

[b]Gravitador[/b]
Clique segurado — pegar · soltar — cai (dá pra jogar)
Botão direito (segurando) — congelar no lugar
E + mouse — girar · com Shift: passos de 15°
Roda do mouse — distância · T — alinhar à grade
R mirando — descongelar · R R — descongelar tudo

[b]Solda[/b]
Segure o clique bem na emenda entre duas peças
(ou entre a peça e o chão = ancorar)
Arraste segurando para fazer vários pontos

[col]
[b]Esmerilhadeira[/b]
Segure o clique — corta a face mirada
(o corte trava no lugar; soltar cancela)
R — girar o corte (0° / 45° / 90° / 135°)
G — liga/desliga a grade de 5 cm (corte livre)
Segure o clique numa bolinha — remove a solda
Segure o clique num isolador — arranca
O corte encaixa nas marcas da Trena

[b]Trena[/b]
Clique — ponto A · outro clique — ponto B
Botão direito — põe/tira marca (cruz vermelha)
R — limpa · G — grade de 5 cm

[b]Alinhador[/b]
Clique no ponto da peça que vai se mover,
  depois no ponto de destino (outra peça/chão)
As faces encostam em esquadro e ela congela
Shift no 2º clique — só mover (sem girar)
Botão direito — cancela

[b]Salvar[/b]
Esc → Salvar / Carregar (mundos e construções)
Para salvar uma máquina: mire nela (ou sente
  no assento) antes de apertar Esc
Automático a cada 5 min e ao sair

[b]Reciclador e loja[/b]
Jogue peças no RECICLADOR = pontos
E no terminal da LOJA — comprar peças

H — mostrar/ocultar ajuda
F11 — tela cheia · F3 — FPS
Esc — menu

[col]
[b]Máquinas[/b]
E no assento — sentar · E de novo — levantar
Tab sentado — modo edição: clique num componente
  destacado para escolher as teclas dele
E (clique, sentado) — usar botão / alavanca
Alavanca variável: segure E e mova o mouse
  para cima/baixo
Fiação: clique na peça de origem (escolha a
  saída), na estrutura por onde o fio passa
  (isoladores) e no destino (escolha a entrada)
Fiação, botão direito: remove isolador, ajustes
  (componente, chip, tela...) ou faixa da alavanca
Chip lógico: botão direito com a Fiação escolhe
  o modo (E, OU, somar, memória, tempo...)
Depurador: mira mostra entradas e saídas ao vivo;
  botão direito: nome e ajustes
Guincho: tecla + recolhe o cabo, − solta
Eletroímã: ligado puxa e gruda aço/ferro
Engate rápido: E nele (ou sinal) trava no
  que encostar na face listrada"""

## Ao soldar: só escurece as bordas da tela (o escuro principal vem do fog preto do mundo).
const WELD_MASK_SHADER := """
shader_type canvas_item;
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 1.7778;
uniform float strength = 0.0;
void fragment() {
	float edge = length((UV - vec2(0.5)) * vec2(aspect, 1.0));
	float a = smoothstep(0.35, 1.0, edge) * 0.9;
	COLOR = vec4(0.0, 0.0, 0.0, a * strength);
}
"""

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
var _points: Label
var shop: ShopUI
var seat_ui: SeatUI
var save_menu: SaveMenu
var placer: BuildPlacer
var port_menu: PortMenu
var node_config: NodeConfigUI
var keypad_ui: KeypadUI
var _debug_panel: PanelContainer
var _debug_text: Label
var _aimed_on_pause: Part = null
var _bar: HBoxContainer
var _cross: Crosshair
var _mask: ColorRect
var _mask_mat: ShaderMaterial
var _mask_strength := 0.0
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

	# Máscara de solda (escurece a tela enquanto a tocha está acesa)
	_mask_mat = ShaderMaterial.new()
	_mask_mat.shader = Shader.new()
	_mask_mat.shader.code = WELD_MASK_SHADER
	_mask = ColorRect.new()
	_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.material = _mask_mat
	_mask.visible = false
	root.add_child(_mask)

	# Mira
	_cross = Crosshair.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_cross)

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
	_bar = bar
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	bottom.add_child(bar)
	for t in player.tools:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(126, 0)
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
	# Duas colunas (o texto é longo demais para uma só caber na tela).
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	for chunk in HELP_TEXT.split("[col]"):
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.custom_minimum_size = Vector2(335, 0)
		rt.add_theme_font_size_override("normal_font_size", 13)
		rt.add_theme_font_size_override("bold_font_size", 14)
		rt.text = chunk.strip_edges()
		cols.add_child(rt)
	_help.add_child(cols)
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

	_points = _label(22, Color(0.55, 1.0, 0.6))
	_points.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_points.position = Vector2(-220, 36)
	_points.size = Vector2(200, 30)
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_points)
	Economy.points_changed.connect(_on_points_changed)
	_on_points_changed(Economy.points())

	shop = ShopUI.new()
	add_child(shop)
	seat_ui = SeatUI.new()
	add_child(seat_ui)
	port_menu = PortMenu.new()
	add_child(port_menu)
	node_config = NodeConfigUI.new()
	add_child(node_config)
	keypad_ui = KeypadUI.new()
	add_child(keypad_ui)
	player.port_menu_requested.connect(func(title: String, items: Array, cb: Callable) -> void: port_menu.open(title, items, cb))
	player.node_config_requested.connect(func(n: SignalNode) -> void: node_config.open(player, n))
	player.keypad_requested.connect(func(n: KeypadNode) -> void: keypad_ui.open(player, n))
	# Painel do Depurador (ao lado da mira)
	_debug_panel = PanelContainer.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.04, 0.08, 0.06, 0.82)
	dsb.set_corner_radius_all(8)
	dsb.set_content_margin_all(10)
	_debug_panel.add_theme_stylebox_override("panel", dsb)
	_debug_panel.set_anchors_preset(Control.PRESET_CENTER)
	_debug_panel.position = Vector2(40, -40)
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_panel.visible = false
	_debug_text = _label(14, Color(0.6, 1.0, 0.7))
	_debug_panel.add_child(_debug_text)
	add_child(_debug_panel)
	save_menu = SaveMenu.new()
	save_menu.world = player.get_parent()
	add_child(save_menu)
	save_menu.closed.connect(func() -> void: _pause.visible = true)
	save_menu.world_loaded.connect(func() -> void:
		save_menu.visible = false
		_resume())
	save_menu.place_requested.connect(_start_placing)
	placer = BuildPlacer.new()
	placer.name = "BuildPlacer"
	player.get_parent().add_child.call_deferred(placer)
	player.edit_requested.connect(func() -> void: seat_ui.open(player, Build.network(player.seat)))
	player.config_requested.connect(func(j: MechJoint) -> void: seat_ui.open_single(player, j))
	player.seat_changed.connect(func(seated: bool) -> void:
		if not seated:
			seat_ui.close())

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

	var title := _label(30, Color(1.0, 0.62, 0.2))
	title.text = "JUNK CONSTRUCTION\nSIMULATOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _label(14, Color(1, 1, 1, 0.6))
	sub.text = "sucata, solda e engenharia · v%s" % ProjectSettings.get_setting("application/config/version")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	box.add_child(_button("Continuar", _resume))
	box.add_child(_button("Salvar / Carregar", func() -> void:
		_pause.visible = false
		save_menu.open(_aimed_on_pause)))

	box.add_child(_small_label("Gráficos"))
	var gfx := OptionButton.new()
	for n in Settings.GRAPHICS_NAMES:
		gfx.add_item(n)
	gfx.selected = Settings.graphics
	gfx.custom_minimum_size = Vector2(0, 36)
	gfx.item_selected.connect(func(i: int) -> void: Settings.set_graphics(i))
	box.add_child(gfx)

	var fov_label := _small_label("Campo de visão: %d°" % roundi(Settings.fov))
	box.add_child(fov_label)
	var fov_slider := HSlider.new()
	fov_slider.min_value = 60
	fov_slider.max_value = 100
	fov_slider.step = 1
	fov_slider.value = Settings.fov
	fov_slider.value_changed.connect(func(v: float) -> void:
		fov_label.text = "Campo de visão: %d°" % roundi(v)
		Settings.set_fov(v))
	box.add_child(fov_slider)

	box.add_child(_small_label("Sensibilidade do mouse"))
	var slider := HSlider.new()
	slider.min_value = 0.0005
	slider.max_value = 0.006
	slider.step = 0.0001
	slider.value = Settings.mouse_sensitivity
	slider.value_changed.connect(func(v: float) -> void: Settings.set_mouse_sensitivity(v))
	box.add_child(slider)

	box.add_child(_button("Sair (salva automaticamente)", func() -> void:
		if Saves.autosave_enabled:
			Saves.autosave()
		get_tree().quit()))


func _small_label(text: String) -> Label:
	var l := _label(14, Color(1, 1, 1, 0.8))
	l.text = text
	return l


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


func _on_points_changed(total: int) -> void:
	_points.text = "%d pontos" % total
	var tw := _points.create_tween()
	_points.scale = Vector2(1.15, 1.15)
	_points.pivot_offset = _points.size * Vector2(1.0, 0.5)
	tw.tween_property(_points, "scale", Vector2.ONE, 0.25)


func open_shop(station: ShopStation) -> void:
	shop.open(station)


func _on_tool_changed(index: int) -> void:
	for i in _hotbar_slots.size():
		_hotbar_slots[i].add_theme_stylebox_override("panel", _style_on if i == index else _style_off)


func _process(delta: float) -> void:
	if player == null:
		return
	_bar.visible = not player.is_seated()
	var dbg := ""
	if player.current() is DebugTool and not player.is_seated() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		dbg = (player.current() as DebugTool).panel_text()
	_debug_panel.visible = dbg != ""
	if dbg != "":
		_debug_text.text = dbg
	if seat_ui.visible or node_config.visible or keypad_ui.visible or port_menu.visible:
		_hint.text = ""
	elif placer and placer.is_active():
		_hint.text = placer.hint_text()
	elif player.is_seated():
		_hint.text = "Sentado   ·   Tab: modo edição (teclas)   ·   E: levantar   ·   Clique: usar botões e alavancas"
	else:
		_hint.text = player.current().hint_text()
	var prog := player.current().progress()
	if prog != _cross.progress:
		_cross.progress = prog
		_cross.queue_redraw()
	_update_weld_mask(delta)
	var part := player.aim_part()
	var usable := player.interact_hint()
	if seat_ui.visible or dbg != "":
		_aim_info.text = ""
	elif usable != "":
		_aim_info.text = usable
	elif part:
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


func _update_weld_mask(delta: float) -> void:
	var target := 0.0
	var tool := player.current()
	if tool is WeldTool and (tool as WeldTool).is_arc_active():
		var p := (tool as WeldTool).arc_point()
		if not player.camera.is_position_behind(p):
			var vp := get_viewport().get_visible_rect().size
			_mask_mat.set_shader_parameter("center", player.camera.unproject_position(p) / vp)
			_mask_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
			target = 1.0
	_mask_strength = move_toward(_mask_strength, target, delta * (9.0 if target > 0.0 else 4.0))
	_mask.visible = _mask_strength > 0.001
	_mask_mat.set_shader_parameter("strength", _mask_strength)


func _unhandled_input(event: InputEvent) -> void:
	if seat_ui.visible or node_config.visible or keypad_ui.visible or port_menu.visible:
		return
	if save_menu.visible:
		if event.is_action_pressed("pause"):
			save_menu.close()
			get_viewport().set_input_as_handled()
		return
	if shop.visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
			shop.close()
			get_viewport().set_input_as_handled()
		return
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
	Saves.capture_frame()   # miniatura do save: a tela antes do menu aparecer
	_aimed_on_pause = player.seat if player.is_seated() else player.aim_part()
	_pause.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume() -> void:
	_pause.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Construção escolhida no menu: fecha tudo e mostra a prévia na mira.
func _start_placing(data: Dictionary) -> void:
	save_menu.visible = false
	_resume()
	if player.is_seated():
		player.stand_up()
	placer.start(player, data)


## Mira simples desenhada em código (com anel de progresso para ações demoradas).
class Crosshair extends Control:
	var progress := -1.0

	func _draw() -> void:
		if progress >= 0.0:
			draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 48, Color(0, 0, 0, 0.45), 5.0)
			draw_arc(Vector2.ZERO, 20.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(1.0, 0.7, 0.2), 3.0)
		var c := Color(1, 1, 1, 0.9)
		var o := Color(0, 0, 0, 0.6)
		draw_circle(Vector2.ZERO, 3.2, o)
		draw_circle(Vector2.ZERO, 2.0, c)
		for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(d * 7, d * 13, o, 4.0)
			draw_line(d * 7, d * 13, c, 2.0)

class_name SaveMenu
extends Control
## Tela de salvar e carregar (menu Esc → Salvar / Carregar).
##   Mundos       salvar o mundo inteiro com nome, carregar, apagar, novo mundo
##   Construções  salvar a máquina mirada (ao abrir o menu), colocar uma salva, apagar

signal closed
signal world_loaded
signal place_requested(data: Dictionary)

const THUMB := Vector2(160, 90)

var world: Node
var aimed: Part = null            ## peça mirada quando o menu abriu

var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _world_list: VBoxContainer
var _build_list: VBoxContainer
var _world_name: LineEdit
var _world_save: Button
var _build_name: LineEdit
var _build_save: Button
var _build_info: Label
var _status: Label
var _last_world_name := "Meu mundo"


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.1, 0.11, 0.13, 0.97), 12, 22))
	panel.custom_minimum_size = Vector2(820, 600)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	for i in 2:
		var t := _button(["Mundos", "Construções"][i], func() -> void: _show_tab(i))
		t.toggle_mode = true
		t.custom_minimum_size = Vector2(150, 40)
		_tabs.append(t)
		top.add_child(t)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(_button("Abrir pasta", Saves.open_folder))
	top.add_child(_button("Voltar", close))

	_pages.append(_build_world_page())
	_pages.append(_build_build_page())
	for p in _pages:
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(p)

	_status = _label("", 14, Color(0.6, 1.0, 0.6))
	v.add_child(_status)
	Saves.changed.connect(_refresh)


func _build_world_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_label("Nome:", 15, Color.WHITE))
	_world_name = LineEdit.new()
	_world_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_name.max_length = 40
	_world_name.text_changed.connect(func(_t: String) -> void: _update_world_button())
	_world_name.text_submitted.connect(func(_t: String) -> void: _world_save.pressed.emit())
	row.add_child(_world_name)
	_world_save = _button("Salvar o mundo", _save_world)
	row.add_child(_world_save)
	page.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	row2.add_child(_confirm_button("Novo mundo", "Apagar tudo e recomeçar?", _new_world))
	row2.add_child(_label("Salvamento automático a cada 5 min e ao sair (guarda os 3 últimos).", 13, Color(1, 1, 1, 0.55)))
	page.add_child(row2)
	page.add_child(_scroll(func(list: VBoxContainer) -> void: _world_list = list))
	return page


func _build_build_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	_build_info = _label("", 14, Color(1.0, 0.85, 0.4))
	_build_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_build_info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_label("Nome:", 15, Color.WHITE))
	_build_name = LineEdit.new()
	_build_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_name.max_length = 40
	_build_name.text_submitted.connect(func(_t: String) -> void: _save_build())
	row.add_child(_build_name)
	_build_save = _button("Salvar construção", _save_build)
	row.add_child(_build_save)
	page.add_child(row)
	var mode := "Colocar uma construção: GRÁTIS por enquanto (modo de teste)." if Saves.builds_free \
		else "Colocar uma construção custa os pontos das peças."
	page.add_child(_label(mode, 13, Color(1, 1, 1, 0.55)))
	page.add_child(_scroll(func(list: VBoxContainer) -> void: _build_list = list))
	return page


func open(p_aimed: Part) -> void:
	aimed = p_aimed if p_aimed and is_instance_valid(p_aimed) and p_aimed.is_inside_tree() else null
	_status.text = ""
	_world_name.text = _last_world_name
	_build_name.text = ""
	_update_build_info()
	_refresh()
	visible = true
	_show_tab(0)


func close() -> void:
	visible = false
	closed.emit()


func _show_tab(i: int) -> void:
	for k in _pages.size():
		_pages[k].visible = k == i
		_tabs[k].button_pressed = k == i


func _update_build_info() -> void:
	if aimed == null:
		_build_info.text = "Para salvar uma máquina: feche o menu, mire nela (ou sente no assento dela) e abra o menu de novo."
		_build_save.disabled = true
		return
	var asms := Saves.machine_of(aimed)
	var n := 0
	for asm: Assembly in asms:
		n += asm.get_parts().size()
	var price := Saves.build_price(Saves.serialize(asms, Saves.machine_origin(asms)))
	_build_info.text = "Máquina mirada: %s · %d peça%s (com o que está soldado, juntas e fios) · vale %d pontos" % [
		aimed.display_name(), n, "" if n == 1 else "s", price]
	_build_save.disabled = false
	if _build_name.text == "":
		_build_name.text = "Construção %d" % (Saves.list(Saves.DIR_BUILDS).size() + 1)


func _update_world_button() -> void:
	var exists := FileAccess.file_exists(Saves.DIR_WORLDS.path_join(Saves.slug(_world_name.text) + ".json"))
	_world_save.text = "Sobrescrever" if exists else "Salvar o mundo"


# --- Ações --------------------------------------------------------------------

func _save_world() -> void:
	var n := _world_name.text.strip_edges()
	if n == "":
		n = "Meu mundo"
	var exists := FileAccess.file_exists(Saves.DIR_WORLDS.path_join(Saves.slug(n) + ".json"))
	if exists and not _world_save.get_meta("armed", false):
		_arm(_world_save, "Confirmar: sobrescrever?", "Sobrescrever")
		return
	_world_save.set_meta("armed", false)
	var path := Saves.save_world(n)
	_last_world_name = n
	_status.text = "Mundo salvo: %s" % n if path != "" else "Não deu para salvar"
	_update_world_button()


func _load_world(path: String, save_name: String) -> void:
	if Saves.load_world(path):
		if not save_name.begins_with("Salvamento automático"):
			_last_world_name = save_name
		world_loaded.emit()
	else:
		_status.text = "Não deu para abrir este save"


func _new_world() -> void:
	if world and world.has_method("new_world"):
		world.new_world()
		world_loaded.emit()


func _save_build() -> void:
	if aimed == null or not is_instance_valid(aimed) or not aimed.is_inside_tree():
		return
	var n := _build_name.text.strip_edges()
	if n == "":
		n = "Construção"
	var exists := FileAccess.file_exists(Saves.DIR_BUILDS.path_join(Saves.slug(n) + ".json"))
	if exists and not _build_save.get_meta("armed", false):
		_arm(_build_save, "Confirmar: sobrescrever?", "Salvar construção")
		return
	_build_save.set_meta("armed", false)
	_build_save.text = "Salvar construção"
	var path := Saves.save_build(aimed, n)
	_status.text = "Construção salva: %s" % n if path != "" else "Não deu para salvar"


func _place_build(path: String) -> void:
	var data := Saves.read(path)
	if data.is_empty():
		_status.text = "Não deu para abrir esta construção"
		return
	var price := Saves.build_price(data)
	if not Saves.builds_free and not Economy.can_afford(price):
		_status.text = "Faltam %d pontos para esta construção" % (price - Economy.points())
		return
	place_requested.emit(data)


# --- Listas -------------------------------------------------------------------

func _refresh() -> void:
	if _world_list == null:
		return
	for c in _world_list.get_children():
		c.queue_free()
	for c in _build_list.get_children():
		c.queue_free()
	var worlds := Saves.list(Saves.DIR_WORLDS)
	if worlds.is_empty():
		_world_list.add_child(_label("Nenhum mundo salvo ainda.", 14, Color(1, 1, 1, 0.5)))
	for e: Dictionary in worlds:
		_world_list.add_child(_row(e, false))
	var builds := Saves.list(Saves.DIR_BUILDS)
	if builds.is_empty():
		_build_list.add_child(_label("Nenhuma construção salva ainda.", 14, Color(1, 1, 1, 0.5)))
	for e: Dictionary in builds:
		_build_list.add_child(_row(e, true))
	_update_world_button()


func _row(e: Dictionary, is_build: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.15, 0.16, 0.19), 8, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	var tex := TextureRect.new()
	tex.custom_minimum_size = THUMB
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if e["thumb"] != "":
		var img := Image.new()
		if img.load(e["thumb"]) == OK:
			tex.texture = ImageTexture.create_from_image(img)
	h.add_child(tex)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(_label(e["name"], 17, Color(1.0, 0.85, 0.4)))
	info.add_child(_label("%s · %d peças" % [Saves.date_text(e["time"]), e["parts"]], 13, Color(1, 1, 1, 0.7)))
	if is_build:
		var price_text := "vale %d pontos · grátis no modo de teste" % e["price"] if Saves.builds_free else "custa %d pontos" % e["price"]
		info.add_child(_label(price_text, 13, Color(0.6, 1.0, 0.6) if Saves.builds_free or Economy.can_afford(e["price"]) else Color(1.0, 0.45, 0.4)))
	h.add_child(info)
	var path: String = e["path"]
	var save_name: String = e["name"]
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	if is_build:
		buttons.add_child(_button("Colocar", func() -> void: _place_build(path)))
	else:
		buttons.add_child(_button("Carregar", func() -> void: _load_world(path, save_name)))
	buttons.add_child(_confirm_button("Apagar", "Confirmar?", func() -> void:
		Saves.delete(path)
		_refresh()))
	h.add_child(buttons)
	return panel


# --- Utilidades de interface ---------------------------------------------------

func _scroll(store: Callable) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 360)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)
	store.call(list)
	return sc


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 36)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	return b


## Botão que pede um segundo clique para confirmar (ações que apagam algo).
func _confirm_button(text: String, confirm_text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 36)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(func() -> void:
		if b.get_meta("armed", false):
			b.set_meta("armed", false)
			b.text = text
			cb.call()
		else:
			_arm(b, confirm_text, text))
	return b


func _arm(b: Button, confirm_text: String, normal_text: String) -> void:
	b.set_meta("armed", true)
	b.text = confirm_text
	get_tree().create_timer(3.0, true).timeout.connect(func() -> void:
		if is_instance_valid(b) and b.get_meta("armed", false):
			b.set_meta("armed", false)
			b.text = normal_text)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func _box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb

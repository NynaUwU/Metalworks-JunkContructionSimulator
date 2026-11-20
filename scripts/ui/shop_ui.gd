class_name ShopUI
extends Control
## Tela da loja.
##
## Esquerda: cartões com ícone de cada item. Direita: prévia 3D girando do item
## escolhido, medidas ajustáveis (com limite), peso, preço e botão de comprar.

signal closed

var station: ShopStation
var _points_label: Label
var _cards := {}                 ## id -> Button
var _group := ButtonGroup.new()
var _selected: Dictionary = {}
var _size := Vector3.ONE

var _preview: PartPreview
var _name_label: Label
var _info_label: Label
var _params_box: VBoxContainer
var _price_label: Label
var _buy_button: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.1, 0.11, 0.13, 0.97), 12, 22))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(1060, 620)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := _label("LOJA DE SUCATA", 30, Color(1.0, 0.62, 0.2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_points_label = _label("", 22, Color(0.55, 1.0, 0.6))
	header.add_child(_points_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	box.add_child(body)

	# --- Lista de itens --------------------------------------------------------
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for cat in Catalog.categories():
		list.add_child(_label(cat, 17, Color(1, 1, 1, 0.7)))
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		list.add_child(grid)
		for item: Dictionary in Catalog.ITEMS:
			if item["cat"] == cat:
				grid.add_child(_make_card(item))

	# --- Detalhes do item escolhido ---------------------------------------------
	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", _box(Color(0.15, 0.16, 0.19), 10, 14))
	detail.custom_minimum_size = Vector2(330, 0)
	body.add_child(detail)
	var dbox := VBoxContainer.new()
	dbox.add_theme_constant_override("separation", 8)
	detail.add_child(dbox)

	var view := SubViewportContainer.new()
	view.custom_minimum_size = Vector2(300, 230)
	view.stretch = true
	dbox.add_child(view)
	_preview = PartPreview.new(300, true)
	_preview.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	view.add_child(_preview)

	_name_label = _label("", 22, Color.WHITE)
	dbox.add_child(_name_label)
	_info_label = _label("", 14, Color(1, 1, 1, 0.75))
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(300, 0)
	dbox.add_child(_info_label)
	_params_box = VBoxContainer.new()
	_params_box.add_theme_constant_override("separation", 4)
	dbox.add_child(_params_box)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dbox.add_child(spacer)
	_price_label = _label("", 20, Color(0.55, 1.0, 0.6))
	dbox.add_child(_price_label)
	_buy_button = Button.new()
	_buy_button.text = "Comprar"
	_buy_button.custom_minimum_size = Vector2(0, 46)
	_buy_button.add_theme_font_size_override("font_size", 20)
	_buy_button.pressed.connect(_on_buy)
	dbox.add_child(_buy_button)

	box.add_child(_label("Recicle sucata para ganhar pontos · os itens aparecem na plataforma ENTREGA · Esc ou E: fechar", 13, Color(1, 1, 1, 0.55)))
	Economy.points_changed.connect(func(_t: int) -> void: refresh())

	_select(Catalog.ITEMS[0])
	_generate_icons()


func _make_card(item: Dictionary) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = _group
	b.custom_minimum_size = Vector2(150, 132)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = false
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_constant_override("icon_max_width", 84)
	if Catalog.is_locked(item):
		b.text = "%s\nem breve" % item["nome"]
		b.disabled = true
	else:
		var tag := "ajustável" if not Catalog.params(item).is_empty() else (
			"componente" if Catalog.is_component(item) else MetalMaterials.display_name(item["mat"]))
		b.text = "%s\n%s" % [item["nome"], tag]
		b.pressed.connect(_select.bind(item))
	_cards[item["id"]] = b
	return b


## Gera os ícones renderizando cada peça numa cena 3D à parte (alguns quadros).
func _generate_icons() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var shot := PartPreview.new(128, false)
	shot.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(shot)
	await get_tree().process_frame
	for item: Dictionary in Catalog.ITEMS:
		if Catalog.is_locked(item):
			continue
		_show_in(shot, item, Catalog.default_size(item))
		shot.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := shot.get_texture().get_image()
		if img and not img.is_empty() and _cards.has(item["id"]):
			(_cards[item["id"]] as Button).icon = ImageTexture.create_from_image(img)
	shot.queue_free()


func _select(item: Dictionary) -> void:
	_selected = item
	_size = Catalog.default_size(item)
	(_cards[item["id"]] as Button).set_pressed_no_signal(true)
	_name_label.text = item["nome"]
	for c in _params_box.get_children():
		c.queue_free()
	for p: Dictionary in Catalog.params(item):
		var row := HBoxContainer.new()
		var name_l := _label("%s\n(máx. %s)" % [p["nome"], Catalog.meters(p["max"])], 13, Color(1, 1, 1, 0.85))
		name_l.custom_minimum_size = Vector2(105, 0)
		row.add_child(name_l)
		var value_l := _label(Catalog.meters(Catalog.param_value(_size, p)), 14, Color(1.0, 0.8, 0.4))
		value_l.custom_minimum_size = Vector2(70, 0)
		value_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var slider := HSlider.new()
		slider.min_value = p["min"]
		slider.max_value = p["max"]
		slider.step = p["step"]
		slider.value = Catalog.param_value(_size, p)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(v: float) -> void:
			_size = Catalog.with_param(_size, p, v)
			value_l.text = Catalog.meters(v)
			_update_detail())
		row.add_child(slider)
		row.add_child(value_l)
		_params_box.add_child(row)
	_update_detail()


func _update_detail() -> void:
	if _selected.is_empty():
		return
	_show_in(_preview, _selected, _size)
	if Catalog.is_component(_selected):
		var info: String = Components.INFO[_selected["component"]]["desc"]
		if _selected["component"] == "roda":
			info = "Raio %s · largura %s\n%s" % [Catalog.meters(_size.x), Catalog.meters(_size.y), info]
		_info_label.text = info
	else:
		_info_label.text = "%s · %s\n%d kg" % [
			MetalMaterials.display_name(_selected["mat"]), Catalog.size_text(_size), roundi(Catalog.mass(_selected, _size))]
	refresh()


func _show_in(pv: PartPreview, item: Dictionary, size: Vector3) -> void:
	if Catalog.is_component(item):
		pv.show_node(Components.build_visual(item["component"], size), Catalog.spawn_bounds(item, size))
	else:
		pv.show_geometry(Catalog.geometry(item, size), item["mat"])


func open(p_station: ShopStation) -> void:
	station = p_station
	visible = true
	refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not visible:
		return
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func refresh() -> void:
	if _points_label == null:
		return
	_points_label.text = "%d pontos" % Economy.points()
	if _selected.is_empty():
		return
	var cost := Catalog.price(_selected, _size)
	var ok := Economy.can_afford(cost)
	_price_label.text = "%d pontos" % cost
	_price_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if ok else Color(1.0, 0.45, 0.4))
	_buy_button.disabled = not ok
	_buy_button.text = "Comprar" if ok else "Faltam %d pontos" % (cost - Economy.points())


func _on_buy() -> void:
	if station and not _selected.is_empty():
		station.buy(_selected["id"], _size)
	refresh()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb

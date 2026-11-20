class_name ShopUI
extends Control
## Tela da loja: lista os itens por categoria e compra com os pontos do reciclador.

signal closed

var station: ShopStation
var _points_label: Label
var _buttons := {}               ## id -> Button


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
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.1, 0.11, 0.13, 0.96)
	ps.set_corner_radius_all(12)
	ps.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(860, 560)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := _label("LOJA DE SUCATA", 30, Color(1.0, 0.62, 0.2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_points_label = _label("", 22, Color(0.55, 1.0, 0.6))
	header.add_child(_points_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for cat in Catalog.categories():
		list.add_child(_label(cat, 18, Color(1, 1, 1, 0.75)))
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		list.add_child(grid)
		for item: Dictionary in Catalog.ITEMS:
			if item["cat"] != cat:
				continue
			var b := Button.new()
			b.custom_minimum_size = Vector2(200, 78)
			b.add_theme_font_size_override("font_size", 14)
			b.text = _item_text(item)
			b.pressed.connect(_on_buy.bind(item["id"]))
			grid.add_child(b)
			_buttons[item["id"]] = b

	box.add_child(_label("Recicle sucata para ganhar pontos · os itens aparecem na plataforma ENTREGA · Esc ou F: fechar", 13, Color(1, 1, 1, 0.6)))
	Economy.points_changed.connect(func(_t: int) -> void: refresh())


func _item_text(item: Dictionary) -> String:
	if Catalog.is_locked(item):
		return "%s\nem breve (Marco 2)" % item["nome"]
	return "%s\n%s · %d kg\n%d pontos" % [
		item["nome"], MetalMaterials.display_name(item["mat"]), roundi(Catalog.mass(item)), Catalog.price(item)]


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
	for item: Dictionary in Catalog.ITEMS:
		var b: Button = _buttons.get(item["id"])
		if b:
			b.disabled = Catalog.is_locked(item) or not Economy.can_afford(Catalog.price(item))


func _on_buy(id: String) -> void:
	if station:
		station.buy(id)
	refresh()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

class_name FpgaEditor
extends Control
## Editor visual do FPGA (botão direito com a Fiação num FPGA). Tela cheia:
##   à esquerda, a lista de peças (pinos, constante e todos os modos do chip lógico):
##     clique para pôr no meio da vista (ou arraste para onde quiser);
##   no meio, o circuito: arraste de uma bolinha de saída (direita) até uma de entrada
##     (esquerda) para ligar; arraste a ponta de uma ligação para fora para desligar;
##     Delete apaga o que estiver selecionado; botão do meio/rodinha movem e dão zoom;
##   em cima: nome do FPGA, salvar/carregar circuitos e fechar (Esc).
## As saídas mostram o valor ao vivo.

const TYPE_IDX := {"n": 0, "v": 1, "s": 2, "p": 3, "l": 4}
const TYPE_LIST := ["n", "v", "s", "p", "l"]
const LIVE_EVERY := 0.15

var player: Player
var fpga: FpgaNode
var graph: GraphEdit
var _palette: Tree
var _search: LineEdit
var _desc: Label
var _title: Label
var _name_edit: LineEdit
var _circ_name: LineEdit
var _circ_list: OptionButton
var _status: Label
var _live := {}                  ## id -> [[Label, porta], ...]
var _live_t := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.07, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 10
	root.offset_right = -12
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	# Barra de cima
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	_title = _label("FPGA", 20, Color(1.0, 0.85, 0.4))
	top.add_child(_title)
	top.add_child(_label("   Nome", 14, Color(1, 1, 1, 0.75)))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "(sem nome)"
	_name_edit.max_length = 24
	_name_edit.custom_minimum_size = Vector2(170, 0)
	_name_edit.text_changed.connect(func(t: String) -> void:
		if fpga:
			fpga.node_name = t.strip_edges())
	top.add_child(_name_edit)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(_label("Circuito", 14, Color(1, 1, 1, 0.75)))
	_circ_name = LineEdit.new()
	_circ_name.placeholder_text = "nome do circuito"
	_circ_name.custom_minimum_size = Vector2(170, 0)
	top.add_child(_circ_name)
	top.add_child(_button("Salvar", _save_circuit))
	_circ_list = OptionButton.new()
	_circ_list.custom_minimum_size = Vector2(190, 0)
	top.add_child(_circ_list)
	top.add_child(_button("Carregar", _load_circuit))
	top.add_child(_button("Apagar salvo", _delete_circuit))
	top.add_child(_button("Limpar tudo", _clear_all))
	top.add_child(_button("Fechar (Esc)", close))
	# Meio: lista de peças + circuito
	var mid := HSplitContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(270, 0)
	left.add_theme_constant_override("separation", 6)
	mid.add_child(left)
	_search = LineEdit.new()
	_search.placeholder_text = "Procurar (ex.: somar, latch, seno)"
	_search.text_changed.connect(func(_t: String) -> void: _fill_palette())
	left.add_child(_search)
	_palette = Tree.new()
	_palette.hide_root = true
	_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette.item_activated.connect(_on_palette_activated)
	_palette.item_selected.connect(_on_palette_selected)
	_palette.set_drag_forwarding(_palette_drag, Callable(), Callable())
	left.add_child(_palette)
	_desc = _label("Clique duas vezes (ou arraste) para pôr no circuito.", 13, Color(1, 1, 1, 0.7))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(0, 80)
	left.add_child(_desc)
	graph = GraphEdit.new()
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.right_disconnects = true
	graph.show_zoom_label = true
	graph.minimap_enabled = false
	graph.connection_lines_thickness = 3.0
	graph.connection_request.connect(_on_connect)
	graph.disconnection_request.connect(_on_disconnect)
	graph.delete_nodes_request.connect(_on_delete)
	graph.end_node_move.connect(_on_moved)
	graph.set_drag_forwarding(Callable(), _graph_can_drop, _graph_drop)
	mid.add_child(graph)
	_status = _label("Arraste da bolinha de saída (direita) até a de entrada (esquerda) para ligar  ·  arraste a ponta de uma ligação para fora para desligar  ·  Delete apaga o selecionado  ·  botão do meio move a vista, rodinha dá zoom  ·  pinos de Entrada/Saída viram as portas do FPGA (de cima para baixo)", 12, Color(1, 1, 1, 0.55))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)
	_fill_palette()


# --- Abrir / fechar ---------------------------------------------------------------------

func open(p_player: Player, n: FpgaNode) -> void:
	player = p_player
	fpga = n
	_name_edit.text = n.node_name
	_title.text = "FPGA"
	_refresh_circuits()
	_rebuild_graph()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	fpga = null
	_live = {}
	if player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or fpga == null:
		return
	if not fpga.is_alive() and fpga.part != null:
		close()
		return
	_live_t -= delta
	if _live_t > 0.0:
		return
	_live_t = LIVE_EVERY
	for id: int in _live:
		for pair: Array in _live[id]:
			var l: Label = pair[0]
			if is_instance_valid(l):
				var v := SignalNode.format(fpga.gate_value(id, pair[1]))
				l.text = ("= %s" % v) if pair.size() > 2 else ("%s = %s" % [pair[1], v])


# --- Lista de peças ---------------------------------------------------------------------

func _fill_palette() -> void:
	_palette.clear()
	var root := _palette.create_item()
	var q := _search.text.strip_edges().to_lower()
	var pins := _palette.create_item(root)
	pins.set_text(0, "Pinos e constante")
	pins.set_selectable(0, false)
	for m: String in [FpgaNode.PIN_IN, FpgaNode.PIN_OUT, FpgaNode.PIN_CONST]:
		var nm: String = FpgaNode.PIN_NAMES[m]
		if q != "" and not nm.to_lower().contains(q):
			continue
		var it := _palette.create_item(pins)
		it.set_text(0, nm)
		it.set_metadata(0, m)
	for cat: String in Gates.CATEGORIES:
		var head := _palette.create_item(root)
		head.set_text(0, cat)
		head.set_selectable(0, false)
		var any := false
		for m: String in Gates.modes_in(cat):
			var d: Dictionary = Gates.DEFS[m]
			if q != "" and not (str(d["name"]).to_lower().contains(q) or str(d["desc"]).to_lower().contains(q) or str(d["sym"]).to_lower() == q):
				continue
			var it := _palette.create_item(head)
			it.set_text(0, "%s   %s" % [d["sym"], d["name"]])
			it.set_metadata(0, m)
			any = true
		head.collapsed = q == "" and cat != "Lógica"
		if not any:
			head.free()


func _palette_mode() -> String:
	var it := _palette.get_selected()
	return str(it.get_metadata(0)) if it and it.get_metadata(0) != null else ""


func _on_palette_selected() -> void:
	var m := _palette_mode()
	if m == "":
		return
	if FpgaNode.PIN_NAMES.has(m):
		_desc.text = {"@in": "Entrada do FPGA: vira uma porta de entrada (fio de fora). Nome e tipo editáveis.",
			"@out": "Saída do FPGA: vira uma porta de saída. Nome e tipo editáveis.",
			"@const": "Valor fixo (número, vetor ou texto)."}[m]
	else:
		var d: Dictionary = Gates.DEFS[m]
		_desc.text = "%s\n%s" % [d["name"], d["desc"]]


func _on_palette_activated() -> void:
	var m := _palette_mode()
	if m != "":
		_add(m, _view_center())


func _palette_drag(_at: Vector2) -> Variant:
	var m := _palette_mode()
	if m == "":
		return null
	var l := _label(_palette.get_selected().get_text(0), 14, Color(1.0, 0.85, 0.4))
	_palette.set_drag_preview(l)
	return {"fpga_mode": m}


func _graph_can_drop(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("fpga_mode")


func _graph_drop(at: Vector2, data: Variant) -> void:
	_add(str(data["fpga_mode"]), (at + graph.scroll_offset) / graph.zoom)


func _view_center() -> Vector2:
	var jitter := Vector2(randf_range(-40, 40), randf_range(-30, 30))
	return (graph.scroll_offset + graph.size * 0.5) / graph.zoom - Vector2(80, 40) + jitter


func _add(mode: String, pos: Vector2) -> void:
	if fpga == null:
		return
	var extra := {}
	if mode == FpgaNode.PIN_IN:
		extra = {"name": _next_letter()}
	var id := fpga.add_gate(mode, pos, extra)
	if id < 0:
		_status.text = "Limite de %d peças no FPGA." % FpgaNode.MAX_GATES
		return
	_make_node(id)


func _next_letter() -> String:
	var used := {}
	for id: int in fpga.gates:
		if fpga.gates[id]["mode"] == FpgaNode.PIN_IN:
			used[fpga.gates[id]["name"]] = true
	for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		if not used.has(c):
			return c
	return "X"


# --- Circuito -----------------------------------------------------------------------------

func _rebuild_graph() -> void:
	graph.clear_connections()
	for c in graph.get_children():
		if c is GraphNode:
			graph.remove_child(c)
			c.queue_free()
	_live = {}
	for id: int in fpga.gates:
		_make_node(id)
	for e: Dictionary in fpga.edges:
		_show_edge(e)


func _show_edge(e: Dictionary) -> void:
	var f := int(e["f"])
	var t := int(e["t"])
	var fi := _port_index(fpga.gate_outs(f), str(e["fp"]))
	var ti := _port_index(fpga.gate_ins(t), str(e["tp"]))
	if fi >= 0 and ti >= 0:
		graph.connect_node("g%d" % f, fi, "g%d" % t, ti)


static func _port_index(ports: Array, port: String) -> int:
	for i in ports.size():
		if ports[i][0] == port:
			return i
	return -1


func _make_node(id: int) -> GraphNode:
	var g: Dictionary = fpga.gates[id]
	var mode := str(g["mode"])
	var gn := GraphNode.new()
	gn.name = "g%d" % id
	gn.title = fpga.gate_title(id)
	gn.position_offset = g["pos"]
	gn.set_meta("id", id)
	var ins := fpga.gate_ins(id)
	var outs := fpga.gate_outs(id)
	var pin := FpgaNode.PIN_NAMES.has(mode)
	if pin:
		_tint(gn, {"@in": Color(0.2, 0.45, 0.25), "@out": Color(0.5, 0.25, 0.15), "@const": Color(0.2, 0.3, 0.55)}[mode])
	if Gates.DEFS.has(mode):
		gn.tooltip_text = str(Gates.DEFS[mode]["desc"])
	var rows := maxi(maxi(ins.size(), outs.size()), 1)
	var lives: Array = []
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		if pin and r == 0:
			_pin_row(row, id, g)
		if r < ins.size() and not pin:
			row.add_child(_label(str(ins[r][0]), 13, SignalNode.TYPE_COLORS[ins[r][1]]))
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.custom_minimum_size = Vector2(18, 0)
		row.add_child(gap)
		if r < outs.size():
			var vl := _label(str(outs[r][0]), 13, SignalNode.TYPE_COLORS[outs[r][1]])
			vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(vl)
			lives.append([vl, str(outs[r][0]), true] if pin else [vl, str(outs[r][0])])
		elif mode == FpgaNode.PIN_OUT:
			var vl2 := _label("", 13, Color(1, 1, 1, 0.8))
			row.add_child(vl2)
			lives.append([vl2, "Valor", true])
		gn.add_child(row)
		var li := r < ins.size()
		var ro := r < outs.size()
		gn.set_slot(r, li, TYPE_IDX[ins[r][1]] if li else 0, SignalNode.TYPE_COLORS[ins[r][1]] if li else Color.WHITE,
			ro, TYPE_IDX[outs[r][1]] if ro else 0, SignalNode.TYPE_COLORS[outs[r][1]] if ro else Color.WHITE)
	_live[id] = lives
	graph.add_child(gn)
	return gn


## Linha de cima dos pinos e da constante: nome (ou valor) e tipo.
func _pin_row(row: HBoxContainer, id: int, g: Dictionary) -> void:
	var mode := str(g["mode"])
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(78, 0)
	edit.expand_to_text_length = true
	if mode == FpgaNode.PIN_CONST:
		var v: Variant = g["value"]
		edit.text = ("%s %s %s" % [v.x, v.y, v.z]) if v is Vector3 else SignalNode.format(v).trim_prefix("\"").trim_suffix("\"")
		edit.placeholder_text = "valor"
		edit.text_changed.connect(func(t: String) -> void: fpga.set_const(id, t))
	else:
		edit.text = str(g["name"])
		edit.placeholder_text = "nome"
		edit.max_length = 16
		edit.text_submitted.connect(func(t: String) -> void: _rename(id, t))
		edit.focus_exited.connect(func() -> void: _rename(id, edit.text))
	row.add_child(edit)
	var opt := OptionButton.new()
	var types: Array = ["n", "v", "s"] if mode == FpgaNode.PIN_CONST else TYPE_LIST
	for t: String in types:
		opt.add_item(SignalNode.TYPE_NAMES[t])
		opt.set_item_metadata(opt.item_count - 1, t)
		if t == g["type"]:
			opt.select(opt.item_count - 1)
	opt.item_selected.connect(func(i: int) -> void:
		var nm: String = str(fpga.gates[id].get("name", ""))
		fpga.set_pin(id, nm, str(opt.get_item_metadata(i)))
		_rebuild_graph())
	row.add_child(opt)


func _rename(id: int, t: String) -> void:
	if fpga == null or not fpga.gates.has(id):
		return
	var before := str(fpga.gates[id]["name"])
	fpga.set_pin(id, t, str(fpga.gates[id]["type"]))
	if str(fpga.gates[id]["name"]) != t.strip_edges() or before != t.strip_edges():
		_rebuild_graph()


func _tint(gn: GraphNode, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	gn.add_theme_stylebox_override("titlebar", sb)
	var sel := sb.duplicate() as StyleBoxFlat
	sel.bg_color = c.lightened(0.25)
	gn.add_theme_stylebox_override("titlebar_selected", sel)


func _id_of(node_name: StringName) -> int:
	return str(node_name).trim_prefix("g").to_int()


func _on_connect(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var f := _id_of(from_node)
	var t := _id_of(to_node)
	var outs := fpga.gate_outs(f)
	var ins := fpga.gate_ins(t)
	if from_port >= outs.size() or to_port >= ins.size():
		return
	if fpga.connect_gates(f, str(outs[from_port][0]), t, str(ins[to_port][0])):
		graph.connect_node(from_node, from_port, to_node, to_port)
	else:
		_status.text = "Tipos diferentes: %s não liga em %s." % [SignalNode.TYPE_NAMES[outs[from_port][1]], SignalNode.TYPE_NAMES[ins[to_port][1]]]


func _on_disconnect(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var f := _id_of(from_node)
	var t := _id_of(to_node)
	var outs := fpga.gate_outs(f)
	var ins := fpga.gate_ins(t)
	if from_port < outs.size() and to_port < ins.size():
		fpga.disconnect_gates(f, str(outs[from_port][0]), t, str(ins[to_port][0]))
	graph.disconnect_node(from_node, from_port, to_node, to_port)


func _on_delete(nodes: Array[StringName]) -> void:
	for nm in nodes:
		var gn := graph.get_node_or_null(NodePath(nm))
		fpga.remove_gate(_id_of(nm))
		_live.erase(_id_of(nm))
		if gn:
			for c: Dictionary in graph.get_connection_list():
				if c["from_node"] == nm or c["to_node"] == nm:
					graph.disconnect_node(c["from_node"], c["from_port"], c["to_node"], c["to_port"])
			graph.remove_child(gn)
			gn.queue_free()


func _on_moved() -> void:
	for c in graph.get_children():
		if c is GraphNode and (c as GraphNode).has_meta("id"):
			var id: int = c.get_meta("id")
			if fpga.gates.has(id) and fpga.gates[id]["pos"] != (c as GraphNode).position_offset:
				fpga.move_gate(id, (c as GraphNode).position_offset)


# --- Circuitos salvos ---------------------------------------------------------------------

func _refresh_circuits() -> void:
	_circ_list.clear()
	var names := FpgaNode.list_circuits()
	if names.is_empty():
		_circ_list.add_item("(nenhum salvo)")
		_circ_list.disabled = true
		return
	_circ_list.disabled = false
	for n in names:
		_circ_list.add_item(n)


func _save_circuit() -> void:
	var n := _circ_name.text.strip_edges()
	if n == "":
		n = fpga.node_name if fpga.node_name != "" else "circuito"
	var used := fpga.save_circuit(n)
	_status.text = ("Circuito salvo: %s" % used) if used != "" else "Não deu para salvar."
	_refresh_circuits()


func _load_circuit() -> void:
	if _circ_list.disabled or _circ_list.selected < 0:
		return
	var n := _circ_list.get_item_text(_circ_list.selected)
	if fpga.load_circuit(n):
		_circ_name.text = n
		_status.text = "Circuito carregado: %s" % n
		_rebuild_graph()


func _delete_circuit() -> void:
	if _circ_list.disabled or _circ_list.selected < 0:
		return
	var n := _circ_list.get_item_text(_circ_list.selected)
	FpgaNode.delete_circuit(n)
	_status.text = "Circuito apagado: %s" % n
	_refresh_circuits()


func _clear_all() -> void:
	fpga.reset_default()
	_rebuild_graph()
	_status.text = "Circuito limpo."


# --- Utilidades -----------------------------------------------------------------------------

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b

class_name WireTool
extends GameTool
## Fiação: liga a SAÍDA de uma peça à ENTRADA de outra (estilo Wiremod).
##
## 1) Clique numa peça com saídas (controle, chip, componente, sensor, assento...).
##    Se ela tiver mais de uma saída, escolha qual no menu.
## 2) (Opcional) Clique nas superfícies por onde o fio deve passar: cada clique cria um
##    isolador ali (ou usa um isolador que já existe). Clicar no último desfaz.
## 3) Clique na peça de destino e escolha a entrada (só aparecem as do mesmo tipo).
## Escolher de novo a mesma ligação desliga o fio.
## G: troca para FIO DE ENERGIA (vermelho, mais grosso): clique numa peça de energia
## (bateria, painel, posto, luz, relé, chave, medidor), nos isoladores e na outra peça.
## Tudo o que está ligado pelos fios de energia forma uma rede e divide a mesma carga.
## Botão direito: cancela o fio em andamento; ou, mirando:
##   isolador → remove · alavanca variável → troca a faixa (-1 a 1 / só positivo)
##   componente, chip, tela... → abre os ajustes

var _src: SignalNode = null
var marking: GadgetNode = null   ## marcando peças para um marcador (Marco 4E)
var power_mode := false          ## G: fio de energia em vez de lógica
var _psrc: PowerNode = null      ## fio de energia em andamento
## Pontas do fio: [peça, ponto local] de onde o jogador clicou (o fio fica preso ali).
var _src_pin: Array = []
var _pending_src_pin: Array = []
var _pending_dst_pin: Array = []
var _src_port := ""
var _via: Array[Part] = []
var _preview: MeshInstance3D
var _imesh: ImmediateMesh
var _line_mat: StandardMaterial3D


func _init(p_player: Player) -> void:
	super(p_player)
	tool_name = "Fiação"
	key_hint = "4"


func _ready() -> void:
	super()
	_imesh = ImmediateMesh.new()
	_preview = MeshInstance3D.new()
	_preview.mesh = _imesh
	_preview.top_level = true
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview)
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.albedo_color = Color(1.0, 0.8, 0.2)
	_line_mat.no_depth_test = true


func _build_viewmodel() -> void:
	var grip := make_box(Vector3(0.06, 0.16, 0.06), Color(0.15, 0.15, 0.16), 0.1, 0.8)
	grip.rotation.x = deg_to_rad(-20)
	viewmodel.add_child(grip)
	var spool := make_cylinder(0.08, 0.07, Color(0.9, 0.45, 0.1), 0.2, 0.6)
	spool.rotation.z = deg_to_rad(90)
	spool.position = Vector3(0, 0.08, -0.06)
	viewmodel.add_child(spool)
	var tip := make_cylinder(0.008, 0.16, Color(0.75, 0.5, 0.25), 0.9, 0.3)
	tip.rotation.x = deg_to_rad(90)
	tip.position = Vector3(0, 0.08, -0.17)
	viewmodel.add_child(tip)
	muzzle.position = Vector3(0, 0.08, -0.25)


func unequip() -> void:
	_cancel()
	marking = null
	_imesh.clear_surfaces()
	super()


func _cancel() -> void:
	_src = null
	_src_port = ""
	_psrc = null
	_src_pin = []
	_pending_src_pin = []
	_pending_dst_pin = []
	_via.clear()


## Tem ajustes que abrem no botão direito?
static func has_config(n: SignalNode) -> bool:
	if n is MechJoint:
		return (n as MechJoint).is_configurable()
	if n is PowerNode:
		return (n as PowerNode).kind in ["luz", "holofote", "bateria"]
	if n is SensorNode:
		return (n as SensorNode).kind in ["ranger", "localizador", "sensor_loc", "buscador", "zona"]
	if n is DriveNode:
		return true
	return n is ChipNode or n is ConstNode or n is KeysNode or n is KeypadNode or n is DisplayNode \
		or n is FpgaNode or n is MemoryNode or n is RadioNode or n is ScreenNode or n is GadgetNode or n is ActuatorNode


## Começa a marcar peças para um marcador (vem dos ajustes dele).
func start_marking(g: GadgetNode) -> void:
	_cancel()
	power_mode = false
	marking = g
	player.toast("Marcando peças: clique numa peça para marcar ou desmarcar · botão direito termina")


func _marking_input(event: InputEvent) -> bool:
	if marking == null or not marking.is_alive():
		marking = null
		return false
	if event.is_action_pressed("secondary"):
		player.toast("%s: %d peça%s marcada%s" % [marking.title(), marking.marked.size(), "" if marking.marked.size() == 1 else "s", "" if marking.marked.size() == 1 else "s"])
		marking = null
		return true
	if event.is_action_pressed("primary"):
		var part := player.aim_part()
		if part == null:
			return true
		if part == marking.part:
			player.toast("Esse é o próprio marcador")
			return true
		var now := marking.toggle_mark(part)
		player.toast("%s %s (%d)" % ["Marcada:" if now else "Desmarcada:", part.display_name(), marking.marked.size()])
		spawn_sparks(player.aim["position"], player.aim["normal"], 6, Color(0.8, 0.45, 1.0))
		return true
	return false


func handle_input(event: InputEvent) -> bool:
	if marking != null and _marking_input(event):
		return true
	if event.is_action_pressed("toggle_grid"):     # G
		power_mode = not power_mode
		_cancel()
		player.toast("Fiação: %s" % ("FIO DE ENERGIA (liga baterias, painéis, luzes, relés...)" if power_mode else "fio de lógica (saída → entrada)"))
		return true
	if power_mode and event.is_action_pressed("primary"):
		_power_click()
		return true
	if event.is_action_pressed("secondary"):
		var aimed := player.aim_part()
		var an := Signals.node_of(aimed)
		if _src or _psrc:
			_cancel()
			player.toast("Fio cancelado")
		elif aimed and aimed.kind == "isolador":
			var pos := aimed.global_position
			Build.delete_part(aimed)
			spawn_sparks(pos, Vector3.UP, 10, Color(1.0, 0.85, 0.3))
			player.toast("Isolador removido")
		elif aimed and aimed.device and aimed.device.kind == "potenciometro":
			aimed.device.toggle_range()
			player.toast("Alavanca variável: %s" % ("só positivo (0 a 1)" if aimed.device.positive_only else "de -1 a 1"))
		elif an is MechJoint and (an as MechJoint).is_configurable():
			player.config_requested.emit(an)
		elif an and has_config(an):
			player.node_config_requested.emit(an)
		return true
	if not event.is_action_pressed("primary"):
		return false
	if player.aim.is_empty():
		return true
	var part := player.aim_part()
	if part == null:
		_place_insulator(null)
		return true
	var n := Signals.node_of(part)
	if part.kind == "isolador":
		if _src == null:
			player.toast("Primeiro clique numa peça com saída (controle, chip, componente...)")
		elif not _via.is_empty() and _via.back() == part:
			_via.pop_back()
			player.toast("Isolador removido do caminho")
		elif _via.has(part):
			player.toast("O fio já passa por este isolador")
		else:
			_via.append(part)
			player.toast("Fio passando pelo isolador %d" % _via.size())
		return true
	if _src == null or n == _src:
		if n == null:
			_place_insulator(part)       # sem fio em andamento: só coloca o isolador
		elif n.outputs().is_empty():
			player.toast("%s não tem saídas de sinal" % n.title())
		else:
			_pending_src_pin = aim_pin(player)
			_pick_output(n)
		return true
	if n and not _compatible_inputs(n).is_empty():
		_pending_dst_pin = aim_pin(player)
		_pick_input(n)
		return true
	if n and not n.inputs().is_empty():
		player.toast("%s não tem entrada de %s" % [n.title(), SignalNode.TYPE_NAMES.get(_src_type(), "?")])
		return true
	_place_insulator(part)
	return true


func _src_type() -> String:
	return _src.port_type(_src_port, true) if _src else ""


func _compatible_inputs(n: SignalNode) -> Array:
	var t := _src_type()
	return n.inputs().filter(func(p: Array) -> bool: return p[1] == t)


## Escolhe a saída de `n` no menu (mesmo que só tenha uma: assim dá para ver o que é).
func _pick_output(n: SignalNode) -> void:
	var outs := n.outputs()
	var items: Array = []
	for p: Array in outs:
		items.append({"text": "%s  (%s) = %s" % [p[0], SignalNode.TYPE_NAMES[p[1]], SignalNode.format(n.out.get(p[0], SignalNode.zero(p[1])))],
			"color": SignalNode.TYPE_COLORS[p[1]]})
	player.port_menu_requested.emit("%s · qual saída?" % n.title(), items, func(i: int) -> void:
		if i >= 0 and i < outs.size():
			_start(n, outs[i][0]))


func _start(n: SignalNode, port: String) -> void:
	_src = n
	_src_port = port
	_src_pin = _pending_src_pin
	_via.clear()
	player.toast("%s · %s: clique nos isoladores (opcional) e depois no destino" % [n.title(), port])


## Escolhe a entrada de `n` do mesmo tipo da saída escolhida, no menu (mesmo que só tenha uma).
func _pick_input(n: SignalNode) -> void:
	var ins := _compatible_inputs(n)
	var items: Array = []
	for p: Array in ins:
		var linked := Signals.is_linked(_src, _src_port, n, p[0])
		items.append({"text": "%s  (%s)%s" % [p[0], SignalNode.TYPE_NAMES[p[1]], "   — ligado: escolha para desligar" if linked else ""],
			"color": SignalNode.TYPE_COLORS[p[1]]})
	player.port_menu_requested.emit("%s · ligar em qual entrada?" % n.title(), items, func(i: int) -> void:
		if i >= 0 and i < ins.size():
			_link(n, ins[i][0]))


func _link(n: SignalNode, port: String) -> void:
	if _src == null or not _src.is_alive():
		_cancel()
		return
	var linked := Signals.toggle(_src, _src_port, n, port, _via, _src_pin, _pending_dst_pin)
	player.toast(("Fio: %s · %s → %s · %s" % [_src.title(), _src_port, n.title(), port]) if linked else "Fio removido")
	if not player.aim.is_empty():
		spawn_sparks(player.aim["position"], player.aim["normal"], 12, Color(1.0, 0.85, 0.3))
	_cancel()


## Cria um isolador na superfície mirada (peça ou chão). Com um fio em andamento,
## o fio passa a ir por ele.
func _place_insulator(on: Part) -> void:
	if on == null and not Build.is_ground(player.aim["collider"]):
		return
	var point: Vector3 = player.aim["position"]
	var ins := Build.place_insulator(on, point, player.aim["normal"])
	if ins == null:
		player.toast("Já tem um isolador aqui")
		return
	spawn_sparks(point, player.aim["normal"], 10, Color(1.0, 0.85, 0.3))
	if _src or _psrc:
		_via.append(ins)
		player.toast("Isolador %d no caminho do fio" % _via.size())
	else:
		player.toast("Isolador colocado: comece um fio numa peça com saída para passar por ele")


## Modo energia: clique.
func _power_click() -> void:
	if player.aim.is_empty():
		return
	var part := player.aim_part()
	if part == null:
		_place_insulator(null)
		return
	if part.kind == "isolador":
		if _psrc == null:
			player.toast("Primeiro clique numa peça de energia (bateria, painel, luz, relé...)")
		elif not _via.is_empty() and _via.back() == part:
			_via.pop_back()
			player.toast("Isolador removido do caminho")
		elif _via.has(part):
			player.toast("O fio já passa por este isolador")
		else:
			_via.append(part)
			player.toast("Fio passando pelo isolador %d" % _via.size())
		return
	var pn := Power.node_of(part)
	if pn == null:
		if _psrc:
			_place_insulator(part)
		else:
			player.toast("Fios de energia vão em peças de energia: bateria, painel solar, posto, luz, holofote, relé, chave, medidor")
		return
	if _psrc == null or pn == _psrc:
		_psrc = pn
		_src_pin = aim_pin(player)
		_via.clear()
		player.toast("Fio de energia de %s: clique nos isoladores (opcional) e na outra peça" % pn.title())
		return
	var linked := Power.toggle(_psrc, pn, _via, _src_pin, aim_pin(player))
	player.toast(("Fio de energia: %s ↔ %s" % [_psrc.title(), pn.title()]) if linked else "Fio de energia removido")
	spawn_sparks(player.aim["position"], player.aim["normal"], 12, Color(1.0, 0.45, 0.15))
	_cancel()


func physics_update(_delta: float) -> void:
	_imesh.clear_surfaces()
	if marking != null and marking.is_alive():
		_line_mat.albedo_color = Color(0.8, 0.45, 1.0)
		var from := marking.part.global_position
		var any := false
		for p in marking.marked:
			if is_instance_valid(p) and (p as Part).is_inside_tree():
				if not any:
					_imesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
					any = true
				_imesh.surface_add_vertex(from)
				_imesh.surface_add_vertex((p as Part).global_position)
		if any:
			_imesh.surface_end()
		return
	if _psrc != null:
		if not _psrc.is_alive():
			_cancel()
			return
		_draw_preview(_src_start(_psrc.signal_part()), WireRenderer.POWER_ON)
		return
	if _src == null or not _src.is_alive():
		_cancel()
		return
	_draw_preview(_src_start(_src.signal_part()), SignalNode.TYPE_COLORS.get(_src_type(), Color(1.0, 0.8, 0.2)))


func _src_start(fallback: Part) -> Vector3:
	return Signals.end_point(_src_pin[0] if _src_pin.size() == 2 else null, _src_pin[1] if _src_pin.size() == 2 else Vector3.ZERO, fallback)


## Ponto mirado, um pouco para fora da superfície (o fio encosta nele): [peça, ponto local].
static func aim_pin(p: Player) -> Array:
	var part := p.aim_part()
	if part == null or p.aim.is_empty():
		return []
	var world: Vector3 = (p.aim["position"] as Vector3) + (p.aim["normal"] as Vector3) * 0.008
	return [part, part.global_transform.affine_inverse() * world]


func _draw_preview(start: Vector3, color: Color) -> void:
	var pts: Array[Vector3] = [start]
	for ins in _via:
		if is_instance_valid(ins):
			pts.append(Components.wire_anchor(ins))
	pts.append(player.aim["position"] if not player.aim.is_empty() else player.eye_position() + player.aim_direction() * 3.0)
	_line_mat.albedo_color = color
	_imesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
	for i in pts.size() - 1:
		_imesh.surface_add_vertex(pts[i])
		_imesh.surface_add_vertex(pts[i + 1])
	_imesh.surface_end()


func hint_text() -> String:
	var part := player.aim_part()
	if marking != null and marking.is_alive():
		var tag := ""
		if part and part != marking.part:
			tag = "Clique: %s %s   ·   " % ["desmarcar" if marking.marked.has(part) else "marcar", part.display_name()]
		return "MARCANDO para %s (%d)   ·   %sBotão direito: terminar" % [marking.title(), marking.marked.size(), tag]
	if power_mode:
		var pn := Power.node_of(part)
		if _psrc:
			if pn and pn != _psrc:
				var linked := Power.find_wire(_psrc, pn) != null
				return "Clique: %s o fio de energia %s ↔ %s   ·   Botão direito: cancelar" % ["remover" if linked else "ligar", _psrc.title(), pn.title()]
			return "Fio de energia de %s: clique na outra peça ou na estrutura para um isolador (%d)   ·   Botão direito: cancelar" % [_psrc.title(), _via.size()]
		if pn:
			var net := Power.network_of(pn)
			var nw := Power.wires_of(pn).size()
			return "%s (%d fio%s de energia, rede com %d peça%s)   ·   Clique: começar um fio de energia   ·   G: fio de lógica" % [pn.title(),
				nw, "" if nw == 1 else "s", net.size(), "" if net.size() == 1 else "s"]
		return "FIO DE ENERGIA: clique numa bateria, painel, posto, luz, relé, chave ou medidor   ·   G: fio de lógica"
	var n := Signals.node_of(part)
	if _src:
		if n and n != _src and not _compatible_inputs(n).is_empty():
			return "Clique: ligar %s · %s em %s   ·   Botão direito: cancelar" % [_src.title(), _src_port, n.title()]
		if part and part.kind == "isolador":
			return "Clique: passar o fio por este isolador"
		return "Fio de %s · %s: clique no destino ou na estrutura para um isolador (%d)   ·   Botão direito: cancelar" % [_src.title(), _src_port, _via.size()]
	if part and part.kind == "isolador":
		return "Botão direito: remover este isolador   ·   Clique numa peça com saída para começar um fio"
	if part and part.device and part.device.kind == "potenciometro":
		return "Clique: começar um fio   ·   Botão direito: faixa %s" % ("0 a 1 → -1 a 1" if part.device.positive_only else "-1 a 1 → só positivo")
	if n:
		var ins := Signals.wires_into(n).size()
		var outs := Signals.wires_from(n).size()
		var parts: Array[String] = ["%s (%d fio%s chegando, %d saindo)" % [n.title(), ins, "" if ins == 1 else "s", outs]]
		if not n.outputs().is_empty():
			parts.append("Clique: começar um fio")
		if has_config(n):
			parts.append("Botão direito: ajustes")
		return "   ·   ".join(parts)
	return "Clique numa peça com saída para começar um fio   ·   Clique numa superfície: isolador   ·   G: fio de energia"

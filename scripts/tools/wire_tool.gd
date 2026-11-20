class_name WireTool
extends GameTool
## Fiação: liga botões, alavancas e alavancas variáveis aos componentes.
##
## 1) Clique num controle (botão / alavanca / alavanca variável).
## 2) (Opcional) Clique nas superfícies por onde o fio deve passar: cada clique cria
##    um isolador ali (ou usa um isolador que já existe). Clicar no último desfaz.
## 3) Clique no componente que ele vai controlar (motor, servo, pistão).
## Clicar de novo no mesmo par desliga o fio.
## Botão direito: cancela o fio em andamento, ou remove o isolador mirado.

var _source: ControlDevice = null
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
	_imesh.clear_surfaces()
	super()


func _cancel() -> void:
	_source = null
	_via.clear()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("secondary"):
		var aimed := player.aim_part()
		if _source:
			_cancel()
			player.toast("Fio cancelado")
		elif aimed and aimed.kind == "isolador":
			var pos := aimed.global_position
			Build.delete_part(aimed)
			spawn_sparks(pos, Vector3.UP, 10, Color(1.0, 0.85, 0.3))
			player.toast("Isolador removido")
		return true
	if not event.is_action_pressed("primary"):
		return false
	if player.aim.is_empty():
		return true
	var part := player.aim_part()
	if part == null:
		_place_insulator(null)
		return true
	if part.device:
		_source = part.device
		_via.clear()
		player.toast("%s selecionado: clique nos isoladores (opcional) e depois no componente" % _source.display_name())
		return true
	if part.kind == "isolador":
		if _source == null:
			player.toast("Primeiro clique num botão, alavanca ou alavanca variável")
		elif not _via.is_empty() and _via.back() == part:
			_via.pop_back()
			player.toast("Isolador removido do caminho")
		elif _via.has(part):
			player.toast("O fio já passa por este isolador")
		else:
			_via.append(part)
			player.toast("Fio passando pelo isolador %d" % _via.size())
		return true
	if part.mech and part.mech.is_actuator():
		if _source == null:
			player.toast("Primeiro clique num botão, alavanca ou alavanca variável")
			return true
		if not is_instance_valid(_source.part):
			_cancel()
			return true
		var linked := Build.toggle_link(_source, part.mech, _via)
		player.toast(("%s ligado ao %s" % [_source.display_name(), part.mech.display_name()]) if linked else "Fio removido")
		spawn_sparks(player.aim["position"], player.aim["normal"], 12, Color(1.0, 0.85, 0.3))
		_cancel()
		return true
	if part.mech and part.mech.type == "dobradica" and _source == null:
		player.toast("A dobradiça é livre: não tem o que controlar")
		return true
	_place_insulator(part)
	return true


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
	if _source:
		_via.append(ins)
		player.toast("Isolador %d no caminho do fio" % _via.size())
	else:
		player.toast("Isolador colocado: comece um fio num controle para passar por ele")


func physics_update(_delta: float) -> void:
	_imesh.clear_surfaces()
	if _source == null or not is_instance_valid(_source.part):
		_cancel()
		return
	var pts: Array[Vector3] = [_source.part.global_position]
	for ins in _via:
		if is_instance_valid(ins):
			pts.append(Components.wire_anchor(ins))
	pts.append(player.aim["position"] if not player.aim.is_empty() else player.eye_position() + player.aim_direction() * 3.0)
	_imesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
	for i in pts.size() - 1:
		_imesh.surface_add_vertex(pts[i])
		_imesh.surface_add_vertex(pts[i + 1])
	_imesh.surface_end()


func hint_text() -> String:
	var part := player.aim_part()
	if _source:
		if part and part.mech and part.mech.is_actuator():
			var linked := part.mech.sources.has(_source)
			return "Clique: %s o fio até este %s   ·   Botão direito: cancelar" % ["remover" if linked else "ligar", part.mech.display_name()]
		if part and part.kind == "isolador":
			return "Clique: passar o fio por este isolador"
		return "Clique na estrutura para criar um isolador no caminho (%d) ou no componente para terminar   ·   Botão direito: cancelar" % _via.size()
	if part and part.device:
		return "Clique: começar um fio a partir deste controle"
	if part and part.mech and part.mech.is_actuator():
		var n := part.mech.sources.size()
		return "%s com %d controle%s ligado%s · clique primeiro num botão ou alavanca" % [part.mech.display_name(), n, "" if n == 1 else "s", "" if n == 1 else "s"]
	if part and part.kind == "isolador":
		return "Botão direito: remover este isolador   ·   Clique num controle para começar um fio"
	return "Clique num controle para começar um fio   ·   Clique numa superfície: isolador"

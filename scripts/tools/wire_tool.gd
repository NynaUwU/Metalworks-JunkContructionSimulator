class_name WireTool
extends GameTool
## Fiação: liga botões, alavancas e alavancas variáveis aos componentes.
##
## 1) Clique num controle (botão / alavanca / alavanca variável).
## 2) Clique no componente que ele vai controlar (motor, servo, pistão).
## Clicar de novo no mesmo par desliga o fio. Botão direito: cancela.

var _source: ControlDevice = null
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
	_source = null
	_imesh.clear_surfaces()
	super()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("secondary"):
		if _source:
			_source = null
			player.toast("Fio cancelado")
		return true
	if not event.is_action_pressed("primary"):
		return false
	var part := player.aim_part()
	if part == null:
		return true
	if part.device:
		_source = part.device
		player.toast("%s selecionado: agora clique no motor, servo ou pistão" % _source.display_name())
		return true
	if part.mech and part.mech.is_actuator():
		if _source == null:
			player.toast("Primeiro clique num botão, alavanca ou alavanca variável")
			return true
		if not is_instance_valid(_source.part):
			_source = null
			return true
		var linked := Build.toggle_link(_source, part.mech)
		player.toast("%s ligado ao %s" % [_source.display_name(), part.mech.display_name()] if linked
			else "Fio removido")
		spawn_sparks(player.aim["position"], player.aim["normal"], 12, Color(1.0, 0.85, 0.3))
		_source = null
		return true
	if part.mech:
		player.toast("A dobradiça é livre: não tem o que controlar")
	return true


func physics_update(_delta: float) -> void:
	_imesh.clear_surfaces()
	if _source == null or not is_instance_valid(_source.part):
		_source = null
		return
	var a := _source.part.global_position
	var b: Vector3 = player.aim["position"] if not player.aim.is_empty() else player.eye_position() + player.aim_direction() * 3.0
	_imesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
	_imesh.surface_add_vertex(a)
	_imesh.surface_add_vertex(b)
	_imesh.surface_end()


func hint_text() -> String:
	var part := player.aim_part()
	if _source:
		if part and part.mech and part.mech.is_actuator():
			var linked := part.mech.sources.has(_source)
			return "Clique: %s o fio até este %s   ·   Botão direito: cancelar" % ["remover" if linked else "ligar", part.mech.display_name()]
		return "Agora clique no motor, servo ou pistão a controlar   ·   Botão direito: cancelar"
	if part and part.device:
		return "Clique: começar um fio a partir deste controle"
	if part and part.mech and part.mech.is_actuator():
		var n := part.mech.sources.size()
		return "%s com %d controle%s ligado%s · clique primeiro num botão ou alavanca" % [part.mech.display_name(), n, "" if n == 1 else "s", "" if n == 1 else "s"]
	return "Clique num botão, alavanca ou alavanca variável para começar um fio"

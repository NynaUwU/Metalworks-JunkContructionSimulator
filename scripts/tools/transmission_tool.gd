class_name TransmissionTool
extends GameTool
## Transmissão (estilo ACF): liga as peças do trem de força sem nada físico.
##   Clique numa peça e depois na outra: liga (ou desliga, se já estiver ligada).
##   Qualquer peça liga em qualquer outra, em qualquer ordem: a simulação acha o caminho
##   do motor até as rodas (câmbios multiplicam, embreagens soltam) e ignora o resto.
##   Botão direito: cancela; mirando numa peça, desfaz todas as ligações dela.
## As ligações só aparecem com esta ferramenta na mão. Esticadas demais, quebram.

const COLORS := {
	"fuel": Color(1.0, 0.8, 0.15), "engine": Color(1.0, 0.45, 0.1), "hub": Color(0.3, 0.7, 1.0), "gen": Color(0.4, 1.0, 0.5),
}

var _src: Object = null
var _mesh: MeshInstance3D
var _imesh: ImmediateMesh
var _lmat: StandardMaterial3D


func _init(p_player: Player) -> void:
	super(p_player)
	tool_name = "Transmissão"
	key_hint = "9"


func _ready() -> void:
	super()
	_imesh = ImmediateMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _imesh
	_mesh.top_level = true
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lmat = StandardMaterial3D.new()
	_lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lmat.vertex_color_use_as_albedo = true
	_lmat.no_depth_test = true
	_mesh.material_override = _lmat
	add_child(_mesh)


func _build_viewmodel() -> void:
	var body := make_box(Vector3(0.07, 0.1, 0.18), Color(0.3, 0.32, 0.35), 0.6, 0.5)
	viewmodel.add_child(body)
	var gear := make_cylinder(0.06, 0.03, Color(1.0, 0.6, 0.15), 0.5, 0.5)
	gear.rotation.z = deg_to_rad(90)
	gear.position = Vector3(0, 0.06, -0.06)
	viewmodel.add_child(gear)
	muzzle.position = Vector3(0, 0.06, -0.12)


func unequip() -> void:
	_src = null
	_imesh.clear_surfaces()
	super()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("secondary"):
		var o := Drive.node_of(player.aim_part())
		if _src:
			_src = null
			player.toast("Ligação cancelada")
		elif o:
			var ls := Drive.links_of(o)
			for l in ls:
				Drive.links.erase(l)
			player.toast("%d ligaç%s de %s removida%s" % [ls.size(), "ão" if ls.size() == 1 else "ões", Drive.describe(o), "" if ls.size() == 1 else "s"])
		return true
	if not event.is_action_pressed("primary"):
		return false
	var o := Drive.node_of(player.aim_part())
	if o == null:
		player.toast("A Transmissão liga tanques, baterias, motores, embreagens, câmbios, geradores e cubos de roda")
		return true
	if _src == null or _src == o:
		_src = o
		player.toast("%s: agora clique na outra peça" % Drive.describe(o))
		return true
	var r := Drive.toggle(_src, o)
	player.toast(r["msg"])
	if r["linked"] and not player.aim.is_empty():
		spawn_sparks(player.aim["position"], player.aim["normal"], 10, Color(1.0, 0.6, 0.15))
	_src = null
	return true


static func _kind_of(l) -> String:
	for o: Object in [l.a, l.b]:
		if o is DriveNode and (o as DriveNode).is_tank() or o is PowerNode and (o as PowerNode).kind == "bateria":
			return "fuel"
	for o: Object in [l.a, l.b]:
		if o is PowerNode:
			return "gen"
	for o: Object in [l.a, l.b]:
		if o is MechJoint:
			return "hub"
	return "engine"


func physics_update(_delta: float) -> void:
	_imesh.clear_surfaces()
	var any := false
	for l in Drive.links:
		if not Drive.alive(l.a) or not Drive.alive(l.b):
			continue
		if not any:
			_imesh.surface_begin(Mesh.PRIMITIVE_LINES)
			any = true
		var c: Color = COLORS[_kind_of(l)]
		var a := Drive.part_of(l.a).global_position
		var b := Drive.part_of(l.b).global_position
		_line(a, b, c)                                 # sem seta: a ligação não tem sentido
	if _src and Drive.alive(_src):
		if not any:
			_imesh.surface_begin(Mesh.PRIMITIVE_LINES)
			any = true
		var to: Vector3 = player.aim["position"] if not player.aim.is_empty() else player.eye_position() + player.aim_direction() * 3.0
		_line(Drive.part_of(_src).global_position, to, Color(1, 1, 1))
	elif _src:
		_src = null
	if any:
		_imesh.surface_end()


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_imesh.surface_set_color(c)
	_imesh.surface_add_vertex(a)
	_imesh.surface_set_color(c)
	_imesh.surface_add_vertex(b)


func hint_text() -> String:
	var o := Drive.node_of(player.aim_part())
	if _src:
		if o and o != _src:
			if Drive.find_link(_src, o):
				return "Clique: desfazer a ligação %s ↔ %s   ·   Botão direito: cancelar" % [Drive.describe(_src), Drive.describe(o)]
			return "Clique: ligar %s → %s  %s" % [Drive.describe(_src), Drive.describe(o), Drive.link_meaning(_src, o)]
		return "Ligando %s: clique na outra peça   ·   Botão direito: cancelar" % Drive.describe(_src)
	if o:
		return "%s (%d ligaç%s)   ·   Clique: começar a ligar   ·   Botão direito: desfazer as ligações dela" % [Drive.describe(o),
			Drive.links_of(o).size(), "ão" if Drive.links_of(o).size() == 1 else "ões"]
	return "Clique num tanque, bateria, motor, embreagem, câmbio, gerador ou cubo de roda (qualquer um em qualquer um)   ·   amarelo: combustível · laranja: motor/câmbio · azul: rodas · verde: gerador"

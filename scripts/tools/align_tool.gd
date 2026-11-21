class_name AlignTool
extends GameTool
## Alinhador (estilo "Precision Alignment" do Garry's Mod).
##   1º clique: ponto na peça que vai se MOVER (grade de 5 cm da peça, ou uma marca)
##   2º clique: ponto de destino em outra peça (ou no chão)
## A peça vai até lá: os dois pontos se encontram, as faces ficam encostadas (viradas uma
## para a outra) e o giro fica em esquadro com a outra peça. Com Shift no 2º clique, ela
## só se move (não gira). Depois de alinhada ela fica congelada, pronta para soldar
## (R com o Gravitador solta). Botão direito cancela.
## Depois do 1º clique, uma prévia transparente mostra onde a peça vai ficar.

var grid_on := true
var _a := {}
var _cursor: MeshInstance3D
var _dot_a: MeshInstance3D
var _ghost: Node3D                 ## prévia: um nó por montagem que vai se mover
var _ghost_of: Array = []          ## montagens na ordem dos filhos de _ghost
static var _ghost_mat: StandardMaterial3D


func _init(p_player: Player) -> void:
	super(p_player)
	tool_name = "Alinhador"
	key_hint = "7"


func _ready() -> void:
	super()
	_cursor = _make_dot(Color(0.4, 0.85, 1.0))
	_dot_a = _make_dot(Color(0.2, 1.0, 0.4))


func _make_dot(c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.014
	sm.height = 0.028
	mi.mesh = sm
	mi.material_override = glow_material(c, 2.0)
	mi.top_level = true
	mi.visible = false
	add_child(mi)
	return mi


func _build_viewmodel() -> void:
	var body := make_box(Vector3(0.08, 0.08, 0.22), Color(0.2, 0.45, 0.85), 0.4, 0.4)
	viewmodel.add_child(body)
	var tip := make_cylinder(0.012, 0.08, Color(0.85, 0.85, 0.9), 0.8, 0.3)
	tip.rotation.x = deg_to_rad(90)
	tip.position = Vector3(0, 0, -0.15)
	viewmodel.add_child(tip)
	muzzle.position = Vector3(0, 0, -0.19)


func unequip() -> void:
	_a = {}
	_cursor.visible = false
	_dot_a.visible = false
	_clear_ghost()
	super()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("toggle_grid"):
		grid_on = not grid_on
		player.toast("Alinhador · grade de 5 cm: %s" % ("ligada" if grid_on else "desligada"))
		return true
	if event.is_action_pressed("secondary"):
		if not _a.is_empty():
			_a = {}
			player.toast("Alinhamento cancelado")
		return true
	if not event.is_action_pressed("primary"):
		return false
	var s := Snap.aimed(player, grid_on)
	if s.is_empty():
		return true
	if _a.is_empty():
		var part: Part = s["part"]
		if part == null:
			player.toast("Comece num ponto da peça que vai se mover")
		elif part.assembly().anchored:
			player.toast("Esta peça está soldada no chão (ancorada): não dá para mover")
		else:
			_a = s
			player.toast("Ponto de origem marcado: agora clique no ponto de destino (Shift: só mover)")
		return true
	var ap: Part = _a["part"]
	if not is_instance_valid(ap) or not ap.is_inside_tree():
		_a = {}
		return true
	if s["part"] != null and (s["part"] as Part).assembly() == ap.assembly():
		player.toast("O destino precisa ser em outra peça (ou no chão)")
		return true
	var msg := align(_a, s, Input.is_action_pressed("modifier"))
	player.toast(msg)
	if msg.begins_with("Alinhada"):
		spawn_sparks(s["world"], s["world_n"], 14, Color(0.4, 0.85, 1.0))
		_a = {}
	return true


## Move a peça de `a` (e o que está preso a ela por juntas) para o ponto `b`.
## Retorna a mensagem para o jogador.
static func align(a: Dictionary, b: Dictionary, only_move := false) -> String:
	var pl := plan(a, b, only_move)
	if not pl["ok"]:
		return pl["msg"]
	var delta: Transform3D = pl["delta"]
	for asm_i: Assembly in pl["list"]:
		asm_i.global_transform = delta * asm_i.global_transform
		asm_i.linear_velocity = Vector3.ZERO
		asm_i.angular_velocity = Vector3.ZERO
		asm_i.reset_physics_interpolation()
		asm_i.set_frozen(true)
	return "Alinhada%s e congelada: solde, e use R com o Gravitador para soltar" % (" (só movida)" if only_move else "")


## Calcula o alinhamento sem mexer em nada: {ok, msg, delta (transformação a aplicar
## nas montagens), list (montagens que se movem)}.
static func plan(a: Dictionary, b: Dictionary, only_move := false) -> Dictionary:
	var part: Part = a["part"]
	var asm := part.assembly()
	var m := Carrier.machine(asm, true)
	if m["pinned"] or asm.anchored:
		return {"ok": false, "msg": "Ela está presa por junta a algo soldado no chão: solte a solda do chão antes"}
	var gt := part.global_transform
	var pa: Vector3 = gt * (a["local"] as Vector3)
	var na: Vector3 = (gt.basis.orthonormalized() * (a["local_n"] as Vector3)).normalized()
	var target: Vector3 = b["world"]
	var nb: Vector3 = (b["world_n"] as Vector3).normalized()
	var rot := Basis()
	if not only_move:
		# Face contra face: a normal da peça vai para o lado oposto da normal do destino.
		rot = _rotation_between(na, -nb)
		# Giro em volta da normal: em esquadro (90°) com a peça de destino (ou o mundo).
		var t_moving := rot * (gt.basis.orthonormalized() * Snap.tangent(a["local_n"]))
		var ref_basis: Basis = (b["part"] as Part).global_basis.orthonormalized() if b["part"] != null else Basis()
		var t_ref := ref_basis * Snap.tangent(ref_basis.inverse() * nb)
		var ang := t_ref.signed_angle_to(t_moving, nb)
		var snapped_ang := snappedf(ang, PI * 0.5)
		rot = Basis(nb, snapped_ang - ang) * rot
	var delta := Transform3D(rot, target) * Transform3D(Basis(), -pa)
	return {"ok": true, "msg": "", "delta": delta, "list": m["list"]}


static func _rotation_between(from: Vector3, to: Vector3) -> Basis:
	var c := from.cross(to)
	var d := from.dot(to)
	if c.length_squared() < 1e-10:
		if d > 0.0:
			return Basis()
		# Opostos: meia volta em volta de qualquer eixo perpendicular.
		var perp := from.cross(Vector3.UP if absf(from.y) < 0.9 else Vector3.RIGHT).normalized()
		return Basis(perp, PI)
	return Basis(c.normalized(), atan2(c.length(), d))


func _process(_delta: float) -> void:
	if not visible:
		return
	var s := Snap.aimed(player, grid_on)
	_cursor.visible = not s.is_empty()
	if not s.is_empty():
		_cursor.global_position = s["world"] + (s["world_n"] as Vector3) * 0.005
	_dot_a.visible = not _a.is_empty() and is_instance_valid(_a["part"])
	if _dot_a.visible:
		_dot_a.global_position = (_a["part"] as Part).global_transform * (_a["local"] as Vector3)
	_update_ghost(s)


# --- Prévia ------------------------------------------------------------------------

## Mostra a peça (e o que vem junto) transparente na pose em que vai ficar.
func _update_ghost(s: Dictionary) -> void:
	var pl := {}
	if not _a.is_empty() and is_instance_valid(_a["part"]) and (_a["part"] as Part).is_inside_tree() and not s.is_empty() \
			and (s["part"] == null or (s["part"] as Part).assembly() != (_a["part"] as Part).assembly()):
		pl = plan(_a, s, Input.is_action_pressed("modifier"))
	if pl.is_empty() or not pl["ok"]:
		if _ghost:
			_ghost.visible = false
		if _a.is_empty():
			_clear_ghost()
		return
	var list: Array = pl["list"]
	if _ghost == null or _ghost_of != list:
		_build_ghost(list)
	var delta: Transform3D = pl["delta"]
	for i in list.size():
		var asm: Assembly = list[i]
		if is_instance_valid(asm):
			(_ghost.get_child(i) as Node3D).global_transform = delta * asm.global_transform
	_ghost.visible = true


func _build_ghost(list: Array) -> void:
	_clear_ghost()
	if _ghost_mat == null:
		_ghost_mat = BuildPlacer._ghost_material(Color(0.35, 0.85, 1.0, 0.35))
	_ghost = Node3D.new()
	_ghost.top_level = true
	add_child(_ghost)
	_ghost_of = list.duplicate()
	for asm: Assembly in list:
		var holder := Node3D.new()
		holder.top_level = true
		_ghost.add_child(holder)
		var inv := asm.global_transform.affine_inverse()
		for part in asm.get_parts():
			_copy_meshes(part, holder, inv)


## Copia as malhas visíveis da peça (forma + detalhes) para o fantasma.
static func _copy_meshes(node: Node, holder: Node3D, inv: Transform3D) -> void:
	for c in node.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and (c as MeshInstance3D).is_visible_in_tree():
			var mi := MeshInstance3D.new()
			mi.mesh = (c as MeshInstance3D).mesh
			mi.material_override = _ghost_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.transform = inv * (c as MeshInstance3D).global_transform
			holder.add_child(mi)
		if c is Node3D and not c is Part:
			_copy_meshes(c, holder, inv)


func _clear_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
	_ghost = null
	_ghost_of = []


func hint_text() -> String:
	if _a.is_empty():
		return "Clique num ponto da peça que vai se mover   ·   G: grade %s" % ("ligada" if grid_on else "desligada")
	return "Clique no ponto de destino (outra peça ou chão)   ·   Shift + clique: só mover   ·   Botão direito: cancelar"

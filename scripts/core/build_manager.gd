extends Node
## Autoload "Build": regras de construção.
##
## - Soldar junta duas montagens (Assembly) em uma só.
## - Remover solda / cortar peça pode separar uma montagem em várias.
## - Soldar no chão "ancora" a montagem (ela fica parada).

signal message(text: String)
## Uma peça foi substituída por pedaços (corte). pieces[0] = lado negativo do plano.
signal part_replaced(old_part: Part, pieces: Array, cut_plane_local: Plane)
signal part_removed(part: Part)

const WELD_SEARCH_RADII: Array[float] = [0.04, 0.09, 0.15]
const WELD_BALL_RADIUS := 0.055
const MIN_PIECE_VOLUME := 0.0004
const MIN_PIECE_THICKNESS := 0.02

var world_root: Node3D
var welds: Array[Weld] = []

var _ball_mesh: SphereMesh
var _ball_material: StandardMaterial3D


func _ready() -> void:
	_ball_mesh = SphereMesh.new()
	_ball_mesh.radius = WELD_BALL_RADIUS
	_ball_mesh.height = WELD_BALL_RADIUS * 2.0
	_ball_mesh.radial_segments = 12
	_ball_mesh.rings = 6
	_ball_material = StandardMaterial3D.new()
	_ball_material.albedo_color = Color(0.36, 0.34, 0.31)
	_ball_material.metallic = 0.7
	_ball_material.roughness = 0.6


## Chamado pelo mundo ao (re)iniciar.
func reset(root: Node3D) -> void:
	world_root = root
	welds.clear()


# ---------------------------------------------------------------------------
# Criação
# ---------------------------------------------------------------------------

func spawn_box(size: Vector3, material_id: String, xform: Transform3D) -> Part:
	return spawn_planes(ConvexGeo.box_planes(size), material_id, xform)


func spawn_planes(planes: Array[Plane], material_id: String, xform: Transform3D) -> Part:
	var part := Part.new()
	if not part.setup_from_planes(planes, material_id):
		part.free()
		return null
	var asm := _new_assembly(xform)
	asm.add_child(part)
	asm.recompute()
	return part


func _new_assembly(xform: Transform3D) -> Assembly:
	var asm := Assembly.new()
	world_root.add_child(asm)
	asm.global_transform = xform
	return asm


## Descobre qual peça foi atingida por um raycast/consulta de forma.
func part_from_collision(collider: Object, shape_index: int) -> Part:
	if collider is Assembly and shape_index >= 0:
		var asm := collider as Assembly
		var owner_id := asm.shape_find_owner(shape_index)
		var owner := asm.shape_owner_get_owner(owner_id)
		return owner as Part
	return null


func is_ground(collider: Object) -> bool:
	return collider is Node and (collider as Node).is_in_group("ground")


# ---------------------------------------------------------------------------
# Solda
# ---------------------------------------------------------------------------

## Procura algo para soldar perto de `point`. Retorna {"ok", "part", "ground"}.
func find_weld_target(part: Part, point: Vector3) -> Dictionary:
	var space := part.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.collision_mask = Layers.AIM
	params.transform = Transform3D(Basis(), point)
	for r in WELD_SEARCH_RADII:
		sphere.radius = r
		var found_ground := false
		var results := space.intersect_shape(params, 32)
		for res: Dictionary in results:
			var other := part_from_collision(res["collider"], res["shape"])
			if other != null and other != part:
				return {"ok": true, "part": other, "ground": false}
			if other == null and is_ground(res["collider"]):
				found_ground = true
		if found_ground:
			return {"ok": true, "part": null, "ground": true}
	return {"ok": false}


## Tenta soldar `part` no ponto `point` (na superfície dela). Retorna true se soldou.
func weld_at(part: Part, point: Vector3) -> bool:
	var target := find_weld_target(part, point)
	if not target["ok"]:
		message.emit("Nada perto para soldar — encoste outra peça")
		return false
	var other: Part = target["part"]
	for w in welds:
		if w.world_pos().distance_to(point) < 0.07:
			var same_pair := (w.part_a == part and w.part_b == other) or (w.part_a == other and w.part_b == part)
			if same_pair:
				message.emit("Já existe uma solda aqui")
				return false
	var w := Weld.new()
	w.part_a = part
	w.part_b = other
	w.local_pos = part.global_transform.affine_inverse() * point
	w.ball = MeshInstance3D.new()
	w.ball.mesh = _ball_mesh
	w.ball.material_override = _ball_material
	part.add_child(w.ball)
	w.ball.position = w.local_pos
	welds.append(w)
	part.welds.append(w)
	if other:
		other.welds.append(w)

	var asm := part.assembly()
	if other == null:
		asm.set_anchored(true)
		message.emit("Soldado no chão (ancorado)")
	else:
		var merged := _merge(asm, other.assembly())
		message.emit("Soldado" if merged.get_parts().size() <= 2 else "Soldado (%d peças)" % merged.get_parts().size())
	return true


func remove_weld(w: Weld) -> void:
	if not welds.has(w):
		return
	welds.erase(w)
	w.part_a.welds.erase(w)
	if w.part_b:
		w.part_b.welds.erase(w)
	if is_instance_valid(w.ball):
		w.ball.queue_free()
	var asm := w.part_a.assembly()
	if asm:
		refresh_assembly(asm)


## Solda mais próxima de um ponto (para a esmerilhadeira remover).
func nearest_weld(point: Vector3, max_dist: float) -> Weld:
	var best: Weld = null
	var best_d := max_dist
	for w in welds:
		var d := w.world_pos().distance_to(point)
		if d < best_d:
			best_d = d
			best = w
	return best


# ---------------------------------------------------------------------------
# Corte
# ---------------------------------------------------------------------------

## Corta a peça por um plano em coordenadas locais da peça. Retorna os pedaços ou [].
func cut_part(part: Part, cut_local: Plane) -> Array:
	if not part.cuttable:
		message.emit("Esta peça não pode ser cortada")
		return []
	var res := ConvexGeo.split(part.planes, cut_local)
	if res.is_empty():
		message.emit("O corte não passa pela peça")
		return []
	for g: Dictionary in res:
		var thin: float = (g["aabb"] as AABB).size[(g["aabb"] as AABB).get_shortest_axis_index()]
		if g["volume"] < MIN_PIECE_VOLUME or thin < MIN_PIECE_THICKNESS:
			message.emit("Pedaço pequeno demais")
			return []

	var asm := part.assembly()
	var pieces: Array[Part] = []
	for g: Dictionary in res:
		var np := Part.new()
		np.apply_geometry(g, part.material_id)
		asm.add_child(np)
		np.transform = part.transform
		pieces.append(np)

	# As soldas vão para o pedaço do lado em que estão.
	var inv := part.global_transform.affine_inverse()
	for w: Weld in part.welds.duplicate():
		var local := inv * w.world_pos()
		var piece: Part = pieces[0] if cut_local.distance_to(local) <= 0.0 else pieces[1]
		if w.part_a == part:
			w.part_a = piece
			w.ball.reparent(piece, true)
			w.local_pos = local
		else:
			w.part_b = piece
		piece.welds.append(w)
	part.welds.clear()

	asm.remove_child(part)
	part_replaced.emit(part, pieces, cut_local)
	part.queue_free()
	refresh_assembly(asm)
	return pieces


# ---------------------------------------------------------------------------
# Remover peça
# ---------------------------------------------------------------------------

func delete_part(part: Part) -> void:
	for w: Weld in part.welds.duplicate():
		welds.erase(w)
		w.part_a.welds.erase(w)
		if w.part_b:
			w.part_b.welds.erase(w)
		if is_instance_valid(w.ball):
			w.ball.queue_free()
	var asm := part.assembly()
	part_removed.emit(part)
	asm.remove_child(part)
	part.queue_free()
	refresh_assembly(asm)


# ---------------------------------------------------------------------------
# Juntar / separar montagens
# ---------------------------------------------------------------------------

func _merge(a: Assembly, b: Assembly) -> Assembly:
	if a == b:
		return a
	if b.get_parts().size() > a.get_parts().size():
		var t := a
		a = b
		b = t
	var total := a.mass + b.mass
	var v := (a.linear_velocity * a.mass + b.linear_velocity * b.mass) / total
	var w := (a.angular_velocity * a.mass + b.angular_velocity * b.mass) / total
	var anchored := a.anchored or b.anchored
	# Se a montagem que vai sumir estava sendo segurada, a mão reaplica no próximo tick.
	for p in b.get_parts():
		p.reparent(a, true)
	b.clear_hold()
	b.queue_free()
	a.recompute()
	a.set_anchored(anchored)
	if not anchored:
		a.linear_velocity = v
		a.angular_velocity = w
	return a


## Verifica se as peças da montagem ainda estão todas ligadas por soldas.
## Se não estiverem, separa em montagens novas. Também atualiza a ancoragem.
func refresh_assembly(asm: Assembly) -> void:
	var parts := asm.get_parts()
	if parts.is_empty():
		asm.queue_free()
		return

	var groups := _connected_groups(parts)
	groups.sort_custom(func(x: Array, y: Array) -> bool: return x.size() > y.size())

	var old_com := asm.world_center_of_mass()
	var old_v := asm.linear_velocity
	var old_w := asm.angular_velocity
	var was_frozen := asm.freeze

	for gi in range(1, groups.size()):
		var na := _new_assembly(asm.global_transform)
		for p: Part in groups[gi]:
			p.reparent(na, true)
		na.recompute()
		var anchored_g := _group_anchored(groups[gi])
		na.set_anchored(anchored_g)
		if not anchored_g and not was_frozen:
			na.linear_velocity = old_v + old_w.cross(na.world_center_of_mass() - old_com)
			na.angular_velocity = old_w

	asm.recompute()
	if asm.hold_part and asm.hold_part.get_parent() != asm:
		asm.clear_hold()
	asm.set_anchored(_group_anchored(groups[0]))


func _connected_groups(parts: Array[Part]) -> Array:
	var remaining := {}
	for p in parts:
		remaining[p] = true
	var groups: Array = []
	while not remaining.is_empty():
		var start: Part = remaining.keys()[0]
		var group: Array[Part] = []
		var stack: Array[Part] = [start]
		remaining.erase(start)
		while not stack.is_empty():
			var cur: Part = stack.pop_back()
			group.append(cur)
			for w: Weld in cur.welds:
				var o := w.other(cur)
				if o != null and remaining.has(o):
					remaining.erase(o)
					stack.append(o)
		groups.append(group)
	return groups


func _group_anchored(group: Array) -> bool:
	for p: Part in group:
		for w: Weld in p.welds:
			if w.is_ground():
				return true
	return false

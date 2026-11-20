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

const WELD_BALL_RADIUS := 0.05
## A solda só alcança o que está dentro da bolinha (não atravessa chapas).
const WELD_REACH := 0.045
## Distância mínima entre bolinhas: um ponto novo só nasce onde não há outra bolinha.
const WELD_MIN_SPACING := 0.09
const MIN_PIECE_VOLUME := 0.0004
const MIN_PIECE_THICKNESS := 0.02

var world_root: Node3D
var welds: Array[Weld] = []
var joints: Array[MechJoint] = []
var devices: Array[ControlDevice] = []
## Assento em que o jogador está sentado (as teclas controlam a rede dele).
var active_seat: Part = null
var seat_keys_enabled := true

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
	joints.clear()
	devices.clear()
	active_seat = null
	seat_keys_enabled = true


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


## Coloca uma peça já montada (ex.: cilindro) numa montagem nova.
func spawn_part(part: Part, xform: Transform3D) -> Part:
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

## Procura algo para soldar perto de `point` (dentro da bolinha de solda).
## Retorna {"ok", "part", "ground"}. Peças têm preferência sobre o chão.
func find_weld_target(part: Part, point: Vector3) -> Dictionary:
	var space := part.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = WELD_REACH
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.collision_mask = Layers.AIM
	params.transform = Transform3D(Basis(), point)
	var found_ground := false
	for res: Dictionary in space.intersect_shape(params, 32):
		var other := part_from_collision(res["collider"], res["shape"])
		if other != null and other != part:
			return {"ok": true, "part": other, "ground": false}
		if other == null and is_ground(res["collider"]):
			found_ground = true
	if found_ground:
		return {"ok": true, "part": null, "ground": true}
	return {"ok": false}


## Já existe uma bolinha de solda neste ponto?
func weld_spot_taken(point: Vector3) -> bool:
	for w in welds:
		if w.world_pos().distance_to(point) < WELD_MIN_SPACING:
			return true
	return false


## Tenta soldar `part` no ponto `point` (na superfície dela).
## Retorna a solda criada, ou null se não havia nada para soldar ou o ponto já tem solda.
func weld_at(part: Part, point: Vector3) -> Weld:
	if weld_spot_taken(point):
		return null
	var target := find_weld_target(part, point)
	if not target["ok"]:
		return null
	return _create_weld(part, target["part"], point)


const INSULATOR_MIN_SPACING := 0.15


## Coloca um isolador (guia de fio) soldado na superfície em `point`, de pé na direção
## `normal`. `on` é a peça da superfície (null = chão/estrutura do mapa).
func place_insulator(on: Part, point: Vector3, normal: Vector3) -> Part:
	for asm in world_root.get_children():
		if asm is Assembly:
			for p: Part in (asm as Assembly).get_parts():
				if p.kind == "isolador" and Components.wire_anchor(p).distance_to(point) < INSULATOR_MIN_SPACING:
					return null
	var y := normal.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(x, y, x.cross(y))
	var ins: Part = Components.spawn("isolador", Transform3D(basis, point + y * 0.081))[0]
	_create_weld(ins, on, point)
	return ins


## Solda direta entre duas peças (sem procurar vizinhos): usada para montar componentes.
func make_weld(part: Part, other: Part, point: Vector3) -> Weld:
	return _create_weld(part, other, point)


func _create_weld(part: Part, other: Part, point: Vector3) -> Weld:
	var w := Weld.new()
	w.part_a = part
	w.part_b = other
	w.local_pos = part.global_transform.affine_inverse() * point
	w.ball = MeshInstance3D.new()
	w.ball.mesh = _ball_mesh
	part.add_child(w.ball)
	w.ball.position = w.local_pos
	_heat_ball(w.ball)
	welds.append(w)
	part.welds.append(w)
	if other:
		other.welds.append(w)

	var asm := part.assembly()
	if other == null:
		asm.set_anchored(true)
	else:
		_merge(asm, other.assembly())
	return w


## A bolinha nasce incandescente e esfria.
func _heat_ball(ball: MeshInstance3D) -> void:
	var hot := _ball_material.duplicate() as StandardMaterial3D
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.45, 0.12)
	hot.emission_energy_multiplier = 4.0
	ball.material_override = hot
	var tw := ball.create_tween()
	tw.tween_property(hot, "emission_energy_multiplier", 0.0, 1.8).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: ball.material_override = _ball_material)


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
	if part.mech:
		_remove_joint(part.mech)
	if part.device:
		_remove_device(part.device)
	if part == active_seat:
		active_seat = null
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
	_refresh_joints()
	return a


## Verifica se as peças da montagem ainda estão todas ligadas por soldas.
## Se não estiverem, separa em montagens novas. Também atualiza a ancoragem.
func refresh_assembly(asm: Assembly) -> void:
	var parts := asm.get_parts()
	if parts.is_empty():
		asm.queue_free()
		_refresh_joints()
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
	_refresh_joints()


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


# ---------------------------------------------------------------------------
# Mecânica: juntas, controles e fios
# ---------------------------------------------------------------------------

func add_joint(j: MechJoint) -> void:
	joints.append(j)
	j.part_a.mech = j
	j.part_b.mech = j
	j.rebuild(world_root)


func add_device(d: ControlDevice) -> void:
	devices.append(d)
	d.part.device = d


func _remove_joint(j: MechJoint) -> void:
	j.destroy()
	joints.erase(j)
	for p in [j.part_a, j.part_b]:
		if is_instance_valid(p) and (p as Part).mech == j:
			(p as Part).mech = null


func _remove_device(d: ControlDevice) -> void:
	devices.erase(d)
	for j in joints:
		j.sources.erase(d)
		j.routes.erase(d)


## Liga (ou desliga, se já estava ligado) um controle a um componente. Retorna true se ligou.
## `via`: isoladores por onde o fio passa (na ordem).
func toggle_link(d: ControlDevice, j: MechJoint, via: Array = []) -> bool:
	if j.sources.has(d):
		j.sources.erase(d)
		j.routes.erase(d)
		return false
	j.sources.append(d)
	if not via.is_empty():
		j.routes[d] = via.duplicate()
	return true


## Recria as juntas cujas peças mudaram de montagem (solda, corte, separação).
func _refresh_joints() -> void:
	for j in joints.duplicate():
		if not j.is_valid():
			_remove_joint(j)
		elif j.needs_rebuild():
			j.rebuild(world_root)


## Componentes ligados ao assento: todas as montagens alcançáveis a partir dele
## passando por juntas (solda junta peças numa montagem; juntas ligam montagens).
func network(seat: Part) -> Array[MechJoint]:
	var out: Array[MechJoint] = []
	if seat == null or not is_instance_valid(seat) or seat.assembly() == null:
		return out
	var visited := {seat.assembly(): true}
	var queue: Array = [seat.assembly()]
	while not queue.is_empty():
		var asm: Assembly = queue.pop_back()
		for j in joints:
			if not j.is_valid():
				continue
			var a := j.part_a.assembly()
			var b := j.part_b.assembly()
			if a != asm and b != asm:
				continue
			if not out.has(j):
				out.append(j)
			for o: Assembly in [a, b]:
				if not visited.has(o):
					visited[o] = true
					queue.append(o)
	return out


func _physics_process(delta: float) -> void:
	if joints.is_empty():
		return
	if active_seat != null and not is_instance_valid(active_seat):
		active_seat = null
	var net := network(active_seat) if active_seat else ([] as Array[MechJoint])
	for j in joints:
		if not j.is_valid():
			continue
		j.read_keys(seat_keys_enabled and net.has(j))
		j.update(delta)

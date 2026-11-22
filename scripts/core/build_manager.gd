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
## Tamanhos do ponto de solda (Solda, tecla R): [nome, raio da bolinha].
## O alcance é 90% do raio: o ponto pequeno não pega o que está ao lado.
const WELD_SIZES := [["pequeno", 0.025], ["normal", 0.05], ["grande", 0.08]]
const MIN_PIECE_VOLUME := 0.0004
const MIN_PIECE_THICKNESS := 0.02

var world_root: Node3D
var welds: Array[Weld] = []
var joints: Array[MechJoint] = []
var devices: Array[ControlDevice] = []
## Assento em que o jogador está sentado (as teclas controlam a rede dele).
var active_seat: Part = null
var seat_player: Node = null      ## jogador sentado (para a "Mira" do assento)
var seat_keys_enabled := true

var _ball_mesh: SphereMesh
var _ball_meshes := {}            ## raio -> malha da bolinha
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
	Signals.reset()
	Power.reset()
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
	if is_instance_valid(collider) and collider is Assembly and shape_index >= 0:
		var asm := collider as Assembly
		# A mira pode ser de um quadro anterior: a peça pode ter saído da montagem.
		var total := 0
		for o in asm.get_shape_owners():
			total += asm.shape_owner_get_shape_count(o)
		if shape_index >= total:
			return null
		var owner_id := asm.shape_find_owner(shape_index)
		var owner := asm.shape_owner_get_owner(owner_id)
		return owner as Part
	return null


func is_ground(collider: Object) -> bool:
	return collider is Node and (collider as Node).is_in_group("ground")


# ---------------------------------------------------------------------------
# Solda
# ---------------------------------------------------------------------------

## Alcance de uma bolinha de raio `radius`.
static func weld_reach(radius: float) -> float:
	return radius * 0.9


## Procura algo para soldar perto de `point` (dentro da bolinha de solda), começando bem
## perto do ponto e crescendo até o alcance: fica com a peça MAIS PRÓXIMA (antes pegava a
## primeira que achasse, e a roda podia soldar na carcaça do motor em vez do disco).
## Retorna {"ok", "part", "ground", "locks"}. Peças têm preferência sobre o chão.
## `locks`: a solda uniria os dois lados de um componente (travaria ele).
func find_weld_target(part: Part, point: Vector3, reach := WELD_REACH) -> Dictionary:
	var space := part.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.collision_mask = Layers.AIM
	params.transform = Transform3D(Basis(), point)
	var found_ground := false
	for frac: float in [0.25, 0.5, 0.75, 1.0]:
		sphere.radius = reach * frac
		for res: Dictionary in space.intersect_shape(params, 32):
			var other := part_from_collision(res["collider"], res["shape"])
			if other != null and other != part:
				return {"ok": true, "part": other, "ground": false, "locks": crosses_joint(part, other)}
			if other == null and is_ground(res["collider"]):
				found_ground = true
	if found_ground:
		return {"ok": true, "part": null, "ground": true, "locks": false}
	return {"ok": false}


## `a` e `b` estão nos dois lados de um mesmo componente (soldá-las trava o componente)?
func crosses_joint(a: Part, b: Part) -> bool:
	var aa := a.assembly()
	var bb := b.assembly()
	if aa == null or bb == null or aa == bb:
		return false
	for j in joints:
		if not j.is_valid() or j.type in MechJoint.SINGLE or j.type == "guincho":
			continue
		var ja := j.part_a.assembly()
		var jb := j.part_b.assembly()
		if (ja == aa and jb == bb) or (ja == bb and jb == aa):
			return true
	return false


## Já existe uma bolinha de solda neste ponto (encostando na bolinha nova)?
func weld_spot_taken(point: Vector3, radius := WELD_BALL_RADIUS) -> bool:
	for w in welds:
		if w.world_pos().distance_to(point) < (radius + w.radius) * 0.9:
			return true
	return false


## Tenta soldar `part` no ponto `point` (na superfície dela), com uma bolinha de `radius`.
## Retorna a solda criada, ou null se não havia nada para soldar, o ponto já tem solda ou
## a solda travaria um componente (a não ser com `force`).
func weld_at(part: Part, point: Vector3, radius := WELD_BALL_RADIUS, force := false) -> Weld:
	if weld_spot_taken(point, radius):
		return null
	var target := find_weld_target(part, point, weld_reach(radius))
	if not target["ok"] or (target["locks"] and not force):
		return null
	return _create_weld(part, target["part"], point, true, radius)


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


## Solda direta entre duas peças (sem procurar vizinhos): usada para montar componentes
## e ao carregar um save (`hot` = false: a bolinha já nasce fria).
func make_weld(part: Part, other: Part, point: Vector3, hot := true, radius := WELD_BALL_RADIUS) -> Weld:
	return _create_weld(part, other, point, hot, radius)


func _ball_mesh_for(radius: float) -> SphereMesh:
	if is_equal_approx(radius, WELD_BALL_RADIUS):
		return _ball_mesh
	var key := snappedf(radius, 0.001)
	if not _ball_meshes.has(key):
		var m := _ball_mesh.duplicate() as SphereMesh
		m.radius = radius
		m.height = radius * 2.0
		_ball_meshes[key] = m
	return _ball_meshes[key]


func _create_weld(part: Part, other: Part, point: Vector3, hot := true, radius := WELD_BALL_RADIUS) -> Weld:
	var w := Weld.new()
	w.part_a = part
	w.part_b = other
	w.radius = radius
	w.local_pos = part.global_transform.affine_inverse() * point
	w.ball = MeshInstance3D.new()
	w.ball.mesh = _ball_mesh_for(radius)
	part.add_child(w.ball)
	w.ball.position = w.local_pos
	if hot:
		_heat_ball(w.ball)
	else:
		w.ball.material_override = _ball_material
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
	for m: Array in part.marks:
		var mp: Vector3 = m[0]
		var target: Part = pieces[0] if cut_local.distance_to(mp) <= 0.0 else pieces[1]
		target.add_mark(mp, m[1])

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
	if part.node:
		Signals.unregister(part.node)
		if part.node is PowerNode:
			Power.unregister(part.node)
	if part.kind == "isolador":
		Signals.remove_via(part)
		Power.remove_via(part)
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
	var frozen := a.frozen or b.frozen
	# Se a montagem que vai sumir estava sendo segurada, o Gravitador reaplica no próximo tick.
	for p in b.get_parts():
		p.reparent(a, true)
	b.clear_hold()
	b.queue_free()
	a.recompute()
	a.frozen = frozen
	a.set_anchored(anchored)
	if not anchored and not frozen:
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
		na.frozen = asm.frozen
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
	Signals.register(j)
	j.part_a.mech = j
	j.part_b.mech = j
	j.rebuild(world_root)
	balance_masses()


func add_device(d: ControlDevice) -> void:
	devices.append(d)
	d.part.device = d
	Signals.register(d)


## Chip, tela, assento... (qualquer outro nó de sinal preso a uma peça).
func add_node(n: SignalNode) -> void:
	n.signal_part().node = n
	Signals.register(n)


func _remove_joint(j: MechJoint) -> void:
	j.destroy()
	joints.erase(j)
	Signals.unregister(j)
	for p in [j.part_a, j.part_b]:
		if is_instance_valid(p) and (p as Part).mech == j:
			(p as Part).mech = null


func _remove_device(d: ControlDevice) -> void:
	devices.erase(d)
	Signals.unregister(d)


## Liga (ou desliga, se já estava ligado) um controle a um componente. Retorna true se ligou.
## `via`: isoladores por onde o fio passa (na ordem).
## Liga (ou desliga) um controle na entrada "Sinal" de um componente.
func toggle_link(d: SignalNode, j: MechJoint, via: Array = []) -> bool:
	return Signals.toggle(d, "Saída", j, "Sinal", via)


## Recria as juntas cujas peças mudaram de montagem (solda, corte, separação).
func _refresh_joints() -> void:
	for j in joints.duplicate():
		if not j.is_valid():
			_remove_joint(j)
		elif j.needs_rebuild():
			j.rebuild(world_root)
	balance_masses()


## Lado leve de uma junta: no mínimo 1/MASS_RATIO da massa do outro lado.
const MASS_RATIO := 8.0
const MAX_MASS_BOOST := 100.0
var _boosted: Array = []
var _no_ccd: Array = []           ## montagens com juntas: sem colisão contínua
var _balance_dirty := false


## Pede um novo balanceamento no próximo tick (ex.: algo foi congelado/descongelado).
func request_balance() -> void:
	_balance_dirty = true


## Balanceamento de massa entre os lados das juntas (ver Assembly.mass_boost).
## Propaga pela cadeia (chassi → braço → montante → roda). Peças congeladas/ancoradas
## não entram (o solver lida bem com corpos parados).
func balance_masses() -> void:
	var boost := {}
	var pairs: Array = []
	var jointed := {}
	for j in joints:
		if not j.is_valid() or j.type in MechJoint.SINGLE or j.type == "guincho":
			continue
		var a := j.part_a.assembly()
		var b := j.part_b.assembly()
		if a == null or b == null or a == b:
			continue
		jointed[a] = true
		jointed[b] = true
		if a.freeze or b.freeze:
			continue
		pairs.append([a, b])
		boost[a] = 1.0
		boost[b] = 1.0
	for pass_i in 6:
		var changed := false
		for pair: Array in pairs:
			for k in 2:
				var light: Assembly = pair[k]
				var heavy: Assembly = pair[1 - k]
				var want: float = heavy.real_mass() * boost[heavy] / MASS_RATIO
				var have: float = light.real_mass() * boost[light]
				if have < want * 0.999:
					boost[light] = minf(want / maxf(light.real_mass(), 0.01), MAX_MASS_BOOST)
					changed = true
		if not changed:
			break
	for old in _no_ccd:
		if is_instance_valid(old) and not jointed.has(old):
			(old as Assembly).continuous_cd = true
	_no_ccd = jointed.keys()
	for asm: Assembly in _no_ccd:
		asm.continuous_cd = false
	# Prato da balança: massa de inércia mínima (o peso continua o mesmo), para a mola
	# dela poder ser bem amortecida sem "passar do ponto" a cada tick.
	for j in joints:
		if j.type == "balanca" and j.is_valid():
			var plate := j.part_b.assembly()
			if plate and not plate.freeze:
				var need := MechJoint.SCALE_PLATE_MASS * pow(j.size_scale, 3.0) / maxf(plate.real_mass(), 0.01)
				boost[plate] = clampf(maxf(boost.get(plate, 1.0), need), 1.0, MAX_MASS_BOOST)
	for old in _boosted:
		if is_instance_valid(old) and not boost.has(old):
			(old as Assembly).set_mass_boost(1.0)
	_boosted = []
	for asm: Assembly in boost:
		asm.set_mass_boost(boost[asm])
		if boost[asm] > 1.0:
			_boosted.append(asm)


## Montagens ligadas a `start` por juntas (incluindo ela mesma).
func connected_assemblies(start: Assembly) -> Array[Assembly]:
	var out: Array[Assembly] = [start]
	var i := 0
	while i < out.size():
		var asm := out[i]
		for j in joints:
			if not j.is_valid():
				continue
			var a := j.part_a.assembly()
			var b := j.part_b.assembly()
			if a == asm and not out.has(b):
				out.append(b)
			elif b == asm and not out.has(a):
				out.append(a)
		i += 1
	return out


## Descongela tudo o que foi congelado pelo Gravitador. Retorna quantas montagens.
func unfreeze_all() -> int:
	var n := 0
	for c in world_root.get_children():
		if c is Assembly and (c as Assembly).frozen and not c.is_queued_for_deletion():
			(c as Assembly).set_frozen(false)
			n += 1
	return n


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
	Signals.tick(delta)
	Power.tick(delta)
	if _balance_dirty:
		_balance_dirty = false
		balance_masses()
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

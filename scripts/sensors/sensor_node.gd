class_name SensorNode
extends SignalNode
## Sensores (Marco 4C, estilo Wiremod). Todos mandam o que medem como sinal.
##
##   ranger        medidor laser: o laser sai pela face de cima (Y local)
##   velocimetro   velocidade (m/s, km/h, local X/Y/Z) e giro (rad/s)
##   giroscopio    inclinação: pitch, yaw, roll (graus)
##   gps           posição; entrada Marcar guarda um ponto e mede a distância até ele
##   localizador   "farol" que o sensor de localizador encontra (canal 1 a 99)
##   sensor_loc    distância e direção até o localizador mais perto do mesmo canal
##   buscador      procura alvos num raio (jogador, peças, componentes, localizadores)
##   zona          detecta o que entra numa caixa em cima dele
##   impacto       força da batida e o que bateu
##   receptor      acende quando um laser (medidor ou ferramenta Laser) acerta nele
## (A balança é um componente com junta: MechJoint "balanca".)

const KINDS := {
	"ranger": "Medidor laser", "velocimetro": "Velocímetro", "giroscopio": "Giroscópio", "gps": "GPS",
	"localizador": "Localizador", "sensor_loc": "Sensor de localizador", "buscador": "Buscador de alvos",
	"zona": "Zona", "impacto": "Detector de impacto", "receptor": "Receptor de laser",
}
const FILTERS := ["Tudo", "Jogador", "Peças", "Componentes", "Localizadores"]
const MACHINE_REFRESH := 30      ## ticks entre recalcular "a própria máquina"

var part: Part
var kind := "ranger"

# Ajustes
var range_m := 50.0              ## ranger, sensor de localizador, buscador
var show_beam := true            ## ranger: mostra o laser
var ignore_own := true           ## ranger/buscador/zona: ignora a própria máquina
var channel := 1                 ## localizador / sensor de localizador
var filter := 0                  ## buscador: índice em FILTERS
var zone_size := Vector3(2, 2, 2)
var show_zone := true

# Estado
var mark := Vector3.ZERO         ## GPS: ponto marcado
var has_mark := false
var _prev_marcar := false
var _hit_ticks := 0              ## receptor: ticks desde o último laser
var _lasers := 0
var _impact := 0.0               ## impacto: força segurada por um tempo
var _impact_hold := 0
var _impact_part: Part = null
var _prev_vel := Vector3.ZERO
var _prev_asm: Assembly = null
var _own: Array = []             ## RIDs da própria máquina
var _own_ticks := 0
var _own_asm: Assembly = null    ## montagem quando a lista foi feita (soldar junta montagens)
var _player: Node3D = null

# Aparência
var beam: MeshInstance3D         ## ranger: laser
var glow: MeshInstance3D
var zone_box: MeshInstance3D
var label: Label3D
var _mat: StandardMaterial3D


func signal_part() -> Part:
	return part


func kind_label() -> String:
	return KINDS.get(kind, kind)


func inputs() -> Array:
	match kind:
		"gps":
			return [["Marcar", NUM]]
	return []


func outputs() -> Array:
	match kind:
		"ranger":
			return [["Distância", NUM], ["Acertou", NUM], ["Posição", VEC], ["Normal", VEC], ["Peça", PART],
				["Velocidade", NUM], ["Material", TXT]]
		"velocimetro":
			return [["Velocidade", NUM], ["km/h", NUM], ["Local", VEC], ["Giro", VEC]]
		"giroscopio":
			return [["Pitch", NUM], ["Yaw", NUM], ["Roll", NUM], ["Ângulos", VEC]]
		"gps":
			return [["Posição", VEC], ["X", NUM], ["Y", NUM], ["Z", NUM], ["Marcado", VEC], ["Distância", NUM]]
		"sensor_loc":
			return [["Achou", NUM], ["Distância", NUM], ["Direção", VEC], ["Posição", VEC]]
		"buscador":
			return [["Quantidade", NUM], ["Alvo", PART], ["Posição", VEC], ["Distância", NUM], ["Alvos", LIST]]
		"zona":
			return [["Dentro", NUM], ["Jogador", NUM], ["Massa", NUM]]
		"impacto":
			return [["Força", NUM], ["Bateu", NUM], ["Peça", PART]]
		"receptor":
			return [["Atingido", NUM], ["Lasers", NUM]]
	return []


func is_source() -> bool:
	return kind != "gps"


# --- Medição -------------------------------------------------------------------------

func update_outputs(dt: float) -> void:
	if part == null or not part.is_inside_tree():
		return
	match kind:
		"ranger":
			_ranger()
		"velocimetro":
			var asm := part.assembly()
			var b := part.global_basis.orthonormalized()
			var v := asm.linear_velocity + asm.angular_velocity.cross(part.global_position - asm.world_center_of_mass())
			out["Velocidade"] = v.length()
			out["km/h"] = v.length() * 3.6
			out["Local"] = b.inverse() * v
			out["Giro"] = b.inverse() * asm.angular_velocity
		"giroscopio":
			var e := part.global_basis.orthonormalized().get_euler(EULER_ORDER_YXZ)
			var deg := Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z))
			out["Pitch"] = deg.x
			out["Yaw"] = deg.y
			out["Roll"] = deg.z
			out["Ângulos"] = deg
		"sensor_loc":
			_beacon()
		"buscador":
			_finder()
		"zona":
			_zone()
		"impacto":
			_impact_sense(dt)
		"receptor":
			_hit_ticks += 1
			var on := _hit_ticks <= 1
			out["Atingido"] = 1.0 if on else 0.0
			out["Lasers"] = float(_lasers) if on else 0.0
			if not on:
				_lasers = 0
			_set_glow(Color(1.0, 0.2, 0.15) if on else Color(0.25, 0.05, 0.04), 3.0 if on else 0.0)


## GPS (não é fonte: lê a entrada Marcar).
func evaluate(inp: Dictionary, _wired: Dictionary, _dt: float) -> void:
	if kind != "gps" or part == null:
		return
	var p := part.global_position
	var marcar := float(inp.get("Marcar", 0.0)) > 0.5
	if marcar and not _prev_marcar:
		mark = p
		has_mark = true
	_prev_marcar = marcar
	out["Posição"] = p
	out["X"] = p.x
	out["Y"] = p.y
	out["Z"] = p.z
	out["Marcado"] = mark
	out["Distância"] = p.distance_to(mark) if has_mark else 0.0


## Corpos da própria máquina (soldada + juntas), recalculados de vez em quando.
func _own_rids() -> Array:
	_own_ticks -= 1
	if _own_ticks <= 0 or _own.is_empty() or part.assembly() != _own_asm:
		_own_ticks = MACHINE_REFRESH
		_own = []
		var asm := part.assembly()
		_own_asm = asm
		if asm:
			for a: Assembly in Carrier.machine(asm, true)["list"]:
				_own.append(a.get_rid())
	return _own if ignore_own else ([part.assembly().get_rid()] if part.assembly() else [])


func _space() -> PhysicsDirectSpaceState3D:
	return part.get_world_3d().direct_space_state


func _ranger() -> void:
	var from := part.global_transform * Vector3(0, part.bounds.end.y + 0.002, 0)
	var dir := part.global_basis.orthonormalized().y
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * range_m, Layers.WORLD | Layers.PARTS | Layers.PLAYER, _own_rids())
	var hit := _space().intersect_ray(q)
	var dist := range_m
	var hit_part: Part = null
	if hit.is_empty():
		out["Acertou"] = 0.0
		out["Posição"] = Vector3.ZERO
		out["Normal"] = Vector3.ZERO
		out["Peça"] = null
		out["Velocidade"] = 0.0
		out["Material"] = ""
		out["Distância"] = range_m
	else:
		var pos: Vector3 = hit["position"]
		dist = from.distance_to(pos)
		var col: Object = hit["collider"]
		hit_part = Build.part_from_collision(col, int(hit["shape"])) if col is Assembly else null
		var vel := Vector3.ZERO
		if col is RigidBody3D:
			var rb := col as RigidBody3D
			vel = rb.linear_velocity + rb.angular_velocity.cross(pos - rb.global_position)
		elif col is CharacterBody3D:
			vel = (col as CharacterBody3D).velocity
		out["Acertou"] = 1.0
		out["Distância"] = dist
		out["Posição"] = pos
		out["Normal"] = hit["normal"]
		out["Peça"] = hit_part
		out["Velocidade"] = vel.length()
		out["Material"] = hit_part.material_id if hit_part else ("jogador" if col is CharacterBody3D else "chão")
		if hit_part:
			laser_hit(hit_part)
	if beam:
		beam.visible = show_beam
		beam.scale = Vector3(1, maxf(dist, 0.01), 1)
		beam.position = Vector3(0, part.bounds.end.y + dist * 0.5, 0)


## Um laser (medidor ou ferramenta) acertou `p`: se for um receptor, ele acende.
static func laser_hit(p: Part) -> void:
	if p and p.node is SensorNode and (p.node as SensorNode).kind == "receptor":
		var r := p.node as SensorNode
		r._hit_ticks = 0
		r._lasers += 1


func _beacon() -> void:
	var best: SensorNode = null
	var best_d := INF
	var here := part.global_position
	for n in Signals.nodes:
		var s := n as SensorNode
		if s == null or s == self or s.kind != "localizador" or s.channel != channel or not s.is_alive():
			continue
		var d := here.distance_to(s.part.global_position)
		if d < best_d and d <= range_m:
			best_d = d
			best = s
	if best == null:
		out["Achou"] = 0.0
		out["Distância"] = 0.0
		out["Direção"] = Vector3.ZERO
		out["Posição"] = Vector3.ZERO
		return
	var to := best.part.global_position - here
	out["Achou"] = 1.0
	out["Distância"] = best_d
	out["Direção"] = (part.global_basis.orthonormalized().inverse() * to).normalized() if best_d > 1e-4 else Vector3.ZERO
	out["Posição"] = best.part.global_position


## Alvos dentro do raio, mais perto primeiro: [{"pos", "part"}].
func _targets() -> Array:
	var here := part.global_position
	var found: Array = []
	var want := FILTERS[clampi(filter, 0, FILTERS.size() - 1)] as String
	if want in ["Tudo", "Jogador"]:
		var pl := _find_player()
		if pl and pl.global_position.distance_to(here) <= range_m:
			found.append({"pos": pl.global_position + Vector3(0, 0.9, 0), "part": null})
	if want != "Jogador":
		var own := _own_rids()
		var sphere := SphereShape3D.new()
		sphere.radius = range_m
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = sphere
		params.collision_mask = Layers.PARTS
		params.transform = Transform3D(Basis(), here)
		params.exclude = own
		var seen := {}
		for res: Dictionary in _space().intersect_shape(params, 64):
			var asm := res["collider"] as Assembly
			if asm == null or seen.has(asm):
				continue
			seen[asm] = true
			for p: Part in asm.get_parts():
				var ok := false
				match want:
					"Tudo", "Peças":
						ok = true
					"Componentes":
						ok = p.comp_kind != ""
					"Localizadores":
						ok = p.node is SensorNode and (p.node as SensorNode).kind == "localizador"
				if ok and p.global_position.distance_to(here) <= range_m:
					found.append({"pos": p.global_position, "part": p})
					if want in ["Tudo", "Peças"]:
						break       # uma por montagem
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["pos"] as Vector3).distance_squared_to(here) < (b["pos"] as Vector3).distance_squared_to(here))
	return found


func _finder() -> void:
	var t := _targets()
	out["Quantidade"] = float(t.size())
	if t.is_empty():
		out["Alvo"] = null
		out["Posição"] = Vector3.ZERO
		out["Distância"] = 0.0
		out["Alvos"] = []
		return
	out["Alvo"] = t[0]["part"]
	out["Posição"] = t[0]["pos"]
	out["Distância"] = part.global_position.distance_to(t[0]["pos"])
	out["Alvos"] = t.slice(0, 16).map(func(d: Dictionary) -> Variant: return d["part"]).filter(func(p: Variant) -> bool: return p != null)


func _find_player() -> Node3D:
	if _player == null or not is_instance_valid(_player):
		_player = part.get_tree().get_first_node_in_group("player") as Node3D
	return _player


## A caixa da zona fica em cima do sensor (a base dela encosta na face de cima).
func zone_transform() -> Transform3D:
	return part.global_transform * Transform3D(Basis(), Vector3(0, part.bounds.end.y + zone_size.y * 0.5, 0))


func _zone() -> void:
	var box := BoxShape3D.new()
	box.size = zone_size
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = box
	params.collision_mask = Layers.PARTS | Layers.PLAYER
	params.transform = zone_transform().orthonormalized()
	params.exclude = _own_rids()
	var count := 0
	var mass := 0.0
	var player_in := false
	var seen := {}
	for res: Dictionary in _space().intersect_shape(params, 64):
		var c: Object = res["collider"]
		if seen.has(c):
			continue
		seen[c] = true
		if c is Assembly:
			count += 1
			mass += (c as Assembly).real_mass()
		elif c is CharacterBody3D:
			player_in = true
	out["Dentro"] = float(count)
	out["Jogador"] = 1.0 if player_in else 0.0
	out["Massa"] = mass
	if zone_box:
		zone_box.visible = show_zone
		zone_box.scale = zone_size
		zone_box.position = Vector3(0, part.bounds.end.y + zone_size.y * 0.5, 0)
		_set_glow(Color(0.3, 1.0, 0.4) if count > 0 or player_in else Color(0.15, 0.3, 0.2), 1.5)


## Impacto: a mudança brusca de velocidade da montagem (fora a gravidade) vezes a massa.
func _impact_sense(dt: float) -> void:
	var asm := part.assembly()
	if asm == null:
		return
	if asm != _prev_asm:
		_prev_asm = asm
		asm.contact_monitor = true
		asm.max_contacts_reported = maxi(asm.max_contacts_reported, 4)
		_prev_vel = asm.linear_velocity
	var v := asm.linear_velocity
	var g := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * asm.gravity_scale
	var dv := (v - _prev_vel) - (g * dt if not asm.freeze else Vector3.ZERO)
	_prev_vel = v
	var force := dv.length() * asm.real_mass() / maxf(dt, 1e-4)
	var bumped := force > 200.0 and not asm.freeze
	if bumped:
		var best: Part = null
		for b in asm.get_colliding_bodies():
			if b is Assembly and not (b as Assembly).get_parts().is_empty():
				best = (b as Assembly).get_parts()[0]
				break
		_impact_part = best
		if force > _impact or _impact_hold <= 0:
			_impact = force
		_impact_hold = 30
	elif _impact_hold > 0:
		_impact_hold -= 1
		if _impact_hold == 0:
			_impact = 0.0
			_impact_part = null
	out["Força"] = _impact
	out["Bateu"] = 1.0 if bumped else 0.0
	out["Peça"] = _impact_part
	_set_glow(Color(1.0, 0.6, 0.1) if _impact_hold > 0 else Color(0.3, 0.15, 0.05), 2.0 if _impact_hold > 0 else 0.0)


func _set_glow(c: Color, energy: float) -> void:
	if glow == null:
		return
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.emission_enabled = true
		glow.material_override = _mat
	_mat.albedo_color = c.darkened(0.4)
	_mat.emission = c
	_mat.emission_energy_multiplier = energy


func update_label() -> void:
	if label and kind in ["localizador", "sensor_loc"]:
		label.text = "%s\nCanal %d" % ["LOC" if kind == "localizador" else "→ LOC", channel]


# --- Salvar --------------------------------------------------------------------------

func save_state() -> Dictionary:
	var d := {}
	match kind:
		"ranger":
			d = {"range": range_m, "beam": show_beam, "own": ignore_own}
		"localizador":
			d = {"ch": channel}
		"sensor_loc":
			d = {"ch": channel, "range": range_m}
		"buscador":
			d = {"range": range_m, "filter": filter, "own": ignore_own}
		"zona":
			d = {"size": [zone_size.x, zone_size.y, zone_size.z], "show": show_zone, "own": ignore_own}
		"gps":
			if has_mark:
				d = {"mark": [mark.x, mark.y, mark.z]}
	return d


func load_state(d: Dictionary) -> void:
	range_m = float(d.get("range", range_m))
	show_beam = bool(d.get("beam", show_beam))
	ignore_own = bool(d.get("own", ignore_own))
	channel = int(d.get("ch", channel))
	filter = int(d.get("filter", filter))
	show_zone = bool(d.get("show", show_zone))
	if d.has("size"):
		var s: Array = d["size"]
		zone_size = Vector3(s[0], s[1], s[2])
	if d.has("mark"):
		var m: Array = d["mark"]
		mark = Vector3(m[0], m[1], m[2])
		has_mark = true
	update_label()

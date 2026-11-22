class_name ActuatorNode
extends SignalNode
## Atuadores (Marco 4E): empurram, seguram, giram e usam coisas por sinal.
## A "frente" deles é o lado da lente/bico (-Z local); a base (embaixo) vai soldada.
##   propulsor_vetorial empurra a máquina para a frente com Força (-1 a 1) × força máxima. Vetor
##                (com fio) escolhe a direção no mundo; Local ligado: nos eixos da peça.
##   hoverball    segura a peça na Altura acima do chão (sem fio: a dos ajustes). Ligado.
##   forcer       empurra (ou puxa, negativo) o que está na frente, até o Alcance. Força em N.
##   gimbal       gira a máquina para a frente apontar para o Alvo (ponto) ou a Direção.
##   peso         massa ajustável (kg) pela entrada Massa.
##   congelador   Congelar ligado: a máquina inteira fica parada no ar; desligado, solta.
##   user         Usar: aperta E no que está na frente (botão, alavanca, chave, bomba...).

const KINDS := {
	"propulsor_vetorial": "Propulsor vetorial", "hoverball": "Hoverball", "forcer": "Forcer", "gimbal": "Gimbal",
	"peso": "Peso ajustável", "congelador": "Congelador", "user": "User (aperta E)",
}
const MACHINE_REFRESH := 30        ## ticks entre recalcular a lista da própria máquina

var part: Part
var kind := "propulsor_vetorial"
var label: Label3D
var flame: CPUParticles3D           ## propulsor: chama
var glow: MeshInstance3D

# Ajustes
var max_force := 2000.0            ## propulsor/hoverball/gimbal (N ou N·m)
var height := 1.5                  ## hoverball: altura padrão (m)
var air_brake := true              ## hoverball: freia o deslize de lado
var reach := 5.0                   ## forcer/user: alcance (m)
var mass_default := 50.0           ## peso: massa sem fio (kg)

# Estado
var force_now := 0.0
var _integral := 0.0
var _own: Array = []
var _own_ticks := 0
var _frozen_list: Array = []
var _prev_use := 0.0
var _pressed_device: ControlDevice = null
var _mat: StandardMaterial3D
var _mass_t := 0.0
var _gim_i := Vector3.ZERO          ## gimbal: parte integral (vence o atrito parado)


func signal_part() -> Part:
	return part


func kind_label() -> String:
	return KINDS.get(kind, kind)


func inputs() -> Array:
	match kind:
		"propulsor_vetorial":
			return [["Força", NUM], ["Vetor", VEC], ["Local", NUM]]
		"hoverball":
			return [["Ligado", NUM], ["Altura", NUM]]
		"forcer":
			return [["Força", NUM], ["Alcance", NUM]]
		"gimbal":
			return [["Ligado", NUM], ["Alvo", VEC], ["Direção", VEC]]
		"peso":
			return [["Massa", NUM]]
		"congelador":
			return [["Congelar", NUM]]
		"user":
			return [["Usar", NUM]]
	return []


func outputs() -> Array:
	match kind:
		"propulsor_vetorial":
			return [["Força", NUM]]
		"hoverball":
			return [["Altura", NUM], ["Força", NUM]]
		"forcer":
			return [["Acertou", NUM], ["Distância", NUM]]
		"gimbal":
			return [["Erro", NUM]]
		"peso":
			return [["Massa", NUM]]
		"congelador":
			return [["Congelado", NUM]]
		"user":
			return [["Usou", NUM], ["Alvo", PART]]
	return []


func is_source() -> bool:
	return false


func _asm() -> Assembly:
	return part.assembly() if part and part.is_inside_tree() else null


## Corpos da própria máquina (para os raios não acertarem nela mesma).
func _own_rids() -> Array:
	_own_ticks -= 1
	if _own_ticks <= 0 or _own.is_empty():
		_own_ticks = MACHINE_REFRESH
		_own = []
		var asm := _asm()
		if asm:
			for a: Assembly in Carrier.machine(asm, true)["list"]:
				_own.append(a.get_rid())
	return _own


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = _own_rids()
	q.collision_mask = Layers.WORLD | Layers.PARTS
	return part.get_world_3d().direct_space_state.intersect_ray(q)


static func _part_hit(r: Dictionary) -> Part:
	if r.is_empty() or not (r["collider"] is Assembly):
		return null
	var asm := r["collider"] as Assembly
	return asm.shape_owner_get_owner(asm.shape_find_owner(int(r["shape"]))) as Part


func front() -> Vector3:
	return -part.global_basis.orthonormalized().z


func evaluate(inp: Dictionary, wired: Dictionary, dt: float) -> void:
	var asm := _asm()
	if asm == null:
		return
	match kind:
		"propulsor_vetorial":
			var mul := clampf(float(inp["Força"]), -1.0, 1.0)
			var dir := front()
			if wired.has("Vetor") and (inp["Vetor"] as Vector3).length() > 1e-6:
				var v: Vector3 = (inp["Vetor"] as Vector3).normalized()
				dir = part.global_basis.orthonormalized() * v if float(inp["Local"]) > 0.0 else v
			force_now = mul * max_force
			_push(asm, dir * force_now, part.global_position)
			out["Força"] = force_now
			_set_flame(absf(mul))
		"hoverball":
			var active := float(inp["Ligado"]) > 0.0 if wired.has("Ligado") else true
			var target := float(inp["Altura"]) if wired.has("Altura") else height
			var from := part.global_position
			var r := _ray(from, from + Vector3.DOWN * 200.0)
			var h: float = from.distance_to(r["position"]) if not r.is_empty() else 200.0
			out["Altura"] = h
			if not active:
				_integral = 0.0
				force_now = 0.0
				out["Força"] = 0.0
				_set_glow(Color(0.15, 0.2, 0.3), 0.2)
				return
			var err := clampf(target - h, -3.0, 3.0)
			# Velocidade no ponto da hoverball (com o giro): amortece também a inclinação.
			var vpt := asm.linear_velocity + asm.angular_velocity.cross(part.global_position - asm.world_center_of_mass())
			var vy := vpt.y
			_integral = clampf(_integral + err * max_force * 0.6 * dt, 0.0, max_force)
			var f := clampf(err * max_force * 0.5 - vy * max_force * 0.35 + _integral, 0.0, max_force)
			var push := Vector3.UP * f
			if air_brake:
				var vh := Vector3(asm.linear_velocity.x, 0.0, asm.linear_velocity.z)
				push += -vh.limit_length(2.0) * max_force * 0.1
			force_now = f
			_push(asm, push, part.global_position)
			out["Força"] = f
			_set_glow(Color(0.3, 0.7, 1.0), 0.8 + 2.5 * f / maxf(max_force, 1.0))
		"forcer":
			var f2 := float(inp["Força"])
			var rng := float(inp["Alcance"]) if wired.has("Alcance") and float(inp["Alcance"]) > 0.0 else reach
			var from2 := part.global_position + front() * (part.bounds.size.z * 0.5 + 0.01)
			var r2 := _ray(from2, from2 + front() * rng)
			var hit := not r2.is_empty() and r2["collider"] is Assembly
			out["Acertou"] = 1.0 if hit else 0.0
			out["Distância"] = from2.distance_to(r2["position"]) if not r2.is_empty() else 0.0
			force_now = f2 if hit else 0.0
			if hit and absf(f2) > 0.0:
				var target_asm := r2["collider"] as Assembly
				if not target_asm.anchored and not target_asm.freeze:
					_push(target_asm, front() * f2, r2["position"])
			_set_glow(Color(0.9, 0.4, 1.0) if absf(force_now) > 0.0 else Color(0.25, 0.1, 0.3), 2.5 if absf(force_now) > 0.0 else 0.2)
		"gimbal":
			var active2 := float(inp["Ligado"]) > 0.0 if wired.has("Ligado") else true
			var want := Vector3.ZERO
			if wired.has("Alvo"):
				want = (inp["Alvo"] as Vector3) - part.global_position
			elif wired.has("Direção"):
				want = inp["Direção"]
			var cur := front()
			var err_deg := rad_to_deg(cur.angle_to(want)) if want.length() > 1e-6 else 0.0
			out["Erro"] = err_deg
			if not active2 or want.length() < 1e-6:
				_gim_i = Vector3.ZERO
				_set_glow(Color(0.2, 0.25, 0.1), 0.2)
				return
			_aim(asm, cur, want.normalized(), dt)
			_set_glow(Color(0.8, 1.0, 0.3), 1.0 + clampf(err_deg / 45.0, 0.0, 2.0))
		"peso":
			var m := clampf(float(inp["Massa"]) if wired.has("Massa") else mass_default, 1.0, 2000.0)
			out["Massa"] = m
			_mass_t -= dt
			if absf(part.mass - m) > maxf(0.5, m * 0.01) and _mass_t <= 0.0:
				_mass_t = 0.2
				part.mass = m
				asm.recompute()
				Build.balance_masses()
				if label:
					label.text = "%d kg" % roundi(m)
		"congelador":
			var want_frozen := float(inp["Congelar"]) > 0.0
			if want_frozen and _frozen_list.is_empty():
				for a: Assembly in Carrier.machine(asm, true)["list"]:
					if not a.anchored and not a.frozen:
						a.set_frozen(true)
						_frozen_list.append(a)
			elif not want_frozen and not _frozen_list.is_empty():
				for a in _frozen_list:
					if is_instance_valid(a) and (a as Assembly).frozen:
						(a as Assembly).set_frozen(false)
				_frozen_list = []
			out["Congelado"] = 1.0 if not _frozen_list.is_empty() else 0.0
			_set_glow(Color(0.5, 0.9, 1.0) if want_frozen else Color(0.1, 0.2, 0.25), 2.5 if want_frozen else 0.2)
		"user":
			var u := float(inp["Usar"])
			out["Usou"] = 0.0
			if u > 0.0 and _prev_use <= 0.0:
				var from3 := part.global_position + front() * (part.bounds.size.z * 0.5 + 0.01)
				var t := _part_hit(_ray(from3, from3 + front() * minf(reach, 3.0)))
				out["Alvo"] = t
				if t and use_part(t):
					out["Usou"] = 1.0
			elif u <= 0.0 and _prev_use > 0.0 and _pressed_device:
				_pressed_device.release()
				_pressed_device = null
			_prev_use = u
			_set_glow(Color(1.0, 0.8, 0.2) if u > 0.0 else Color(0.25, 0.2, 0.05), 2.0 if u > 0.0 else 0.2)


func _push(asm: Assembly, f: Vector3, at: Vector3) -> void:
	if f.length_squared() < 1e-6 or asm.freeze:
		return
	asm.sleeping = false
	asm.apply_force(f, at - asm.global_position)


## Gimbal: torque que leva a frente até a direção pedida (amortecido).
func _aim(asm: Assembly, cur: Vector3, want: Vector3, dt: float) -> void:
	if asm.freeze:
		return
	var axis := cur.cross(want)
	var s := axis.length()
	var ang := atan2(s, cur.dot(want))
	if s < 1e-6:
		axis = part.global_basis.orthonormalized().y if ang > 1.0 else Vector3.ZERO
	else:
		axis /= s
	var w := asm.angular_velocity
	# Proporcional + integral (cresce enquanto o erro continua: vence o atrito parado) + amortecimento.
	_gim_i = (_gim_i + axis * ang * 300.0 * dt).limit_length(800.0)
	if ang < 0.02:
		_gim_i *= 0.9
	var acc := axis * ang * 200.0 + _gim_i - w * 28.0
	var st := PhysicsServer3D.body_get_direct_state(asm.get_rid())
	var tq := acc * asm.mass * 0.5
	if st:
		var inv: Basis = st.inverse_inertia_tensor
		if absf(inv.determinant()) > 1e-12:
			tq = inv.inverse() * acc
	asm.sleeping = false
	asm.apply_torque(tq.limit_length(max_force))


## User: o que o jogador faria apertando E nesta peça. Retorna se usou algo.
func use_part(t: Part) -> bool:
	if t.device:
		t.device.press()
		if t.device.kind == "botao":
			_pressed_device = t.device        # solta quando Usar desligar
		else:
			t.device.release()
		return true
	if t.interact_kind == "chave" and t.node is PowerNode:
		(t.node as PowerNode).toggle()
		return true
	if t.interact_kind == "bomba" and t.assembly() and t.assembly().anchored:
		Drive.refuel(t.global_position, 5.0, 0.2)
		return true
	if t.interact_kind == "engate" and t.mech:
		t.mech.manual = not t.mech.manual
		return true
	return false


func _set_flame(f: float) -> void:
	if flame:
		flame.emitting = f > 0.02
		flame.initial_velocity_min = 1.5 + 3.0 * f
		flame.initial_velocity_max = 2.5 + 4.0 * f


func _set_glow(c: Color, energy: float) -> void:
	if glow == null:
		return
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.emission_enabled = true
		glow.material_override = _mat
	_mat.albedo_color = c.darkened(0.3)
	_mat.emission = c
	_mat.emission_energy_multiplier = energy


func save_state() -> Dictionary:
	match kind:
		"propulsor_vetorial", "gimbal":
			return {"max": max_force}
		"hoverball":
			return {"max": max_force, "h": height, "brake": air_brake}
		"forcer", "user":
			return {"reach": reach}
		"peso":
			return {"mass": mass_default}
	return {}


func load_state(d: Dictionary) -> void:
	max_force = clampf(float(d.get("max", max_force)), 10.0, 100000.0)
	height = clampf(float(d.get("h", height)), 0.1, 100.0)
	air_brake = bool(d.get("brake", air_brake))
	reach = clampf(float(d.get("reach", reach)), 0.5, 100.0)
	mass_default = clampf(float(d.get("mass", mass_default)), 1.0, 2000.0)

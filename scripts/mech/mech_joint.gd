class_name MechJoint
extends RefCounted
## Junta mecânica entre duas peças.
##
## A junta liga a peça "base" (part_a: carcaça) à peça "móvel" (part_b: rotor, haste,
## folha). Como soldar/cortar troca as montagens (corpos rígidos) das peças, a junta
## física do Godot é recriada sempre que isso acontece (rebuild).
##
## Eixo de giro / deslizamento = `axis` (local da part_a), passando por `pivot`.
##
## Tipos:
##   motor        gira com velocidade = valor × velocidade máxima (rígido ou solto sem sinal)
##   servo        vai ao ângulo = valor × ângulo máximo e segura
##   pistao       estica com sinal; sem sinal volta ao início (ou fica parado, se `hold`)
##   servo_linear vai à posição = (valor+1)/2 × curso e segura
##   dobradica    gira livre, com limite (as folhas não se atravessam)
##   pino         dobradiça de pino: gira livre, volta inteira
##   esferica     junta esférica: inclina para qualquer lado (até `max_angle`)
##   trava        dobradiça com trava: livre; com sinal trava no ângulo atual
##   torcao       dobradiça de torção: sempre tenta voltar ao ângulo inicial
##   mola         mola linear (suspensão): comprime com peso e volta
##   guincho      cabo entre o corpo e o gancho; sinal + recolhe, − solta
##   propulsor    (1 peça) empurra na direção do eixo: força = valor × força máx
##   ima          (1 peça) eletroímã: puxa e gruda aço/ferro enquanto ligado
##   engate       (1 peça) engate rápido: trava no que encostar na face (E ou sinal)
##
## Por padrão os dois lados da junta COLIDEM entre si (o que for soldado de um lado bate
## no outro). A opção `collide` desligada deixa passar (ex.: roda encostada na carcaça).
## Pistão/servo linear nunca colidem: a haste corre por dentro da camisa.

const HINGE_SIGN := -1.0          ## sentido do motor da HingeJoint3D em relação ao nosso ângulo
const PISTON_SIGN := 1.0
const HINGE_LIMIT := deg_to_rad(170.0)

const NAMES := {
	"motor": "Motor", "servo": "Servo", "pistao": "Pistão", "servo_linear": "Servo linear",
	"dobradica": "Dobradiça", "pino": "Dobradiça de pino", "esferica": "Junta esférica",
	"trava": "Dobradiça com trava", "torcao": "Dobradiça de torção", "mola": "Mola",
	"guincho": "Guincho", "propulsor": "Propulsor", "ima": "Eletroímã", "engate": "Engate rápido",
}
## Recebem sinal (teclas do assento / fios).
const ACTUATORS := ["motor", "servo", "pistao", "servo_linear", "trava", "guincho", "propulsor", "ima", "engate"]
## Não recebem sinal, mas têm ajustes (botão direito da Fiação).
const CONFIG_ONLY := ["torcao", "mola", "dobradica", "pino", "esferica"]
const ROTARY := ["motor", "servo", "dobradica", "pino", "trava", "torcao"]
const LINEAR := ["pistao", "servo_linear", "mola"]
## Componentes de uma peça só (part_b == part_a), sem junta física.
const SINGLE := ["propulsor", "ima", "engate"]
const MAGNETIC := ["aco", "ferro", "carcaca", "carcaca_azul"]
const ROPE_MIN := 0.25
const MAGNET_RANGE := 0.6
const LOCK_DIST := 0.05
const PROBE_BACK := 0.02
const SPRING_WAKE_TICKS := 30     ## mola parada: confere a cada meio segundo se a carga mudou
const SPRING_GAIN := 4.0          ## mola/torção: quanto maior, menos amortecida

var type := "motor"
var part_a: Part
var part_b: Part
var pivot := Vector3.ZERO         ## ponto do eixo (coordenadas da part_a)
var axis := Vector3.UP            ## eixo (coordenadas da part_a)
var rest := Transform3D.IDENTITY  ## part_b em relação à part_a na posição zero
var joint: Joint3D

## Ajustes (modo edição do assento ou botão direito da Fiação)
var speed := 8.0                  ## motor/servo: rad/s · pistão/servo linear: m/s
var strength := 1500.0            ## motor/servo: torque (N·m) · pistão: força (N)
var max_angle := deg_to_rad(45.0) ## servo / junta esférica
var stroke := 0.5                 ## pistão / servo linear (m)
var invert := false
var toggle := false               ## teclas: alternar em vez de segurar
var hold := false                 ## pistão: sem sinal fica parado (em vez de voltar)
var free_idle := false            ## motor: sem sinal gira solto (em vez de travar)
var lock_idle := false            ## dobradiça com trava: travada sem sinal (o sinal destrava)
var manual := false               ## engate: ligado pela tecla E
var rope_len := 1.0               ## guincho: comprimento atual do cabo (m)
var max_rope := 20.0              ## guincho: comprimento máximo (m)
var hook_anchor := Vector3.ZERO   ## guincho: onde o cabo prende no gancho (local da part_b)

## Efeitos visuais (criados por Components)
var fx: CPUParticles3D            ## chama do propulsor
var indicator: MeshInstance3D     ## luz / face que acende
var coil: Node3D                  ## espiral da mola
var coil_gap := 0.26
var _lock: Joint3D                ## eletroímã / engate: junta temporária com o que grudou
var lock_target: Part
var collide := true               ## os dois lados colidem entre si (pistões nunca)
var _sleep_ticks := 0
static var _fx_mats := {}

## Teclas: até 2 por direção. Cada uma: {"key": physical_keycode} ou {"mouse": botão}.
const MAX_KEYS := 2
var bind_pos: Array = []
var bind_neg: Array = []

## Controles ligados por fio
var sources: Array = []           ## ControlDevice
var routes := {}                  ## ControlDevice -> Array de isoladores (Part) por onde o fio passa

var key_value := 0.0              ## valor vindo das teclas (calculado pelo Build)
var _latched := 0.0
var _prev_pos := false
var _prev_neg := false
var _motor_on := true


func is_actuator() -> bool:
	return type in ACTUATORS


func is_configurable() -> bool:
	return type in ACTUATORS or type in CONFIG_ONLY


func display_name() -> String:
	return NAMES.get(type, type)


func is_valid() -> bool:
	return is_instance_valid(part_a) and is_instance_valid(part_b) \
		and part_a.is_inside_tree() and part_b.is_inside_tree() \
		and not part_a.is_queued_for_deletion() and not part_b.is_queued_for_deletion()


## Pontos do fio de um controle até este componente (passando pelos isoladores).
func wire_points(d: ControlDevice) -> PackedVector3Array:
	var pts := PackedVector3Array([d.part.global_position])
	for ins in routes.get(d, []):
		if is_instance_valid(ins) and (ins as Part).is_inside_tree():
			pts.append(Components.wire_anchor(ins))
	pts.append(part_a.global_position)
	return pts


## Guarda a posição atual como "zero" (chamado ao criar o componente).
func capture_rest() -> void:
	rest = part_a.global_transform.affine_inverse() * part_b.global_transform


func needs_rebuild() -> bool:
	if type in SINGLE or type == "guincho":
		return false   # sem junta física (força calculada à mão / trava temporária)
	var a := part_a.assembly()
	var b := part_b.assembly()
	if a == b:
		return joint != null
	if joint == null or not is_instance_valid(joint):
		return true
	return joint.get_node_or_null(joint.node_a) != a or joint.get_node_or_null(joint.node_b) != b


func destroy() -> void:
	_free_joint()
	_release_lock()


## Tira a junta física da cena NA HORA (se ficasse até o fim do quadro, ao sair ela
## poderia desfazer a "não colisão" da junta nova entre os mesmos corpos).
func _free_joint() -> void:
	if joint and is_instance_valid(joint):
		if joint.get_parent():
			joint.get_parent().remove_child(joint)
		joint.queue_free()
	joint = null


## (Re)cria a junta física entre as montagens atuais das duas peças.
## A junta "nasce" na pose atual; por isso os limites são compensados pela posição atual.
func rebuild(root: Node) -> void:
	_free_joint()
	if type in SINGLE or type == "guincho":
		return
	var a := part_a.assembly()
	var b := part_b.assembly()
	if a == null or b == null or a == b:
		return   # soldadas uma na outra: o componente fica travado
	var xf: Transform3D
	if type == "mola":
		var gm := Generic6DOFJoint3D.new()
		var e := extension()
		gm.set("linear_limit_y/lower_distance", -0.2 - e)
		gm.set("linear_limit_y/upper_distance", 0.12 - e)
		# A "mola" é o motor linear com força = rigidez × compressão (estável em qualquer rigidez).
		gm.set("linear_motor_y/enabled", true)
		gm.set("linear_motor_y/force_limit", 0.0)
		gm.set("linear_motor_y/target_velocity", 0.0)
		joint = gm
		xf = part_a.global_transform * Transform3D(_axis_basis(), pivot)
	elif type in LINEAR:
		var g := Generic6DOFJoint3D.new()
		var ext := extension()
		g.set("linear_limit_y/lower_distance", -ext)
		g.set("linear_limit_y/upper_distance", stroke - ext)
		g.set("linear_motor_y/enabled", true)
		g.set("linear_motor_y/force_limit", strength)
		g.set("linear_motor_y/target_velocity", 0.0)
		joint = g
		xf = part_a.global_transform * Transform3D(_axis_basis(), pivot)
	elif type == "esferica":
		var c := ConeTwistJoint3D.new()
		c.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, max_angle)
		c.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, PI)
		joint = c
		# ConeTwist: o eixo de torção é o X local da junta.
		xf = part_a.global_transform * Transform3D(_twist_basis(), pivot)
	else:
		var h := HingeJoint3D.new()
		var motorized := type in ["motor", "servo", "torcao"]
		h.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, motorized)
		_motor_on = motorized
		h.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, strength / float(Engine.physics_ticks_per_second))
		h.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
		if type in ["dobradica", "trava", "torcao"]:
			# Limite de ±170° em relação ao "zero", compensado pelo ângulo atual.
			var a0 := angle()
			var l1 := HINGE_SIGN * (-HINGE_LIMIT - a0)
			var l2 := HINGE_SIGN * (HINGE_LIMIT - a0)
			h.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
			h.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, minf(l1, l2))
			h.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, maxf(l1, l2))
		joint = h
		# Para o hinge, o eixo é o Z local da junta.
		xf = part_a.global_transform * Transform3D(_hinge_basis(), pivot)
	joint.exclude_nodes_from_collision = not sides_collide()
	root.add_child(joint)
	joint.global_transform = xf
	joint.node_a = joint.get_path_to(a)
	# A junta guarda a pose dos dois lados no momento em que é criada. Para uma folga
	# momentânea (ou um tranco) não virar permanente, ela é criada com o lado b na pose
	# CERTA (só com o movimento permitido) e o corpo volta para onde estava; a junta
	# puxa de volta.
	var actual := b.global_transform
	b.global_transform = ideal_b_transform() * part_b.transform.affine_inverse()
	joint.node_b = joint.get_path_to(b)
	b.global_transform = actual


func sides_collide() -> bool:
	return collide and not type in LINEAR


## Onde a peça b deveria estar agora: igual à pose atual, mas sem folga (só com o
## movimento que a junta permite: giro no eixo, deslizar no eixo ou girar no pivô).
func ideal_b_transform() -> Transform3D:
	var at := part_a.global_transform
	var cur := at.affine_inverse() * part_b.global_transform
	var ax := axis.normalized()
	var rel: Transform3D
	if type in LINEAR:
		var ext := (cur.origin - rest.origin).dot(ax)
		rel = Transform3D(rest.basis, rest.origin + ax * ext)
	elif type == "esferica":
		var rot := cur.basis.orthonormalized() * rest.basis.orthonormalized().inverse()
		var pivot_in_b := rest.affine_inverse() * pivot
		var bb := rot * rest.basis
		rel = Transform3D(bb, pivot - bb * pivot_in_b)
	else:
		var twist := Transform3D(Basis(ax, angle()), Vector3.ZERO)
		rel = Transform3D(Basis(), pivot) * twist * Transform3D(Basis(), -pivot) * rest
	return at * rel


func _axis_basis() -> Basis:
	# Base cujo Y é o eixo (pistão: deslizamento no Y da junta).
	var y := axis.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


func _hinge_basis() -> Basis:
	# Base cujo Z é o eixo (HingeJoint3D gira em torno do Z).
	var z := axis.normalized()
	var x := z.cross(Vector3.UP if absf(z.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, z.cross(x), z)


func _twist_basis() -> Basis:
	# Base cujo X é o eixo (ConeTwistJoint3D torce em torno do X).
	var x := axis.normalized()
	var y := x.cross(Vector3.FORWARD if absf(x.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


## Atualiza a força/torque da junta física depois de mudar `strength` (ou o ângulo da esférica).
func apply_strength() -> void:
	if joint == null or not is_instance_valid(joint):
		return
	if type in LINEAR:
		joint.set("linear_motor_y/force_limit", strength)
	elif type == "esferica":
		(joint as ConeTwistJoint3D).set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, max_angle)
	elif type in ["motor", "servo", "torcao", "trava"]:
		(joint as HingeJoint3D).set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, strength / float(Engine.physics_ticks_per_second))


## Ângulo atual (giratórias) em radianos, em torno do eixo.
func angle() -> float:
	var cur := part_a.global_transform.affine_inverse() * part_b.global_transform
	var q := (cur.basis.orthonormalized() * rest.basis.orthonormalized().inverse()).get_rotation_quaternion()
	return wrapf(2.0 * atan2(Vector3(q.x, q.y, q.z).dot(axis.normalized()), q.w), -PI, PI)


## Extensão atual (lineares), em metros.
func extension() -> float:
	var cur := part_a.global_transform.affine_inverse() * part_b.global_transform
	return (cur.origin - rest.origin).dot(axis.normalized())


## Valor de controle final (-1..1).
func control_value() -> float:
	var v := key_value
	for s: ControlDevice in sources:
		if is_instance_valid(s.part):
			v += s.value
	v = clampf(v, -1.0, 1.0)
	return -v if invert else v


## Tem algum sinal chegando (tecla ou controle)?
func has_input() -> bool:
	if absf(key_value) > 0.001:
		return true
	for s: ControlDevice in sources:
		if is_instance_valid(s.part) and absf(s.value) > 0.001:
			return true
	return false


## Lê as teclas do assento (chamado só quando alguém está sentado na mesma rede).
func read_keys(enabled: bool) -> void:
	var pos := enabled and _any_pressed(bind_pos)
	var neg := enabled and _any_pressed(bind_neg)
	if toggle:
		if pos and not _prev_pos:
			_latched = 0.0 if _latched > 0.5 else 1.0
		if neg and not _prev_neg:
			_latched = 0.0 if _latched < -0.5 else -1.0
		key_value = _latched if enabled else 0.0
	else:
		key_value = (1.0 if pos else 0.0) - (1.0 if neg else 0.0)
	_prev_pos = pos
	_prev_neg = neg


static func _any_pressed(list: Array) -> bool:
	for b: Dictionary in list:
		if _pressed(b):
			return true
	return false


static func _pressed(b: Dictionary) -> bool:
	if b.has("key"):
		return Input.is_physical_key_pressed(b["key"])
	if b.has("mouse"):
		return Input.is_mouse_button_pressed(b["mouse"])
	return false


static func binding_text(b: Dictionary) -> String:
	if b.has("key"):
		var code := DisplayServer.keyboard_get_keycode_from_physical(b["key"])
		return OS.get_keycode_string(code if code != KEY_NONE else b["key"])
	if b.has("mouse"):
		return {MOUSE_BUTTON_LEFT: "Mouse esq.", MOUSE_BUTTON_RIGHT: "Mouse dir.", MOUSE_BUTTON_MIDDLE: "Mouse meio",
			MOUSE_BUTTON_XBUTTON1: "Mouse lat. 1", MOUSE_BUTTON_XBUTTON2: "Mouse lat. 2"}.get(b["mouse"], "Mouse %d" % b["mouse"])
	return "—"


## Aplica o controle à junta física (todo tick de física).
func update(delta: float) -> void:
	match type:
		"guincho":
			_update_winch(delta)
			return
		"propulsor":
			_update_thruster()
			return
		"ima":
			_update_magnet()
			return
		"engate":
			_update_coupler()
			return
		"mola":
			_update_spring()
			return
	if joint == null or not is_instance_valid(joint):
		return
	var v := control_value()
	match type:
		"torcao":
			# Mola de torção: torque máximo do motor = rigidez × ângulo, sempre para o zero.
			var th := angle()
			var h := joint as HingeJoint3D
			h.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, strength * absf(th) * delta)
			h.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, clampf(-th * SPRING_GAIN, -speed, speed) * HINGE_SIGN)
			_spring_wake(absf(th) > 0.05)
		"trava":
			var locked := (v > 0.5) != lock_idle
			if locked != _motor_on:
				_motor_on = locked
				(joint as HingeJoint3D).set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, locked)
				_wake(true)
			if locked:
				(joint as HingeJoint3D).set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
		"motor":
			# Solto: sem sinal, o motor é desligado e o eixo gira livre.
			var on := not free_idle or has_input()
			if on != _motor_on:
				_motor_on = on
				(joint as HingeJoint3D).set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, on)
				_wake(true)
			_set_hinge_velocity(v * speed)
		"servo":
			var err := v * max_angle - angle()
			_set_hinge_velocity(clampf(err * 10.0, -speed, speed))
		"pistao":
			var vel: float
			if hold:
				vel = v * speed                      # sem sinal: fica parado
			else:
				var target := clampf(v, 0.0, 1.0) * stroke
				vel = clampf((target - extension()) * 8.0, -speed, speed)
			_set_linear_velocity(vel)
		"servo_linear":
			var target := (v + 1.0) * 0.5 * stroke
			_set_linear_velocity(clampf((target - extension()) * 8.0, -speed, speed))


func _set_hinge_velocity(w: float) -> void:
	(joint as HingeJoint3D).set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, w * HINGE_SIGN)
	_wake(absf(w) > 0.01)


func _set_linear_velocity(vel: float) -> void:
	joint.set("linear_motor_y/target_velocity", vel * PISTON_SIGN)
	_wake(absf(vel) > 0.01)


func _wake(active: bool) -> void:
	if not active:
		return
	for p in [part_a, part_b]:
		var asm: Assembly = (p as Part).assembly()
		if asm and asm.sleeping and not asm.freeze:
			asm.sleeping = false



# --- Componentes com física calculada à mão ----------------------------------

static func _inv_mass(asm: Assembly) -> float:
	return 0.0 if asm.freeze or asm.mass <= 0.0 else 1.0 / asm.mass


static func _point_velocity(asm: Assembly, p: Vector3) -> Vector3:
	return asm.linear_velocity + asm.angular_velocity.cross(p - asm.world_center_of_mass())


## Quanto um impulso unitário na direção `n`, aplicado em `p`, muda a velocidade desse
## ponto (massa efetiva inversa: translação + rotação).
static func _inv_mass_at(asm: Assembly, p: Vector3, n: Vector3) -> float:
	if asm.freeze or asm.mass <= 0.0:
		return 0.0
	var r := p - asm.world_center_of_mass()
	var state := PhysicsServer3D.body_get_direct_state(asm.get_rid())
	var inv_i: Basis = state.inverse_inertia_tensor if state else Basis.IDENTITY.scaled(Vector3.ONE / asm.mass)
	return 1.0 / asm.mass + (inv_i * r.cross(n)).cross(r).dot(n)


func rope_start() -> Vector3:
	return part_a.global_transform * pivot


func rope_end() -> Vector3:
	return part_b.global_transform * hook_anchor


## Guincho: o cabo só puxa (nunca empurra). Sinal + recolhe, − solta.
func _update_winch(delta: float) -> void:
	var v := control_value()
	var a := part_a.assembly()
	var b := part_b.assembly()
	if a == null or b == null or a == b:
		return
	if absf(v) > 0.01:
		var new_len := clampf(rope_len - v * speed * delta, ROPE_MIN, max_rope)
		if new_len != rope_len:
			rope_len = new_len
			# Pendurado e parado, o gancho dorme: acorda para descer/subir com o cabo.
			for asm: Assembly in [a, b]:
				if not asm.freeze:
					asm.sleeping = false
	var pa := rope_start()
	var pb := rope_end()
	var d := pa.distance_to(pb)
	if d <= rope_len or d < 1e-4:
		return
	var n := (pb - pa) / d
	var inv := _inv_mass_at(a, pa, n) + _inv_mass_at(b, pb, n)
	if inv <= 0.0:
		return
	var vrel := (_point_velocity(b, pb) - _point_velocity(a, pa)).dot(n)
	# Corrige o excesso devagar (folga de 5 mm) para o cabo não dar trancos nem "quicar".
	var lam := maxf(vrel + 0.2 * maxf(d - rope_len - 0.005, 0.0) / delta, 0.0) / inv
	lam = minf(lam, strength * delta)   # força máxima do guincho
	var impulse := n * lam
	if not b.freeze:
		b.apply_impulse(-impulse, pb - b.global_position)
		b.sleeping = false
	if not a.freeze:
		a.apply_impulse(impulse, pa - a.global_position)
		a.sleeping = false


## Propulsor: força ao longo do eixo (chama do lado oposto).
func _update_thruster() -> void:
	var v := control_value()
	if fx:
		fx.emitting = absf(v) > 0.05
	var asm := part_a.assembly()
	if absf(v) < 0.01 or asm == null or asm.freeze:
		return
	var dir := (part_a.global_basis.orthonormalized() * axis).normalized()
	var at := part_a.global_transform * pivot
	asm.apply_force(dir * v * strength, at - asm.global_position)
	asm.sleeping = false


func _face() -> Vector3:
	return part_a.global_transform * pivot


func _face_normal() -> Vector3:
	return (part_a.global_basis.orthonormalized() * axis).normalized()


## Raios saindo da face (centro + 4 pontos). Retorna {part, point, dist} do mais perto.
func _probe_face(length: float, magnetic_only: bool) -> Dictionary:
	var asm := part_a.assembly()
	var n := _face_normal()
	var b := part_a.global_basis.orthonormalized()
	var u := (b.x - n * b.x.dot(n)).normalized()
	var w := n.cross(u)
	var r := 0.08
	var space := part_a.get_world_3d().direct_space_state
	var best := {}
	for off: Vector3 in [Vector3.ZERO, u * r, -u * r, w * r, -w * r]:
		# Começa 2 cm por dentro da face: pega também o que já está encostado/afundado.
		var from := _face() + off - n * PROBE_BACK
		var q := PhysicsRayQueryParameters3D.create(from, from + n * (length + PROBE_BACK), Layers.PARTS, [asm.get_rid()])
		q.hit_from_inside = true
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var p := Build.part_from_collision(hit["collider"], hit["shape"])
		if p == null or (magnetic_only and not p.material_id in MAGNETIC):
			continue
		var dist := maxf(from.distance_to(hit["position"]) - PROBE_BACK, 0.0)
		if best.is_empty() or dist < best["dist"]:
			best = {"part": p, "point": hit["position"], "dist": dist}
	return best


## Eletroímã: ligado, puxa aço/ferro à frente da face e gruda ao encostar.
func _update_magnet() -> void:
	var on := control_value() > 0.5
	_set_indicator(2 if lock_target else (1 if on else 0))
	if not on:
		_release_lock()
		return
	if lock_target:
		_keep_lock()
		return
	var hit := _probe_face(MAGNET_RANGE, true)
	if hit.is_empty():
		return
	if hit["dist"] < LOCK_DIST:
		_make_lock(hit["part"])
		return
	var f: float = strength * (1.0 - float(hit["dist"]) / MAGNET_RANGE)
	var n := _face_normal()
	var tasm: Assembly = (hit["part"] as Part).assembly()
	var asm := part_a.assembly()
	if not tasm.freeze:
		tasm.apply_force(-n * f, (hit["point"] as Vector3) - tasm.global_position)
		tasm.sleeping = false
	if not asm.freeze:
		asm.apply_force(n * f, _face() - asm.global_position)
		asm.sleeping = false


## Engate rápido: ligado (E ou sinal), trava no que encostar na face.
func _update_coupler() -> void:
	var on := manual or control_value() > 0.5
	if not on:
		_release_lock()
		_set_indicator(0)
		return
	if lock_target:
		_keep_lock()
		_set_indicator(2)
		return
	_set_indicator(1)
	var hit := _probe_face(LOCK_DIST + 0.02, false)
	if not hit.is_empty():
		_make_lock(hit["part"])


func is_locked() -> bool:
	return lock_target != null


func _make_lock(target: Part) -> void:
	_release_lock()
	var a := part_a.assembly()
	var b := target.assembly()
	if a == null or b == null or a == b:
		return
	var g := Generic6DOFJoint3D.new()   # tudo travado
	g.exclude_nodes_from_collision = false
	Build.world_root.add_child(g)
	g.global_transform = part_a.global_transform
	g.node_a = g.get_path_to(a)
	g.node_b = g.get_path_to(b)
	_lock = g
	lock_target = target


## Se soldas/cortes trocaram as montagens, refaz a trava na pose atual.
func _keep_lock() -> void:
	if not is_instance_valid(lock_target) or not lock_target.is_inside_tree():
		_release_lock()
		return
	var a := part_a.assembly()
	var b := lock_target.assembly()
	if a == b:
		_release_lock()
		return
	if _lock == null or not is_instance_valid(_lock) \
			or _lock.get_node_or_null(_lock.node_a) != a or _lock.get_node_or_null(_lock.node_b) != b:
		_make_lock(lock_target)


func _release_lock() -> void:
	if _lock and is_instance_valid(_lock):
		_lock.queue_free()
	_lock = null
	lock_target = null


## 0 = desligado, 1 = ligado/armado, 2 = grudado/travado.
func _set_indicator(level: int) -> void:
	if indicator == null or not is_instance_valid(indicator):
		return
	if _fx_mats.is_empty():
		_fx_mats[0] = GameTool.glow_material(Color(0.2, 0.06, 0.05), 0.2)
		_fx_mats[1] = GameTool.glow_material(Color(1.0, 0.75, 0.15), 2.0)
		_fx_mats[2] = GameTool.glow_material(Color(0.3, 1.0, 0.45), 2.5)
	var m: Material = _fx_mats[level]
	if indicator.material_override != m:
		indicator.material_override = m


## Mola: o motor linear empurra de volta com força = rigidez × compressão.
## Parada com peso em cima, força e peso se equilibram (compressão = peso / rigidez).
func _update_spring() -> void:
	var ext := extension()
	if coil and is_instance_valid(coil):
		coil.scale.y = maxf((coil_gap + ext) / coil_gap, 0.1)
	if joint == null or not is_instance_valid(joint):
		return
	# Força limitada ao curso da mola: puxada além do fim (ex.: num tranco), não "explode".
	joint.set("linear_motor_y/force_limit", strength * minf(absf(ext), 0.2))
	joint.set("linear_motor_y/target_velocity", clampf(-ext * SPRING_GAIN, -2.0, 2.0) * PISTON_SIGN)
	_spring_wake(absf(ext) > 0.01)


## Mola/torção paradas (dormindo): a cada meio segundo acordam para ver se a carga
## mudou (ex.: tiraram o peso de cima, o que não acorda os corpos sozinho).
func _spring_wake(deflected: bool) -> void:
	var a := part_a.assembly()
	var b := part_b.assembly()
	if not deflected or a == null or b == null:
		_sleep_ticks = 0
		return
	if not ((a.sleeping or a.freeze) and (b.sleeping or b.freeze)):
		_sleep_ticks = 0
		return
	_sleep_ticks += 1
	if _sleep_ticks < SPRING_WAKE_TICKS:
		return
	_sleep_ticks = 0
	for asm: Assembly in [a, b]:
		if not asm.freeze:
			asm.sleeping = false

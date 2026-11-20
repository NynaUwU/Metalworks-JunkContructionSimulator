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
##
## Os dois lados da junta COLIDEM entre si (o que for soldado de um lado bate no outro).

const HINGE_SIGN := -1.0          ## sentido do motor da HingeJoint3D em relação ao nosso ângulo
const PISTON_SIGN := 1.0
const HINGE_LIMIT := deg_to_rad(170.0)

const NAMES := {
	"motor": "Motor", "servo": "Servo", "pistao": "Pistão", "servo_linear": "Servo linear",
	"dobradica": "Dobradiça", "pino": "Dobradiça de pino", "esferica": "Junta esférica",
}
const ACTUATORS := ["motor", "servo", "pistao", "servo_linear"]
const ROTARY := ["motor", "servo", "dobradica", "pino"]
const LINEAR := ["pistao", "servo_linear"]

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
	var a := part_a.assembly()
	var b := part_b.assembly()
	if a == b:
		return joint != null
	if joint == null or not is_instance_valid(joint):
		return true
	return joint.get_node_or_null(joint.node_a) != a or joint.get_node_or_null(joint.node_b) != b


func destroy() -> void:
	if joint and is_instance_valid(joint):
		joint.queue_free()
	joint = null


## (Re)cria a junta física entre as montagens atuais das duas peças.
## A junta "nasce" na pose atual; por isso os limites são compensados pela posição atual.
func rebuild(root: Node) -> void:
	destroy()
	var a := part_a.assembly()
	var b := part_b.assembly()
	if a == null or b == null or a == b:
		return   # soldadas uma na outra: o componente fica travado
	var xf: Transform3D
	if type in LINEAR:
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
		var motorized := type in ["motor", "servo"]
		h.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, motorized)
		_motor_on = motorized
		h.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, strength / float(Engine.physics_ticks_per_second))
		h.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
		if type == "dobradica":
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
	joint.exclude_nodes_from_collision = false
	root.add_child(joint)
	joint.global_transform = xf
	joint.node_a = joint.get_path_to(a)
	joint.node_b = joint.get_path_to(b)


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
	elif type in ["motor", "servo"]:
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
func update(_delta: float) -> void:
	if joint == null or not is_instance_valid(joint) or not is_actuator():
		return
	var v := control_value()
	match type:
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

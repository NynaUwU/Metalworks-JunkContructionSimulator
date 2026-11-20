class_name MechJoint
extends RefCounted
## Junta mecânica entre duas peças: motor, servo, pistão ou dobradiça livre.
##
## A junta liga a peça "base" (part_a: carcaça) à peça "móvel" (part_b: rotor, braço,
## haste). Como soldar/cortar troca as montagens (corpos rígidos) das peças, a junta
## física do Godot é recriada sempre que isso acontece (rebuild).
##
## Eixo de giro / deslizamento = Y local da part_a, passando por `pivot`.
##
## Controle: valor de -1 a 1 vindo das teclas do assento + controles ligados por fio.
##   motor: velocidade = valor × velocidade máxima
##   servo: ângulo     = valor × ângulo máximo
##   pistão: extensão  = valor (0..1) × curso

const HINGE_SIGN := -1.0          ## sentido do motor da HingeJoint3D em relação ao nosso ângulo
const PISTON_SIGN := 1.0

var type := "motor"               ## "motor", "servo", "pistao", "dobradica"
var part_a: Part
var part_b: Part
var pivot := Vector3.ZERO         ## ponto do eixo (coordenadas da part_a)
var axis := Vector3.UP            ## eixo (coordenadas da part_a)
var rest := Transform3D.IDENTITY  ## part_b em relação à part_a na posição zero
var joint: Joint3D

## Ajustes (editáveis no modo edição do assento)
var speed := 8.0                  ## motor: rad/s · servo: rad/s · pistão: m/s
var strength := 1500.0            ## motor/servo: torque (N·m) · pistão: força (N)
var max_angle := deg_to_rad(45.0) ## servo
var stroke := 0.5                 ## pistão (m)
var invert := false
var toggle := false               ## teclas: alternar em vez de segurar

## Teclas: até 2 por direção. Cada uma: {"key": physical_keycode} ou {"mouse": botão}.
const MAX_KEYS := 2
var bind_pos: Array = []
var bind_neg: Array = []

## Controles ligados por fio
var sources: Array = []           ## ControlDevice

var key_value := 0.0              ## valor vindo das teclas (calculado pelo Build)
var _latched := 0.0
var _prev_pos := false
var _prev_neg := false


func is_actuator() -> bool:
	return type != "dobradica"


func display_name() -> String:
	return {"motor": "Motor", "servo": "Servo", "pistao": "Pistão", "dobradica": "Dobradiça"}[type]


func is_valid() -> bool:
	return is_instance_valid(part_a) and is_instance_valid(part_b) \
		and part_a.is_inside_tree() and part_b.is_inside_tree() \
		and not part_a.is_queued_for_deletion() and not part_b.is_queued_for_deletion()


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
func rebuild(root: Node) -> void:
	destroy()
	var a := part_a.assembly()
	var b := part_b.assembly()
	if a == null or b == null or a == b:
		return   # soldadas uma na outra: o componente fica travado
	var frame := Transform3D(_axis_basis(), pivot)
	var xf := part_a.global_transform * frame
	if type == "pistao":
		var g := Generic6DOFJoint3D.new()
		var ext := extension()
		g.set("linear_limit_y/lower_distance", -ext)
		g.set("linear_limit_y/upper_distance", stroke - ext)
		g.set("linear_motor_y/enabled", true)
		g.set("linear_motor_y/force_limit", strength)
		g.set("linear_motor_y/target_velocity", 0.0)
		joint = g
	else:
		var h := HingeJoint3D.new()
		h.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, type != "dobradica")
		h.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, strength / float(Engine.physics_ticks_per_second))
		h.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
		joint = h
		# Para o hinge, o eixo é o Z local da junta.
		xf = part_a.global_transform * Transform3D(_hinge_basis(), pivot)
	joint.exclude_nodes_from_collision = true
	root.add_child(joint)
	joint.global_transform = xf
	joint.node_a = joint.get_path_to(a)
	joint.node_b = joint.get_path_to(b)


func _axis_basis() -> Basis:
	# Base cujo Y é o eixo (para o pistão: deslizamento no Y da junta).
	var y := axis.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


func _hinge_basis() -> Basis:
	# Base cujo Z é o eixo (HingeJoint3D gira em torno do Z).
	var z := axis.normalized()
	var x := z.cross(Vector3.UP if absf(z.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, z.cross(x), z)


## Atualiza a força/torque da junta física depois de mudar `strength`.
func apply_strength() -> void:
	if joint == null or not is_instance_valid(joint):
		return
	if type == "pistao":
		joint.set("linear_motor_y/force_limit", strength)
	elif type != "dobradica":
		(joint as HingeJoint3D).set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, strength / float(Engine.physics_ticks_per_second))


## Ângulo atual (servo/motor) em radianos, em torno do eixo.
func angle() -> float:
	var cur := part_a.global_transform.affine_inverse() * part_b.global_transform
	var q := (cur.basis.orthonormalized() * rest.basis.orthonormalized().inverse()).get_rotation_quaternion()
	return wrapf(2.0 * atan2(Vector3(q.x, q.y, q.z).dot(axis.normalized()), q.w), -PI, PI)


## Extensão atual do pistão (m).
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
			_set_hinge_velocity(v * speed)
		"servo":
			var err := v * max_angle - angle()
			_set_hinge_velocity(clampf(err * 10.0, -speed, speed))
		"pistao":
			var target := clampf(v, 0.0, 1.0) * stroke
			var vel := clampf((target - extension()) * 8.0, -speed, speed)
			joint.set("linear_motor_y/target_velocity", vel * PISTON_SIGN)
			_wake(absf(vel) > 0.01)


func _set_hinge_velocity(w: float) -> void:
	(joint as HingeJoint3D).set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, w * HINGE_SIGN)
	_wake(absf(w) > 0.01)


func _wake(active: bool) -> void:
	if not active:
		return
	for p in [part_a, part_b]:
		var asm: Assembly = (p as Part).assembly()
		if asm and asm.sleeping and not asm.freeze:
			asm.sleeping = false

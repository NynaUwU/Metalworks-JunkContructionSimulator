class_name Assembly
extends RigidBody3D
## Corpo rígido formado por uma ou mais peças soldadas.
##
## "Segurar" uma peça (Gravitador) é feito aqui: enquanto hold_part != null, a
## montagem ignora a gravidade e é guiada por velocidade até o alvo, ainda colidindo
## com o mundo. O controle é firme: corrige quase todo o erro a cada tick e ainda
## "antecipa" o movimento do alvo (velocidade do alvo), então não fica atrasado
## como se estivesse pendurado numa corda.

const HOLD_LINEAR_GAIN := 0.75    ## fração do erro de posição corrigida por tick
const HOLD_ANGULAR_GAIN := 0.7
const HOLD_MAX_SPEED := 90.0
const HOLD_MAX_SPIN := 40.0

static var _physics_material: PhysicsMaterial
static var _rubber_material: PhysicsMaterial

var anchored := false             ## soldada ao chão: fica parada
var frozen := false               ## congelada pelo Gravitador (botão direito)
var hold_part: Part = null
var hold_grab_local := Vector3.ZERO
var hold_target := Transform3D.IDENTITY
var _last_target := Transform3D.IDENTITY
var _has_last_target := false


func _init() -> void:
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	collision_layer = Layers.PARTS
	collision_mask = Layers.WORLD | Layers.PARTS | Layers.PLAYER
	if _physics_material == null:
		_physics_material = PhysicsMaterial.new()
		_physics_material.friction = 0.85
		_physics_material.bounce = 0.0
	physics_material_override = _physics_material
	angular_damp = 0.4
	linear_damp = 0.05


func get_parts() -> Array[Part]:
	var out: Array[Part] = []
	for c in get_children():
		if c is Part and not c.is_queued_for_deletion():
			out.append(c)
	return out


## Recalcula massa e centro de massa a partir das peças.
func recompute() -> void:
	var total := 0.0
	var com := Vector3.ZERO
	for p in get_parts():
		total += p.mass
		com += (p.transform * p.local_centroid) * p.mass
	if total <= 0.0:
		return
	mass = total
	center_of_mass = com / total
	var has_wheel := false
	for p in get_parts():
		if p.kind == "roda":
			has_wheel = true
			break
	if has_wheel:
		if _rubber_material == null:
			_rubber_material = PhysicsMaterial.new()
			_rubber_material.friction = 1.4
			_rubber_material.bounce = 0.0
		physics_material_override = _rubber_material
	else:
		physics_material_override = _physics_material


func set_anchored(value: bool) -> void:
	anchored = value
	if value:
		clear_hold()
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	freeze = anchored or frozen


func set_frozen(value: bool) -> void:
	frozen = value
	if value:
		clear_hold()
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	freeze = anchored or frozen
	if not freeze:
		sleeping = false


func is_held() -> bool:
	return hold_part != null


func set_hold(part: Part, grab_local: Vector3, target: Transform3D) -> void:
	if part != hold_part or not grab_local.is_equal_approx(hold_grab_local):
		_has_last_target = false   # alvo novo: sem "antecipação" no primeiro tick
	hold_part = part
	hold_grab_local = grab_local
	hold_target = target
	if gravity_scale != 0.0:
		gravity_scale = 0.0
	if can_sleep:
		can_sleep = false
	if sleeping:
		sleeping = false


func clear_hold() -> void:
	_has_last_target = false
	hold_part = null
	gravity_scale = 1.0
	can_sleep = true


## Centro de massa em coordenadas do mundo.
func world_center_of_mass() -> Vector3:
	return global_transform * center_of_mass


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if hold_part == null:
		return
	if not is_instance_valid(hold_part) or hold_part.get_parent() != self:
		clear_hold()
		return
	var dt := state.step
	var cur: Transform3D = state.transform * hold_part.transform

	# Antecipação: quanto o alvo andou/girou desde o último tick.
	var q_tgt := hold_target.basis.orthonormalized().get_rotation_quaternion()
	var ff_v := Vector3.ZERO
	var ff_w := Vector3.ZERO
	if _has_last_target:
		ff_v = (hold_target * hold_grab_local - _last_target * hold_grab_local) / dt
		ff_w = _angular_velocity_between(_last_target.basis.orthonormalized().get_rotation_quaternion(), q_tgt, dt)
	_last_target = hold_target
	_has_last_target = true

	# Rotação: erro entre a orientação atual e a desejada.
	var q_cur := cur.basis.orthonormalized().get_rotation_quaternion()
	var q_err := (q_tgt * q_cur.inverse()).normalized()
	if q_err.w < 0.0:
		q_err = -q_err
	var w := ff_w
	var axis := Vector3(q_err.x, q_err.y, q_err.z)
	if axis.length_squared() > 1e-12:
		var angle := 2.0 * acos(clampf(q_err.w, -1.0, 1.0))
		w += axis.normalized() * angle / dt * HOLD_ANGULAR_GAIN
	w = w.limit_length(HOLD_MAX_SPIN)

	# Posição: leva o ponto de pega até o alvo.
	var grab_cur := cur * hold_grab_local
	var grab_tgt := hold_target * hold_grab_local
	var v_point := ((grab_tgt - grab_cur) / dt * HOLD_LINEAR_GAIN + ff_v).limit_length(HOLD_MAX_SPEED)
	var com := state.transform.origin + state.center_of_mass
	state.angular_velocity = w
	state.linear_velocity = v_point - w.cross(grab_cur - com)


static func _angular_velocity_between(q_from: Quaternion, q_to: Quaternion, dt: float) -> Vector3:
	var d := (q_to * q_from.inverse()).normalized()
	if d.w < 0.0:
		d = -d
	var axis := Vector3(d.x, d.y, d.z)
	if axis.length_squared() < 1e-12:
		return Vector3.ZERO
	return axis.normalized() * 2.0 * acos(clampf(d.w, -1.0, 1.0)) / dt

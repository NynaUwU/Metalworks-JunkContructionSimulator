class_name Assembly
extends RigidBody3D
## Corpo rígido formado por uma ou mais peças soldadas.
##
## "Segurar" uma peça (estilo Physics Gun) é feito aqui: enquanto hold_part != null,
## a montagem ignora a gravidade e é guiada por velocidade até o alvo. Isso mantém a
## peça "flutuando" e ainda colidindo com o mundo.

const HOLD_LINEAR_GAIN := 0.35    ## fração do erro de posição corrigida por tick
const HOLD_ANGULAR_GAIN := 0.3
const HOLD_MAX_SPEED := 30.0
const HOLD_MAX_SPIN := 18.0

static var _physics_material: PhysicsMaterial
static var _rubber_material: PhysicsMaterial

var anchored := false             ## soldada ao chão: fica parada (congelada)
var hold_part: Part = null
var hold_grab_local := Vector3.ZERO
var hold_target := Transform3D.IDENTITY


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
	freeze = value


func is_held() -> bool:
	return hold_part != null


func set_hold(part: Part, grab_local: Vector3, target: Transform3D) -> void:
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

	# Rotação: erro entre a orientação atual e a desejada.
	var q_cur := cur.basis.orthonormalized().get_rotation_quaternion()
	var q_tgt := hold_target.basis.orthonormalized().get_rotation_quaternion()
	var q_err := (q_tgt * q_cur.inverse()).normalized()
	if q_err.w < 0.0:
		q_err = -q_err
	var w := Vector3.ZERO
	var axis := Vector3(q_err.x, q_err.y, q_err.z)
	if axis.length_squared() > 1e-12:
		var angle := 2.0 * acos(clampf(q_err.w, -1.0, 1.0))
		w = axis.normalized() * angle / dt * HOLD_ANGULAR_GAIN
	w = w.limit_length(HOLD_MAX_SPIN)

	# Posição: leva o ponto de pega até o alvo.
	var grab_cur := cur * hold_grab_local
	var grab_tgt := hold_target * hold_grab_local
	var v_point := ((grab_tgt - grab_cur) / dt * HOLD_LINEAR_GAIN).limit_length(HOLD_MAX_SPEED)
	var com := state.transform.origin + state.center_of_mass
	state.angular_velocity = w
	state.linear_velocity = v_point - w.cross(grab_cur - com)

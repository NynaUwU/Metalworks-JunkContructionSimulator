class_name Assembly
extends RigidBody3D
## Corpo rígido formado por uma ou mais peças soldadas.
##
## Enquanto o Gravitador carrega a montagem (`carried`), ela fica sem gravidade e sem
## dormir; quem mexe na velocidade é o Gravitador (que move a máquina inteira junto).

static var _physics_material: PhysicsMaterial
static var _rubber_material: PhysicsMaterial

var anchored := false             ## soldada ao chão: fica parada
var frozen := false               ## congelada pelo Gravitador (botão direito)
var carried := false              ## sendo carregada pelo Gravitador
var hold_part: Part = null        ## (compatibilidade) peça segurada nesta montagem


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
	return carried


## O Gravitador começou/parou de carregar esta montagem.
func set_carried(value: bool) -> void:
	if carried == value:
		return
	carried = value
	gravity_scale = 0.0 if value else 1.0
	can_sleep = not value
	if value and sleeping:
		sleeping = false


func clear_hold() -> void:
	hold_part = null
	set_carried(false)


## Centro de massa em coordenadas do mundo.
func world_center_of_mass() -> Vector3:
	return global_transform * center_of_mass

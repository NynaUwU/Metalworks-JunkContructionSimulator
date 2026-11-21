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
## Balanceamento de massa (Build.balance_masses): peças muito mais leves que o que está
## do outro lado de uma junta ganham "massa de inércia" só para a física, com a gravidade
## compensada (o peso é o mesmo). Sem isso, o solver deixa a junta ceder sob carga.
var mass_boost := 1.0
var _part_mass := 1.0
var hold_part: Part = null        ## (compatibilidade) peça segurada nesta montagem


func _init() -> void:
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	# Colisão contínua: chapas finas rápidas não atravessam umas às outras. Desligada em
	# montagens com juntas (Build.balance_masses): ela "volta" o corpo ao ponto do impacto
	# ignorando a junta, e a máquina desmonta em batidas fortes.
	continuous_cd = true
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
	_part_mass = total
	mass = total * mass_boost
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


## Massa de verdade (soma das peças), sem o balanceamento.
func real_mass() -> float:
	return _part_mass


func set_mass_boost(f: float) -> void:
	if is_equal_approx(f, mass_boost):
		return
	mass_boost = f
	mass = _part_mass * f
	_apply_gravity()


func _apply_gravity() -> void:
	gravity_scale = 0.0 if carried else 1.0 / mass_boost


func set_anchored(value: bool) -> void:
	anchored = value
	if value:
		clear_hold()
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	freeze = anchored or frozen
	Build.request_balance()


func set_frozen(value: bool) -> void:
	frozen = value
	if value:
		clear_hold()
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	freeze = anchored or frozen
	if not freeze:
		sleeping = false
	Build.request_balance()


func is_held() -> bool:
	return carried


## O Gravitador começou/parou de carregar esta montagem.
func set_carried(value: bool) -> void:
	if carried == value:
		return
	carried = value
	_apply_gravity()
	can_sleep = not value
	if value and sleeping:
		sleeping = false


func clear_hold() -> void:
	hold_part = null
	set_carried(false)


## Centro de massa em coordenadas do mundo.
func world_center_of_mass() -> Vector3:
	return global_transform * center_of_mass

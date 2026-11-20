class_name ShopStation
extends Node3D
## Loja: um terminal (aperte E) e uma plataforma de ENTREGA onde os itens comprados aparecem.

const PAD_OFFSET := Vector3(0, 0, -4.2)   ## posição da plataforma de entrega (local)
const PAD_SIZE := 3.2

var terminal: StaticBody3D
var _recent: Array = []          ## [peça, tempo] das entregas recentes (a física ainda não as vê)


func _ready() -> void:
	var body_mat := StationBuilder.mat(Color(0.2, 0.22, 0.26), 0.5, 0.6)
	var screen_mat := StationBuilder.mat(Color(0.25, 0.65, 1.0), 0.4, 0.0, 1.6)
	var stripe := StationBuilder.mat(Color(0.95, 0.72, 0.1), 0.6, 0.1)
	var pad_mat := StationBuilder.mat(Color(0.28, 0.29, 0.31), 0.8, 0.3)

	# Terminal
	terminal = StationBuilder.solid_box(self, Vector3(1.0, 1.5, 0.6), Vector3(0, 0.75, 0), body_mat)
	terminal.set_meta("interact", "shop")
	terminal.set_meta("interact_label", "abrir a loja")
	var screen := StationBuilder.visual_box(Vector3(0.8, 0.5, 0.02), Vector3(0, 0.45, 0.31), screen_mat)
	screen.rotation.x = deg_to_rad(-12)
	terminal.add_child(screen)
	StationBuilder.label_sign(self, "LOJA", Vector3(0, 2.25, 0))
	StationBuilder.label_sign(self, "aperte E no terminal", Vector3(0, 1.85, 0), 38, Color(1, 1, 1, 0.85))

	# Plataforma de entrega (dá para soldar nela, como no chão)
	var pad := StationBuilder.solid_box(self, Vector3(PAD_SIZE, 0.08, PAD_SIZE), PAD_OFFSET + Vector3(0, 0.04, 0), pad_mat)
	pad.add_to_group("ground")
	for s: float in [-1.0, 1.0]:
		add_child(StationBuilder.visual_box(Vector3(PAD_SIZE, 0.085, 0.12), PAD_OFFSET + Vector3(0, 0.04, s * (PAD_SIZE * 0.5 - 0.06)), stripe))
		add_child(StationBuilder.visual_box(Vector3(0.12, 0.085, PAD_SIZE), PAD_OFFSET + Vector3(s * (PAD_SIZE * 0.5 - 0.06), 0.04, 0), stripe))
	StationBuilder.label_sign(self, "ENTREGA", PAD_OFFSET + Vector3(0, 1.2, -PAD_SIZE * 0.5), 56)


## Tenta comprar o item (com o tamanho escolhido, se ajustável). Retorna a peça criada (ou null).
func buy(item_id: String, size := Vector3.ZERO) -> Part:
	var item := Catalog.get_item(item_id)
	if item.is_empty() or Catalog.is_locked(item):
		return null
	size = Catalog.clamp_size(item, size)
	var cost := Catalog.price(item, size)
	if not Economy.can_afford(cost):
		Build.message.emit("Pontos insuficientes (precisa de %d)" % cost)
		return null
	var xf := _free_spawn_transform(item, size)
	var part: Part
	if Catalog.is_component(item):
		var parts := Components.spawn(item["component"], xf, size)
		part = parts[0] if not parts.is_empty() else null
	else:
		part = Build.spawn_planes(Catalog.planes(item, size), item["mat"], xf)
	if part == null:
		return null
	_recent.append([part, Time.get_ticks_msec()])
	Economy.spend(cost)
	StationBuilder.sparks(get_parent(), xf.origin, 25, Color(0.4, 0.8, 1.0))
	Build.message.emit("Comprado: %s (−%d pontos): está na ENTREGA" % [item["nome"], cost])
	return part


func _hits_recent(box: AABB) -> bool:
	for e: Array in _recent:
		var p: Part = e[0]
		if (p.global_transform * p.bounds).grow(0.02).intersects(box):
			return true
	return false


## Procura uma altura livre acima da plataforma para o item aparecer.
func _free_spawn_transform(item: Dictionary, size: Vector3) -> Transform3D:
	var aabb := Catalog.spawn_bounds(item, size)
	var shape := BoxShape3D.new()
	shape.size = aabb.size
	var base := global_transform * PAD_OFFSET
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = Layers.PARTS | Layers.PLAYER
	var space := get_world_3d().direct_space_state
	var now := Time.get_ticks_msec()
	_recent = _recent.filter(func(e: Array) -> bool: return is_instance_valid(e[0]) and now - int(e[1]) < 1500)
	var y := 0.1 - aabb.position.y
	for i in 12:
		var xf := Transform3D(global_transform.basis, base + Vector3(0, y, 0))
		params.transform = xf * Transform3D(Basis(), aabb.get_center())
		if space.intersect_shape(params, 1).is_empty() and not _hits_recent(xf * aabb):
			return xf
		y += 0.6
	return Transform3D(global_transform.basis, base + Vector3(0, y, 0))

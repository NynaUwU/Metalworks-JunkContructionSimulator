class_name Recycler
extends Node3D
## Reciclador: toda peça que cai no funil é triturada e vira pontos.
## Peças soldadas a outras são recicladas uma a uma (só as que estão dentro do funil).

const SIZE := 4.0                 ## largura externa do funil
const FLOOR_Y := 0.6              ## altura do fundo do funil
const WALL_TOP := 1.4             ## altura da borda
const WALL := 0.2                 ## espessura das paredes

## Volume interno do funil (coordenadas locais): o centro da peça precisa estar aqui.
var intake := AABB(
	Vector3(-SIZE * 0.5 + WALL, FLOOR_Y - 0.05, -SIZE * 0.5 + WALL),
	Vector3(SIZE - WALL * 2.0, WALL_TOP - FLOOR_Y + 0.25, SIZE - WALL * 2.0))

var _area: Area3D
var _rollers: Array[Node3D] = []
var _total_label: Label3D
var _recycled_total := 0.0


func _ready() -> void:
	var body_mat := StationBuilder.mat(Color(0.18, 0.33, 0.24), 0.6, 0.4)
	var rim_mat := StationBuilder.mat(Color(0.95, 0.72, 0.1), 0.5, 0.2)
	var dark := StationBuilder.mat(Color(0.08, 0.08, 0.09), 0.9, 0.2)
	var steel := StationBuilder.mat(Color(0.55, 0.57, 0.6), 0.35, 0.9)

	# Corpo (o fundo do funil é o topo do corpo)
	StationBuilder.solid_box(self, Vector3(SIZE, FLOOR_Y, SIZE), Vector3(0, FLOOR_Y * 0.5, 0), body_mat)
	add_child(StationBuilder.visual_box(Vector3(SIZE - WALL * 2.0, 0.02, SIZE - WALL * 2.0), Vector3(0, FLOOR_Y + 0.011, 0), dark))

	# Paredes do funil com borda amarela
	var h := WALL_TOP - FLOOR_Y
	var y := FLOOR_Y + h * 0.5
	var off := SIZE * 0.5 - WALL * 0.5
	StationBuilder.solid_box(self, Vector3(WALL, h, SIZE), Vector3(off, y, 0), body_mat)
	StationBuilder.solid_box(self, Vector3(WALL, h, SIZE), Vector3(-off, y, 0), body_mat)
	StationBuilder.solid_box(self, Vector3(SIZE - WALL * 2.0, h, WALL), Vector3(0, y, off), body_mat)
	StationBuilder.solid_box(self, Vector3(SIZE - WALL * 2.0, h, WALL), Vector3(0, y, -off), body_mat)
	for s: float in [-1.0, 1.0]:
		add_child(StationBuilder.visual_box(Vector3(WALL + 0.02, 0.08, SIZE + 0.02), Vector3(off * s, WALL_TOP + 0.04, 0), rim_mat))
		add_child(StationBuilder.visual_box(Vector3(SIZE + 0.02, 0.08, WALL + 0.02), Vector3(0, WALL_TOP + 0.04, off * s), rim_mat))

	# Rolos trituradores (só visuais)
	for z: float in [-0.45, 0.45]:
		var roller := Node3D.new()
		roller.position = Vector3(0, FLOOR_Y + 0.12, z)
		add_child(roller)
		var cyl := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.28
		cm.bottom_radius = 0.28
		cm.height = SIZE - WALL * 2.0 - 0.1
		cm.radial_segments = 12
		cyl.mesh = cm
		cyl.material_override = steel
		cyl.rotation.z = PI * 0.5
		roller.add_child(cyl)
		for k in 6:
			var tooth := StationBuilder.visual_box(Vector3(SIZE - WALL * 2.0 - 0.2, 0.12, 0.08), Vector3.ZERO, dark)
			tooth.rotation.x = TAU * k / 6.0
			tooth.position = Vector3(0, cos(TAU * k / 6.0), sin(TAU * k / 6.0)) * 0.3
			roller.add_child(tooth)
		_rollers.append(roller)

	StationBuilder.label_sign(self, "RECICLADOR", Vector3(0, WALL_TOP + 2.2, 0))
	_total_label = StationBuilder.label_sign(self, "jogue sucata aqui = pontos", Vector3(0, WALL_TOP + 1.75, 0), 40, Color(1, 1, 1, 0.85))

	# Sensor de peças
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = Layers.PARTS
	_area.monitorable = false
	add_child(_area)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = intake.size
	cs.shape = bs
	cs.position = intake.get_center()
	_area.add_child(cs)


func _process(delta: float) -> void:
	for i in _rollers.size():
		_rollers[i].rotate_x(delta * (5.0 if i == 0 else -5.0))


func _physics_process(_delta: float) -> void:
	var to_recycle: Array[Part] = []
	var inv := global_transform.affine_inverse()
	for body in _area.get_overlapping_bodies():
		var asm := body as Assembly
		if asm == null or asm.is_queued_for_deletion():
			continue
		for p in asm.get_parts():
			var center := inv * (p.global_transform * p.local_centroid)
			if intake.has_point(center):
				to_recycle.append(p)
	for p in to_recycle:
		recycle(p)


func recycle(part: Part) -> void:
	var value := Economy.recycle_value(part.material_id, part.mass)
	var where := part.global_transform * part.local_centroid
	var label := "%s %d kg" % [part.display_name(), roundi(part.mass)]
	Build.delete_part(part)
	Economy.add(value)
	_recycled_total += value
	var parent := get_parent()
	StationBuilder.sparks(parent, where, 35)
	StationBuilder.popup(parent, "+%s" % _format(value), where + Vector3(0, 0.6, 0))
	Build.message.emit("Reciclado: %s  ·  +%s pontos" % [label, _format(value)])


func _format(v: float) -> String:
	return str(roundi(v)) if v >= 10.0 else ("%.1f" % v)

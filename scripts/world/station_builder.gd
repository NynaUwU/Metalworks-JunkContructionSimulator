class_name StationBuilder
extends RefCounted
## Utilidades para montar máquinas fixas do mapa (reciclador, loja...) com caixas simples.


static func mat(color: Color, rough := 0.7, metal := 0.3, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


## Caixa estática com colisão (camada WORLD). Não entra no grupo "ground", então
## não serve de ponto de ancoragem para solda.
static func solid_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	parent.add_child(body)
	body.position = pos
	body.rotation = rot
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.add_child(visual_box(size, Vector3.ZERO, material))
	return body


static func visual_box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	return mi


static func label_sign(parent: Node3D, text: String, pos: Vector3, size := 72, color := Color(1, 0.75, 0.3)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = pos
	parent.add_child(l)
	return l


## Texto que sobe e some (ex.: "+12").
static func popup(parent: Node, text: String, at: Vector3, color := Color(0.5, 1.0, 0.55)) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.005
	l.modulate = color
	l.outline_size = 16
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	parent.add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", at + Vector3(0, 1.4, 0), 1.3)
	tw.tween_property(l, "modulate:a", 0.0, 1.3).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


## Faíscas simples (para máquinas do mapa).
static func sparks(parent: Node, at: Vector3, amount := 30, color := Color(1.0, 0.62, 0.2)) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 0.85
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -9.8, 0)
	var quad := BoxMesh.new()
	quad.size = Vector3(0.015, 0.015, 0.06)
	p.mesh = quad
	p.material_override = GameTool.glow_material(color, 4.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

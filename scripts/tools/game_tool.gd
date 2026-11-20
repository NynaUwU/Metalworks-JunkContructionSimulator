class_name GameTool
extends Node3D
## Base das ferramentas. Cada ferramenta é filha da câmera (para o modelo em 1ª pessoa).

const VIEW_POS := Vector3(0.24, -0.2, -0.42)   ## posição do modelo na tela

var player: Player
var tool_name := "Ferramenta"
var key_hint := ""
var viewmodel: Node3D
var muzzle: Node3D           ## ponta da ferramenta (para efeitos)


func _init(p_player: Player) -> void:
	player = p_player


func _ready() -> void:
	viewmodel = Node3D.new()
	viewmodel.position = VIEW_POS
	viewmodel.scale = Vector3.ONE * 0.55
	viewmodel.rotation_degrees = Vector3(0, 4, 0)
	add_child(viewmodel)
	muzzle = Node3D.new()
	viewmodel.add_child(muzzle)
	_build_viewmodel()
	visible = false


## Sobrescrever: monta o modelo 3D simples da ferramenta.
func _build_viewmodel() -> void:
	pass


func equip() -> void:
	visible = true


func unequip() -> void:
	visible = false


## Retorna true se consumiu o evento.
func handle_input(_event: InputEvent) -> bool:
	return false


func physics_update(_delta: float) -> void:
	pass


## true quando a ferramenta está usando WASD (ex.: girando peça).
func blocks_movement() -> bool:
	return false


func hint_text() -> String:
	return ""


## Progresso de uma ação demorada (0..1) para a mira mostrar; -1 = nenhuma.
func progress() -> float:
	return -1.0


# --- utilidades para montar modelos -------------------------------------------

static func make_box(size: Vector3, color: Color, metallic := 0.6, rough := 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color, metallic, rough)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func make_cylinder(radius: float, height: float, color: Color, metallic := 0.6, rough := 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = _mat(color, metallic, rough)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _mat(color: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	return m


static func glow_material(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static var _star: ImageTexture

## Textura de faísca em forma de estrela (gerada em código, sem arquivo).
static func star_texture() -> ImageTexture:
	if _star:
		return _star
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := (x - n * 0.5 + 0.5) / (n * 0.5)
			var dy := (y - n * 0.5 + 0.5) / (n * 0.5)
			var core := exp(-(dx * dx + dy * dy) * 18.0)
			var arms := exp(-absf(dx) * 22.0) * exp(-absf(dy) * 3.0) + exp(-absf(dy) * 22.0) * exp(-absf(dx) * 3.0)
			var diag := exp(-absf(dx - dy) * 16.0) * exp(-absf(dx + dy) * 5.0) + exp(-absf(dx + dy) * 16.0) * exp(-absf(dx - dy) * 5.0)
			var a := clampf(core + arms * 0.75 + diag * 0.3, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_star = ImageTexture.create_from_image(img)
	return _star


## Material de faísca: brilho aditivo, sempre virado para a câmera e sem fog.
static func star_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = star_texture()
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.no_depth_test = false
	return m


## Faíscas (efeito de solda/corte).
func spawn_sparks(at: Vector3, normal: Vector3, amount := 40, color := Color(1.0, 0.62, 0.2)) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.55
	p.explosiveness = 0.9
	p.direction = normal
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var quad := BoxMesh.new()
	quad.size = Vector3(0.012, 0.012, 0.05)
	p.mesh = quad
	p.particle_flag_align_y = false
	p.material_override = glow_material(color, 4.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

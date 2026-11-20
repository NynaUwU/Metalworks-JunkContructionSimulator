class_name PartPreview
extends SubViewport
## Mini cena 3D isolada para mostrar uma peça: ícones da loja e prévia girando.

var spin := true
var _pivot: Node3D
var _mesh: MeshInstance3D


func _init(px := 256, p_spin := true) -> void:
	size = Vector2i(px, px)
	spin = p_spin
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.64, 0.7)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, 35, 0)
	key.light_energy = 1.4
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -140, 0)
	fill.light_energy = 0.5
	fill.light_color = Color(0.75, 0.85, 1.0)
	add_child(fill)

	var cam := Camera3D.new()
	cam.fov = 32.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.8, 3.8), Vector3.ZERO)

	_pivot = Node3D.new()
	_pivot.rotation_degrees = Vector3(0, -35, 0)
	add_child(_pivot)
	_mesh = MeshInstance3D.new()
	_pivot.add_child(_mesh)


## Mostra uma geometria (de ConvexGeo.solve) escalada para caber na imagem.
func show_geometry(geo: Dictionary, material_id: String) -> void:
	if geo.is_empty():
		_mesh.mesh = null
		return
	var mesh := ConvexGeo.build_mesh(geo)
	mesh.surface_set_material(0, MetalMaterials.get_material(material_id))
	mesh.surface_set_material(1, MetalMaterials.edge_material())
	_mesh.mesh = mesh
	var aabb: AABB = geo["aabb"]
	var s := 1.9 / maxf(aabb.get_longest_axis_size(), 0.01)
	_mesh.scale = Vector3.ONE * s
	_mesh.position = -aabb.get_center() * s


func _process(delta: float) -> void:
	if spin and _pivot:
		_pivot.rotate_y(delta * 0.7)

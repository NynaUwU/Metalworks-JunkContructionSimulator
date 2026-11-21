class_name Part
extends CollisionShape3D
## Uma peça física (chapa, viga, bloco...).
##
## A peça é a forma de colisão dentro de uma Assembly (RigidBody3D). Peças soldadas
## entre si ficam na MESMA Assembly e por isso se movem como um único corpo rígido.

var material_id := "aco"
var kind := "metal"          ## "metal", "motor", "servo", "pistao", "dobradica", "roda", "assento", "botao"...
var label := ""              ## nome mostrado no HUD (componentes); vazio = nome do material
var cuttable := true
var mech: MechJoint = null   ## junta mecânica da qual esta peça faz parte (componentes)
var device: ControlDevice = null   ## botão / alavanca / potenciômetro
var node: SignalNode = null        ## chip, tela, assento... (nó de sinal desta peça)
var interact_kind := ""      ## "assento", "botao"... (tecla F)
var planes: Array[Plane] = []
var volume := 0.0
var mass := 1.0
var local_centroid := Vector3.ZERO
var bounds := AABB()
var welds: Array = []        ## Weld conectadas a esta peça

## Componente de origem (para salvar/carregar). Peça comum: comp_kind vazio.
var comp_kind := ""
var comp_index := -1                     ## posição no Array devolvido por Components.spawn
var comp_group := 0                      ## igual para todas as peças do mesmo componente
var comp_offset := Transform3D.IDENTITY  ## pose ao nascer, em relação à origem do componente
var comp_size := Vector3.ZERO            ## medidas pedidas (rodas) ou tamanho (peças mecânicas)

## Marcas da Trena (para guiar cortes): [posição local, normal local] de cada uma.
var marks: Array = []
var _mark_nodes: Array = []
static var _mark_mat: StandardMaterial3D

var mesh_instance: MeshInstance3D


## Monta a peça a partir de planos. Retorna false se a forma for inválida.
func setup_from_planes(p_planes: Array[Plane], p_material: String) -> bool:
	var geo := ConvexGeo.solve(p_planes)
	if geo.is_empty():
		return false
	apply_geometry(geo, p_material)
	return true


func apply_geometry(geo: Dictionary, p_material: String) -> void:
	material_id = p_material
	planes = geo["planes"]
	volume = geo["volume"]
	local_centroid = geo["centroid"]
	bounds = geo["aabb"]
	mass = maxf(volume * MetalMaterials.density(material_id), 0.05)

	var s := ConvexPolygonShape3D.new()
	s.points = geo["verts"]
	shape = s

	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		add_child(mesh_instance)
	var mesh := ConvexGeo.build_mesh(geo)
	mesh.surface_set_material(0, MetalMaterials.get_material(material_id))
	mesh.surface_set_material(1, MetalMaterials.edge_material())
	mesh_instance.mesh = mesh


## Peça cilíndrica (rodas, discos). Eixo do cilindro = Y local. Não pode ser cortada.
func setup_cylinder(radius: float, height: float, p_material: String) -> void:
	material_id = p_material
	cuttable = false
	planes = []
	volume = PI * radius * radius * height
	local_centroid = Vector3.ZERO
	bounds = AABB(Vector3(-radius, -height * 0.5, -radius), Vector3(radius * 2.0, height, radius * 2.0))
	mass = maxf(volume * MetalMaterials.density(material_id), 0.05)
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	shape = s
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		add_child(mesh_instance)
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 28
	cm.rings = 1
	mesh_instance.mesh = cm
	mesh_instance.material_override = MetalMaterials.get_material(material_id)


## Malha extra só visual, presa à peça (detalhes de componentes).
func add_visual(mesh: Mesh, xform: Transform3D, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform
	mi.material_override = material
	add_child(mi)
	return mi


## Põe uma marca (cruz vermelha) na superfície, em coordenadas locais.
func add_mark(local_pos: Vector3, local_n: Vector3) -> void:
	marks.append([local_pos, local_n.normalized()])
	_add_mark_node(local_pos, local_n.normalized())


func remove_mark(index: int) -> void:
	if index < 0 or index >= marks.size():
		return
	marks.remove_at(index)
	var n: Node = _mark_nodes[index]
	_mark_nodes.remove_at(index)
	if is_instance_valid(n):
		n.queue_free()


## Marca mais perto de um ponto local (índice, ou -1 se nenhuma está a menos de `max_d`).
func nearest_mark(local_pos: Vector3, max_d: float) -> int:
	var best := -1
	var best_d := max_d
	for i in marks.size():
		var d := (marks[i][0] as Vector3).distance_to(local_pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func _add_mark_node(p: Vector3, n: Vector3) -> void:
	if _mark_mat == null:
		_mark_mat = StandardMaterial3D.new()
		_mark_mat.albedo_color = Color(1.0, 0.1, 0.08)
		_mark_mat.emission_enabled = true
		_mark_mat.emission = Color(1.0, 0.1, 0.08)
		_mark_mat.emission_energy_multiplier = 1.2
		_mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var x := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var root := Node3D.new()
	root.transform = Transform3D(Basis(x, n, x.cross(n)).orthonormalized(), p + n * 0.002)
	for ang in [PI * 0.25, -PI * 0.25]:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.003, 0.008)
		bar.mesh = bm
		bar.material_override = _mark_mat
		bar.rotation.y = ang
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bar)
	add_child(root)
	_mark_nodes.append(root)


func assembly() -> Assembly:
	return get_parent() as Assembly


func display_name() -> String:
	return label if label != "" else MetalMaterials.display_name(material_id)


## Texto curto para o HUD, ex.: "Aço · 2.00 × 0.10 × 2.00 m · 314 kg".
func describe() -> String:
	if label != "":
		return "%s · %d kg" % [label, roundi(mass)]
	var s := bounds.size
	return "%s · %.2f × %.2f × %.2f m · %d kg" % [display_name(), s.x, s.y, s.z, roundi(mass)]

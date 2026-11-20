class_name Part
extends CollisionShape3D
## Uma peça física (chapa, viga, bloco...).
##
## A peça é a forma de colisão dentro de uma Assembly (RigidBody3D). Peças soldadas
## entre si ficam na MESMA Assembly e por isso se movem como um único corpo rígido.

var material_id := "aco"
var kind := "metal"          ## no futuro: "motor", "roda", "assento", ...
var cuttable := true
var planes: Array[Plane] = []
var volume := 0.0
var mass := 1.0
var local_centroid := Vector3.ZERO
var bounds := AABB()
var welds: Array = []        ## Weld conectadas a esta peça

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


func assembly() -> Assembly:
	return get_parent() as Assembly


func display_name() -> String:
	return MetalMaterials.display_name(material_id)


## Texto curto para o HUD, ex.: "Aço · 2.00 × 0.10 × 2.00 m · 314 kg".
func describe() -> String:
	var s := bounds.size
	return "%s · %.2f × %.2f × %.2f m · %d kg" % [display_name(), s.x, s.y, s.z, roundi(mass)]

class_name WireRenderer
extends MeshInstance3D
## Desenha os fios entre controles e componentes (cabo levemente caído).
## Fio aceso (laranja) quando o controle está mandando sinal.

const SEGMENTS := 10

var _imesh := ImmediateMesh.new()


func _ready() -> void:
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	material_override = m


func _process(_delta: float) -> void:
	_imesh.clear_surfaces()
	var any := false
	for j: MechJoint in Build.joints:
		if not j.is_valid():
			continue
		for d: ControlDevice in j.sources:
			if not is_instance_valid(d.part):
				continue
			if not any:
				_imesh.surface_begin(Mesh.PRIMITIVE_LINES)
				any = true
			var color := Color(1.0, 0.55, 0.1) if absf(d.value) > 0.05 else Color(0.08, 0.08, 0.09)
			_cable(d.part.global_position, j.part_a.global_position, color)
	if any:
		_imesh.surface_end()


func _cable(a: Vector3, b: Vector3, color: Color) -> void:
	var sag := clampf(a.distance_to(b) * 0.15, 0.05, 0.8)
	var prev := a
	for i in range(1, SEGMENTS + 1):
		var t := float(i) / SEGMENTS
		var p := a.lerp(b, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t)
		_imesh.surface_set_color(color)
		_imesh.surface_add_vertex(prev)
		_imesh.surface_set_color(color)
		_imesh.surface_add_vertex(p)
		prev = p

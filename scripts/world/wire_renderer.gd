class_name WireRenderer
extends MeshInstance3D
## Desenha os fios entre controles e componentes (cabo levemente caído).
## Fio aceso (laranja) quando o controle está mandando sinal.
## Também desenha o cabo de aço dos guinchos (tubo fino, caído quando está frouxo).

const SEGMENTS := 10
const ROPE_SEGMENTS := 14
const ROPE_RADIUS := 0.012
const ROPE_COLOR := Color(0.32, 0.33, 0.35)

var _imesh := ImmediateMesh.new()


func _ready() -> void:
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = m


func _process(_delta: float) -> void:
	_imesh.clear_surfaces()
	var any := false
	for w in Signals.wires:
		if not w.is_valid():
			continue
		if not any:
			_imesh.surface_begin(Mesh.PRIMITIVE_LINES)
			any = true
		var pts := Signals.wire_points(w)
		var color := _wire_color(w)
		for i in pts.size() - 1:
			_cable(pts[i], pts[i + 1], color)
	if any:
		_imesh.surface_end()
	var rope := false
	for j: MechJoint in Build.joints:
		if j.type != "guincho" or not j.is_valid():
			continue
		if not rope:
			_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			rope = true
		_rope(j.rope_start(), j.rope_end(), j.rope_len)
	if rope:
		_imesh.surface_end()


## Cabo do guincho: reto quando esticado; frouxo, cai numa curva (parábola).
func _rope(a: Vector3, b: Vector3, length: float) -> void:
	var d := a.distance_to(b)
	var slack := maxf(length - d, 0.0)
	var sag := sqrt(3.0 * maxf(d, 0.05) * slack / 8.0) if slack > 0.0 else 0.0
	var pts: Array[Vector3] = []
	for i in ROPE_SEGMENTS + 1:
		var t := float(i) / ROPE_SEGMENTS
		pts.append(a.lerp(b, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t))
	for i in ROPE_SEGMENTS:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var dir := p1 - p0
		if dir.length_squared() < 1e-8:
			continue
		dir = dir.normalized()
		var u := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized() * ROPE_RADIUS
		var w := dir.cross(u)
		var ring: Array[Vector3] = [u, w, -u, -w]
		for k in 4:
			var r0 := ring[k]
			var r1 := ring[(k + 1) % 4]
			var shade := ROPE_COLOR * (0.75 + 0.25 * float(k % 2))
			shade.a = 1.0
			for v: Vector3 in [p0 + r0, p1 + r0, p1 + r1, p0 + r0, p1 + r1, p0 + r1]:
				_imesh.surface_set_color(shade)
				_imesh.surface_add_vertex(v)


## Cor do fio: escuro desligado; aceso na cor do tipo (número laranja, vetor azul,
## texto verde, peça roxo, lista branco) quando há sinal.
static func _wire_color(w) -> Color:
	var t: String = w.type()
	var v: Variant = w.value()
	var active := false
	match t:
		SignalNode.NUM:
			active = absf(float(v)) > 0.05
		SignalNode.VEC:
			active = (v as Vector3).length_squared() > 1e-6
		SignalNode.TXT:
			active = str(v) != ""
		_:
			active = v != null and not (v is Array and (v as Array).is_empty())
	var c: Color = SignalNode.TYPE_COLORS.get(t, Color.WHITE)
	return c if active else c.darkened(0.82)


func _cable(a: Vector3, b: Vector3, color: Color) -> void:
	var sag := clampf(a.distance_to(b) * 0.06, 0.0, 0.5)
	var prev := a
	for i in range(1, SEGMENTS + 1):
		var t := float(i) / SEGMENTS
		var p := a.lerp(b, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t)
		_imesh.surface_set_color(color)
		_imesh.surface_add_vertex(prev)
		_imesh.surface_set_color(color)
		_imesh.surface_add_vertex(p)
		prev = p

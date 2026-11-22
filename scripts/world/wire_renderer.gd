class_name WireRenderer
extends MeshInstance3D
## Desenha os fios (tubos finos, levemente caídos) e o cabo de aço dos guinchos.
##   fio de lógica: aceso na cor do tipo quando há sinal
##   fio de energia: mais grosso, vermelho escuro; vermelho vivo quando passa energia
## Em distâncias curtas (até ~0,4 m) o fio fica quase reto.

const SEGMENTS := 10
const ROPE_SEGMENTS := 14
const ROPE_RADIUS := 0.012
const ROPE_COLOR := Color(0.32, 0.33, 0.35)
const LOGIC_RADIUS := 0.007
const POWER_RADIUS := 0.012
const POWER_OFF := Color(0.32, 0.05, 0.05)
const POWER_ON := Color(0.95, 0.12, 0.1)

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
	var open := false
	for w in Signals.wires:
		if not w.is_valid():
			continue
		if not open:
			_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			open = true
		var pts := Signals.wire_points(w)
		var color := _wire_color(w)
		for i in pts.size() - 1:
			_tube(cable_points(pts[i], pts[i + 1]), LOGIC_RADIUS, color)
	for w in Power.wires:
		if not w.is_valid():
			continue
		if not open:
			_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			open = true
		var pts := Power.wire_points(w)
		var color := POWER_ON if w.amps > 0.5 else POWER_OFF
		for i in pts.size() - 1:
			_tube(cable_points(pts[i], pts[i + 1]), POWER_RADIUS, color)
	for j: MechJoint in Build.joints:
		if j.type != "guincho" or not j.is_valid():
			continue
		if not open:
			_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			open = true
		_tube(rope_points(j.rope_start(), j.rope_end(), j.rope_len), ROPE_RADIUS, ROPE_COLOR)
	if open:
		_imesh.surface_end()


## Pontos de um fio entre `a` e `b`: caído no meio (até 6% do comprimento), mas
## praticamente reto em distâncias curtas (abaixo de ~0,4 m).
static func cable_points(a: Vector3, b: Vector3) -> Array[Vector3]:
	var d := a.distance_to(b)
	var sag := clampf(d * 0.06, 0.0, 0.5) * smoothstep(0.3, 1.5, d)
	var pts: Array[Vector3] = []
	var n := SEGMENTS if sag > 0.002 else 1
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(b, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t))
	return pts


## Cabo do guincho: reto quando esticado; frouxo, cai numa curva (parábola).
static func rope_points(a: Vector3, b: Vector3, length: float) -> Array[Vector3]:
	var d := a.distance_to(b)
	var slack := maxf(length - d, 0.0)
	var sag := sqrt(3.0 * maxf(d, 0.05) * slack / 8.0) if slack > 0.0 else 0.0
	var pts: Array[Vector3] = []
	for i in ROPE_SEGMENTS + 1:
		var t := float(i) / ROPE_SEGMENTS
		pts.append(a.lerp(b, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t))
	return pts


## Tubo de 4 lados ao longo dos pontos (sombreado leve para dar volume).
func _tube(pts: Array[Vector3], radius: float, color: Color) -> void:
	for i in pts.size() - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var dir := p1 - p0
		if dir.length_squared() < 1e-8:
			continue
		dir = dir.normalized()
		var u := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized() * radius
		var w := dir.cross(u)
		var ring: Array[Vector3] = [u, w, -u, -w]
		for k in 4:
			var r0 := ring[k]
			var r1 := ring[(k + 1) % 4]
			var shade := color * (0.72 + 0.28 * float(k % 2))
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
	return c if active else c.darkened(0.7)

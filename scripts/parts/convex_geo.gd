class_name ConvexGeo
extends RefCounted
## Geometria de peças convexas.
##
## Cada peça de metal é guardada como um conjunto de planos (semiespaços).
## Os planos apontam para FORA: um ponto está dentro se plane.distance_to(p) <= 0.
## Cortar = adicionar um plano. Assim qualquer corte (eixo ou 45°) funciona igual.

const EPS := 0.0006

## Ângulos da linha de corte sobre a face mirada (R alterna entre eles).
const CUT_ANGLES: Array[float] = [0.0, 45.0, 90.0, 135.0]


## Normal (local) do plano de corte para a face mirada.
## O plano é sempre perpendicular à face: a linha de corte fica desenhada sobre ela,
## girada `angle_deg` graus. Com 0° a linha acompanha as arestas da peça.
static func face_cut_normal(face_n: Vector3, angle_deg: float) -> Vector3:
	var ref := Vector3.RIGHT
	var least := 2.0
	for a: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		var d := absf(face_n.dot(a))
		if d < least - 1e-4:
			least = d
			ref = a
	var t1 := face_n.cross(ref).normalized()
	var t2 := face_n.cross(t1).normalized()
	var ang := deg_to_rad(angle_deg)
	return (t1 * cos(ang) + t2 * sin(ang)).normalized()


## Normal da face da peça mais alinhada com a direção `n` (coordenadas locais).
static func closest_face_normal(planes: Array[Plane], n: Vector3) -> Vector3:
	var best := n
	var best_dot := -2.0
	for pl in planes:
		var d := pl.normal.dot(n)
		if d > best_dot:
			best_dot = d
			best = pl.normal
	return best


static func box_planes(size: Vector3) -> Array[Plane]:
	var h := size * 0.5
	var out: Array[Plane] = [
		Plane(Vector3.RIGHT, h.x),
		Plane(Vector3.LEFT, h.x),
		Plane(Vector3.UP, h.y),
		Plane(Vector3.DOWN, h.y),
		Plane(Vector3.BACK, h.z),
		Plane(Vector3.FORWARD, h.z),
	]
	return out


## Resolve um conjunto de planos em geometria.
## Retorna {} se o sólido for vazio/degenerado; senão:
## { verts, faces:[{plane, poly}], planes, volume, centroid, aabb }
static func solve(planes: Array[Plane]) -> Dictionary:
	var raw := Geometry3D.compute_convex_mesh_points(planes)
	var verts := PackedVector3Array()
	for p in raw:
		var dup := false
		for q in verts:
			if p.distance_squared_to(q) < 1e-8:
				dup = true
				break
		if not dup:
			verts.append(p)
	if verts.size() < 4:
		return {}

	var faces: Array = []
	var used: Array[Plane] = []
	for pl in planes:
		var on := PackedVector3Array()
		for v in verts:
			if absf(pl.distance_to(v)) < EPS * 4.0:
				on.append(v)
		if on.size() < 3:
			continue
		var repeated := false
		for u in used:
			if u.normal.dot(pl.normal) > 0.9999 and absf(u.d - pl.d) < EPS * 4.0:
				repeated = true
				break
		if repeated:
			continue
		used.append(pl)
		faces.append({"plane": pl, "poly": sort_polygon(on, pl.normal)})
	if faces.size() < 4:
		return {}

	var inner := Vector3.ZERO
	for v in verts:
		inner += v
	inner /= verts.size()
	var vol := 0.0
	var cen := Vector3.ZERO
	for f: Dictionary in faces:
		var poly: PackedVector3Array = f["poly"]
		for i in range(1, poly.size() - 1):
			var a := poly[0]
			var b := poly[i]
			var c := poly[i + 1]
			var tv := absf((a - inner).dot((b - inner).cross(c - inner))) / 6.0
			vol += tv
			cen += (inner + a + b + c) * 0.25 * tv
	if vol < 1e-7:
		return {}
	cen /= vol

	var aabb := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		aabb = aabb.expand(v)
	return {
		"verts": verts,
		"faces": faces,
		"planes": used,
		"volume": vol,
		"centroid": cen,
		"aabb": aabb,
	}


## Ordena os pontos de uma face convexa em sentido anti-horário visto de fora (normal n).
static func sort_polygon(pts: PackedVector3Array, n: Vector3) -> PackedVector3Array:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var u := Vector3.ZERO
	for p in pts:
		if (p - c).length_squared() > 1e-10:
			u = (p - c).normalized()
			break
	var w := n.cross(u)
	var keyed: Array = []
	for p in pts:
		var d := p - c
		keyed.append([atan2(d.dot(w), d.dot(u)), p])
	keyed.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var out := PackedVector3Array()
	for e: Array in keyed:
		out.append(e[1])
	return out


## Malha da peça: superfície 0 = faces, superfície 1 = arestas (linhas).
static func build_mesh(geo: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Dictionary in geo["faces"]:
		var n: Vector3 = (f["plane"] as Plane).normal
		var poly: PackedVector3Array = f["poly"]
		for i in range(1, poly.size() - 1):
			# Godot usa sentido horário para a face da frente.
			for v in [poly[0], poly[i + 1], poly[i]]:
				st.set_normal(n)
				st.add_vertex(v)
	var mesh := st.commit()

	var centroid: Vector3 = geo["centroid"]
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	for f: Dictionary in geo["faces"]:
		var poly: PackedVector3Array = f["poly"]
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			lines.add_vertex(a + (a - centroid).normalized() * 0.003)
			lines.add_vertex(b + (b - centroid).normalized() * 0.003)
	lines.commit(mesh)
	return mesh


## Divide o sólido pelo plano de corte. Retorna [lado_negativo, lado_positivo] ou [].
static func split(planes: Array[Plane], cut: Plane) -> Array:
	var pa: Array[Plane] = planes.duplicate()
	pa.append(cut)
	var pb: Array[Plane] = planes.duplicate()
	pb.append(Plane(-cut.normal, -cut.d))
	var a := solve(pa)
	var b := solve(pb)
	if a.is_empty() or b.is_empty():
		return []
	return [a, b]


## Polígono da face de corte (em coordenadas locais), para a pré-visualização.
static func cut_polygon(planes: Array[Plane], cut: Plane) -> PackedVector3Array:
	var pa: Array[Plane] = planes.duplicate()
	pa.append(cut)
	var geo := solve(pa)
	if geo.is_empty():
		return PackedVector3Array()
	for f: Dictionary in geo["faces"]:
		var pl: Plane = f["plane"]
		if pl.normal.dot(cut.normal) > 0.9999 and absf(pl.d - cut.d) < EPS * 4.0:
			return f["poly"]
	return PackedVector3Array()


## Encaixa a base ortonormal na orientação de 90° mais próxima dos eixos do mundo.
static func snap_basis(b: Basis) -> Basis:
	var x := snap_axis(b.x)
	var y := snap_axis(b.y, x)
	return Basis(x, y, x.cross(y))


## Eixo do mundo (±X, ±Y, ±Z) mais próximo de v; opcionalmente ignora o eixo `avoid`.
static func snap_axis(v: Vector3, avoid := Vector3.ZERO) -> Vector3:
	var best := Vector3.RIGHT
	var best_dot := -1.0
	for a: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		if absf(a.dot(avoid)) > 0.5:
			continue
		var d := v.dot(a)
		if absf(d) > best_dot:
			best_dot = absf(d)
			best = a * (1.0 if d >= 0.0 else -1.0)
	return best

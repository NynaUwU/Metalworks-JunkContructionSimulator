class_name Snap
extends RefCounted
## Ponto mirado encaixado na grade de 5 cm da peça (a mesma da Esmerilhadeira), em cima
## da face mirada. Uma marca da Trena perto tem preferência. No chão: grade do mundo.

const GRID := 0.05
const MARK_SNAP := 0.03


## Retorna {part, local, local_n, world, world_n} (part = null no chão), ou {} sem mira.
static func aimed(player: Player, grid := true) -> Dictionary:
	if player.aim.is_empty():
		return {}
	var point: Vector3 = player.aim["position"]
	var normal: Vector3 = (player.aim["normal"] as Vector3).normalized()
	var part := player.aim_part()
	if part == null:
		var w := Vector3(snappedf(point.x, GRID), point.y, snappedf(point.z, GRID)) if grid else point
		return {"part": null, "local": w, "local_n": normal, "world": w, "world_n": normal}
	return on_part(part, point, normal, grid)


static func on_part(part: Part, point: Vector3, normal: Vector3, grid := true) -> Dictionary:
	var gt := part.global_transform
	var inv := gt.affine_inverse()
	var local := inv * point
	var ln := (inv.basis * normal).normalized()
	var face_d := ln.dot(local)
	if not part.planes.is_empty():
		ln = ConvexGeo.closest_face_normal(part.planes, ln)
		for pl: Plane in part.planes:
			if pl.normal.dot(ln) > 0.999:
				face_d = pl.d
				break
	var mark := part.nearest_mark(local, MARK_SNAP)
	if mark >= 0:
		local = part.marks[mark][0]
	elif grid:
		local = local.snapped(Vector3.ONE * GRID)
		local -= ln * (ln.dot(local) - face_d)      # volta para cima da face
	return {"part": part, "local": local, "local_n": ln, "world": gt * local, "world_n": (gt.basis * ln).normalized()}


## Eixo local da peça mais "deitado" na face (para medir e alinhar o giro).
static func tangent(n: Vector3) -> Vector3:
	var best := Vector3.RIGHT
	var best_d := INF
	for a: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		var d := absf(a.dot(n))
		if d < best_d:
			best_d = d
			best = a
	return (best - n * best.dot(n)).normalized()


## "1,25 m" (cm abaixo de 1 m: "35 cm").
static func length_text(d: float) -> String:
	if absf(d) < 1.0:
		return "%d cm" % roundi(d * 100.0)
	return ("%.2f m" % d).replace(".", ",")

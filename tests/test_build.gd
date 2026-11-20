extends Node3D
## Testes automáticos da lógica de construção (rodar sem tela):
##   godot --headless --path . res://tests/test_build.tscn

var _fails := 0
var _checks := 0


func check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		push_error("FALHOU: " + what)
		print("  FALHOU ", what)


func near(a: float, b: float, tol := 1e-3) -> bool:
	return absf(a - b) <= tol


func _ready() -> void:
	Build.reset(self)
	var ground := StaticBody3D.new()
	ground.collision_layer = Layers.WORLD
	ground.add_to_group("ground")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(100, 1, 100)
	cs.shape = bs
	ground.add_child(cs)
	add_child(ground)
	ground.position.y = -0.5
	await get_tree().physics_frame
	await _run()
	print("\n%d verificações, %d falhas" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _run() -> void:
	print("== Geometria")
	var box := ConvexGeo.solve(ConvexGeo.box_planes(Vector3(2, 0.1, 2)))
	check(box["verts"].size() == 8, "caixa tem 8 vértices")
	check(box["faces"].size() == 6, "caixa tem 6 faces")
	check(near(box["volume"], 0.4), "volume da chapa 2x0.1x2 = 0.4 (deu %f)" % box["volume"])
	check((box["centroid"] as Vector3).length() < 1e-4, "centróide na origem")

	var halves := ConvexGeo.split(ConvexGeo.box_planes(Vector3(2, 0.1, 2)), Plane(Vector3.RIGHT, 0.3))
	check(halves.size() == 2, "corte reto gera 2 pedaços")
	check(near(halves[0]["volume"] + halves[1]["volume"], 0.4), "volumes somam o original")
	check(near(halves[0]["volume"], 1.3 * 0.1 * 2), "lado negativo tem 1.3 m de largura")

	var n := ConvexGeo.CUT_DIRECTIONS[5]
	var diag := ConvexGeo.split(ConvexGeo.box_planes(Vector3(2, 0.1, 2)), Plane(n, 0.0))
	check(diag.size() == 2, "corte 45° gera 2 pedaços")
	check(near(diag[0]["volume"], 0.2) and near(diag[1]["volume"], 0.2), "corte diagonal divide ao meio")
	check(diag[0]["verts"].size() == 6, "pedaço triangular tem 6 vértices")

	var miss := ConvexGeo.split(ConvexGeo.box_planes(Vector3(1, 1, 1)), Plane(Vector3.RIGHT, 2.0))
	check(miss.is_empty(), "corte fora da peça não divide")

	var poly := ConvexGeo.cut_polygon(ConvexGeo.box_planes(Vector3(1, 1, 1)), Plane(Vector3.UP, 0.0))
	check(poly.size() == 4, "polígono de pré-visualização tem 4 cantos")

	var snapped := ConvexGeo.snap_basis(Basis(Vector3.UP, 0.3) * Basis(Vector3.RIGHT, 1.4))
	check(snapped.determinant() > 0.99 and snapped.is_conformal(), "alinhar à grade gera base válida")

	print("== Peças e soldas")
	var a := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(0, 0.05, 0)))
	var b := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(1.0, 0.05, 0)))
	check(a != null and b != null, "peças criadas")
	check(near(a.mass, 78.5, 0.1), "massa do aço (1x0.1x1) = 78.5 kg")
	check(a.assembly() != b.assembly(), "peças começam separadas")

	await _frames(3)
	var ok := Build.weld_at(a, Vector3(0.5, 0.05, 0))
	check(ok, "solda na emenda funcionou")
	check(a.assembly() == b.assembly(), "soldadas = mesma montagem")
	check(near(a.assembly().mass, 157.0, 0.2), "massa somada")
	check(near((a.assembly().world_center_of_mass() - Vector3(0.5, 0.05, 0)).length(), 0.0, 0.01), "centro de massa no meio")

	var far := Build.weld_at(a, Vector3(-0.5, 3.0, 0.3))
	check(far == false, "solda sem nada por perto é recusada")

	print("== Corte com soldas")
	var c := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(2.0, 0.05, 0)))
	await _frames(3)
	Build.weld_at(b, Vector3(1.5, 0.05, 0))
	var asm := b.assembly()
	check(asm.get_parts().size() == 3, "três peças soldadas em linha")
	var pieces := Build.cut_part(b, Plane(Vector3.RIGHT, 0.0))
	check(pieces.size() == 2, "corte da peça do meio gerou 2 pedaços")
	await _frames(1)
	check(pieces[0].assembly() != pieces[1].assembly(), "linha cortada ao meio vira 2 montagens")
	check(pieces[0].assembly() == a.assembly(), "pedaço esquerdo continua soldado em A")
	check(pieces[1].assembly() == c.assembly(), "pedaço direito continua soldado em C")

	print("== Remover solda")
	var w := Build.nearest_weld(Vector3(0.5, 0.05, 0), 0.3)
	check(w != null, "achou a solda pela posição")
	Build.remove_weld(w)
	await _frames(1)
	check(a.assembly() != pieces[0].assembly(), "sem solda, peças se separam")

	print("== Ancorar no chão")
	var d := Build.spawn_box(Vector3(0.5, 0.5, 0.5), "ferro", Transform3D(Basis(), Vector3(-5, 0.25, 0)))
	await _frames(3)
	check(Build.weld_at(d, Vector3(-5, 0.0, 0.25)), "solda no chão")
	check(d.assembly().anchored and d.assembly().freeze, "montagem ancorada fica congelada")
	Build.remove_weld(Build.nearest_weld(Vector3(-5, 0.0, 0.25), 0.3))
	check(not d.assembly().anchored and not d.assembly().freeze, "sem a solda do chão, volta a ter física")

	print("== Física")
	var e := Build.spawn_box(Vector3(1, 1, 1), "aco", Transform3D(Basis(Vector3.UP, 0.4), Vector3(8, 3, 0)))
	await _frames(150)
	check(near(e.global_position.y, 0.5, 0.05), "bloco cai e para no chão (y=%.3f)" % e.global_position.y)

	var f := Build.spawn_box(Vector3(2, 0.1, 2), "aco", Transform3D(Basis(), Vector3(12, 0.05, 0)))
	await _frames(5)
	var target := Transform3D(Basis(Vector3.UP, 0.7), Vector3(12, 2.5, 1))
	f.assembly().set_hold(f, Vector3.ZERO, target)
	await _frames(90)
	var err := f.global_transform.origin.distance_to(target.origin)
	check(err < 0.03, "peça segurada flutua até o alvo (erro %.3f m)" % err)
	var ang := f.global_transform.basis.get_rotation_quaternion().angle_to(target.basis.get_rotation_quaternion())
	check(ang < 0.03, "peça segurada gira até o alvo (erro %.3f rad)" % ang)
	f.assembly().clear_hold()
	await _frames(120)
	check(near(f.global_position.y, 0.05, 0.012), "ao soltar (E), a peça cai e assenta no chão (y=%.3f)" % f.global_position.y)

	print("== Corte em peça girada")
	var g := Build.spawn_box(Vector3(2, 0.2, 0.2), "aco", Transform3D(Basis(Vector3.UP, 0.8), Vector3(16, 0.1, 0)))
	await _frames(10)
	var gp := Build.cut_part(g, Plane(ConvexGeo.CUT_DIRECTIONS[3], 0.0))
	check(gp.size() == 2, "corte 45° em peça girada")
	await _frames(60)
	check(gp[0].global_position.y > -0.1 and gp[1].global_position.y > -0.1, "pedaços não atravessam o chão")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

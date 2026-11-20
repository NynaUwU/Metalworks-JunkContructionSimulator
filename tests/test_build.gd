extends Node3D
## Testes automáticos da lógica de construção (rodar sem tela):
##   godot --headless --path . res://tests/test_build.tscn

const EXPECTED_CHECKS := 93

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
	if _checks < EXPECTED_CHECKS:
		_fails += 1
		print("  FALHOU só %d de %d verificações rodaram (erro no meio do teste?)" % [_checks, EXPECTED_CHECKS])
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

	var n := Vector3(1, 0, 1).normalized()
	var diag := ConvexGeo.split(ConvexGeo.box_planes(Vector3(2, 0.1, 2)), Plane(n, 0.0))
	check(diag.size() == 2, "corte 45° gera 2 pedaços")
	check(near(diag[0]["volume"], 0.2) and near(diag[1]["volume"], 0.2), "corte diagonal divide ao meio")
	check(diag[0]["verts"].size() == 6, "pedaço triangular tem 6 vértices")

	var miss := ConvexGeo.split(ConvexGeo.box_planes(Vector3(1, 1, 1)), Plane(Vector3.RIGHT, 2.0))
	check(miss.is_empty(), "corte fora da peça não divide")

	var poly := ConvexGeo.cut_polygon(ConvexGeo.box_planes(Vector3(1, 1, 1)), Plane(Vector3.UP, 0.0))
	check(poly.size() == 4, "polígono de pré-visualização tem 4 cantos")

	for face: Vector3 in [Vector3.UP, Vector3.RIGHT, Vector3.BACK, Vector3(1, 0, 1).normalized()]:
		for ang: float in ConvexGeo.CUT_ANGLES:
			var cn := ConvexGeo.face_cut_normal(face, ang)
			check(absf(cn.dot(face)) < 1e-4 and near(cn.length(), 1.0), "corte perpendicular à face %s em %d°" % [face, ang])
	var beam_cut := ConvexGeo.face_cut_normal(Vector3.RIGHT, 0.0)
	check(absf(absf(beam_cut.z) - 1.0) < 1e-4, "0° na lateral de uma viga corta atravessado (normal ±Z)")
	var top_45 := ConvexGeo.face_cut_normal(Vector3.UP, 45.0)
	check(near(absf(top_45.x), 0.7071) and near(absf(top_45.z), 0.7071), "45° na face de cima é diagonal")

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
	check(ok != null, "solda na emenda funcionou")
	check(a.assembly() == b.assembly(), "soldadas = mesma montagem")
	check(near(a.assembly().mass, 157.0, 0.2), "massa somada")
	check(near((a.assembly().world_center_of_mass() - Vector3(0.5, 0.05, 0)).length(), 0.0, 0.01), "centro de massa no meio")

	var far := Build.weld_at(a, Vector3(-0.5, 3.0, 0.3))
	check(far == null, "solda sem nada por perto é recusada")
	check(Build.weld_at(a, Vector3(0.5, 0.05, 0.04)) == null, "onde já tem bolinha não nasce outra")
	check(Build.weld_at(a, Vector3(0.5, 0.05, 0.2)) != null, "ponto livre na mesma emenda vira nova solda")

	# A solda só alcança o que está dentro da bolinha.
	var low := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(20, 0.05, 5)))
	var top := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(20, 0.15, 5)))
	var gap_a := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(24, 0.3, 5)))
	var gap_b := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(25.08, 0.3, 5)))
	gap_a.assembly().freeze = true
	gap_b.assembly().freeze = true
	await _frames(3)
	check(Build.weld_at(top, Vector3(20, 0.2, 5)) == null, "não solda através de uma chapa")
	check(Build.weld_at(gap_a, Vector3(24.5, 0.3, 5)) == null, "vão de 8 cm é grande demais para soldar")
	var near_a := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(24, 0.3, 8)))
	var near_b := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(25.03, 0.3, 8)))
	near_a.assembly().freeze = true
	near_b.assembly().freeze = true
	await _frames(3)
	check(Build.weld_at(near_a, Vector3(24.5, 0.3, 8)) != null, "vão de 3 cm (dentro da bolinha) solda")
	check(low.assembly() != top.assembly(), "chapa de baixo continua separada")
	var plate_time := GrinderTool.cut_time(Build.spawn_box(Vector3(2, 0.1, 2), "aco", Transform3D(Basis(), Vector3(0, 5, 30))), Plane(Vector3.RIGHT, 0.0))
	check(near(plate_time, 1.2, 0.01), "cortar uma chapa 2x2 ao meio leva 1,2 s (deu %.2f)" % plate_time)

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
	var w := Build.nearest_weld(Vector3(0.5, 0.05, 0), 0.05)
	check(w != null, "achou a solda pela posição")
	Build.remove_weld(w)
	await _frames(1)
	check(a.assembly() == pieces[0].assembly(), "com uma das duas soldas ainda inteira, continuam juntas")
	Build.remove_weld(Build.nearest_weld(Vector3(0.5, 0.05, 0.2), 0.05))
	await _frames(1)
	check(a.assembly() != pieces[0].assembly(), "sem solda, peças se separam")

	print("== Ancorar no chão")
	var d := Build.spawn_box(Vector3(0.5, 0.5, 0.5), "ferro", Transform3D(Basis(), Vector3(-5, 0.25, 0)))
	await _frames(3)
	check(Build.weld_at(d, Vector3(-5, 0.0, 0.25)) != null, "solda no chão")
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
	var gp := Build.cut_part(g, Plane(Vector3(1, 1, 0).normalized(), 0.0))
	check(gp.size() == 2, "corte 45° em peça girada")
	await _frames(60)
	check(gp[0].global_position.y > -0.1 and gp[1].global_position.y > -0.1, "pedaços não atravessam o chão")

	await _run_economy()
	await _run_tools()


func _run_economy() -> void:
	print("== Pontos, reciclador e loja")
	Economy.reset()
	check(Economy.points() == 0, "pontos começam em zero")
	var v := Economy.recycle_value("aco", 78.5)
	check(near(v, 7.85), "chapa de aço 1x1 vale 7,85 pontos")
	check(Economy.recycle_value("aluminio", 10.0) > Economy.recycle_value("aco", 10.0), "alumínio vale mais por kg que aço")

	var exploit := true
	for item: Dictionary in Catalog.ITEMS:
		if Catalog.is_locked(item) or Catalog.is_component(item):
			continue
		var g := Catalog.geometry(item)
		if g.is_empty() or Catalog.mass(item) <= 0.0:
			exploit = false
			check(false, "item %s tem geometria válida" % item["id"])
		if Catalog.price(item) <= Economy.recycle_value(item["mat"], Catalog.mass(item)):
			exploit = false
	check(exploit, "todo item custa mais do que o reciclador paga por ele")
	check(near(Catalog.mass(Catalog.get_item("chapa_tri")), 157.0, 0.5), "chapa triangular tem metade do peso da 2x2")
	var viga := Catalog.get_item("viga")
	var len_param: Dictionary = Catalog.params(viga)[0]
	var v4 := Catalog.with_param(Catalog.default_size(viga), len_param, 4.0)
	check(near(v4.z, 4.0) and Catalog.price(viga, v4) > Catalog.price(viga), "viga de 4 m custa mais que a de 2 m")
	check(near(Catalog.with_param(v4, len_param, 50.0).z, 6.0), "comprimento limitado a 6 m")
	check(near(Catalog.with_param(v4, len_param, 0.1).z, 0.5), "comprimento mínimo de 0,5 m")
	check(near(Catalog.with_param(v4, len_param, 2.6).z, 2.5), "comprimento anda em passos de 25 cm")
	check(near(Catalog.clamp_size(viga, Vector3(9, 9, 9)).x, 0.2), "a loja não deixa mudar a seção da viga")
	var tri := Catalog.get_item("chapa_tri")
	var tri3 := Catalog.with_param(Catalog.default_size(tri), Catalog.params(tri)[0], 3.0)
	check(near(tri3.x, 3.0) and near(tri3.z, 3.0), "chapa triangular cresce nos dois lados")

	var rec := Recycler.new()
	add_child(rec)
	rec.position = Vector3(30, 0, 0)
	await _frames(2)
	var junk := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(30, 2.5, 0)))
	var junk_ref: WeakRef = weakref(junk)
	await _frames(90)
	check(junk_ref.get_ref() == null, "peça que cai no funil é reciclada")
	check(Economy.points() == 7, "reciclar a chapa deu 7 pontos (tem %d)" % Economy.points())

	var outside := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(34, 0.05, 0)))
	await _frames(30)
	check(is_instance_valid(outside) and outside.is_inside_tree(), "peça fora do funil não é reciclada")

	# Cortar em pedacinhos não rende mais pontos do que a peça inteira.
	Economy.reset()
	var bar := Build.spawn_box(Vector3(0.1, 0.1, 2), "aluminio", Transform3D(Basis(), Vector3(-10, 0.05, 5)))
	var whole := Economy.recycle_value("aluminio", bar.mass)
	var pieces: Array = [bar]
	for k in 5:
		var nxt: Array = []
		for p: Part in pieces:
			var halves := Build.cut_part(p, Plane(Vector3.BACK, p.local_centroid.z))
			nxt.append_array(halves if not halves.is_empty() else [p])
		pieces = nxt
	var total := 0.0
	for p: Part in pieces:
		total += Economy.recycle_value(p.material_id, p.mass)
	check(pieces.size() == 32 and near(total, whole, 0.01), "32 pedacinhos valem o mesmo que a barra inteira")

	var shop := ShopStation.new()
	add_child(shop)
	shop.position = Vector3(-30, 0, 0)
	await _frames(2)
	Economy.reset(5)
	var big := Vector3(2, 0.1, 2)
	check(shop.buy("chapa", big) == null and Economy.points() == 5, "sem pontos suficientes não compra")
	Economy.reset(200)
	var price := Catalog.price(Catalog.get_item("chapa"), big)
	var bought := shop.buy("chapa", big)
	check(bought != null and Economy.points() == 200 - price, "compra desconta %d pontos" % price)
	check(bought.global_position.distance_to(shop.global_transform * ShopStation.PAD_OFFSET) < 2.0, "item aparece na plataforma de entrega")
	var second := shop.buy("chapa", big)
	check(second != null and second.global_position.y > bought.global_position.y + 0.3, "segunda compra aparece acima da primeira")
	Economy.reset(100)
	var motor := shop.buy("motor")
	check(motor != null and motor.mech != null and Economy.points() == 100 - Components.price("motor"), "compra de motor (componente com junta)")
	var wheel := shop.buy("roda", Vector3(0.6, 0.3, 0))
	check(wheel != null and near((wheel.shape as CylinderShape3D).radius, 0.6), "roda comprada com raio 0,6 m")
	Economy.reset(500)
	var long_beam := shop.buy("viga", Vector3(0, 0, 5.0))
	check(long_beam != null and near(long_beam.bounds.size.z, 5.0), "compra de viga com 5 m")


func _aim(player: Player, feet: Vector3, target: Vector3) -> void:
	player.teleport(feet)
	player.velocity = Vector3.ZERO
	var eye := feet + Vector3(0, Player.EYE_HEIGHT, 0)
	var d := (target - eye).normalized()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = asin(clampf(d.y, -1.0, 1.0))


func _run_tools() -> void:
	print("== Ferramentas segurando o botão")
	var player := Player.new()
	add_child(player)
	await _frames(2)

	# Esmerilhadeira: corte demora, trava no lugar e soltar cancela.
	var plate := Build.spawn_box(Vector3(2, 0.1, 2), "aco", Transform3D(Basis(), Vector3(40, 0.05, 0)))
	var plate_ref: WeakRef = weakref(plate)
	player.select_tool(2)
	var grinder: GrinderTool = player.tools[2]
	grinder.angle_index = 0
	_aim(player, Vector3(40, 0, 2.6), Vector3(40, 0.1, 0.3))
	await _frames(3)
	grinder.begin_use()
	check(grinder.mode == GrinderTool.Mode.CUTTING, "clicar começa o corte")
	await _frames(30)
	check(plate_ref.get_ref() != null, "meio segundo ainda não cortou")
	grinder.cancel()
	await _frames(70)
	check(plate_ref.get_ref() != null, "soltar o botão cancela o corte")
	grinder.begin_use()
	await _frames(90)
	check(plate_ref.get_ref() == null, "segurando até o fim, a chapa é cortada")

	# Solda: segurar cria pontos; no mesmo lugar não nasce outro.
	var w1 := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(44, 0.05, -5)))
	var w2 := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(45, 0.05, -5)))
	await _frames(5)
	player.select_tool(1)
	var welder: WeldTool = player.tools[1]
	_aim(player, Vector3(44.48, 0, -3.2), Vector3(44.48, 0.1, -5))
	await _frames(3)
	var before := Build.welds.size()
	welder.begin_use()
	await _frames(30)
	check(welder.is_arc_active(), "tocha acesa enquanto segura")
	check(Build.welds.size() == before + 1 and w1.assembly() == w2.assembly(), "segurar na emenda criou 1 ponto de solda")
	await _frames(30)
	check(Build.welds.size() == before + 1, "parado no mesmo lugar não cria outra bolinha")
	welder.handle_input(_release_event())
	check(not welder.is_arc_active(), "soltar apaga a tocha")
	player.queue_free()


func _release_event() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = "primary"
	ev.pressed = false
	return ev


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

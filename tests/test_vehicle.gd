extends Node3D
## Veículos: aderência das rodas (arrancada/freada) e pistão no modo amortecedor.
##   godot --headless --path . res://tests/test_vehicle.tscn

const EXPECTED_CHECKS := 12

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


func _ready() -> void:
	Build.reset(self)
	var ground := StaticBody3D.new()
	ground.collision_layer = Layers.WORLD
	ground.add_to_group("ground")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(600, 1, 600)
	cs.shape = bs
	ground.add_child(cs)
	add_child(ground)
	ground.position.y = -0.5
	await _frames(2)
	await _run()
	if _checks < EXPECTED_CHECKS:
		_fails += 1
		print("  FALHOU só %d de %d verificações rodaram (erro no meio do teste?)" % [_checks, EXPECTED_CHECKS])
	print("\n%d verificações, %d falhas" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Maior escorregamento (m/s) entre a roda e o chão, no ponto de contato, em `n` ticks.
func _max_slip(joints: Array, n: int) -> float:
	var worst := 0.0
	for i in n:
		await get_tree().physics_frame
		for j: MechJoint in joints:
			if j.type != "motor":
				continue
			var wa: Assembly = j.part_b.assembly()
			var contact := j.part_b.global_position - Vector3.UP * 0.4
			var gv := wa.linear_velocity + wa.angular_velocity.cross(contact - wa.world_center_of_mass())
			worst = maxf(worst, Vector2(gv.x, gv.z).length())
	return worst


func _car(o: Vector3, cargo_kg := 0.0) -> Dictionary:
	var seat := DemoBuilds.build_car(o)
	if cargo_kg > 0.0:
		var h := cargo_kg / 785.0 / (1.2 * 1.6)
		var cargo := Build.spawn_box(Vector3(1.2, h, 1.6), "aco", Transform3D(Basis(), o + Vector3(0, 0.65 + h * 0.5, -0.3)))
		Build.make_weld(cargo, seat, o + Vector3(0, 0.7, -0.3))
	var joints: Array = Build.network(seat)
	var btn: Part = Components.spawn("botao", Transform3D(Basis(), o + Vector3(5, 0.04, 5)))[0]
	for j: MechJoint in joints:
		Build.toggle_link(btn.device, j)
	return {"seat": seat, "joints": joints, "btn": btn}


func _run() -> void:
	print("== Aderência das rodas")
	for cargo: float in [0.0, 1500.0]:
		var car := _car(Vector3(-40 if cargo == 0.0 else 40, 0, 0), cargo)
		await _frames(60)
		var chassis: Assembly = (car["seat"] as Part).assembly()
		var btn: Part = car["btn"]
		btn.device.press()
		var s_go := await _max_slip(car["joints"], 120)
		var v := Vector2(chassis.linear_velocity.x, chassis.linear_velocity.z).length()
		btn.device.release()
		var s_stop := await _max_slip(car["joints"], 120)
		var name := "carrinho" if cargo == 0.0 else "carro de %.1f t" % (chassis.real_mass() / 1000.0)
		# (o motor simples é limitado: o carro pesado sai mais devagar, mas sem patinar)
		check(s_go < 0.5 and v > 2.0, "%s: rodas não patinam na arrancada (%.2f m/s de escorregamento, %.1f m/s)" % [name, s_go, v])
		check(s_stop < 0.5, "%s: rodas não derrapam na freada (%.2f m/s)" % [name, s_stop])

	print("== Pistão no modo amortecedor")
	# Pistão de pé, base soldada no chão; um bloco em cima da haste.
	var load_kg := 100.0
	var dampers: Array = []
	for i in 2:
		var x := -4.0 + i * 3.0
		var pis := Components.spawn("pistao", Transform3D(Basis(), Vector3(x, 0.35, 10)))
		pis[0].assembly().set_anchored(true)
		var j: MechJoint = pis[0].mech
		j.damper = true
		j.damping = 300.0 if i == 0 else 2500.0
		var top: Vector3 = pis[1].global_transform * Vector3(0, 0.3, 0)
		var side := pow(load_kg / 785.0, 1.0 / 3.0)
		var block := Build.spawn_box(Vector3(side, side, side), "aco", Transform3D(Basis(), top + Vector3(0, side * 0.5, 0)))
		Build.make_weld(block, pis[1], top)
		dampers.append(j)
	var expect: float = dampers[0].ride * dampers[0].stroke - (load_kg + (dampers[0].part_b as Part).mass) * 9.8 / dampers[0].stiffness
	var lo := [INF, INF]
	var hi := [-INF, -INF]
	for t in 240:
		await get_tree().physics_frame
		if t > 20:
			for i in 2:
				var e: float = dampers[i].extension()
				lo[i] = minf(lo[i], e)
				hi[i] = maxf(hi[i], e)
	await _frames(120)
	var settled: float = dampers[1].extension()
	print("     esperado %.3f m · assentou %.3f m · faixa pouco amortecido %.3f / bem amortecido %.3f" % [expect, settled, hi[0] - lo[0], hi[1] - lo[1]])
	check(absf(settled - expect) < 0.02, "segura o peso na altura certa: rigidez × compressão = peso (%.3f m, esperado %.3f)" % [settled, expect])
	check(hi[0] - lo[0] > (hi[1] - lo[1]) * 1.5, "mais amortecimento = balança menos (%.3f m contra %.3f m)" % [hi[0] - lo[0], hi[1] - lo[1]])
	check(absf(dampers[0].extension() - expect) < 0.02, "pouco amortecido também para no lugar (%.3f m)" % dampers[0].extension())
	var stiff_j: MechJoint = dampers[1]
	stiff_j.stiffness *= 2.0
	await _frames(120)
	check(stiff_j.extension() > settled + 0.02, "mais rigidez = afunda menos (%.3f m → %.3f m)" % [settled, stiff_j.extension()])
	# Sinal: sobe até o fim do curso (suspensão hidráulica).
	var lever: Part = Components.spawn("alavanca", Transform3D(Basis(), Vector3(0, 0.04, 14)))[0]
	Build.toggle_link(lever.device, stiff_j)
	lever.device.press()
	await _frames(180)
	check(stiff_j.extension() > stiff_j.stroke * 0.85, "com sinal o amortecedor sobe (%.3f m de %.2f m)" % [stiff_j.extension(), stiff_j.stroke])
	lever.device.press()
	await _frames(10)

	# Salvar e carregar mantém o modo e os ajustes.
	var data: Dictionary = JSON.parse_string(JSON.stringify(Saves.serialize(Saves.world_assemblies(), Transform3D.IDENTITY)))
	Saves.clear_world()
	await _frames(5)
	Saves.restore(data, Transform3D.IDENTITY)
	await _frames(5)
	var found := 0
	for j in Build.joints:
		if j.type == "pistao" and j.damper:
			found += 1
	check(found == 2, "salvar e carregar mantém o modo amortecedor (%d de 2)" % found)

	print("== Model-T de um jogador: suspensão dianteira com pinos e amortecedores (em linha reta)")
	Saves.clear_world()
	await _frames(5)
	var mt := Saves.restore(Saves.read("res://tests/data/model_t.json"), Transform3D(Basis(), Vector3(30, 0.3, 30)))
	await _frames(120)
	var drive: Array = []
	for j in Build.joints:
		for b: Dictionary in j.bind_pos:
			if b.get("key", 0) == KEY_W:
				drive.append(j)
	var go: Part = Components.spawn("botao", Transform3D(Basis(), Vector3(40, 0.04, 40)))[0]
	for j: MechJoint in drive:
		Build.toggle_link(go.device, j)
	var seat_mt: Part = null
	for p: Part in mt:
		if p.kind == "assento":
			seat_mt = p
	var start := seat_mt.global_position
	go.device.press()
	var worst := Vector2.ZERO
	for i in 480:
		await get_tree().physics_frame
		if i == 360:
			go.device.release()          # freia
		for j in Build.joints:
			worst = worst.max(_play(j))
	var moved := Vector2(seat_mt.global_position.x - start.x, seat_mt.global_position.z - start.z).length()
	check(moved > 5.0, "o Model-T anda (%.1f m)" % moved)
	check(worst.x < 2.0 and worst.y < 0.015, "acelerando e freando, nenhuma junta da suspensão dobra (%.2f°, %.1f cm)" % [worst.x, worst.y * 100.0])


## Folga de uma junta: inclinação fora do eixo (graus) e separação do pivô (m).
static func _play(j: MechJoint) -> Vector2:
	if not j.is_valid() or j.type in MechJoint.SINGLE or j.type == "guincho":
		return Vector2.ZERO
	var cur := j.part_a.global_transform.affine_inverse() * j.part_b.global_transform
	var d := cur * j.rest.affine_inverse()
	var ax := j.axis.normalized()
	var swing := rad_to_deg((d.basis.orthonormalized() * ax).angle_to(ax))
	var sep := d * j.pivot - j.pivot
	if j.type in MechJoint.LINEAR:
		sep -= ax * sep.dot(ax)
	if j.type == "esferica":
		swing = 0.0
	return Vector2(swing, sep.length())

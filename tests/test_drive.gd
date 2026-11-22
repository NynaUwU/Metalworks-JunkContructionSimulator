extends Node3D
## Trem de força (Marco 4D): aceleração, troca de marcha, freio, esterço de tanque, ré,
## falta de combustível, ligações livres (qualquer peça em qualquer ordem) e quebra,
## embreagens (automática, manual, sem embreagem), elétrico, gerador, motor simples
## limitado, bomba de combustível e salvar.
##   godot --headless --path . res://tests/test_drive.tscn

const EXPECTED_CHECKS := 23

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
	bs.size = Vector3(1000, 1, 1000)
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


func _const(v: float, at := Vector3(0, 0.05, 400)) -> ConstNode:
	var p: Part = Components.spawn("constante", Transform3D(Basis(), at + Vector3(randf_range(-30, 30), 0, randf_range(-5, 5))))[0]
	(p.node as ConstNode).set_value(SignalNode.NUM, v)
	return p.node as ConstNode


func _run() -> void:
	print("== Carro com motor, câmbio automático e cubos")
	var car := DemoBuilds.build_engine_car(Vector3(0, 0, 0))
	var en: DriveNode = car["engine"]
	var gn: DriveNode = car["gearbox"]
	var chassis: Part = car["chassis"]
	var thr := _const(0.0)
	Signals.connect_ports(thr, "Valor", en, "Acelerador")
	await _frames(60)
	check(en.running and absf(en.rpm() - 850.0) < 150.0, "motor liga sozinho e fica em marcha lenta (%d rpm)" % roundi(en.rpm()))
	thr.set_value(SignalNode.NUM, 1.0)
	var p0 := chassis.global_position
	await _frames(360)
	var v := Vector2(chassis.assembly().linear_velocity.x, chassis.assembly().linear_velocity.z).length()
	var moved_fwd := (chassis.global_position - p0).dot(Vector3.FORWARD)
	check(v > 8.0 and moved_fwd > 20.0, "acelera para a frente: %.1f m/s em 6 s (%.0f m)" % [v, moved_fwd])
	check(gn.gear >= 2, "o câmbio automático trocou de marcha (%dª)" % gn.gear)
	# Freio
	var brake := _const(0.0)
	Signals.connect_ports(brake, "Valor", gn, "Freio")
	thr.set_value(SignalNode.NUM, 0.0)
	brake.set_value(SignalNode.NUM, 1.0)
	await _frames(240)
	check(chassis.assembly().linear_velocity.length() < 0.3, "freio para o carro (%.2f m/s)" % chassis.assembly().linear_velocity.length())
	brake.set_value(SignalNode.NUM, 0.0)
	# Esterço de tanque, parado
	var dir := _const(0.0)
	Signals.connect_ports(dir, "Valor", gn, "Dir")
	dir.set_value(SignalNode.NUM, 1.0)
	var yaw0 := chassis.global_basis.get_euler().y
	var pos0 := chassis.global_position
	await _frames(120)
	var turned := rad_to_deg(wrapf(chassis.global_basis.get_euler().y - yaw0, -PI, PI))
	var drift := chassis.global_position.distance_to(pos0)
	check(turned < -40.0 and drift < 3.5 and en.rpm() > 600.0,
		"esterço de tanque gira quase no lugar para a direita (%.0f° em 2 s, saiu %.1f m, motor %d rpm)" % [turned, drift, roundi(en.rpm())])
	dir.set_value(SignalNode.NUM, 0.0)
	await _frames(30)
	# Ré
	var rev := _const(0.0)
	Signals.connect_ports(rev, "Valor", gn, "Ré")
	rev.set_value(SignalNode.NUM, 1.0)
	thr.set_value(SignalNode.NUM, 1.0)
	var pr := chassis.global_position
	var fwd := -chassis.global_basis.z
	await _frames(240)
	check(gn.gear == -1 and (chassis.global_position - pr).dot(fwd) < -2.0, "ré anda para trás (%.1f m)" % -(chassis.global_position - pr).dot(fwd))
	thr.set_value(SignalNode.NUM, 0.0)
	rev.set_value(SignalNode.NUM, 0.0)

	print("== Combustível")
	var tank: DriveNode = car["tank"]
	tank.fuel = 0.002
	thr.set_value(SignalNode.NUM, 1.0)
	await _frames(240)
	check(not en.running and tank.fuel <= 0.0, "sem combustível, o motor desliga")
	thr.set_value(SignalNode.NUM, 0.0)
	# Bomba de combustível
	var pump: Part = Components.spawn("bomba", Transform3D(Basis(), tank.part.global_position + Vector3(3, 0.6, 0)))[0]
	Build.make_weld(pump, null, pump.global_position + Vector3(0, -0.55, 0))
	Economy.reset(100.0)
	var r := Drive.refuel(pump.global_position, 5.0, 0.2)
	check(absf(float(r["liters"]) - tank.capacity()) < 0.1 and absf(Economy.precise_points() - (100.0 - tank.capacity() * 0.2)) < 0.01,
		"a bomba enche o tanque e cobra (%.1f L por %.1f pontos)" % [float(r["liters"]), float(r["cost"])])
	await _frames(60)
	check(en.running, "com combustível, o motor liga de novo")
	thr.set_value(SignalNode.NUM, 0.0)

	print("== Ligações")
	var t2: Part = Components.spawn("tanque_diesel", Transform3D(Basis(), Vector3(60, 0.3, 0)))[0]
	var e2: Part = Components.spawn("motor_4l", Transform3D(Basis(), Vector3(61.5, 0.2, 0)))[0]
	var odd := Drive.toggle(t2.node, e2.node)
	var hub := Components.spawn("cubo", Transform3D(Basis(), Vector3(63, 0.1, 0)))
	var odd2 := Drive.toggle(e2.node, hub[0].mech)
	await _frames(30)
	check(odd["linked"] and odd2["linked"] and not (e2.node as DriveNode).running,
		"qualquer ligação é aceita (diesel no motor a gasolina, motor direto no cubo), mas diesel não abastece motor a gasolina")
	Drive.toggle(e2.node, hub[0].mech)
	var t3: Part = Components.spawn("tanque_gasolina", Transform3D(Basis(), Vector3(60, 0.3, 3)))[0]
	var ok := Drive.toggle(t3.node, e2.node)
	var broke := [false]
	Drive.link_broken.connect(func(_at: Vector3) -> void: broke[0] = true)
	t3.assembly().global_position += Vector3(0, 0, 6)
	await _frames(3)
	check(ok["linked"] and broke[0] and Drive.find_link(t3.node, e2.node) == null, "ligação esticada demais quebra")

	print("== Embreagens")
	var ccar := DemoBuilds.build_engine_car(Vector3(-120, 0, 0), "motor_4l", "cambio_auto", false, "embreagem_manual")
	var ce: DriveNode = ccar["engine"]
	var cc: DriveNode = ccar["clutch"]
	var cch: Part = ccar["chassis"]
	var pedal := _const(1.0)
	Signals.connect_ports(pedal, "Valor", cc, "Pedal")
	var cthr := _const(1.0)
	Signals.connect_ports(cthr, "Valor", ce, "Acelerador")
	var cp0 := cch.global_position
	await _frames(120)
	check(ce.running and ce.rpm() > 2000.0 and cch.global_position.distance_to(cp0) < 0.5,
		"embreagem manual com o pedal no fundo: motor gira (%d rpm) e o carro fica parado (%.2f m)" % [roundi(ce.rpm()), cch.global_position.distance_to(cp0)])
	cthr.set_value(SignalNode.NUM, 0.0)
	await _frames(30)
	pedal.set_value(SignalNode.NUM, 0.0)
	cthr.set_value(SignalNode.NUM, 1.0)
	var cp1 := cch.global_position
	await _frames(240)
	var c_fwd := (cch.global_position - cp1).dot(Vector3.FORWARD)
	check(c_fwd > 5.0 and cc.out.get("Engate", 0.0) > 0.5, "soltando o pedal, o carro anda (%.1f m, engate %d%%)" % [c_fwd, roundi(100.0 * float(cc.out.get("Engate", 0.0)))])
	cthr.set_value(SignalNode.NUM, 0.0)
	# Sem embreagem: motor ligado direto no câmbio
	var dcar := DemoBuilds.build_engine_car(Vector3(-160, 0, 0), "motor_4l", "cambio_auto", false, "")
	var de: DriveNode = dcar["engine"]
	var dthr := _const(1.0)
	Signals.connect_ports(dthr, "Valor", de, "Acelerador")
	var dp0: Vector3 = (dcar["chassis"] as Part).global_position
	await _frames(240)
	var d_fwd := ((dcar["chassis"] as Part).global_position - dp0).dot(Vector3.FORWARD)
	check(dcar["clutch"] == null and de.running and d_fwd > 3.0, "sem embreagem, o motor fica preso às rodas e o carro anda (%.1f m)" % d_fwd)
	dthr.set_value(SignalNode.NUM, 0.0)

	print("== Ordem livre")
	# Mesmo carro, ligado numa ordem estranha: tanque no câmbio, rodas em corrente,
	# ligações feitas de trás para a frente.
	var fcar := DemoBuilds.build_engine_car(Vector3(-200, 0, 0), "motor_4l", "cambio_auto", false)
	var fe: DriveNode = fcar["engine"]
	var fg: DriveNode = fcar["gearbox"]
	var fc: DriveNode = fcar["clutch"]
	var fhubs: Array = fcar["hubs"]
	for o: Object in [fe, fg, fc, fcar["tank"]] + fhubs:
		for l in Drive.links_of(o):
			Drive.links.erase(l)
	Drive.link(fhubs[0], fg)
	for k in range(1, fhubs.size()):
		Drive.link(fhubs[k], fhubs[k - 1])
	Drive.link(fcar["tank"], fg)
	Drive.link(fg, fc)
	Drive.link(fc, fe)
	var fnet := Drive.explore(fe)
	check(fnet["hubs"].size() == 4 and fnet["fuel"].size() == 1 and (fnet["hubs"][3]["gbs"] as Array).size() == 1 and (fnet["hubs"][3]["clutches"] as Array).size() == 1,
		"a simulação acha o caminho em qualquer ordem (4 rodas, 1 tanque, câmbio e embreagem no caminho)")
	var fthr := _const(1.0)
	Signals.connect_ports(fthr, "Valor", fe, "Acelerador")
	var fp0: Vector3 = (fcar["chassis"] as Part).global_position
	await _frames(240)
	var f_fwd := ((fcar["chassis"] as Part).global_position - fp0).dot(Vector3.FORWARD)
	check(fe.running and f_fwd > 5.0, "e o carro anda igual (%.1f m)" % f_fwd)
	fthr.set_value(SignalNode.NUM, 0.0)
	# Dois câmbios em série: as relações multiplicam
	var g2: Part = Components.spawn("cambio_manual", Transform3D(Basis(), (fcar["chassis"] as Part).global_position * Vector3(1, 0, 1) + Vector3(2.5, 0.2, 0)))[0]
	Drive.links.erase(Drive.find_link(fhubs[0], fg))
	Drive.link(fg, g2.node)
	Drive.link(g2.node, fhubs[0])
	var fnet2 := Drive.explore(fe)
	check((fnet2["hubs"][0]["gbs"] as Array).size() == 2, "câmbio → câmbio: as rodas veem os dois câmbios no caminho")

	print("== Motor elétrico e gerador")
	var ecar := DemoBuilds.build_engine_car(Vector3(120, 0, 0), "motor_eletrico", "cambio_auto", false)
	var ee: DriveNode = ecar["engine"]
	for l in Drive.links_of(ecar["tank"]):
		Drive.links.erase(l)
	var bat: Part = Components.spawn("bateria", Transform3D(Basis(), Vector3(120, 0.62, 0.95)), Vector3(1.6, 0, 0))[0]
	Build.make_weld(bat, ecar["chassis"], Vector3(120, 0.47, 0.95))
	(bat.node as PowerNode).charge = 100.0
	Drive.toggle(bat.node, ee)
	var ethr := _const(1.0)
	Signals.connect_ports(ethr, "Valor", ee, "Acelerador")
	var ep0: Vector3 = (ecar["chassis"] as Part).global_position
	await _frames(180)
	check(ee.running and (bat.node as PowerNode).charge < 100.0 and (ecar["chassis"] as Part).global_position.distance_to(ep0) > 5.0,
		"motor elétrico anda com a bateria (%.2f Wh gastos)" % (100.0 - (bat.node as PowerNode).charge))
	ethr.set_value(SignalNode.NUM, 0.0)
	var gen_e: Part = Components.spawn("motor_mono", Transform3D(Basis(), Vector3(0, 0.2, 60)))[0]
	var gen_t: Part = Components.spawn("tanque_gasolina", Transform3D(Basis(), Vector3(1, 0.3, 60)))[0]
	var gen: Part = Components.spawn("gerador", Transform3D(Basis(), Vector3(-1, 0.15, 60)))[0]
	var gbat: Part = Components.spawn("bateria", Transform3D(Basis(), Vector3(-2, 0.12, 60)))[0]
	(gbat.node as PowerNode).charge = 0.0
	Drive.toggle(gen_t.node, gen_e.node)
	Drive.toggle(gen_e.node, gen.node)
	Power.connect_nodes(gen.node, gbat.node)
	await _frames(120)
	check((gbat.node as PowerNode).charge > 0.0 and (gen.node as PowerNode).drive_w > 0.0,
		"motor → gerador carrega a bateria (%.0f W)" % (gen.node as PowerNode).drive_w)

	print("== Motor simples limitado")
	var sm := Components.spawn("motor", Transform3D(Basis(), Vector3(0, 0.2, 80)))
	var sj: MechJoint = sm[0].mech
	sj.strength = 5000.0
	sj.speed = 30.0
	sj.apply_strength()
	check(sj.strength <= MechJoint.SIMPLE_MAX_TORQUE and sj.speed <= MechJoint.SIMPLE_MAX_SPEED,
		"motor simples fica limitado (%d N·m, %.0f rad/s)" % [roundi(sj.strength), sj.speed])

	print("== Câmbio manual")
	var mcar := DemoBuilds.build_engine_car(Vector3(0, 0, 200), "motor_4l", "cambio_manual", false)
	var mg: DriveNode = mcar["gearbox"]
	var up := _const(0.0)
	Signals.connect_ports(up, "Valor", mg, "Sobe")
	var g0 := mg.gear
	for k in 2:
		up.set_value(SignalNode.NUM, 1.0)
		await _frames(3)
		up.set_value(SignalNode.NUM, 0.0)
		await _frames(3)
	check(mg.gear == g0 + 2, "manual: Sobe passa a marcha (%d → %d)" % [g0, mg.gear])

	print("== Salvar e carregar")
	gn.tank_steer = true
	var n_links := Drive.links.size()
	var data: Dictionary = JSON.parse_string(JSON.stringify(Saves.serialize(Saves.world_assemblies(), Transform3D.IDENTITY)))
	Saves.clear_world()
	await _frames(3)
	Saves.restore(data, Transform3D.IDENTITY)
	await _frames(3)
	check(Drive.links.size() == n_links and n_links >= 6, "ligações de transmissão voltam (%d)" % Drive.links.size())
	var full := false
	for n in Signals.nodes:
		if n is DriveNode and (n as DriveNode).is_tank() and (n as DriveNode).fuel > 15.0:
			full = true
	check(full, "o combustível dos tanques volta")

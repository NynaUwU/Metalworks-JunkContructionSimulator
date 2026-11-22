extends Node3D
## Sensores (Marco 4C): medidor laser, velocímetro, giroscópio, GPS, localizador,
## buscador, zona, impacto, receptor + ferramenta Laser, balança, salvar.
##   godot --headless --path . res://tests/test_sensors.tscn

const EXPECTED_CHECKS := 18

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
	bs.size = Vector3(400, 1, 400)
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


func _sensor(kind: String, at: Vector3, frozen := true) -> SensorNode:
	var b := Components.bounds(kind)
	var p: Part = Components.spawn(kind, Transform3D(Basis(), at + Vector3(0, -b.position.y + 0.005, 0)))[0]
	if frozen:
		p.assembly().set_frozen(true)
	return p.node as SensorNode


func _block(size: Vector3, at: Vector3, frozen := true) -> Part:
	var p := Build.spawn_box(size, "aco", Transform3D(Basis(), at))
	if frozen:
		p.assembly().set_frozen(true)
	return p


func _run() -> void:
	print("== Medidor laser")
	var rg := _sensor("ranger", Vector3(0, 0, 0))
	var roof := _block(Vector3(1, 0.1, 1), Vector3(0, 3.05, 0))
	await _frames(3)
	var top_y: float = (rg.part.global_transform * Vector3(0, rg.part.bounds.end.y, 0)).y
	var d: float = rg.out.get("Distância", 0.0)
	check(float(rg.out["Acertou"]) == 1.0 and absf(d - (3.0 - top_y)) < 0.02 and rg.out["Peça"] == roof and rg.out["Material"] == "aco"
		and (rg.out["Normal"] as Vector3).dot(Vector3.DOWN) > 0.99, "mede a distância até a peça de cima (%.2f m, aço, normal para baixo)" % d)
	# Uma chapa soldada no próprio medidor, no caminho do laser, é ignorada.
	var shield := Build.spawn_box(Vector3(0.3, 0.02, 0.3), "aco", Transform3D(Basis(), rg.part.global_position + Vector3(0, 0.5, 0)))
	var post := Build.spawn_box(Vector3(0.02, 0.45, 0.02), "aco", Transform3D(Basis(), rg.part.global_position + Vector3(0.1, 0.25, 0)))
	Build.make_weld(post, rg.part, rg.part.global_position + Vector3(0.1, 0.04, 0))
	Build.make_weld(post, shield, rg.part.global_position + Vector3(0.1, 0.49, 0))
	await _frames(3)
	check(rg.out["Peça"] == roof, "ignora a própria máquina (chapa soldada no caminho)")
	rg.range_m = 1.0
	await _frames(3)
	check(float(rg.out["Acertou"]) == 0.0 and is_equal_approx(float(rg.out["Distância"]), 1.0), "alcance de 1 m: não acerta o teto a 3 m")
	rg.range_m = 50.0

	print("== Velocímetro e giroscópio")
	var vel := _sensor("velocimetro", Vector3(10, 2, 0), false)
	var vasm := vel.part.assembly()
	vasm.linear_velocity = Vector3(3, 0, 4)
	vasm.angular_velocity = Vector3.ZERO
	Signals.tick(1.0 / 60.0)
	check(absf(float(vel.out["Velocidade"]) - 5.0) < 0.01 and absf(float(vel.out["km/h"]) - 18.0) < 0.05,
		"velocidade 5 m/s = 18 km/h (%.2f)" % float(vel.out["Velocidade"]))
	var gyro := _sensor("giroscopio", Vector3(14, 0, 0))
	var gasm := gyro.part.assembly()
	gasm.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(10), deg_to_rad(30), 0), EULER_ORDER_YXZ), gasm.global_position + Vector3(0, 1, 0))
	Signals.tick(1.0 / 60.0)
	check(absf(float(gyro.out["Pitch"]) - 10.0) < 0.1 and absf(float(gyro.out["Yaw"]) - 30.0) < 0.1 and absf(float(gyro.out["Roll"])) < 0.1,
		"giroscópio: pitch %.1f°, yaw %.1f°, roll %.1f°" % [float(gyro.out["Pitch"]), float(gyro.out["Yaw"]), float(gyro.out["Roll"])])

	print("== GPS")
	var gps := _sensor("gps", Vector3(20, 0, 0))
	var k: Part = Components.spawn("constante", Transform3D(Basis(), Vector3(20, 0.05, 2)))[0]
	(k.node as ConstNode).set_value(SignalNode.NUM, 0.0)
	Signals.connect_ports(k.node, "Valor", gps, "Marcar")
	await _frames(2)
	(k.node as ConstNode).set_value(SignalNode.NUM, 1.0)
	await _frames(2)
	var marked: Vector3 = gps.out["Marcado"]
	gps.part.assembly().global_position += Vector3(3, 0, 4)
	await _frames(2)
	check(marked.distance_to(Vector3(20, marked.y, 0)) < 0.01 and absf(float(gps.out["Distância"]) - 5.0) < 0.01,
		"GPS marca um ponto e mede a distância até ele (%.2f m)" % float(gps.out["Distância"]))

	print("== Localizador")
	var b3 := _sensor("localizador", Vector3(40, 0, 0))
	b3.channel = 3
	var b2 := _sensor("localizador", Vector3(32, 0, 0))
	b2.channel = 2
	var seeker := _sensor("sensor_loc", Vector3(30, 0, 0))
	seeker.channel = 3
	await _frames(2)
	var dir: Vector3 = seeker.out["Direção"]
	check(float(seeker.out["Achou"]) == 1.0 and absf(float(seeker.out["Distância"]) - 10.0) < 0.05 and dir.dot(Vector3.RIGHT) > 0.99,
		"acha o localizador do mesmo canal (10 m, para +X), não o de outro canal")
	seeker.channel = 9
	await _frames(2)
	check(float(seeker.out["Achou"]) == 0.0, "canal sem localizador: não acha")

	print("== Buscador de alvos")
	var finder := _sensor("buscador", Vector3(60, 0, 0))
	finder.range_m = 8.0
	finder.filter = SensorNode.FILTERS.find("Peças")
	var t1 := _block(Vector3(0.3, 0.3, 0.3), Vector3(64, 0.15, 0))
	_block(Vector3(0.3, 0.3, 0.3), Vector3(60, 0.15, 6))
	_block(Vector3(0.3, 0.3, 0.3), Vector3(70, 0.15, 0))      # fora do raio
	await _frames(3)
	check(float(finder.out["Quantidade"]) == 2.0 and finder.out["Alvo"] == t1 and absf(float(finder.out["Distância"]) - 4.0) < 0.1,
		"buscador acha as 2 peças no raio, a mais perto primeiro (%.1f m)" % float(finder.out["Distância"]))
	finder.filter = SensorNode.FILTERS.find("Componentes")
	await _frames(2)
	check(float(finder.out["Quantidade"]) == 0.0, "filtro Componentes: blocos comuns não contam")

	print("== Zona")
	var zone := _sensor("zona", Vector3(80, 0, 0))
	await _frames(2)
	var empty_ok := float(zone.out["Dentro"]) == 0.0
	var falling := _block(Vector3(0.4, 0.4, 0.4), Vector3(80, 1.5, 0), false)
	await _frames(60)
	check(empty_ok and float(zone.out["Dentro"]) == 1.0 and absf(float(zone.out["Massa"]) - falling.assembly().real_mass()) < 0.1,
		"zona: vazia, depois detecta a peça que caiu dentro (%.0f kg)" % float(zone.out["Massa"]))

	print("== Detector de impacto")
	var crate := _block(Vector3(0.5, 0.5, 0.5), Vector3(90, 2.5, 0), false)
	var imp_b := Components.bounds("impacto")
	var imp_p: Part = Components.spawn("impacto", Transform3D(Basis(), Vector3(90, 2.75 - imp_b.position.y, 0)))[0]
	Build.make_weld(imp_p, crate, Vector3(90, 2.75, 0))
	var imp := imp_p.node as SensorNode
	var bumped := false
	var peak := 0.0
	for i in 90:
		await get_tree().physics_frame
		bumped = bumped or float(imp.out.get("Bateu", 0.0)) > 0.0
		peak = maxf(peak, float(imp.out.get("Força", 0.0)))
	check(bumped and peak > 500.0, "caixa caindo de 2 m: o detector sente a batida (%.0f N)" % peak)

	print("== Receptor de laser e ferramenta Laser")
	var rec := _sensor("receptor", Vector3(0, 1.0, 10))      # congelado no ar
	var rg2 := _sensor("ranger", Vector3(0, 0, 10))          # laser para cima, no fundo do receptor
	await _frames(3)
	var lit_by_ranger := float(rec.out.get("Atingido", 0.0)) == 1.0
	check(lit_by_ranger or rg2.out.get("Peça") == rec.part, "o laser do medidor acende o receptor")
	var player := Player.new()
	add_child(player)
	await _frames(2)
	var rec2 := _sensor("receptor", Vector3(0, 0, 20))
	player.teleport(Vector3(0, 0, 23))
	var dpos := rec2.part.global_position - (player.global_position + Vector3(0, Player.EYE_HEIGHT, 0))
	player.yaw = atan2(-dpos.x, -dpos.z)
	player.pitch = asin(clampf(dpos.normalized().y, -1.0, 1.0))
	player.select_tool(7)
	var laser: LaserTool = player.tools[7]
	await _frames(3)
	laser.firing = true
	await _frames(3)
	check(float(rec2.out.get("Atingido", 0.0)) == 1.0, "a ferramenta Laser acende o receptor")
	laser.firing = false
	await _frames(3)
	check(float(rec2.out.get("Atingido", 1.0)) == 0.0, "soltando, o receptor apaga")
	player.queue_free()

	print("== Balança")
	var sc := Components.spawn("balanca", Transform3D(Basis(), Vector3(100, 0.035, 0)))
	sc[0].assembly().set_anchored(true)
	var j: MechJoint = sc[0].mech
	await _frames(90)
	var tare: float = j.out.get("Peso", 0.0)
	var side := pow(100.0 / 785.0, 1.0 / 3.0)
	_block(Vector3(side, side, side), sc[1].global_position + Vector3(0, 0.015 + side * 0.5 + 0.01, 0), false)
	await _frames(150)
	var w: float = j.out.get("Peso", 0.0)
	check(absf(tare - 3.77) < 0.3 and absf(w - tare - 100.0) < 1.5, "balança: prato %.2f kg (vazia) e pesa 100 kg (%.1f kg)" % [tare, w - tare])

	print("== Salvar e carregar")
	rg.range_m = 33.0
	b3.channel = 7
	var data: Dictionary = JSON.parse_string(JSON.stringify(Saves.serialize(Saves.world_assemblies(), Transform3D.IDENTITY)))
	Saves.clear_world()
	await _frames(3)
	Saves.restore(data, Transform3D.IDENTITY)
	await _frames(3)
	var r33 := false
	var ch7 := false
	var gps_mark := false
	for n in Signals.nodes:
		var s := n as SensorNode
		if s == null:
			continue
		r33 = r33 or (s.kind == "ranger" and is_equal_approx(s.range_m, 33.0))
		ch7 = ch7 or (s.kind == "localizador" and s.channel == 7)
		gps_mark = gps_mark or (s.kind == "gps" and s.has_mark)
	check(r33 and ch7 and gps_mark, "ajustes dos sensores voltam (alcance, canal, ponto do GPS)")
	var scales := Build.joints.filter(func(jj: MechJoint) -> bool: return jj.type == "balanca")
	check(scales.size() == 1, "a balança volta como componente")

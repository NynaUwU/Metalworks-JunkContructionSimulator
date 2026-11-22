extends Node3D
## Energia elétrica (Marco 4B): rede, baterias, luzes, relé, chave, painel solar, posto
## de recarga, medidor, salvar.
##   godot --headless --path . res://tests/test_power.tscn

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
	bs.size = Vector3(300, 1, 300)
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


func _spawn(kind: String, at: Vector3, size := Vector3.ZERO) -> PowerNode:
	var b := Components.bounds(kind, size)
	var p: Part = Components.spawn(kind, Transform3D(Basis(), at + Vector3(0, -b.position.y + 0.01, 0)), size)[0]
	return p.node as PowerNode


## Um "tick" longo de energia (as contas usam o tempo: 1 hora = Wh direto).
func _hours(h: float) -> void:
	Signals.tick(1.0 / 60.0)
	Power.tick(h * 3600.0)


func _run() -> void:
	print("== Baterias")
	var small := _spawn("bateria", Vector3(0, 0, 0), Vector3(0.6, 0, 0))
	var mid := _spawn("bateria", Vector3(1, 0, 0))
	var big := _spawn("bateria", Vector3(2, 0, 0), Vector3(1.6, 0, 0))
	check(absf(small.capacity() - 10.8) < 0.01 and absf(mid.capacity() - 50.0) < 0.01 and absf(big.capacity() - 204.8) < 0.01,
		"bateria pequena/média/grande: %.1f / %.0f / %.1f Wh" % [small.capacity(), mid.capacity(), big.capacity()])
	check(absf(mid.charge - 25.0) < 0.01, "bateria nova vem pela metade (%.1f Wh)" % mid.charge)

	print("== Rede: luz gastando da bateria")
	var lamp := _spawn("luz", Vector3(1, 0, 1.5))
	Power.connect_nodes(mid, lamp)
	await _frames(2)
	_hours(1.0)
	check(absf(mid.charge - 10.0) < 0.05, "luz de 15 W por 1 h: 25 → 10 Wh (%.2f)" % mid.charge)
	check(lamp.supply > 0.99 and lamp.light.visible and lamp.light.light_energy > 1.0, "luz acesa com energia")
	_hours(1.0)
	check(mid.charge < 0.01 and lamp.supply < 0.7 and lamp.supply > 0.6, "bateria acaba: a luz fica fraca na proporção (%.2f)" % lamp.supply)
	_hours(0.5)
	check(lamp.supply < 0.01 and not lamp.light.visible and float(lamp.out.get("Acesa", 1.0)) < 0.01, "sem carga, a luz apaga")

	print("== Rede dividida: baterias juntas")
	Power.connect_nodes(mid, big)
	big.charge = 100.0
	_hours(0.0)
	var total := mid.charge + big.charge
	check(absf(total - 100.0) < 0.01 and absf(mid.charge / mid.capacity() - big.charge / big.capacity()) < 1e-4,
		"baterias da mesma rede dividem a carga (mesma %%: %.1f%% e %.1f%%)" % [100.0 * mid.charge / mid.capacity(), 100.0 * big.charge / big.capacity()])
	check(lamp.supply > 0.99, "com a bateria grande na rede, a luz volta")

	print("== Relé e chave")
	var lamp2 := _spawn("luz", Vector3(6, 0, 0))
	var relay := _spawn("rele", Vector3(5, 0, 0))
	var bat2 := _spawn("bateria", Vector3(4, 0, 0))
	Power.connect_nodes(bat2, relay)
	Power.connect_nodes(relay, lamp2)
	await _frames(3)
	check(lamp2.supply < 0.01, "relé sem sinal: não passa energia (luz apagada)")
	var lever: Part = Components.spawn("alavanca", Transform3D(Basis(), Vector3(5, 0.05, 2)))[0]
	Signals.connect_ports(lever.device, "Saída", relay, "Liga")
	lever.device.press()
	await _frames(3)
	check(relay.closed and lamp2.supply > 0.99 and Power.network_of(lamp2).has(bat2), "relé com sinal: a bateria acende a luz")
	lever.device.press()
	await _frames(3)
	var sw := _spawn("chave", Vector3(8, 0, 0))
	var lamp3 := _spawn("luz", Vector3(9, 0, 0))
	Power.connect_nodes(bat2, sw)
	Power.connect_nodes(sw, lamp3)
	await _frames(3)
	var off_ok := lamp3.supply < 0.01
	sw.toggle()
	await _frames(3)
	check(off_ok and lamp3.supply > 0.99 and float(sw.out.get("Ligada", 0.0)) == 1.0, "chave: E liga e desliga a passagem")

	print("== Painel solar")
	var panel := _spawn("solar", Vector3(12, 0, 0))
	var bat3 := _spawn("bateria", Vector3(13, 0, 0))
	bat3.charge = 0.0
	Power.connect_nodes(panel, bat3)
	_hours(1.0)
	var expect_w := PowerNode.SOLAR_W * Vector3.UP.dot(-Power.sun_dir)
	check(absf(bat3.charge - expect_w) < 0.1 and absf(panel.power_w - expect_w) < 0.1, "painel virado para cima carrega a bateria (%.1f Wh em 1 h)" % bat3.charge)
	panel.part.assembly().global_transform = Transform3D(Basis(Vector3.RIGHT, PI), panel.part.assembly().global_position)
	var before := bat3.charge
	_hours(1.0)
	check(absf(bat3.charge - before) < 0.01, "painel de cabeça para baixo não gera")

	print("== Posto de recarga")
	var post := _spawn("recarga", Vector3(20, 0, 0))
	var bat4 := _spawn("bateria", Vector3(21, 0, 0))
	bat4.charge = 0.0
	Power.connect_nodes(post, bat4)
	Economy.reset(100.0)
	_hours(1.0)
	check(bat4.charge < 0.01 and Economy.points() == 100, "solto (não soldado no chão) não recarrega")
	Build.make_weld(post.part, null, post.part.global_position + Vector3(0, -0.6, 0))
	await _frames(2)
	_hours(1.0)
	check(absf(bat4.charge - 50.0) < 0.01 and absf(Economy.precise_points() - 95.0) < 0.01,
		"soldado no chão: enche a bateria e cobra 1 ponto a cada 10 Wh (%.1f Wh, %.1f pontos)" % [bat4.charge, Economy.precise_points()])
	bat4.charge = 0.0
	Economy.reset(1.0)
	_hours(1.0)
	check(absf(bat4.charge - 10.0) < 0.05 and Economy.precise_points() < 0.01, "sem pontos, para de carregar (%.1f Wh com 1 ponto)" % bat4.charge)

	print("== Medidor")
	var meter := _spawn("medidor", Vector3(1, 0, 3))
	Power.connect_nodes(meter, mid)
	_hours(0.0)
	await _frames(2)
	var cap := mid.capacity() + big.capacity()
	check(absf(float(meter.out["Capacidade"]) - cap) < 0.01 and absf(float(meter.out["Consumo"]) - PowerNode.LIGHT_W) < 0.01,
		"medidor: capacidade %.0f Wh e consumo %.0f W da rede" % [float(meter.out["Capacidade"]), float(meter.out["Consumo"])])
	check(float(mid.out["%"]) > 0.0 and absf(float(meter.out["%"]) - float(mid.out["%"])) < 0.01, "bateria e medidor mandam a %% como sinal (%.1f%%)" % float(meter.out["%"]))

	print("== Luz: cor e brilho pelo sinal")
	var k: Part = Components.spawn("constante", Transform3D(Basis(), Vector3(1, 0.05, 4)))[0]
	var kn := k.node as ConstNode
	kn.set_value(SignalNode.VEC, Vector3(255, 0, 0))
	Signals.connect_ports(kn, kn.outputs()[0][0], lamp, "Cor")
	await _frames(3)
	check(lamp.color.is_equal_approx(Color(1, 0, 0)) and lamp.light.light_color.is_equal_approx(Color(1, 0, 0)), "entrada Cor (vetor 0 a 255) troca a cor da luz")

	print("== Salvar e carregar")
	mid.charge = 20.0
	big.charge = 81.92
	lamp.brightness = 0.5
	var data: Dictionary = JSON.parse_string(JSON.stringify(Saves.serialize(Saves.world_assemblies(), Transform3D.IDENTITY)))
	var n_pw: int = (data["pwires"] as Array).size()
	Saves.clear_world()
	await _frames(3)
	Saves.restore(data, Transform3D.IDENTITY)
	await _frames(3)
	var bats := Power.nodes.filter(func(n: PowerNode) -> bool: return n.kind == "bateria")
	var lamps := Power.nodes.filter(func(n: PowerNode) -> bool: return n.kind == "luz" and is_equal_approx(n.brightness, 0.5))
	check(Power.wires.size() == n_pw and n_pw >= 9, "fios de energia voltam (%d)" % Power.wires.size())
	var sum := 0.0
	for b: PowerNode in bats:
		sum += b.charge
	check(lamps.size() == 1 and sum > 50.0, "carga das baterias e ajustes da luz voltam (%.1f Wh no total)" % sum)

	print("== Construção salva leva o que está no fio de energia")
	var a1 := _spawn("bateria", Vector3(40, 0, 0))
	var l1 := _spawn("luz", Vector3(42, 0, 0))
	Power.connect_nodes(a1, l1)
	var machine := Saves.machine_of(a1.part)
	check(machine.has(l1.part.assembly()), "a luz ligada pelo fio entra na construção da bateria")
	Build.delete_part(l1.part)
	await _frames(2)
	check(Power.wires_of(a1).is_empty(), "apagar a peça apaga os fios de energia dela")

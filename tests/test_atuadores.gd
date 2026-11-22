extends Node3D
## Atuadores, caixa de transferência e diferencial (Marco 4E, parte 3).
##   godot --headless --path . res://tests/test_atuadores.tscn

const EXPECTED_CHECKS := 15

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
	bs.size = Vector3(2000, 1, 2000)
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


func _const(v: Variant, at: Vector3) -> ConstNode:
	var p: Part = Components.spawn("constante", Transform3D(Basis(), at))[0]
	Build.make_weld(p, null, at + Vector3(0, -0.03, 0))
	var k := p.node as ConstNode
	k.set_value(SignalNode.VEC if v is Vector3 else SignalNode.NUM, v)
	return k


## Um atuador soldado em cima de um bloco de aço. Retorna [atuador, bloco].
func _rig(kind: String, at: Vector3, block := Vector3(0.4, 0.1, 0.4)) -> Array:
	var b: Part = Build.spawn_box(block, "aco", Transform3D(Basis(), at + Vector3(0, block.y * 0.5, 0)))
	var ab := Components.bounds(kind)
	var top := at + Vector3(0, block.y, 0)
	var p: Part = Components.spawn(kind, Transform3D(Basis(), top + Vector3(0, -ab.position.y, 0)))[0]
	Build.make_weld(p, b, top)
	return [p.node, b]


func _run() -> void:
	print("== Propulsor vetorial")
	var r1 := _rig("propulsor_vetorial", Vector3(0, 0, 0))
	var th: ActuatorNode = r1[0]
	var tb: Part = r1[1]
	await _frames(20)
	var p0 := tb.global_position
	var thr := _const(1.0, Vector3(5, 0.03, 5))
	Signals.connect_ports(thr, "Valor", th, "Força")
	await _frames(120)
	var moved := (tb.global_position - p0).dot(Vector3.FORWARD)
	check(moved > 1.0 and float(th.out["Força"]) == th.max_force, "empurra para a frente (lado da lente): %.1f m em 2 s" % moved)
	thr.set_value(SignalNode.NUM, 0.0)
	var up := _const(Vector3.UP, Vector3(6, 0.03, 5))
	Signals.connect_ports(up, "Valor", th, "Vetor")
	await _frames(60)
	var y0 := tb.global_position.y
	thr.set_value(SignalNode.NUM, 1.0)
	await _frames(60)
	check(tb.global_position.y > y0 + 0.5, "Vetor (para cima) escolhe a direção: subiu %.1f m" % (tb.global_position.y - y0))
	thr.set_value(SignalNode.NUM, 0.0)

	print("== Hoverball")
	var r2 := _rig("hoverball", Vector3(20, 0, 0), Vector3(0.3, 0.1, 0.3))
	var hb: ActuatorNode = r2[0]
	hb.max_force = 3000.0
	hb.height = 1.5
	await _frames(300)
	var hv := (r2[1] as Part).assembly().linear_velocity.length()
	check(absf(float(hb.out["Altura"]) - 1.5) < 0.2 and hv < 0.3, "segura na altura pedida (%.2f m de 1,5, %.2f m/s)" % [float(hb.out["Altura"]), hv])
	var off := _const(0.0, Vector3(25, 0.03, 5))
	Signals.connect_ports(off, "Valor", hb, "Ligado")
	await _frames(120)
	check(float(hb.out["Altura"]) < 0.4, "desligada, desce (%.2f m)" % float(hb.out["Altura"]))

	print("== Forcer")
	var fp: Part = Components.spawn("forcer", Transform3D(Basis(), Vector3(40, 0.05 - Components.bounds("forcer").position.y, 0)))[0]
	Build.make_weld(fp, null, Vector3(40, 0.05, 0))
	var fn := fp.node as ActuatorNode
	var target: Part = Build.spawn_box(Vector3(0.3, 0.3, 0.3), "aluminio", Transform3D(Basis(), Vector3(40, 0.15, -2.0)))
	await _frames(20)
	var t0 := target.global_position
	var fk := _const(400.0, Vector3(42, 0.03, 3))
	Signals.connect_ports(fk, "Valor", fn, "Força")
	await _frames(90)
	var pushed := t0.distance_to(target.global_position)
	check(float(fn.out["Acertou"]) == 1.0 or pushed > 2.0, "acerta o que está na frente")
	check((target.global_position - t0).dot(Vector3.FORWARD) > 0.5, "empurra para longe (%.1f m)" % (target.global_position - t0).dot(Vector3.FORWARD))

	print("== Gimbal")
	var r3 := _rig("gimbal", Vector3(60, 0, 0), Vector3(0.3, 0.1, 0.3))
	var gb: ActuatorNode = r3[0]
	gb.max_force = 5000.0
	var dirk := _const(Vector3.RIGHT, Vector3(63, 0.03, 4))
	Signals.connect_ports(dirk, "Valor", gb, "Direção")
	await _frames(240)
	check(float(gb.out["Erro"]) < 10.0, "gira a máquina para a frente apontar para a Direção (erro %.1f°)" % float(gb.out["Erro"]))

	print("== Peso, congelador e User")
	var r4 := _rig("peso", Vector3(80, 0, 0))
	var pw: ActuatorNode = r4[0]
	var m0 := (r4[1] as Part).assembly().real_mass()
	var mk := _const(500.0, Vector3(82, 0.03, 3))
	Signals.connect_ports(mk, "Valor", pw, "Massa")
	await _frames(20)
	check(absf((r4[1] as Part).assembly().real_mass() - m0 - (500.0 - 0.0)) < 60.0 and is_equal_approx(pw.part.mass, 500.0),
		"peso: a massa vira %.0f kg (máquina %.0f → %.0f kg)" % [pw.part.mass, m0, (r4[1] as Part).assembly().real_mass()])
	var r5 := _rig("congelador", Vector3(100, 3, 0))
	var cz: ActuatorNode = r5[0]
	var ck := _const(1.0, Vector3(102, 0.03, 3))
	Signals.connect_ports(ck, "Valor", cz, "Congelar")
	await _frames(60)
	var still := (r5[1] as Part).global_position.y
	ck.set_value(SignalNode.NUM, 0.0)
	await _frames(60)
	check(still > 2.9 and (r5[1] as Part).global_position.y < 1.0 and float(cz.out["Congelado"]) == 0.0, "congelador segura no ar e solta (%.2f m → %.2f m)" % [still, (r5[1] as Part).global_position.y])
	var bt: Part = Components.spawn("botao", Transform3D(Basis(), Vector3(120, 0.04, -0.6)))[0]
	Build.make_weld(bt, null, Vector3(120, 0.0, -0.6))
	var up_: Part = Components.spawn("user", Transform3D(Basis(), Vector3(120, 0.04 - Components.bounds("user").position.y, -0.35)))[0]
	Build.make_weld(up_, null, Vector3(120, 0.04, -0.35))
	var un := up_.node as ActuatorNode
	var uk := _const(0.0, Vector3(122, 0.03, 3))
	Signals.connect_ports(uk, "Valor", un, "Usar")
	await _frames(5)
	uk.set_value(SignalNode.NUM, 1.0)
	await _frames(3)
	var held := bt.device.value
	uk.set_value(SignalNode.NUM, 0.0)
	await _frames(3)
	check(held == 1.0 and bt.device.value == 0.0 and un.out["Alvo"] == bt, "User aperta o botão na frente enquanto Usar está ligado e solta depois")

	print("== Caixa de transferência e diferencial")
	var car := DemoBuilds.build_engine_car(Vector3(0, 1.2, 200), "motor_4l", "cambio_auto", false)
	var ch: Part = car["chassis"]
	Build.make_weld(ch, null, ch.global_position)      # chassi preso no ar: as rodas giram soltas
	var en: DriveNode = car["engine"]
	var gbx: DriveNode = car["gearbox"]
	var hubs: Array = car["hubs"]
	var tr: DriveNode = Components.spawn("transferencia", Transform3D(Basis(), ch.global_position + Vector3(0, 0.5, 0.4)))[0].node
	var df: DriveNode = Components.spawn("diferencial", Transform3D(Basis(), ch.global_position + Vector3(0, 0.5, 0.0)))[0].node
	Build.make_weld(tr.part, ch, ch.global_position + Vector3(0, 0.39, 0.4))
	Build.make_weld(df.part, ch, ch.global_position + Vector3(0, 0.37, 0.0))
	for j in hubs:
		Drive.links.erase(Drive.find_link(gbx, j))
		Drive.link(df, j)
	Drive.link(gbx, tr)
	Drive.link(tr, df)
	var net := Drive.explore(en)
	var hub_path: Array = net["hubs"][0]["gbs"]
	check(hub_path.size() == 3 and net["hubs"][0]["diff"] == df, "câmbio → transferência → diferencial → rodas: as três relações no caminho")
	tr.low = true
	var ratio_low := 1.0
	for g: DriveNode in hub_path:
		ratio_low *= g.total_ratio()
	tr.low = false
	var ratio_high := 1.0
	for g: DriveNode in hub_path:
		ratio_high *= g.total_ratio()
	check(is_equal_approx(ratio_low / ratio_high, tr.low_ratio / tr.high_ratio), "reduzida multiplica a relação por %.1f" % (ratio_low / ratio_high))
	# Diferencial: uma roda presa, as outras giram mais (aberto) ou igual (travado)
	var thk := _const(0.35, ch.global_position + Vector3(3, 0, 0))
	Signals.connect_ports(thk, "Valor", en, "Acelerador")
	var stuck: MechJoint = hubs[0]
	stuck.part_b.assembly().set_frozen(true)
	await _frames(180)
	var open_ratio := _free_ratio(en, hubs, stuck)
	var lk := _const(1.0, ch.global_position + Vector3(4, 0, 0))
	Signals.connect_ports(lk, "Valor", df, "Travar")
	await _frames(180)
	var locked_ratio := _free_ratio(en, hubs, stuck)
	check(open_ratio > 1.2 and float(df.out["Diferença"]) >= 0.0, "aberto: com uma roda presa, as outras giram mais rápido (%.2f × o giro do motor ÷ relação)" % open_ratio)
	check(locked_ratio < 1.12 and locked_ratio > 0.85 and float(df.out["Travado"]) == 1.0, "travado: as rodas soltas giram no giro do motor ÷ relação (%.2f ×)" % locked_ratio)

	print("== Salvar")
	hb.height = 2.5
	df.diff_ratio = 3.2
	tr.low_default = true
	var data: Dictionary = JSON.parse_string(JSON.stringify(Saves.serialize(Saves.world_assemblies(), Transform3D.IDENTITY)))
	Saves.clear_world()
	await _frames(3)
	Saves.restore(data, Transform3D.IDENTITY)
	await _frames(3)
	var ok_h := false
	var ok_d := false
	for n in Signals.nodes:
		if n is ActuatorNode and (n as ActuatorNode).kind == "hoverball" and is_equal_approx((n as ActuatorNode).height, 2.5):
			ok_h = true
		if n is DriveNode and (n as DriveNode).is_diff() and is_equal_approx((n as DriveNode).diff_ratio, 3.2):
			for m in Signals.nodes:
				if m is DriveNode and (m as DriveNode).is_transfer() and (m as DriveNode).low_default:
					ok_d = true
	check(ok_h and ok_d, "ajustes dos atuadores, da transferência e do diferencial voltam do save")


## Giro médio das rodas soltas ÷ (giro do motor ÷ relação do caminho).
func _free_ratio(en: DriveNode, hubs: Array, stuck: MechJoint) -> float:
	var net := Drive.explore(en)
	var ratio := 1.0
	for g: DriveNode in net["hubs"][0]["gbs"]:
		ratio *= g.total_ratio()
	var sum := 0.0
	var k := 0
	for j: MechJoint in hubs:
		if j == stuck:
			continue
		sum += (-1.0 if j.invert else 1.0) * j.spin()
		k += 1
	var target := en.omega / ratio if absf(ratio) > 1e-4 else 1.0
	return (sum / k) / target if absf(target) > 1e-4 else 0.0

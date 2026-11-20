extends Node3D
## Testes do salvamento: mundo inteiro e construções individuais.
##   godot --headless --path . res://tests/test_save.tscn

const EXPECTED_CHECKS := 41

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
	Economy.reset()
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
	Saves.world = self
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


func _all_parts() -> Array[Part]:
	var out: Array[Part] = []
	for asm in Saves.world_assemblies():
		out.append_array((asm as Assembly).get_parts())
	return out


## Resumo comparável de cada peça: material, volume e posição.
func _snapshot() -> Array:
	var out: Array = []
	for p in _all_parts():
		out.append({"m": p.material_id, "vol": p.volume, "pos": p.global_position, "kind": p.kind,
			"anch": p.assembly().anchored, "frz": p.assembly().frozen})
	return out


func _matches(before: Array, after: Array, offset := Transform3D.IDENTITY) -> int:
	var used := {}
	var ok := 0
	for b: Dictionary in before:
		var want: Vector3 = offset * (b["pos"] as Vector3)
		for i in after.size():
			if used.has(i):
				continue
			var a: Dictionary = after[i]
			if a["m"] == b["m"] and a["kind"] == b["kind"] and absf(a["vol"] - b["vol"]) < 1e-4 \
					and (a["pos"] as Vector3).distance_to(want) < 0.01:
				used[i] = true
				ok += 1
				break
	return ok


func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


func _run() -> void:
	print("== Montando um mundo")
	var o := Vector3(0, 0, 0)
	var base := Build.spawn_box(Vector3(3, 0.1, 2), "aco", Transform3D(Basis(), o + Vector3(0, 0.05, 0)))
	Build.make_weld(base, null, o + Vector3(-1.45, 0.0, 0))                      # ancorada no chão
	var wall := Build.spawn_box(Vector3(0.1, 0.8, 2), "ferro", Transform3D(Basis(), o + Vector3(1.45, 0.5, 0)))
	Build.make_weld(wall, base, o + Vector3(1.45, 0.1, 0.5))
	var cut_me := Build.spawn_box(Vector3(1, 0.1, 1), "aluminio", Transform3D(Basis(), o + Vector3(5, 0.05, 0)))
	var pieces := Build.cut_part(cut_me, Plane(Vector3(1, 0, 1).normalized(), 0.1))
	var frozen := Build.spawn_box(Vector3(0.5, 0.5, 0.5), "aco", Transform3D(Basis(Vector3.UP, 0.4), o + Vector3(8, 2.0, 0)))
	frozen.assembly().set_frozen(true)
	var motor := Components.spawn("motor", Transform3D(Basis(), o + Vector3(-0.8, 0.27, 0.3)))
	Build.make_weld(motor[0], base, o + Vector3(-0.8, 0.1, 0.3))
	var wheel: Part = Components.spawn("roda", Transform3D(Basis(), o + Vector3(-0.8, 0.6, 0.3)), Vector3(0.3, 0.15, 0))[0]
	Build.make_weld(wheel, motor[1], o + Vector3(-0.8, 0.52, 0.3))
	var lever: Part = Components.spawn("alavanca", Transform3D(Basis(), o + Vector3(0.5, 0.14, -0.6)))[0]
	Build.make_weld(lever, base, o + Vector3(0.5, 0.1, -0.6))
	var ins := Build.place_insulator(base, o + Vector3(0, 0.1, -0.2), Vector3.UP)
	Build.toggle_link(lever.device, motor[0].mech, [ins])
	var pot: Part = Components.spawn("potenciometro", Transform3D(Basis(), o + Vector3(-0.2, 0.14, 0.7)))[0]
	Build.make_weld(pot, base, o + Vector3(-0.2, 0.1, 0.7))
	pot.device.toggle_range()
	pot.device.drag(-150.0)
	var piston := Components.spawn("pistao", Transform3D(Basis(), o + Vector3(12, 0.36, 0)))
	piston[0].mech.hold = true
	piston[0].mech.strength = 7777.0
	piston[0].mech.bind_pos = [{"key": KEY_Q}, {"mouse": MOUSE_BUTTON_RIGHT}]
	var winch := Components.spawn("guincho", Transform3D(Basis(), o + Vector3(16, 0.14, 0)))
	winch[0].mech.rope_len = 3.25
	var lock := Components.spawn("trava", Transform3D(Basis(), o + Vector3(20, 0.02, 0)))
	lock[0].mech.lock_idle = true
	var coupler: Part = Components.spawn("engate", Transform3D(Basis(), o + Vector3(24, 0.04, 0)))[0]
	Build.spawn_box(Vector3(0.3, 0.2, 0.3), "aco", Transform3D(Basis(), o + Vector3(24, 0.19, 0)))
	var seat := Components.spawn("assento", Transform3D(Basis(), o + Vector3(28, 0.06, 0)))
	Economy.reset(123.4)
	await _frames(20)
	coupler.mech.manual = true
	await _frames(5)
	check(pieces.size() == 2 and coupler.mech.is_locked(), "cena montada (peça cortada, engate travado)")

	var before := _snapshot()
	var n_welds := Build.welds.size()
	var n_joints := Build.joints.size()
	var n_devices := Build.devices.size()
	var n_asm := Saves.world_assemblies().size()

	print("== Salvar → apagar → carregar")
	var data := _json(Saves.serialize(Saves.world_assemblies(), Transform3D.IDENTITY))
	check(data.get("format", "") == Saves.FORMAT and int(data.get("version", 0)) == Saves.VERSION, "save tem formato e versão")
	Saves.clear_world()
	await _frames(3)
	check(Saves.world_assemblies().is_empty() and Build.joints.is_empty() and Build.welds.is_empty(), "apagar o mundo remove peças, juntas e soldas")
	Saves.restore(data, Transform3D.IDENTITY)
	await _frames(3)
	var after := _snapshot()
	check(after.size() == before.size(), "mesmo número de peças (%d → %d)" % [before.size(), after.size()])
	check(_matches(before, after) == before.size(), "cada peça volta no lugar, com o mesmo metal e volume (%d/%d)" % [_matches(before, after), before.size()])
	check(Build.welds.size() == n_welds, "mesmo número de soldas (%d → %d)" % [n_welds, Build.welds.size()])
	check(Build.joints.size() == n_joints and Build.devices.size() == n_devices, "mesmo número de componentes e controles")
	check(Saves.world_assemblies().size() == n_asm, "as soldas juntam as mesmas montagens (%d → %d)" % [n_asm, Saves.world_assemblies().size()])

	var parts := _all_parts()
	var find := func(pred: Callable) -> Part:
		for p in parts:
			if pred.call(p):
				return p
		return null
	var base2: Part = find.call(func(p: Part) -> bool: return p.material_id == "aco" and absf(p.volume - 0.6) < 1e-3)
	check(base2 != null and base2.assembly().anchored, "a chapa ancorada continua ancorada")
	var frozen2: Part = find.call(func(p: Part) -> bool: return p.global_position.distance_to(o + Vector3(8, 2, 0)) < 0.01)
	check(frozen2 != null and frozen2.assembly().frozen, "a peça congelada continua congelada no ar")
	var cut_n := 0
	var cut_vol := 0.0
	for p in parts:
		if p.material_id == "aluminio":
			cut_n += 1
			cut_vol += p.volume
	check(cut_n == 2 and absf(cut_vol - 0.1) < 1e-4, "os dois pedaços cortados voltam com o corte")
	var motor2: Part = find.call(func(p: Part) -> bool: return p.kind == "motor" and p.comp_index == 0)
	var lever2: Part = find.call(func(p: Part) -> bool: return p.kind == "alavanca")
	check(motor2 != null and lever2 != null and motor2.mech.sources.has(lever2.device), "o fio da alavanca até o motor voltou")
	var routed: Array = motor2.mech.routes.get(lever2.device, []) if motor2 and lever2 else []
	check(routed.size() == 1 and (routed[0] as Part).kind == "isolador", "o fio passa pelo mesmo isolador")
	var wheel2: Part = find.call(func(p: Part) -> bool: return p.kind == "roda")
	check(wheel2 != null and wheel2.assembly() == motor2.mech.part_b.assembly(), "a roda continua soldada no disco do motor")
	lever2.device.press()
	await _frames(40)
	check(wheel2.assembly().angular_velocity.length() > 3.0, "ligando a alavanca, o motor carregado gira a roda (%.1f rad/s)" % wheel2.assembly().angular_velocity.length())
	lever2.device.press()
	var pot2: Part = find.call(func(p: Part) -> bool: return p.kind == "potenciometro")
	check(pot2.device.positive_only and absf(pot2.device.value - 0.5) < 0.01, "alavanca variável: faixa só positiva e posição (%.2f)" % pot2.device.value)
	var piston2: Part = find.call(func(p: Part) -> bool: return p.kind == "pistao" and p.comp_index == 0)
	var pj: MechJoint = piston2.mech
	check(pj.hold and is_equal_approx(pj.strength, 7777.0), "pistão: ajustes voltam (ficar parado, força)")
	check(pj.bind_pos.size() == 2 and typeof(pj.bind_pos[0]["key"]) == TYPE_INT and pj.bind_pos[0]["key"] == KEY_Q \
		and pj.bind_pos[1]["mouse"] == MOUSE_BUTTON_RIGHT, "pistão: teclas e botão do mouse voltam")
	var winch2: Part = find.call(func(p: Part) -> bool: return p.kind == "guincho" and p.comp_index == 0)
	check(absf(winch2.mech.rope_len - 3.25) < 1e-3, "guincho: comprimento do cabo volta")
	var lock2: Part = find.call(func(p: Part) -> bool: return p.kind == "trava" and p.comp_index == 0)
	check(lock2.mech.lock_idle and lock2.mech.joint != null, "dobradiça com trava: opção e junta física voltam")
	var coupler2: Part = find.call(func(p: Part) -> bool: return p.kind == "engate")
	check(coupler2.mech.manual and coupler2.mech.is_locked(), "engate: ligado e travado no bloco")
	var seat2: Part = find.call(func(p: Part) -> bool: return p.kind == "assento" and p.comp_index == 1)
	check(seat2 != null and seat2.has_meta("seat_base") and seat2.assembly().get_parts().size() == 2, "assento e encosto voltam juntos")
	var hot := false
	for w in Build.welds:
		if w.ball.material_override is StandardMaterial3D and (w.ball.material_override as StandardMaterial3D).emission_enabled:
			hot = true
	check(not hot, "as bolinhas de solda carregadas já nascem frias")

	print("== Arquivos do mundo")
	var path := Saves.save_world("Teste do Save çá")
	check(path.ends_with("teste_do_save_ca.json") and FileAccess.file_exists(path), "salvar cria o arquivo (%s)" % path.get_file())
	var listed := Saves.list(Saves.DIR_WORLDS)
	var entry: Dictionary = {}
	for e: Dictionary in listed:
		if e["path"] == path:
			entry = e
	check(entry.get("name", "") == "Teste do Save çá" and entry.get("parts", 0) == before.size(), "a lista mostra o nome e o número de peças")
	Economy.reset(0.0)
	check(Saves.load_world(path), "carregar o arquivo funciona")
	await _frames(3)
	check(absf(Economy.precise_points() - 123.4) < 1e-6, "os pontos voltam (%.1f)" % Economy.precise_points())
	check(_snapshot().size() == before.size(), "o mundo carregado do arquivo tem todas as peças")
	Saves.delete(path)
	check(not FileAccess.file_exists(path), "apagar remove o arquivo")

	print("== Construção individual")
	Saves.clear_world()
	await _frames(2)
	var seat_car := DemoBuilds.build_car(Vector3(0, 0, 40))
	var lone := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), Vector3(5, 0.05, 40)))
	await _frames(30)
	var machine := Saves.machine_of(seat_car)
	var machine_parts := 0
	for asm: Assembly in machine:
		machine_parts += asm.get_parts().size()
	check(machine_parts == 15 and not machine.has(lone.assembly()), "a máquina inclui chassi, assento, motores e rodas, mas não a chapa solta (%d peças)" % machine_parts)
	var origin := Saves.machine_origin(machine)
	check(absf(origin.origin.y) < 0.1, "a origem fica na base da máquina (y = %.2f)" % origin.origin.y)
	var bp := _json(Saves.serialize(machine, origin))
	var expected_price := 0.0
	for k in ["assento", "motor", "motor", "motor", "motor", "roda", "roda", "roda", "roda"]:
		expected_price += Components.price(k, Vector3(0.4, 0.2, 0) if k == "roda" else Vector3.ZERO)
	expected_price += Economy.recycle_value("aco", 1.6 * 0.1 * 2.4 * MetalMaterials.density("aco")) * Catalog.PRICE_FACTOR
	var price := Saves.build_price(bp)
	check(price == ceili(expected_price - 1e-6), "preço = componentes + chassi pelo preço da loja (%d pontos)" % price)
	var car_before := _snapshot()
	var joints_before := Build.joints.size()
	var place := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(30, 0, -20))
	Economy.reset(0.0)
	Saves.builds_free = true
	var made := Saves.place_build(bp, place)
	check(made.size() == 15 and Economy.points() == 0, "modo de teste: coloca de graça (%d peças)" % made.size())
	check(Build.joints.size() == joints_before + 4, "os 4 motores da cópia viram componentes de verdade")
	var copy_snap: Array = []
	for p: Part in made:
		copy_snap.append({"m": p.material_id, "vol": p.volume, "pos": p.global_position, "kind": p.kind})
	var car_only: Array = car_before.filter(func(s: Dictionary) -> bool: return (s["pos"] as Vector3).distance_to(Vector3(5, 0.05, 40)) > 0.5)
	check(_matches(car_only, copy_snap, place * origin.affine_inverse()) == 15, "a cópia é igual, girada 90° e no lugar escolhido")
	Saves.builds_free = false
	Economy.reset(price - 1)
	check(Saves.place_build(bp, place.translated(Vector3(10, 0, 0))).is_empty() and Economy.points() == price - 1, "cobrando: sem pontos suficientes, não coloca nem cobra")
	Economy.reset(price + 5)
	var paid := Saves.place_build(bp, place.translated(Vector3(10, 0, 0)))
	check(paid.size() == 15 and Economy.points() == 5, "cobrando: coloca e desconta o preço")
	Saves.builds_free = true
	await _frames(5)
	var copy_seat: Part = null
	for p: Part in made:
		if p.interact_kind == "assento" and p.comp_index == 0:
			copy_seat = p
	var net := Build.network(copy_seat)
	var bound := 0
	for j in net:
		if not j.bind_pos.is_empty():
			bound += 1
	check(net.size() == 4 and bound == 4, "a cópia dirige: assento controla os 4 motores com as teclas salvas")

	print("== Colocar com a prévia")
	var player := Player.new()
	add_child(player)
	await _frames(2)
	player.teleport(Vector3(-40, 0.05, 0))
	player.yaw = 0.0
	player.pitch = deg_to_rad(-30)
	await _frames(5)
	var placer := BuildPlacer.new()
	add_child(placer)
	placer.start(player, bp)
	var meshes := placer.find_children("*", "MeshInstance3D", true, false).size()
	check(placer.is_active() and meshes >= 15, "a prévia fantasma mostra a construção (%d malhas)" % meshes)
	var at := placer.target_origin()
	check(absf(at.origin.y) < 0.1 and at.origin.z < -1.0, "a prévia fica no chão, na frente do jogador (%.1f m)" % -at.origin.z)
	var n_before := _all_parts().size()
	placer.place()
	await _frames(2)
	check(not placer.is_active() and _all_parts().size() == n_before + 15, "clicar coloca a construção e sai do modo de colocar")
	player.queue_free()

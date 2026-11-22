extends Node
## Screenshots rápidos de uma cena só (desenvolvimento).
## Uso: godot --path . -- --quick=weld --tour=/pasta

var out_dir := ""
var scene := "weld"
var world: Node3D
var player: Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = get_parent()
	player = world.player
	world.hud._help.visible = false
	await _frames(30)
	match scene:
		"weld":
			await _weld()
		_:
			if has_method("_" + scene):
				await call("_" + scene)
	get_tree().quit()


func _weld() -> void:
	var base := Build.spawn_box(Vector3(1.5, 0.1, 1.0), "aco", Transform3D(Basis(), Vector3(8, 1.06, -6)))
	var wall := Build.spawn_box(Vector3(1.5, 0.8, 0.1), "ferro", Transform3D(Basis(), Vector3(8, 1.51, -6.45)))
	await _frames(20)
	player.teleport(Vector3(8.6, 0.05, -4.4))
	_look_from_eye(Vector3(8.0, 1.11, -6.39))
	player.select_tool(1)
	await _frames(5)
	var welder: WeldTool = player.tools[1]
	welder.begin_use()
	for i in 40:
		await get_tree().physics_frame
	await _shot("q_weld_fog")
	assert(base != null and wall != null)


func _edit() -> void:
	# Modo edição: componentes destacados através de tudo; um selecionado.
	player.sit(world.demo_seat)
	await _frames(5)
	player.yaw = deg_to_rad(150)
	player.pitch = deg_to_rad(-25)
	var ui: SeatUI = world.hud.seat_ui
	ui.open(player, Build.network(world.demo_seat))
	await _frames(5)
	await _shot("e1_destaque_atras")
	player.yaw = deg_to_rad(-25)
	player.pitch = deg_to_rad(-30)
	await _frames(3)
	var front: MechJoint = null
	var best := INF
	for j in ui._joints:
		var sp := player.camera.unproject_position(j.part_a.global_position)
		var d := sp.distance_to(Vector2(800, 450))
		if d < best:
			best = d
			front = j
	ui._hover = null
	ui._select(front)
	await _frames(5)
	await _shot("e2_componente_selecionado")
	ui.close()
	player.stand_up()


func _insulators() -> void:
	var o := Vector3(4, 0, 9)
	var lever: Part = Components.spawn("alavanca", Transform3D(Basis(), o + Vector3(-2.5, 0.06, 0)))[0]
	var post := Build.spawn_box(Vector3(0.2, 1.6, 0.2), "aco", Transform3D(Basis(), o + Vector3(-0.8, 0.8, -0.6)))
	var post2 := Build.spawn_box(Vector3(0.2, 1.6, 0.2), "aco", Transform3D(Basis(), o + Vector3(0.9, 0.8, -0.6)))
	var i1: Part = Components.spawn("isolador", Transform3D(Basis(), o + Vector3(-0.8, 1.68, -0.6)))[0]
	var i2: Part = Components.spawn("isolador", Transform3D(Basis(), o + Vector3(0.9, 1.68, -0.6)))[0]
	var motor := Components.spawn("motor", Transform3D(Basis(), o + Vector3(2.4, 0.17, 0)))
	var wheel: Part = Components.spawn("roda", Transform3D(Basis(), o + Vector3(2.4, 0.43, 0)), Vector3(0.35, 0.2, 0))[0]
	await _frames(15)
	Build.make_weld(post, i1, o + Vector3(-0.8, 1.6, -0.6))
	Build.make_weld(post2, i2, o + Vector3(0.9, 1.6, -0.6))
	Build.make_weld(wheel, motor[1], o + Vector3(2.4, 0.33, 0))
	for p in [post, post2, motor[0]]:
		(p as Part).assembly().set_anchored(true)
	Build.toggle_link(lever.device, motor[0].mech, [i1, i2])
	lever.device.press()
	for i in 30:
		await get_tree().physics_frame
	player.teleport(o + Vector3(0, 0.05, 4.2))
	_look_from_eye(o + Vector3(0, 0.9, -0.3))
	player.select_tool(3)
	await _frames(10)
	await _shot("i1_isoladores")


func _v05() -> void:
	# Componentes novos lado a lado
	var o := Vector3(6, 0.02, 2)
	var kinds := ["motor", "servo", "pistao", "servo_linear", "dobradica", "pino", "esferica"]
	for i in kinds.size():
		var b := Components.bounds(kinds[i])
		Components.spawn(kinds[i], Transform3D(Basis(), o + Vector3(i * 0.9, -b.position.y + 0.02, 0)))
	await _frames(20)
	player.teleport(o + Vector3(2.7, 0.03, 2.6))
	_look_from_eye(o + Vector3(2.7, 0.25, 0))
	await _frames(10)
	await _shot("v1_componentes")
	# Gravitador segurando e girando um bloco
	var crate := Build.spawn_box(Vector3(1, 0.5, 0.5), "ferro", Transform3D(Basis(), o + Vector3(-3, 0.27, 2)))
	await _frames(10)
	player.select_tool(0)
	var grav: HandTool = player.tools[0]
	_look_from_eye(crate.global_position)
	await _frames(3)
	grav.grab()
	grav.hold_distance = 2.5
	await _frames(5)
	grav.rotating = true
	grav._rotate_by(Vector2(140, -60))
	grav.rotating = false
	player.pitch = deg_to_rad(5)
	await _frames(40)
	await _shot("v2_gravitador")


func _v06() -> void:
	# Marco 3: componentes novos lado a lado
	var o := Vector3(6, 0.02, 2)
	var kinds := ["trava", "torcao", "mola", "guincho", "propulsor", "ima", "engate"]
	for i in kinds.size():
		var b := Components.bounds(kinds[i])
		Components.spawn(kinds[i], Transform3D(Basis(), o + Vector3(i * 0.95, -b.position.y + 0.02, 0)))
	await _frames(20)
	player.teleport(o + Vector3(2.9, 0.03, 2.4))
	_look_from_eye(o + Vector3(2.9, 0.2, 0))
	await _frames(10)
	await _shot("m1_componentes")
	# Em ação: guincho segurando um bloco, ímã com aço grudado, propulsor ligado, engate travado
	var a := o + Vector3(0, 0, -5)
	var beam := Build.spawn_box(Vector3(4.5, 0.2, 0.3), "aco", Transform3D(Basis(), a + Vector3(1.8, 2.6, 0)))
	beam.assembly().set_anchored(true)
	var lever: Part = Components.spawn("alavanca", Transform3D(Basis(), a + Vector3(1.8, 0.06, 1.6)))[0]
	var w := Components.spawn("guincho", Transform3D(Basis(), a + Vector3(0, 2.36, 0)))
	Build.make_weld(w[0], beam, a + Vector3(0, 2.5, 0))
	var crate := Build.spawn_box(Vector3(0.4, 0.4, 0.4), "ferro", Transform3D(Basis(), w[1].global_position + Vector3(0, -0.25, 0)))
	Build.make_weld(w[1], crate, w[1].global_position + Vector3(0, -0.05, 0))
	w[0].mech.rope_len = 1.2
	var mg: Part = Components.spawn("ima", Transform3D(Basis(), a + Vector3(1.5, 2.45, 0)))[0]
	Build.make_weld(mg, beam, a + Vector3(1.5, 2.5, 0))
	var th: Part = Components.spawn("propulsor", Transform3D(Basis(), a + Vector3(2.8, 1.5, 0)))[0]
	th.assembly().set_anchored(true)
	var cp: Part = Components.spawn("engate", Transform3D(Basis(), a + Vector3(4.0, 0.06, 0)))[0]
	Build.spawn_box(Vector3(0.3, 0.3, 0.3), "aluminio", Transform3D(Basis(), a + Vector3(4.0, 0.27, 0)))
	for j: MechJoint in [mg.mech, th.mech, cp.mech]:
		Build.toggle_link(lever.device, j)
	lever.device.press()
	Build.spawn_box(Vector3(0.3, 0.3, 0.3), "aco", Transform3D(Basis(), a + Vector3(1.5, 1.95, 0)))
	await _frames(90)
	player.teleport(a + Vector3(2.0, 0.03, 4.2))
	_look_from_eye(a + Vector3(2.0, 1.3, 0))
	await _frames(10)
	await _shot("m2_em_acao")


func _depot() -> void:
	player.teleport(Vector3(-30, 0.05, 38.5))
	_look_from_eye(Vector3(-30, 0.2, 30))
	await _frames(60)
	await _shot("m3_deposito")


func _saves() -> void:
	# Salvar o mundo e a construção (carrinho de exemplo) e mostrar as telas.
	player.teleport(Vector3(-7, 0.05, 7.5))
	_look_from_eye(Vector3(-7, 0.5, 3))
	await _frames(30)
	var hud: Hud = world.hud
	hud._open_pause()
	Saves.save_world("Pátio com carrinho")
	await _frames(2)
	hud.save_menu.open(hud._aimed_on_pause)
	hud._pause.visible = false
	hud.save_menu._build_name.text = "Carrinho de exemplo"
	hud.save_menu._save_build()
	hud.save_menu._show_tab(0)
	await _frames(5)
	await _shot("s1_mundos")
	hud.save_menu._show_tab(1)
	await _frames(5)
	await _shot("s2_construcoes")
	var data := Saves.read(Saves.DIR_BUILDS.path_join("carrinho_de_exemplo.json"))
	hud.save_menu.visible = false
	hud._resume()
	player.teleport(Vector3(4, 0.05, 6))
	player.yaw = deg_to_rad(-60)
	player.pitch = deg_to_rad(-12)
	await _frames(5)
	hud.placer.start(player, data)
	await _frames(10)
	await _shot("s3_previa")
	hud.placer.place()
	await _frames(60)
	await _shot("s4_colocada")


func _loadperf() -> void:
	# Tempo de salvar/carregar o mundo inteiro (desenvolvimento).
	var n := Saves.world_assemblies().size()
	var t0 := Time.get_ticks_msec()
	var path := Saves.save_world("perf_teste")
	var t1 := Time.get_ticks_msec()
	Saves.load_world(path)
	var t2 := Time.get_ticks_msec()
	await _frames(30)
	print("PERF montagens=%d salvar=%d ms carregar=%d ms tamanho=%d KB montagens_depois=%d" % [
		n, t1 - t0, t2 - t1, FileAccess.get_file_as_bytes(path).size() / 1024, Saves.world_assemblies().size()])
	Saves.delete(path)


func _physperf() -> void:
	# Custo da física: mundo completo + 3 carrinhos andando (desenvolvimento).
	var btn: Part = Components.spawn("botao", Transform3D(Basis(), Vector3(0, 0.04, 20)))[0]
	for k in 3:
		var seat := DemoBuilds.build_car(Vector3(-20 + k * 6, 0, 20))
		for j in Build.network(seat):
			Build.toggle_link(btn.device, j)
	await _frames(30)
	btn.device.press()
	var total := 0.0
	var worst := 0.0
	for i in 300:
		await get_tree().physics_frame
		var t := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		total += t
		worst = maxf(worst, t)
	print("PHYS média %.2f ms, pior %.2f ms por tick" % [total / 300.0, worst])


func _logic() -> void:
	# Circuito de exemplo: pulsador → contador → mostrador / tela de texto; alavanca → NÃO → indicador.
	var o := Vector3(6, 0.03, 0)
	var sp := func(kind: String, at: Vector3) -> Part:
		return Components.spawn(kind, Transform3D(Basis(), o + at))[0]
	var pul: Part = sp.call("chip", Vector3(-1.2, 0, 0))
	(pul.node as ChipNode).set_mode("pulsador")
	var cnt: Part = sp.call("chip", Vector3(-0.4, 0, 0))
	(cnt.node as ChipNode).set_mode("contador")
	var num: Part = sp.call("mostrador", Vector3(0.6, 0, 0))
	var txt: Part = sp.call("tela_texto", Vector3(0.4, 0, -0.9))
	(txt.node as DisplayNode).template = "Contagem: {A}\nJunk Construction"
	var lever: Part = Components.spawn("alavanca", Transform3D(Basis(), o + Vector3(-1.2, 0.01, 0.9)))[0]
	var nao: Part = sp.call("chip", Vector3(-0.4, 0, 0.9))
	(nao.node as ChipNode).set_mode("nao")
	var ind: Part = sp.call("indicador", Vector3(0.4, 0, 0.9))
	var px: Part = sp.call("pixel", Vector3(1.2, 0, 0.9))
	var kc: Part = sp.call("constante", Vector3(1.2, 0, 1.6))
	(kc.node as ConstNode).set_value(SignalNode.VEC, Vector3(255, 120, 0))
	Signals.connect_ports(pul.node, "Pulso", cnt.node, "Somar")
	Signals.connect_ports(cnt.node, "Valor", num.node, "Valor")
	Signals.connect_ports(cnt.node, "Valor", txt.node, "A")
	Signals.connect_ports(lever.device, "Saída", nao.node, "A")
	Signals.connect_ports(nao.node, "Saída", ind.node, "Valor")
	Signals.connect_ports(kc.node, "Valor", px.node, "Cor")
	await _frames(200)
	player.teleport(o + Vector3(0, 0.03, 2.6))
	_look_from_eye(o + Vector3(0, 0.0, 0.1))
	await _frames(10)
	await _shot("l1_circuito")
	# Depurador mirando no contador
	player.select_tool(4)
	_look_from_eye(cnt.global_position)
	await _frames(5)
	await _shot("l2_depurador")
	# Ajustes do chip
	var hud: Hud = world.hud
	hud.node_config.open(player, cnt.node)
	await _frames(5)
	await _shot("l3_ajustes_chip")
	hud.node_config.close()
	# Menu de portas (rotear tem 4 saídas)
	(pul.node as ChipNode).set_mode("roteia")
	player.select_tool(3)
	_look_from_eye(pul.global_position)
	await _frames(3)
	var wt: WireTool = player.tools[3]
	wt._pick_output(pul.node)
	await _frames(5)
	await _shot("l4_menu_portas")
	hud.port_menu.close()
	# Depósito de eletrônica
	player.select_tool(0)
	player.teleport(Vector3(-32, 0.05, 9.5))
	_look_from_eye(Vector3(-32, 0.0, 4.5))
	await _frames(30)
	await _shot("l5_deposito")


func _precision() -> void:
	# Tamanhos P/M/G, cilindros, Trena com marcas, puxador.
	var o := Vector3(6, 0.02, 0)
	var x := 0.0
	for kind in ["motor", "pistao", "servo"]:
		for k in [0.6, 1.0, 1.6]:
			var b := Components.bounds(kind, Vector3(k, 0, 0))
			Components.spawn(kind, Transform3D(Basis(), o + Vector3(x, -b.position.y + 0.02, 0)), Vector3(k, 0, 0))
			x += b.size.x + 0.35
	for ws: Vector3 in [Vector3(0.35, 0.2, 0), Vector3(0.55, 0.3, 0), Vector3(0.8, 0.4, 0)]:
		Components.spawn("roda", Transform3D(Basis(Vector3.BACK, PI * 0.5), o + Vector3(x + ws.x, ws.x + 0.02, 0)), ws)
		x += ws.x * 2.0 + 0.3
	await _frames(40)
	player.teleport(o + Vector3(x * 0.5, 0.03, 4.2))
	_look_from_eye(o + Vector3(x * 0.5, 0.4, 0))
	await _frames(10)
	await _shot("p1_tamanhos")
	# Cilindros + chapa com marcas e medida
	var c := Vector3(-6, 0, 6)
	var cy := Catalog.get_item("cilindro")
	Build.spawn_planes(Catalog.planes(cy, Vector3(0.4, 0.4, 2.0)), "aco", Transform3D(Basis(Vector3.UP, 0.3), c + Vector3(-1.5, 0.2, 0)))
	Build.spawn_planes(Catalog.planes(Catalog.get_item("tambor"), Vector3(0.8, 0.8, 0.5)), "ferro", Transform3D(Basis(), c + Vector3(-1.5, 0.4, 1.4)))
	var plate := Build.spawn_box(Vector3(2, 0.1, 1), "aco", Transform3D(Basis(), c + Vector3(1, 0.05, 0.5)))
	await _frames(20)
	plate.add_mark(Vector3(0.35, 0.05, 0), Vector3.UP)
	plate.add_mark(Vector3(-0.4, 0.05, 0.25), Vector3.UP)
	player.teleport(c + Vector3(0.6, 0.03, 2.6))
	player.select_tool(5)
	var tape: MeasureTool = player.tools[5]
	_look_from_eye(c + Vector3(1.35, 0.1, 0.5))
	await _frames(3)
	tape.handle_input(_press_action("primary"))
	_look_from_eye(c + Vector3(0.6, 0.1, 0.75))
	await _frames(8)
	await _shot("p2_trena_cilindros")
	# Puxador numa porta
	player.select_tool(0)
	var hinge := Components.spawn("dobradica", Transform3D(Basis(Vector3.BACK, PI * 0.5), c + Vector3(4, 1.2, 0)))
	hinge[0].assembly().set_anchored(true)
	var door := Build.spawn_box(Vector3(0.05, 1.0, 0.8), "aluminio", Transform3D(Basis(), hinge[1].global_position + Vector3(0, 0, 0.5)))
	Build.make_weld(door, hinge[1], hinge[1].global_position + Vector3(0, 0, 0.15))
	var handle: Part = Components.spawn("puxador", Transform3D(Basis(Vector3.BACK, -PI * 0.5), door.global_position + Vector3(0.0375, 0, 0.3)))[0]
	Build.make_weld(handle, door, door.global_position + Vector3(0.025, 0, 0.3))
	await _frames(20)
	player.teleport(door.global_position + Vector3(1.5, -1.2, 0.3))
	_look_from_eye(handle.global_position + Vector3(0.05, 0, 0))
	await _frames(5)
	await _shot("p3_puxador")


func _press_action(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _bisect_sit() -> void:
	player.sit(world.demo_seat)
	for i in 30:
		await get_tree().physics_frame
	player.stand_up()
	await _mechwire()


func _bisect_drive() -> void:
	player.sit(world.demo_seat)
	await _frames(5)
	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	w.keycode = KEY_W
	w.pressed = true
	Input.parse_input_event(w)
	for i in 70:
		await get_tree().physics_frame
	var up := w.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	for i in 40:
		await get_tree().physics_frame
	print("DBG car ", world.demo_seat.global_position, " W pressed? ", Input.is_physical_key_pressed(KEY_W))
	player.stand_up()
	await _mechwire()
	print("DBG car depois ", world.demo_seat.global_position, " cam ", player.camera.global_position)


func _bisect_edit() -> void:
	player.sit(world.demo_seat)
	await _frames(5)
	world.hud.seat_ui.open(Build.network(world.demo_seat))
	await _frames(8)
	world.hud.seat_ui.close()
	player.stand_up()
	await _mechwire()


func _mechwire() -> void:
	var o := Vector3(4, 0, 9)
	var lever: Part = Components.spawn("alavanca", Transform3D(Basis(), o + Vector3(-1.2, 0.06, 0)))[0]
	var piston := Components.spawn("pistao", Transform3D(Basis(), o + Vector3(0.6, 0.33, 0)))
	var plate := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), o + Vector3(0.6, 0.97, 0)))
	await _frames(10)
	Build.make_weld(plate, piston[1], o + Vector3(0.6, 0.92, 0))
	Build.toggle_link(lever.device, piston[0].mech)
	lever.device.press()
	for i in 50:
		await get_tree().physics_frame
	print("DBG piston base ", piston[0].global_position, " rod ", piston[1].global_position, " plate ", plate.global_position)
	player.teleport(o + Vector3(0, 0.05, 3.2))
	_look_from_eye(o + Vector3(-0.2, 0.6, 0))
	player.select_tool(3)
	await _frames(10)
	print("DBG player ", player.global_position, " yaw ", player.yaw)
	await _shot("w_fiacao")


func _mech() -> void:
	# 1) Depósito de componentes no galpão
	player.teleport(Vector3(-30, 0.05, 31))
	_look_from_eye(Vector3(-30, 0.3, 24))
	await _frames(15)
	await _shot("m1_deposito")

	# 2) Carrinho de exemplo visto de fora
	player.teleport(Vector3(-3.5, 0.05, 6.5))
	_look_from_eye(Vector3(-7, 0.5, 3))
	await _frames(10)
	await _shot("m2_carrinho")

	# 3) Sentado no carrinho, andando com W
	player.sit(world.demo_seat)
	await _frames(5)
	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	w.keycode = KEY_W
	w.pressed = true
	Input.parse_input_event(w)
	for i in 70:
		await get_tree().physics_frame
	await _shot("m3_dirigindo")
	w = w.duplicate()
	w.pressed = false
	Input.parse_input_event(w)
	for i in 40:
		await get_tree().physics_frame

	# 4) Modo edição do assento
	world.hud.seat_ui.open(Build.network(world.demo_seat))
	await _frames(8)
	await _shot("m4_modo_edicao")
	world.hud.seat_ui.close()
	player.stand_up()

	# 5) Alavanca ligada a um pistão por fio
	var o := Vector3(4, 0, 9)
	var lever: Part = Components.spawn("alavanca", Transform3D(Basis(), o + Vector3(-1.2, 0.06, 0)))[0]
	var piston := Components.spawn("pistao", Transform3D(Basis(), o + Vector3(0.6, 0.33, 0)))
	var plate := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), o + Vector3(0.6, 0.97, 0)))
	await _frames(10)
	Build.make_weld(plate, piston[1], o + Vector3(0.6, 0.92, 0))
	Build.toggle_link(lever.device, piston[0].mech)
	lever.device.press()
	for i in 50:
		await get_tree().physics_frame
	print("DBG piston base ", piston[0].global_position, " rod ", piston[1].global_position, " plate ", plate.global_position, " valid ", is_instance_valid(piston[0]))
	player.teleport(o + Vector3(0, 0.05, 3.2))
	_look_from_eye(o + Vector3(-0.2, 0.6, 0))
	player.select_tool(3)
	await _frames(10)
	await _shot("m5_fiacao")

	# 6) Loja com componentes
	Economy.reset(300)
	world.hud.open_shop(world.shop)
	world.hud.shop._select(Catalog.get_item("motor"))
	await _frames(10)
	await _shot("m6_loja_componentes")
	world.hud.shop.close()


func _look_from_eye(target: Vector3) -> void:
	var eye := player.global_position + Vector3(0, Player.EYE_HEIGHT, 0)
	var d := (target - eye).normalized()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = asin(clampf(d.y, -1, 1))
	player.velocity = Vector3.ZERO


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	img.save_png(out_dir.path_join(shot_name + ".png"))
	print("screenshot: ", shot_name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _help() -> void:
	world.hud._help.visible = true
	await _frames(10)
	await _shot("p4_ajuda")


func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func _slipw() -> void:
	var seat: Part = world.demo_seat
	player.sit(seat)
	await _frames(30)
	var joints: Array = Build.network(seat)
	var chassis := seat.assembly()
	for phase in [["W", KEY_W, 180], ["solto", KEY_NONE, 60], ["D", KEY_D, 120], ["solto", KEY_NONE, 60], ["W+A", KEY_W, 120]]:
		if phase[1] != KEY_NONE:
			_key(phase[1], true)
		if phase[0] == "W+A":
			_key(KEY_A, true)
		for i in int(phase[2]):
			await get_tree().physics_frame
			if i % 30 == 29:
				var v := chassis.linear_velocity
				var line := "%s t=%.1f car v=%.2f yaw=%.2f |" % [phase[0], (i + 1) / 60.0, Vector2(v.x, v.z).length(), chassis.angular_velocity.y]
				for j: MechJoint in joints:
					if j.type != "motor":
						continue
					var wa: Assembly = j.part_b.assembly()
					var axis_w: Vector3 = (j.part_a.global_basis * j.axis).normalized()
					var rel := (wa.angular_velocity - j.part_a.assembly().angular_velocity).dot(axis_w)
					var contact := j.part_b.global_position - Vector3.UP * 0.4
					var gv := wa.linear_velocity + wa.angular_velocity.cross(contact - wa.world_center_of_mass())
					line += " rim %.2f slip %.2f;" % [rel * 0.4, Vector2(gv.x, gv.z).length()]
				print(line)
		_key(KEY_W, false)
		_key(KEY_A, false)
		_key(KEY_D, false)


func _slipt() -> void:
	# Carro no terreno (fora do pátio).
	for spot: Vector2 in [Vector2(70, 20), Vector2(-75, 60)]:
		var h: float = world.terrain_height(spot.x, spot.y)
		var o := Vector3(spot.x, h + 0.3, spot.y)
		var seat := DemoBuilds.build_car(o)
		var joints: Array = Build.network(seat)
		var btn: Part = Components.spawn("botao", Transform3D(Basis(), o + Vector3(4, 2, 4)))[0]
		btn.assembly().set_frozen(true)
		for j: MechJoint in joints:
			Build.toggle_link(btn.device, j)
		await _frames(90)
		var chassis := seat.assembly()
		btn.device.press()
		for i in 240:
			await get_tree().physics_frame
			if i % 20 == 19:
				var v := chassis.linear_velocity
				var line := "T%s t=%.2f v=%.2f vy=%.2f |" % [str(spot), (i + 1) / 60.0, Vector2(v.x, v.z).length(), v.y]
				for j: MechJoint in joints:
					var wa: Assembly = j.part_b.assembly()
					var axis_w: Vector3 = (j.part_a.global_basis * j.axis).normalized()
					var rel := (wa.angular_velocity - j.part_a.assembly().angular_velocity).dot(axis_w)
					var contact := j.part_b.global_position - Vector3.UP * 0.4
					var gv := wa.linear_velocity + wa.angular_velocity.cross(contact - wa.world_center_of_mass())
					line += " %.2f/%.2f" % [absf(rel) * 0.4, gv.length()]
				print(line)
		btn.device.release()


func _octo() -> void:
	# Peças "cilíndricas" octogonais: pistão, servo linear, motor, servo, ímã, propulsor, mola, isolador, cilindros.
	var o := Vector3(6, 0.02, 0)
	var x := 0.0
	for kind in ["pistao", "servo_linear", "motor", "servo", "ima", "propulsor", "mola", "isolador", "botao", "dobradica"]:
		var b := Components.bounds(kind)
		Components.spawn(kind, Transform3D(Basis(), o + Vector3(x - b.position.x, -b.position.y + 0.02, 0)))
		x += b.size.x + 0.3
	var cy := Catalog.get_item("cilindro")
	Build.spawn_planes(Catalog.planes(cy, Vector3(0.3, 0.3, 1.2)), "aco", Transform3D(Basis(Vector3.UP, 0.4), o + Vector3(x * 0.3, 0.15, 1.3)))
	Build.spawn_planes(Catalog.planes(Catalog.get_item("tambor"), Vector3(0.8, 0.8, 0.5)), "ferro", Transform3D(Basis(), o + Vector3(x * 0.7, 0.4, 1.4)))
	await _frames(40)
	player.teleport(o + Vector3(x * 0.5, 0.03, 4.0))
	_look_from_eye(o + Vector3(x * 0.5, 0.3, 0.4))
	await _frames(10)
	await _shot("o1_octogonais")


func _runhold() -> void:
	var o := Vector3(10, 0, 20)
	var block := Build.spawn_box(Vector3(0.5, 0.5, 0.5), "aco", Transform3D(Basis(), o + Vector3(0, 0.25, -2)))
	await _frames(20)
	player.teleport(o)
	_look_from_eye(block.global_position)
	player.select_tool(0)
	await _frames(3)
	player.hand.grab()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("modifier")
	Input.action_press("move_forward")
	var p0 := player.global_position
	for i in 60:
		await get_tree().physics_frame
	var d := player.global_position.distance_to(p0)
	print("RUNHOLD holding=%s mouse=%d andou %.2f m em 1 s · bloco a %.2f m do jogador" % [player.hand.holding, Input.mouse_mode, d, block.global_position.distance_to(player.global_position)])
	Input.action_release("modifier")
	Input.action_release("move_forward")


func _alignghost() -> void:
	var c := Vector3(-6, 0, 10)
	var base := Build.spawn_box(Vector3(2.0, 0.1, 1.5), "aco", Transform3D(Basis(), c + Vector3(0, 0.05, 0)))
	var mot := Components.spawn("motor", Transform3D(Basis(Vector3(1, 0, 1).normalized(), 0.8), c + Vector3(1.6, 1.3, -0.6)))
	var wheel: Part = Components.spawn("roda", Transform3D(Basis(Vector3(1, 0, 1).normalized(), 0.8), mot[1].global_position + mot[1].global_basis.y * 0.12), Vector3(0.35, 0.2, 0))[0]
	Build.make_weld(wheel, mot[1], mot[1].global_position + mot[1].global_basis.y * 0.03)
	await _frames(5)
	for p: Part in [mot[0], mot[1], wheel]:
		p.assembly().set_frozen(true)
	await _frames(10)
	player.teleport(c + Vector3(0.3, 0.03, 3.2))
	player.select_tool(6)
	var al: AlignTool = player.tools[6]
	# 1º ponto: fundo da carcaça do motor
	var bottom: Vector3 = mot[0].global_transform * Vector3(0, -Components.MOTOR_HALF_H, 0)
	al._a = Snap.on_part(mot[0], bottom, mot[0].global_basis * Vector3.DOWN)
	_look_from_eye(c + Vector3(-0.4, 0.1, 0.2))
	await _frames(10)
	await _shot("a1_previa_alinhador")


func _energy() -> void:
	var o := Vector3(6, 0.02, -2)
	var sp := func(kind: String, at: Vector3, size := Vector3.ZERO) -> PowerNode:
		var b := Components.bounds(kind, size)
		var p: Part = Components.spawn(kind, Transform3D(Basis(), o + at + Vector3(0, -b.position.y, 0)), size)[0]
		return p.node as PowerNode
	var bat := sp.call("bateria", Vector3(0, 0, 0)) as PowerNode
	var big := sp.call("bateria", Vector3(-0.9, 0, 0.3), Vector3(1.6, 0, 0)) as PowerNode
	var l1 := sp.call("luz", Vector3(1.0, 0, -0.6)) as PowerNode
	var l2 := sp.call("luz", Vector3(1.6, 0, 0.2)) as PowerNode
	l2.color = Color(0.3, 0.6, 1.0)
	var spot := sp.call("holofote", Vector3(0.4, 0, -1.4)) as PowerNode
	var relay := sp.call("rele", Vector3(0.6, 0, 0.6)) as PowerNode
	var meter := sp.call("medidor", Vector3(-0.4, 0, 1.2)) as PowerNode
	var panel := sp.call("solar", Vector3(-1.4, 0, -1.2)) as PowerNode
	var po := Components.spawn("pino_oct", Transform3D(Basis(), o + Vector3(2.4, 0.08, -1.0)))
	var po2 := Components.spawn("pino", Transform3D(Basis(), o + Vector3(2.4, 0.08, -0.4)))
	assert(po.size() == 2 and po2.size() == 2)
	Power.connect_nodes(bat, l1)
	Power.connect_nodes(bat, relay)
	Power.connect_nodes(relay, l2)
	Power.connect_nodes(bat, spot)
	Power.connect_nodes(bat, big)
	Power.connect_nodes(big, meter)
	Power.connect_nodes(panel, big)
	var lever: Part = Components.spawn("alavanca", Transform3D(Basis(), o + Vector3(1.4, 0.04, 1.3)))[0]
	Signals.connect_ports(lever.device, "Saída", relay, "Liga")
	lever.device.press()
	await _frames(30)
	player.teleport(o + Vector3(0.4, 0.03, 3.2))
	_look_from_eye(o + Vector3(0.4, 0.1, -0.2))
	await _frames(10)
	await _shot("e1_energia")
	# Depósito de eletrônica com as peças de energia e o posto de recarga
	player.teleport(Vector3(-32, 0.05, 14.5))
	_look_from_eye(Vector3(-33.5, 0.2, 6.5))
	await _frames(30)
	await _shot("e2_deposito_energia")


func _mouse(button: MouseButton, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = down
	ev.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(ev)


func _wheelsel() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.select_tool(0)
	await _frames(5)
	_mouse(MOUSE_BUTTON_WHEEL_DOWN, true)
	_mouse(MOUSE_BUTTON_WHEEL_DOWN, false)
	_mouse(MOUSE_BUTTON_WHEEL_DOWN, true)
	_mouse(MOUSE_BUTTON_WHEEL_DOWN, false)
	await _frames(5)
	print("WHEEL depois de 2x para baixo: escolha=%d atual=%d" % [player.tool_select, player.current_tool])
	await _shot("t1_roda_escolha")
	_mouse(MOUSE_BUTTON_LEFT, true)
	_mouse(MOUSE_BUTTON_LEFT, false)
	await _frames(5)
	print("WHEEL clique: escolha=%d atual=%d (%s)" % [player.tool_select, player.current_tool, player.current().tool_name])
	_mouse(MOUSE_BUTTON_WHEEL_UP, true)
	_mouse(MOUSE_BUTTON_WHEEL_UP, false)
	await _frames(5)
	_mouse(MOUSE_BUTTON_RIGHT, true)
	_mouse(MOUSE_BUTTON_RIGHT, false)
	await _frames(5)
	print("WHEEL cima + botão direito: escolha=%d atual=%d" % [player.tool_select, player.current_tool])
	# Segurando algo com o Gravitador, a roda é dele (distância).
	player.select_tool(0)
	var block := Build.spawn_box(Vector3(0.4, 0.4, 0.4), "aco", Transform3D(Basis(), player.global_position + Vector3(0, 0.2, -2.5)))
	await _frames(20)
	_look_from_eye(block.global_position)
	await _frames(3)
	player.hand.grab()
	var d0: float = player.hand.hold_distance
	_mouse(MOUSE_BUTTON_WHEEL_UP, true)
	_mouse(MOUSE_BUTTON_WHEEL_UP, false)
	await _frames(5)
	print("WHEEL segurando: escolha=%d distância %.1f → %.1f" % [player.tool_select, d0, player.hand.hold_distance])
	player.hand.drop()
	# Passa do tempo: fecha sozinho.
	_mouse(MOUSE_BUTTON_WHEEL_DOWN, true)
	_mouse(MOUSE_BUTTON_WHEEL_DOWN, false)
	await get_tree().create_timer(3.4).timeout
	print("WHEEL depois de 3,4 s parado: escolha=%d atual=%d" % [player.tool_select, player.current_tool])


func _sensors() -> void:
	var o := Vector3(6, 0.02, -2)
	var sp := func(kind: String, at: Vector3, frozen := true) -> Part:
		var b := Components.bounds(kind)
		var p: Part = Components.spawn(kind, Transform3D(Basis(), o + at + Vector3(0, -b.position.y, 0)))[0]
		if frozen:
			p.assembly().set_frozen(true)
		return p
	sp.call("ranger", Vector3(-1.2, 0, -0.6))
	var rec: Part = sp.call("receptor", Vector3(-1.2, 1.6, -0.6))
	assert(rec != null)
	var z: Part = sp.call("zona", Vector3(0.6, 0, -1.2))
	(z.node as SensorNode).zone_size = Vector3(1.2, 1.0, 1.2)
	Build.spawn_box(Vector3(0.3, 0.3, 0.3), "aco", Transform3D(Basis(), o + Vector3(0.6, 0.5, -1.2)))
	var sc := Components.spawn("balanca", Transform3D(Basis(), o + Vector3(-0.2, 0.035, 0.6)))
	sc[0].assembly().set_anchored(true)
	Build.spawn_box(Vector3(0.25, 0.25, 0.25), "aco", Transform3D(Basis(), o + Vector3(-0.2, 0.3, 0.6)))
	var loc: Part = sp.call("localizador", Vector3(1.4, 0, 0.4))
	(loc.node as SensorNode).channel = 5
	(loc.node as SensorNode).update_label()
	sp.call("gps", Vector3(0.6, 0, 0.5))
	sp.call("velocimetro", Vector3(1.0, 0, 1.0))
	sp.call("buscador", Vector3(-1.0, 0, 1.1))
	sp.call("impacto", Vector3(1.6, 0, -0.4))
	var rec2: Part = sp.call("receptor", Vector3(1.8, 0, 1.2))
	await _frames(40)
	player.teleport(o + Vector3(0.3, 0.03, 3.4))
	player.select_tool(7)
	_look_from_eye(rec2.global_position)
	await _frames(3)
	(player.tools[7] as LaserTool).firing = true
	await _frames(6)
	_look_from_eye(o + Vector3(0.2, 0.4, -0.3))
	await _frames(2)
	_look_from_eye(rec2.global_position + Vector3(-0.6, 0.35, -0.6))
	await _frames(4)
	await _shot("s1_sensores")
	(player.tools[7] as LaserTool).firing = false


func _drive() -> void:
	# Carro de exemplo novo (motor + câmbio + cubos) com a Transmissão na mão.
	await _frames(60)
	player.teleport(Vector3(-10.2, 0.03, 5.6))
	player.select_tool(8)
	_look_from_eye(Vector3(-13, 0.5, 2.6))
	await _frames(10)
	await _shot("d1_transmissao")
	player.select_tool(0)
	player.teleport(Vector3(-40, 0.05, 31.5))
	_look_from_eye(Vector3(-40, 0.2, 23))
	await _frames(30)
	await _shot("d2_deposito_motores")


func _pins() -> void:
	var o := Vector3(6, 0.02, -2)
	var plate := Build.spawn_box(Vector3(1.6, 0.05, 0.8), "aco", Transform3D(Basis(), o + Vector3(0, 0.025, 0)))
	plate.assembly().set_frozen(true)
	var lev: Part = Components.spawn("alavanca", Transform3D(Basis(), o + Vector3(-0.6, 0.09, 0.1)))[0]
	var lamp: Part = Components.spawn("indicador", Transform3D(Basis(), o + Vector3(0.6, 0.075, 0.1)))[0]
	lev.assembly().set_frozen(true)
	lamp.assembly().set_frozen(true)
	var i1 := Build.place_insulator(plate, o + Vector3(-0.2, 0.05, -0.2), Vector3.UP)
	var i2 := Build.place_insulator(plate, o + Vector3(0.2, 0.05, -0.2), Vector3.UP)
	var pa := [lev, lev.global_transform.affine_inverse() * (o + Vector3(-0.52, 0.09, 0.1))]       # lateral da alavanca
	var pb := [lamp, lamp.global_transform.affine_inverse() * (o + Vector3(0.6, 0.11, 0.1))]
	Signals.connect_ports(lev.device, "Saída", lamp.node, "Valor", [i1, i2], pa, pb)
	lev.device.press()
	var bat: Part = Components.spawn("bateria", Transform3D(Basis(), o + Vector3(-0.4, 0.16, 0.9)))[0]
	var lz: Part = Components.spawn("luz", Transform3D(Basis(), o + Vector3(0.5, 0.05, 0.9)))[0]
	Power.connect_nodes(bat.node, lz.node, [], [bat, bat.global_transform.affine_inverse() * (o + Vector3(-0.25, 0.2, 0.9))], [lz, lz.global_transform.affine_inverse() * (o + Vector3(0.43, 0.05, 0.9))])
	await _frames(30)
	player.teleport(o + Vector3(0, 0.03, 2.3))
	_look_from_eye(o + Vector3(0, 0.05, 0.2))
	await _frames(10)
	await _shot("w1_pontas_e_isolador")

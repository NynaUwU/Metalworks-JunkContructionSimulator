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
	player.teleport(Vector3(-30, 0.05, 33.5))
	_look_from_eye(Vector3(-30, 0.2, 25))
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

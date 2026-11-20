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

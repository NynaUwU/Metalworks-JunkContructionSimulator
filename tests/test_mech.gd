extends Node3D
## Testes da mecânica (motores, servos, pistões, dobradiças, controles, assento).
##   godot --headless --path . res://tests/test_mech.tscn

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
	bs.size = Vector3(400, 1, 400)
	cs.shape = bs
	ground.add_child(cs)
	add_child(ground)
	ground.position.y = -0.5
	await _frames(2)
	await _run()
	print("\n%d verificações, %d falhas" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Prende a carcaça de um componente no chão para testar só o movimento.
func _anchor(p: Part) -> void:
	p.assembly().set_anchored(true)


func _run() -> void:
	print("== Motor")
	var m := Components.spawn("motor", Transform3D(Basis(), Vector3(0, 1, 0)))
	var mj: MechJoint = m[0].mech
	_anchor(m[0])
	check(mj != null and mj.joint != null, "motor tem junta física")
	mj.key_value = 0.0
	await _frames(10)
	var a0 := mj.angle()
	mj.sources.clear()
	var lever := Components.spawn("alavanca", Transform3D(Basis(), Vector3(3, 0.04, 0)))[0]
	Build.toggle_link(lever.device, mj)
	lever.device.press()
	check(lever.device.value == 1.0, "alavanca ligada vale 1")
	await _frames(60)
	var w: float = m[1].assembly().angular_velocity.dot(m[0].global_basis.y)
	check(absf(w) > mj.speed * 0.8, "motor gira com a alavanca ligada (%.1f rad/s)" % w)
	lever.device.press()
	await _frames(40)
	w = m[1].assembly().angular_velocity.length()
	check(w < 0.5, "alavanca desligada: motor freia (%.2f rad/s)" % w)
	check(not is_equal_approx(mj.angle(), a0), "rotor girou")

	print("== Servo")
	var s := Components.spawn("servo", Transform3D(Basis(), Vector3(6, 1, 0)))
	var sj: MechJoint = s[0].mech
	_anchor(s[0])
	var pot := Components.spawn("potenciometro", Transform3D(Basis(), Vector3(8, 0.04, 0)))[0]
	Build.toggle_link(pot.device, sj)
	pot.device.scroll(10)
	check(near(pot.device.value, 1.0), "potenciômetro no máximo vale 1")
	await _frames(90)
	check(near(sj.angle(), sj.max_angle, 0.06), "servo vai a +45° (%.1f°)" % rad_to_deg(sj.angle()))
	pot.device.scroll(-15)
	await _frames(90)
	check(near(sj.angle(), -sj.max_angle * 0.5, 0.06), "potenciômetro em -0,5: servo a -22,5° (%.1f°)" % rad_to_deg(sj.angle()))

	print("== Pistão")
	var p := Components.spawn("pistao", Transform3D(Basis(), Vector3(12, 0.3, 0)))
	var pj: MechJoint = p[0].mech
	_anchor(p[0])
	await _frames(20)
	check(near(pj.extension(), 0.0, 0.03), "pistão começa recolhido (%.3f m)" % pj.extension())
	var button := Components.spawn("botao", Transform3D(Basis(), Vector3(14, 0.04, 0)))[0]
	Build.toggle_link(button.device, pj)
	button.device.press()
	await _frames(60)
	check(near(pj.extension(), pj.stroke, 0.04), "segurando o botão, o pistão estica (%.3f m)" % pj.extension())
	button.device.release()
	await _frames(60)
	check(near(pj.extension(), 0.0, 0.04), "soltando o botão, recolhe (%.3f m)" % pj.extension())

	print("== Pistão levanta peso")
	var load := Build.spawn_box(Vector3(1, 0.2, 1), "aco", Transform3D(Basis(), Vector3(12, 0.72, 0)))
	await _frames(20)
	Build.make_weld(load, p[1], Vector3(12, 0.62, 0))
	check(load.assembly() == p[1].assembly(), "carga soldada na haste")
	await _frames(5)
	check(pj.joint != null and pj.part_b.assembly() != pj.part_a.assembly(), "junta recriada depois da solda")
	button.device.press()
	await _frames(90)
	check(pj.extension() > pj.stroke * 0.85, "pistão levanta 157 kg (%.3f m)" % pj.extension())
	button.device.release()

	print("== Dobradiça")
	var h := Components.spawn("dobradica", Transform3D(Basis(), Vector3(18, 1.5, 0)))
	_anchor(h[0])
	var lowest := 9.0
	for i in 60:
		await get_tree().physics_frame
		lowest = minf(lowest, h[1].global_position.y)
	check(lowest < 1.4, "folha solta da dobradiça cai girando (mais baixo y=%.2f)" % lowest)
	check(h[1].global_position.distance_to(h[0].global_transform * Vector3(0, 0, 0.13)) < 0.3, "e continua presa no eixo")

	print("== Rede do assento")
	var chassis := Build.spawn_box(Vector3(2, 0.1, 1), "aco", Transform3D(Basis(), Vector3(30, 0.05, 0)))
	var seat := Components.spawn("assento", Transform3D(Basis(), Vector3(30, 0.16, 0)))
	var mm := Components.spawn("motor", Transform3D(Basis(), Vector3(31.5, 0.25, 0)))
	await _frames(5)
	Build.make_weld(seat[0], chassis, Vector3(30, 0.1, 0.3))
	check(Build.network(seat[0]).is_empty(), "motor solto não está na rede do assento")
	Build.make_weld(mm[0], chassis, Vector3(31.5, 0.1, 0))
	check(Build.network(seat[0]).has(mm[0].mech), "motor soldado no chassi entra na rede")
	var ss := Components.spawn("servo", Transform3D(Basis(), Vector3(31.5, 0.7, 0)))
	Build.make_weld(ss[0], mm[1], Vector3(31.5, 0.55, 0))
	check(Build.network(seat[0]).has(ss[0].mech), "servo preso no disco do motor também entra (pela junta)")

	print("== Teclas do assento")
	Build.active_seat = seat[0]
	mm[0].mech.bind_pos = [{"key": KEY_W}]
	Input.parse_input_event(_key(KEY_W, true))
	await _frames(3)
	check(mm[0].mech.key_value == 1.0, "W apertado no assento: motor recebe +1")
	Input.parse_input_event(_key(KEY_W, false))
	await _frames(3)
	check(mm[0].mech.key_value == 0.0, "soltou W: volta a 0")
	mm[0].mech.toggle = true
	Input.parse_input_event(_key(KEY_W, true))
	await _frames(2)
	Input.parse_input_event(_key(KEY_W, false))
	await _frames(2)
	check(mm[0].mech.key_value == 1.0, "modo alternar: um toque liga e fica ligado")
	Build.active_seat = null
	await _frames(2)
	check(mm[0].mech.key_value == 0.0, "levantou do assento: teclas param de valer")

	print("== Reciclar componente")
	var rj := mm[0].mech
	Build.delete_part(mm[0])
	await _frames(2)
	check(not Build.joints.has(rj), "reciclar a carcaça remove a junta")
	check(is_instance_valid(mm[1]) and mm[1].mech == null, "o disco fica como peça solta")

	await _car_test()
	await _demo_car_test()
	await _player_test()


func _key(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	return ev


## Carrinho: chassi + 4 motores com rodas, acionado por uma alavanca.
func _car_test() -> void:
	print("== Carrinho")
	var x0 := 60.0
	var chassis := Build.spawn_box(Vector3(1.6, 0.1, 2.4), "aco", Transform3D(Basis(), Vector3(x0, 0.6, 0)))
	var lever := Components.spawn("alavanca", Transform3D(Basis(), Vector3(x0, 0.69, 0.6)))[0]
	Build.make_weld(lever, chassis, Vector3(x0, 0.65, 0.6))
	# Motores com o eixo apontando para fora (±X), presos nas laterais do chassi.
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.9, 0.9]:
			var basis := Basis(Vector3.BACK, -side * PI * 0.5)   # Y local -> ±X do mundo
			var motor_pos := Vector3(x0 + side * (0.8 + 0.15), 0.6, z)
			var parts := Components.spawn("motor", Transform3D(basis, motor_pos))
			Build.make_weld(parts[0], chassis, Vector3(x0 + side * 0.8, 0.6, z))
			var wheel_pos := motor_pos + basis.y * (0.15 + 0.064 + 0.1)
			var wheel := Components.spawn("roda", Transform3D(basis, wheel_pos), Vector3(0.4, 0.2, 0))[0]
			Build.make_weld(wheel, parts[1], motor_pos + basis.y * (0.15 + 0.064))
			# Lado esquerdo e direito giram em sentidos opostos para andar para a frente.
			parts[0].mech.invert = side > 0.0
			Build.toggle_link(lever.device, parts[0].mech)
	await _frames(60)
	var start := chassis.global_position
	lever.device.press()
	await _frames(180)
	var moved := chassis.global_position - start
	check(Vector2(moved.x, moved.z).length() > 3.0, "carrinho anda com a alavanca ligada (%.1f m)" % Vector2(moved.x, moved.z).length())
	check(absf(moved.x) < Vector2(moved.x, moved.z).length() * 0.5, "e anda reto (desvio x=%.2f)" % moved.x)
	check(chassis.global_basis.y.dot(Vector3.UP) > 0.9, "sem capotar")


## Carrinho de exemplo do mapa: W anda para a frente (-Z), A vira à esquerda.
func _demo_car_test() -> void:
	print("== Carrinho de exemplo (teclas)")
	var o := Vector3(100, 0, 0)
	var seat := DemoBuilds.build_car(o)
	var chassis := seat.assembly()
	await _frames(60)
	Build.active_seat = seat
	var start := chassis.global_position
	Input.parse_input_event(_key(KEY_W, true))
	await _frames(150)
	Input.parse_input_event(_key(KEY_W, false))
	var moved := chassis.global_position - start
	check(moved.z < -3.0, "W anda para a frente, para onde o assento olha (dz=%.1f m)" % moved.z)
	await _frames(60)
	var fwd0 := -chassis.global_basis.z
	Input.parse_input_event(_key(KEY_A, true))
	await _frames(60)
	Input.parse_input_event(_key(KEY_A, false))
	var fwd1 := -chassis.global_basis.z
	var turn := rad_to_deg(atan2(fwd0.cross(fwd1).y, fwd0.dot(fwd1)))
	check(turn > 15.0, "A vira para a esquerda (%.0f°)" % turn)
	Build.active_seat = null


func _press(action: String, pressed: bool) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	return ev


func _aim(player: Player, feet: Vector3, target: Vector3) -> void:
	player.teleport(feet)
	player.velocity = Vector3.ZERO
	var d := (target - (feet + Vector3(0, Player.EYE_HEIGHT, 0))).normalized()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = asin(clampf(d.y, -1.0, 1.0))


## Jogador de verdade: fiação, usar alavanca com F, sentar e levantar.
func _player_test() -> void:
	print("== Jogador: fiação, alavanca e assento")
	var player := Player.new()
	add_child(player)
	await _frames(2)
	var o := Vector3(140, 0, 0)
	var lever := Components.spawn("alavanca", Transform3D(Basis(), o + Vector3(0, 0.04, 0)))[0]
	var motor := Components.spawn("motor", Transform3D(Basis(), o + Vector3(1.5, 0.17, 0)))
	await _frames(10)

	player.select_tool(3)
	var wire: WireTool = player.tools[3]
	_aim(player, o + Vector3(0, 0, 2.2), lever.global_position)
	await _frames(3)
	wire.handle_input(_press("primary", true))
	_aim(player, o + Vector3(1.5, 0, 2.2), motor[0].global_position)
	await _frames(3)
	wire.handle_input(_press("primary", true))
	check(motor[0].mech.sources.has(lever.device), "fiação: clicar na alavanca e depois no motor liga o fio")

	# Isolador feito com a máquina de solda (botão direito) numa chapa
	var plate := Build.spawn_box(Vector3(1, 0.1, 1), "aco", Transform3D(Basis(), o + Vector3(0.8, 0.05, -1.5)))
	var servo := Components.spawn("servo", Transform3D(Basis(), o + Vector3(1.6, 0.17, -3.0)))
	await _frames(10)
	# Fiação: começa na alavanca e clica na chapa → cria um isolador no caminho
	_aim(player, o + Vector3(0, 0, 2.2), lever.global_position)
	await _frames(3)
	wire.handle_input(_press("primary", true))
	_aim(player, o + Vector3(0.8, 0, 0.6), o + Vector3(0.8, 0.1, -1.5))
	await _frames(3)
	wire.handle_input(_press("primary", true))
	var ins: Part = null
	for c in get_children():
		if c is Assembly:
			for p: Part in (c as Assembly).get_parts():
				if p.kind == "isolador":
					ins = p
	check(ins != null and ins.assembly() == plate.assembly(), "fiação: clicar na chapa cria um isolador soldado nela")
	wire.handle_input(_press("primary", true))
	var count := 0
	for c in get_children():
		if c is Assembly:
			for p: Part in (c as Assembly).get_parts():
				if p.kind == "isolador":
					count += 1
	check(count == 1, "no mesmo lugar não cria outro isolador")
	_aim(player, o + Vector3(1.6, 0, -0.8), servo[0].global_position)
	await _frames(3)
	wire.handle_input(_press("primary", true))
	var sj: MechJoint = servo[0].mech
	check(sj.sources.has(lever.device) and sj.routes.get(lever.device, []).has(ins), "fio passa pelo isolador")
	check(sj.wire_points(lever.device).size() == 3, "desenho do fio: controle → isolador → servo")
	# Esmerilhadeira: segurar no isolador arranca ele; o fio continua, só sem passar por ali
	player.select_tool(2)
	var grinder: GrinderTool = player.tools[2]
	_aim(player, o + Vector3(0.8, 0, 0.6), ins.global_position + Vector3(0, 0.07, 0))
	await _frames(3)
	grinder.begin_use()
	check(grinder.mode == GrinderTool.Mode.REMOVING, "esmerilhadeira mirando o isolador: modo arrancar")
	await _frames(50)
	check(not is_instance_valid(ins) or not ins.is_inside_tree(), "segurando, o isolador é arrancado")
	check(sj.wire_points(lever.device).size() == 2 and sj.sources.has(lever.device), "sem o isolador o fio continua ligado (só some do caminho)")

	_aim(player, o + Vector3(0, 0, 1.6), lever.global_position)
	await _frames(3)
	player.use_interact()
	check(lever.device.value == 1.0, "F na alavanca liga")
	await _frames(40)
	check(motor[1].assembly().angular_velocity.length() > 5.0, "motor ligado pela alavanca gira")

	var seat := Components.spawn("assento", Transform3D(Basis(), o + Vector3(-2, 0.1, 0)))[0]
	await _frames(20)
	_aim(player, o + Vector3(-2, 0, 1.4), seat.global_position)
	await _frames(3)
	player.use_interact()
	check(player.is_seated() and Build.active_seat == seat, "F no assento: sentou")
	await _frames(5)
	check(player.global_position.distance_to(seat.global_position) < 1.5, "jogador acompanha o assento")
	player.use_interact()
	await _frames(3)
	check(not player.is_seated() and Build.active_seat == null and player.collision_layer == Layers.PLAYER, "F de novo: levantou")

	# Levantar de um carrinho não pode empurrar o carrinho.
	var car_seat := DemoBuilds.build_car(o + Vector3(0, 0, -12))
	await _frames(60)
	player.sit(car_seat)
	await _frames(10)
	var before := car_seat.global_position
	player.stand_up()
	await _frames(60)
	var kicked := car_seat.global_position.distance_to(before)
	check(kicked < 0.15, "levantar do carrinho não empurra o carrinho (%.2f m)" % kicked)
	check(player.global_position.distance_to(car_seat.global_position) < 4.0, "e o jogador desce do lado")
	player.queue_free()

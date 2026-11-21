extends Node3D
## Rigidez das juntas e estabilidade (Gravitador, mola, guincho).
##   godot --headless --path . res://tests/test_rigid.tscn
##
## "Folga" de uma junta = o quanto o lado móvel saiu do lugar além do movimento
## permitido: inclinação fora do eixo (graus) e separação do pivô (cm).

const EXPECTED_CHECKS := 19

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


func _play_of(joints: Array) -> Vector2:
	var w := Vector2.ZERO
	for j: MechJoint in joints:
		w = w.max(play(j))
	return w


## Carrinho de exemplo com as rodas soldadas encostando na carcaça do motor.
func _flush_car(origin: Vector3) -> Array:
	var out: Array = []
	var chassis := Build.spawn_box(Vector3(1.6, 0.1, 2.4), "aco", Transform3D(Basis(), origin + Vector3(0, 0.6, 0)))
	var seat: Array[Part] = Components.spawn("assento", Transform3D(Basis(), origin + Vector3(0, 0.71, 0.35)))
	Build.make_weld(seat[0], chassis, origin + Vector3(0, 0.65, 0.35))
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.9, 0.9]:
			var basis := Basis(Vector3.BACK, -side * PI * 0.5)
			var motor_pos := origin + Vector3(side * 0.95, 0.6, z)
			var motor: Array[Part] = Components.spawn("motor", Transform3D(basis, motor_pos))
			Build.make_weld(motor[0], chassis, origin + Vector3(side * 0.8, 0.6, z))
			# face interna da roda 5 cm DENTRO da carcaça (encostando/raspando)
			var wheel: Part = Components.spawn("roda", Transform3D(basis, motor_pos + basis.y * 0.2), Vector3(0.4, 0.2, 0))[0]
			Build.make_weld(wheel, motor[1], motor_pos + basis.y * 0.214)
			motor[0].mech.invert = side > 0.0
			motor[0].mech.collide = false     # opção: a roda pode encostar na carcaça sem raspar
			motor[0].mech.rebuild(Build.world_root)
			out.append(motor[0].mech)
	return out


## Folga atual: [inclinação fora do eixo (graus), separação do pivô (m)].
static func play(j: MechJoint) -> Vector2:
	var cur := j.part_a.global_transform.affine_inverse() * j.part_b.global_transform
	var d := cur * j.rest.affine_inverse()        # quanto o lado b saiu da pose "zero" (no espaço de a)
	var ax := j.axis.normalized()
	var swing := rad_to_deg((d.basis.orthonormalized() * ax).angle_to(ax))
	var sep := d * j.pivot - j.pivot
	if j.type in MechJoint.LINEAR:
		sep -= ax * sep.dot(ax)                   # deslizar no eixo é permitido
	if j.type == "esferica":
		swing = 0.0
	return Vector2(swing, sep.length())


## Pior folga entre as juntas, acompanhando por `frames` ticks.
func _worst(joints: Array, frames: int, each := Callable()) -> Vector2:
	var worst := Vector2.ZERO
	for i in frames:
		if each.is_valid():
			each.call(i)
		await get_tree().physics_frame
		for j: MechJoint in joints:
			if j.is_valid() and j.joint != null:
				var p := play(j)
				worst = Vector2(maxf(worst.x, p.x), maxf(worst.y, p.y))
	return worst


func _run() -> void:
	print("== Dobradiça de pino com carga de lado")
	var pin := Components.spawn("pino", Transform3D(Basis(), Vector3(0, 1.5, 0)))
	pin[0].assembly().set_anchored(true)
	var load_plate := Build.spawn_box(Vector3(0.1, 1.0, 1.0), "aco", Transform3D(Basis(), Vector3(0.18, 1.5, 0.45)))
	Build.make_weld(load_plate, pin[1], Vector3(0.13, 1.5, 0.05))
	await _frames(5)
	var pw := await _worst([pin[0].mech], 120)
	print("     folga: %.2f° / %.1f cm" % [pw.x, pw.y * 100.0])
	check(pw.x < 1.0 and pw.y < 0.01, "pino com 78 kg pendurado de lado quase não tem folga (%.2f°, %.1f cm)" % [pw.x, pw.y * 100.0])

	print("== Todas as juntas com peso de lado")
	var kinds := ["motor", "servo", "pistao", "servo_linear", "dobradica", "pino", "trava", "torcao", "mola", "esferica"]
	var all_joints: Array = []
	for i in kinds.size():
		var c := Components.spawn(kinds[i], Transform3D(Basis(), Vector3(-20 - i * 3.0, 2.0, 10)))
		c[0].assembly().set_anchored(true)
		# Peso do lado de fora da parte móvel (sem encostar na base) e deslocado de lado.
		var out := (c[1].global_position - c[0].global_position).normalized()
		var perp := out.cross(Vector3.UP if absf(out.y) < 0.9 else Vector3.RIGHT).normalized()
		var side := c[1].global_position + out * 0.45 + perp * 0.3
		var weight := Build.spawn_box(Vector3(0.5, 0.06, 0.5), "aco", Transform3D(Basis(), side))
		Build.make_weld(weight, c[1], c[1].global_position + out * 0.1)
		all_joints.append(c[0].mech)
	await _frames(10)
	var per := {}
	for f in 120:
		await get_tree().physics_frame
		for j: MechJoint in all_joints:
			var p := play(j)
			var cur: Vector2 = per.get(j.type, Vector2.ZERO)
			per[j.type] = Vector2(maxf(cur.x, p.x), maxf(cur.y, p.y))
	var worst_all := Vector2.ZERO
	var line := ""
	for k: String in per:
		var v: Vector2 = per[k]
		line += "%s %.2f°/%.1fcm  " % [k, v.x, v.y * 100.0]
		worst_all = Vector2(maxf(worst_all.x, v.x), maxf(worst_all.y, v.y))
	print("     " + line)
	check(worst_all.x < 1.0 and worst_all.y < 0.01, "todas as juntas aguentam 12 kg de lado sem folga (pior %.2f°, %.1f cm)" % [worst_all.x, worst_all.y * 100.0])

	print("== Carrinho andando e freando")
	var seat := DemoBuilds.build_car(Vector3(20, 0, 0))
	var car_joints: Array = Build.network(seat)
	var btn: Part = Components.spawn("botao", Transform3D(Basis(), Vector3(25, 0.04, 0)))[0]
	for j: MechJoint in car_joints:
		Build.toggle_link(btn.device, j)
	await _frames(30)
	btn.device.press()
	var drive := await _worst(car_joints, 150)
	btn.device.release()
	var brake := await _worst(car_joints, 60)
	var cw := Vector2(maxf(drive.x, brake.x), maxf(drive.y, brake.y))
	print("     folga: %.2f° / %.1f cm" % [cw.x, cw.y * 100.0])
	check(cw.x < 1.0 and cw.y < 0.01, "motores do carrinho andando e freando ficam firmes (%.2f°, %.1f cm)" % [cw.x, cw.y * 100.0])

	print("== Carro pesado (1,9 t) andando: as rodas não dobram")
	var heavy_seat := DemoBuilds.build_car(Vector3(-60, 0, -40))
	var load_h := 1500.0 / 785.0 / (1.2 * 1.6)
	var cargo := Build.spawn_box(Vector3(1.2, load_h, 1.6), "aco", Transform3D(Basis(), Vector3(-60, 0.65 + load_h * 0.5, -40.3)))
	Build.make_weld(cargo, heavy_seat, Vector3(-60, 0.7, -40.3))
	var heavy_joints: Array = Build.network(heavy_seat)
	var hb: Part = Components.spawn("botao", Transform3D(Basis(), Vector3(-55, 0.04, -35)))[0]
	for j: MechJoint in heavy_joints:
		Build.toggle_link(hb.device, j)
	await _frames(60)
	var wheel_asm: Assembly = heavy_joints[0].part_b.assembly()
	var weight_ok := absf(wheel_asm.mass * wheel_asm.gravity_scale - wheel_asm.real_mass()) < 0.01
	print("     roda: massa real %.0f kg, massa de inércia %.0f kg (x%.1f)" % [wheel_asm.real_mass(), wheel_asm.mass, wheel_asm.mass_boost])
	check(wheel_asm.mass_boost > 1.0 and weight_ok, "a roda ganha massa de inércia, mas o peso continua o mesmo")
	var start_hp := heavy_seat.global_position
	hb.device.press()
	var hv := await _worst(heavy_joints, 180)
	var dist := heavy_seat.global_position.distance_to(start_hp)
	hb.device.release()
	print("     folga: %.2f° / %.1f cm, andou %.1f m" % [hv.x, hv.y * 100.0, dist])
	check(hv.x < 1.0 and hv.y < 0.01 and dist > 4.0, "carro de 1,9 t anda sem as rodas dobrarem (%.2f°, %.1f cm, %.1f m)" % [hv.x, hv.y * 100.0, dist])

	print("== Gravitador sacudindo o carrinho")
	var player := Player.new()
	add_child(player)
	await _frames(2)
	var chassis: Part = null
	for p: Part in seat.assembly().get_parts():
		if p.kind == "metal":
			chassis = p
	player.teleport(Vector3(20, 0.05, 4.0))
	var to := chassis.global_position - (player.global_position + Vector3(0, Player.EYE_HEIGHT, 0))
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = asin(to.normalized().y)
	await _frames(3)
	player.select_tool(0)
	var grav: HandTool = player.tools[0]
	grav.grab()
	check(grav.holding, "o Gravitador pega o carrinho")
	var yaw0 := player.yaw
	var shake := await _worst(car_joints, 150, func(i: int) -> void:
		player.yaw = yaw0 + sin(i * 0.25) * 0.9          # vai e volta rápido
		player.pitch = -0.25 + sin(i * 0.4) * 0.35
		grav.hold_distance = 4.0 + sin(i * 0.3) * 2.0)
	print("     folga: %.2f° / %.1f cm" % [shake.x, shake.y * 100.0])
	check(shake.x < 4.0 and shake.y < 0.03, "sacudindo o carrinho no Gravitador, nenhuma junta desmonta (%.2f°, %.1f cm)" % [shake.x, shake.y * 100.0])
	grav.drop()
	await _frames(60)

	print("== Mola carregada no Gravitador")
	var sp := Components.spawn("mola", Transform3D(Basis(), Vector3(40, 0.06, 0)))
	await _frames(20)
	player.teleport(Vector3(40, 0.05, 2.5))
	var to2 := sp[1].global_position - (player.global_position + Vector3(0, Player.EYE_HEIGHT, 0))
	player.yaw = atan2(-to2.x, -to2.z)
	player.pitch = asin(to2.normalized().y)
	await _frames(3)
	grav.grab()
	var yaw1 := player.yaw
	var max_ext := 0.0
	var max_rel := 0.0
	for i in 150:
		# no ar (sem bater no chão), sacudindo para todo lado
		player.yaw = yaw1 + sin(i * 0.25) * 0.9
		player.pitch = 0.15 + sin(i * 0.4) * 0.25
		await get_tree().physics_frame
		max_ext = maxf(max_ext, absf(sp[0].mech.extension()))
		max_rel = maxf(max_rel, (sp[0].assembly().linear_velocity - sp[1].assembly().linear_velocity).length())
	player.yaw = yaw1          # para de sacudir antes de soltar (senão é um arremesso)
	player.pitch = 0.15
	await _frames(40)
	grav.drop()
	await _frames(150)
	var rest_speed := sp[0].assembly().linear_velocity.length() + sp[1].assembly().linear_velocity.length()
	print("     extensão máx %.3f m, velocidade entre as placas máx %.1f m/s, depois de soltar %.2f m/s" % [max_ext, max_rel, rest_speed])
	check(max_ext < 0.06, "carregando a mola, as placas não se separam (%.3f m)" % max_ext)
	check(max_rel < 3.0 and rest_speed < 0.5, "a mola não sai voando (entre placas %.1f m/s, depois de soltar %.2f m/s)" % [max_rel, rest_speed])

	print("== Pegar de perto")
	player.teleport(Vector3(60, 0.05, 0.7))
	await _frames(5)
	var near_box := Build.spawn_box(Vector3(0.2, 0.2, 0.2), "aco", Transform3D(Basis(), player.eye_position() + Vector3(0, -0.1, -0.6)))
	near_box.assembly().set_frozen(true)
	await _frames(3)
	var to3 := near_box.global_position - (player.global_position + Vector3(0, Player.EYE_HEIGHT, 0))
	player.yaw = atan2(-to3.x, -to3.z)
	player.pitch = asin(to3.normalized().y)
	await _frames(3)
	var eye_dist := player.eye_position().distance_to(near_box.global_position)
	grav.grab()
	await _frames(40)
	var after := player.eye_position().distance_to(near_box.global_position)
	print("     distância ao pegar %.2f m, depois %.2f m" % [eye_dist, after])
	check(grav.holding and absf(after - eye_dist) < 0.25, "pegar de perto não empurra a peça para longe (%.2f → %.2f m)" % [eye_dist, after])
	grav.drop()
	player.queue_free()

	print("== Roda soldada encostada na carcaça do motor, andando e virando")
	var fl := _flush_car(Vector3(0, 0, -60))
	await _frames(30)
	var still := _play_of(fl)
	var go: Part = Components.spawn("botao", Transform3D(Basis(), Vector3(6, 0.04, -55)))[0]
	var spin: Part = Components.spawn("botao", Transform3D(Basis(), Vector3(7, 0.04, -55)))[0]
	for j: MechJoint in fl:
		Build.toggle_link(go.device, j)
		if j.invert:
			Build.toggle_link(spin.device, j)
	go.device.press()
	var moving := Vector2.ZERO
	for f in 240:
		if f == 120:
			spin.device.press()        # lado direito ao contrário: vira no lugar
		await get_tree().physics_frame
		moving = moving.max(_play_of(fl))
	go.device.release()
	spin.device.release()
	await _frames(90)
	var after_drive := _play_of(fl)
	print("     parado %.2f°/%.1fcm, andando %.2f°/%.1fcm, depois %.2f°/%.1fcm" % [still.x, still.y * 100, moving.x, moving.y * 100, after_drive.x, after_drive.y * 100])
	check(moving.x < 1.5 and moving.y < 0.015 and after_drive.x < 0.5, "sem colisão entre os lados, roda encostada na carcaça não tomba ao andar e virar (%.2f°, depois %.2f°)" % [moving.x, after_drive.x])

	print("== Junta refeita depois de sair do lugar")
	var hm := Components.spawn("motor", Transform3D(Basis(), Vector3(0, 1.0, -80)))
	hm[0].assembly().set_anchored(true)
	await _frames(5)
	var rotor_asm := hm[1].assembly()
	rotor_asm.global_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(8.0)), Vector3(0.03, 0, 0)) * rotor_asm.global_transform
	var broken := play(hm[0].mech)
	hm[0].mech.rebuild(Build.world_root)
	await _frames(40)
	var healed := play(hm[0].mech)
	print("     torta %.1f°/%.1fcm → refeita %.2f°/%.2fcm" % [broken.x, broken.y * 100, healed.x, healed.y * 100])
	check(broken.x > 5.0 and healed.x < 0.3 and healed.y < 0.003, "ao refazer a junta (solda, corte, save), ela volta para a pose certa (%.2f°)" % healed.x)

	print("== Pistão: dá para soldar na camisa")
	var ps := Components.spawn("pistao", Transform3D(Basis(), Vector3(0, 0.36, -90)))
	await _frames(10)
	var side_pt := ps[0].global_transform * Vector3(0.13, 0.35, 0)
	var plate := Build.spawn_box(Vector3(0.1, 0.4, 0.4), "aco", Transform3D(Basis(), side_pt + Vector3(0.05, 0, 0)))
	await _frames(2)
	var wsleeve := Build.weld_at(plate, side_pt)
	check(wsleeve != null and plate.assembly() == ps[0].assembly(), "soldar na lateral da camisa prende na base do pistão")

	print("== Parte congelada: puxar um braço não arrasta o outro")
	var deck := Build.spawn_box(Vector3(2, 0.1, 1), "aco", Transform3D(Basis(), Vector3(100, 1.0, 0)))
	var arms: Array[Part] = []
	for x: float in [-0.8, 0.8]:
		var h := Components.spawn("dobradica", Transform3D(Basis(), Vector3(100 + x, 1.08, 0.3)))
		Build.make_weld(h[0], deck, Vector3(100 + x, 1.05, 0.15))
		var bar := Build.spawn_box(Vector3(0.1, 0.06, 0.8), "aco", Transform3D(Basis(), Vector3(100 + x, 1.08, 0.75)))
		Build.make_weld(bar, h[1], Vector3(100 + x, 1.08, 0.4))
		arms.append(bar)
	deck.assembly().set_frozen(true)
	await _frames(5)
	var other_start := arms[1].global_position
	var pulled_start := arms[0].global_position
	var pc := Carrier.new()
	for i in 60:
		pc.step(arms[0], Vector3.ZERO, arms[0].global_transform.translated(Vector3(0, 0.6, 0) * minf(i / 20.0, 1.0)), 1.0 / 60.0)
		await get_tree().physics_frame
	var other_moved := arms[1].global_position.distance_to(other_start)
	var pulled_moved := arms[0].global_position.distance_to(pulled_start)
	pc.release()
	print("     puxado andou %.2f m, o outro %.3f m" % [pulled_moved, other_moved])
	check(pulled_moved > 0.1 and other_moved < 0.02, "com o chassi congelado, só o braço puxado se mexe (o outro andou %.3f m)" % other_moved)

	print("== Carregar o guincho: o gancho não vem junto rígido")
	var cw2 := Components.spawn("guincho", Transform3D(Basis(), Vector3(120, 0.14, 0)))
	await _frames(30)
	var wc := Carrier.new()
	var body_y0 := cw2[0].global_position.y
	var hook_y0 := cw2[1].global_position.y
	for i in 8:
		wc.step(cw2[0], Vector3.ZERO, cw2[0].global_transform.translated(Vector3(0, 0.3, 0)), 1.0 / 60.0)
		await get_tree().physics_frame
	var body_up := cw2[0].global_position.y - body_y0
	var hook_up := cw2[1].global_position.y - hook_y0
	print("     corpo subiu %.2f m, gancho %.2f m" % [body_up, hook_up])
	check(not wc.carried.has(cw2[1].assembly()) and hook_up < body_up * 0.5, "o gancho fica no cabo, não é carregado junto (corpo +%.2f m, gancho +%.2f m)" % [body_up, hook_up])
	wc.release()

	print("== Guincho congelado no ar: gancho chegando ao fim do cabo")
	var fw := Components.spawn("guincho", Transform3D(Basis(), Vector3(140, 4, 0)))
	fw[0].assembly().set_frozen(true)
	var fj: MechJoint = fw[0].mech
	fj.rope_len = 1.5
	var taut := false
	var bounce := 0.0
	var frames_after := 0
	for i in 240:
		await get_tree().physics_frame
		if not taut and fj.rope_start().distance_to(fj.rope_end()) >= fj.rope_len - 0.01:
			taut = true
		if taut and frames_after < 90:
			frames_after += 1
			bounce = maxf(bounce, fw[1].assembly().linear_velocity.y)
	print("     chegou ao fim: %s, maior velocidade para cima depois %.2f m/s" % [taut, bounce])
	check(taut and bounce < 0.6, "ao chegar no fim do cabo, o gancho para sem quicar (sobe no máx %.2f m/s)" % bounce)

	print("== Guincho com o gancho pendurado")
	var w := Components.spawn("guincho", Transform3D(Basis(), Vector3(80, 4, 0)))
	w[0].assembly().set_anchored(true)
	var wj: MechJoint = w[0].mech
	wj.rope_len = 1.5
	await _frames(240)                         # cai, balança e acalma
	var hook := w[1].assembly()
	var max_v := 0.0
	var max_over := 0.0
	for i in 120:
		await get_tree().physics_frame
		max_v = maxf(max_v, absf(hook.linear_velocity.y))
		max_over = maxf(max_over, wj.rope_start().distance_to(wj.rope_end()) - wj.rope_len)
	print("     velocidade vertical máx %.2f m/s, cabo esticado além do tamanho %.1f cm" % [max_v, max_over * 100.0])
	check(max_v < 0.5, "pendurado, o gancho não pula (vertical máx %.2f m/s)" % max_v)
	check(max_over < 0.03, "o cabo segura o gancho no comprimento certo (+%.1f cm)" % (max_over * 100.0))
	# Balançando forte de lado
	hook.linear_velocity = Vector3(4, 0, 2)
	await _frames(180)
	var max_v2 := 0.0
	for i in 60:
		await get_tree().physics_frame
		max_v2 = maxf(max_v2, hook.linear_velocity.length())
	print("     depois de empurrado: velocidade máx %.2f m/s" % max_v2)
	check(max_v2 < 4.5, "empurrado, o gancho só balança, sem ganhar energia (%.2f m/s)" % max_v2)

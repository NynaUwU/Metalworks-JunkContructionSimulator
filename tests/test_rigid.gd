extends Node3D
## Rigidez das juntas e estabilidade (Gravitador, mola, guincho).
##   godot --headless --path . res://tests/test_rigid.tscn
##
## "Folga" de uma junta = o quanto o lado móvel saiu do lugar além do movimento
## permitido: inclinação fora do eixo (graus) e separação do pivô (cm).

const EXPECTED_CHECKS := 11

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

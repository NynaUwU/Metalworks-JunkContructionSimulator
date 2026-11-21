extends Node3D
## Testes: chapas finas rápidas, cilindros, tamanhos, Trena, marcas, Alinhador, puxador.
##   godot --headless --path . res://tests/test_precision.tscn

const EXPECTED_CHECKS := 33

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


func _aim(player: Player, feet: Vector3, target: Vector3) -> void:
	player.teleport(feet)
	player.velocity = Vector3.ZERO
	var d := (target - (feet + Vector3(0, Player.EYE_HEIGHT, 0))).normalized()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = asin(clampf(d.y, -1.0, 1.0))


func _run() -> void:
	print("== Chapas finas rápidas")
	var o := Vector3(0, 20, -40)
	var wall := Build.spawn_box(Vector3(1.5, 1.5, 0.05), "aco", Transform3D(Basis(), o))
	wall.assembly().set_frozen(true)
	var bullet := Build.spawn_box(Vector3(0.5, 0.05, 0.5), "aco", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), o + Vector3(0, 0, 1.5)))
	bullet.assembly().gravity_scale = 0.0
	bullet.assembly().linear_velocity = Vector3(0, 0, -40)
	await _frames(30)
	check(bullet.global_position.z > o.z, "chapa de 5 cm a 40 m/s não atravessa outra chapa de 5 cm")
	var mot := Components.spawn("motor", Transform3D(Basis(), Vector3(10, 0.2, -40)))
	await _frames(2)
	check(bullet.assembly().continuous_cd and not mot[0].assembly().continuous_cd, "colisão contínua só nas peças soltas (máquinas com juntas não desmontam)")

	print("== Cilindros octogonais")
	var cyl_item := Catalog.get_item("cilindro")
	var geo := Catalog.geometry(cyl_item, Vector3(0.4, 0.4, 2.0))
	var area := 2.0 * 0.4 * 0.4 * tan(PI / 8.0)       # octógono com 0,4 m entre faces opostas
	var aabb: AABB = geo["aabb"]
	check(Catalog.planes(cyl_item, Vector3(0.4, 0.4, 2.0)).size() == 10 and absf(geo["volume"] - area * 2.0) < 1e-3 \
		and absf(aabb.size.x - 0.4) < 1e-4 and absf(aabb.size.y - 0.4) < 1e-4,
		"prisma de 8 lados com o volume certo e do tamanho pedido (%.4f m³, %.2f × %.2f)" % [geo["volume"], aabb.size.x, aabb.size.y])
	var cyl := Build.spawn_planes(Catalog.planes(cyl_item, Vector3(0.4, 0.4, 2.0)), "aco", Transform3D(Basis(), Vector3(20, 0.2, -40)))
	await _frames(20)
	check(cyl.global_position.y < 0.2 and absf(cyl.global_basis.y.dot(Vector3.UP)) > 0.99, "fica apoiado numa face, sem rolar")
	check(Build.cut_part(cyl, Plane(Vector3.BACK, 0.3)).size() == 2, "dá para cortar o cilindro")

	print("== Tamanhos pequeno / médio / grande")
	var bm := Components.bounds("motor", Vector3.ZERO)
	var bg := Components.bounds("motor", Vector3(Components.SIZE_LARGE, 0, 0))
	check(absf(bg.size.x - bm.size.x * 1.6) < 1e-4 and Components.price("motor", Vector3(0.6, 0, 0)) < Components.price("motor") \
		and Components.price("motor") < Components.price("motor", Vector3(1.6, 0, 0)), "motor grande é 1,6× maior e mais caro; pequeno mais barato")
	var small := Components.spawn("motor", Transform3D(Basis(), Vector3(30, 1, -40)), Vector3(0.6, 0, 0))
	var big := Components.spawn("motor", Transform3D(Basis(), Vector3(34, 1.5, -40)), Vector3(1.6, 0, 0))
	small[0].assembly().set_anchored(true)
	big[0].assembly().set_anchored(true)
	check(small[0].mech.strength < big[0].mech.strength and absf(big[0].mech.pivot.y - small[0].mech.pivot.y * 1.6 / 0.6) < 1e-4, "força e medidas acompanham o tamanho")
	var btn: Part = Components.spawn("botao", Transform3D(Basis(), Vector3(32, 0.04, -38)))[0]
	Build.toggle_link(btn.device, small[0].mech)
	Build.toggle_link(btn.device, big[0].mech)
	btn.device.press()
	await _frames(60)
	check(small[1].assembly().angular_velocity.length() > 5.0 and big[1].assembly().angular_velocity.length() > 5.0, "motor pequeno e grande giram")
	btn.device.release()
	var gp := Components.spawn("pistao", Transform3D(Basis(), Vector3(40, 0.36 * 1.6, -40)), Vector3(1.6, 0, 0))
	gp[0].assembly().set_anchored(true)
	var b2: Part = Components.spawn("botao", Transform3D(Basis(), Vector3(41, 0.04, -38)))[0]
	Build.toggle_link(b2.device, gp[0].mech)
	b2.device.press()
	await _frames(90)
	check(gp[0].mech.stroke > 0.79 and gp[0].mech.extension() > 0.7, "pistão grande estica 0,8 m (%.2f)" % gp[0].mech.extension())
	var spr := Components.spawn("mola", Transform3D(Basis(), Vector3(44, 0.04, -40)), Vector3(0.6, 0, 0))
	spr[0].assembly().set_anchored(true)
	await _frames(30)
	check(absf(spr[0].mech.extension()) < 0.02 and is_equal_approx(spr[0].mech.size_scale, 0.6), "mola pequena funciona (curso proporcional)")
	var wheel_item := Catalog.get_item("roda")
	var wsize := Catalog.with_choice(Catalog.default_size(wheel_item), wheel_item["params"][0], 2)
	check(wsize.is_equal_approx(Vector3(0.8, 0.4, 0)) and Catalog.clamp_size(wheel_item, Vector3(0.5, 0.25, 0)).is_equal_approx(Vector3(0.5, 0.25, 0)), "roda: tamanho grande = raio 0,8; ajuste fino continua valendo")
	var mot_item := Catalog.get_item("motor")
	check(is_equal_approx(Catalog.clamp_size(mot_item, Vector3(1.6, 0, 0)).x, 1.6) and is_equal_approx(Catalog.clamp_size(mot_item, Vector3(1.2, 0, 0)).x, 1.0), "loja: tamanho do motor só pequeno/médio/grande")
	var data: Dictionary = JSON.parse_string(JSON.stringify(Saves.serialize([big[0].assembly(), big[1].assembly()], Transform3D.IDENTITY)))
	var copy := Saves.restore(data, Transform3D(Basis(), Vector3(0, 0, 10)))
	var copy_motor: Part = copy.filter(func(p: Part) -> bool: return p.comp_index == 0)[0]
	check(is_equal_approx(copy_motor.mech.size_scale, 1.6) and absf(copy_motor.mech.strength - big[0].mech.strength) < 1.0, "salvar e carregar mantém o tamanho")

	print("== Trena e marcas")
	var player := Player.new()
	add_child(player)
	await _frames(2)
	var plate := Build.spawn_box(Vector3(2.0, 0.1, 1.0), "aco", Transform3D(Basis(), Vector3(60, 0.05, -40)))
	await _frames(5)
	_aim(player, Vector3(60, 0, -38.5), Vector3(60.37, 0.1, -40.02))
	await _frames(3)
	var s := Snap.aimed(player)
	var loc: Vector3 = s["local"]
	check(s["part"] == plate and is_equal_approx(loc.x, 0.35) and is_equal_approx(loc.z, 0.0) and is_equal_approx(loc.y, 0.05), "ponto mirado encaixa na grade de 5 cm, em cima da face (%s)" % str(loc))
	var edges := MeasureTool.edges_text(plate, loc, s["local_n"])
	check(edges.contains("1,35 m | 65 cm"), "mostra a distância até as bordas (%s)" % edges)
	player.select_tool(5)
	var tape: MeasureTool = player.tools[5]
	tape.handle_input(_press("primary"))
	_aim(player, Vector3(60, 0, -38.5), Vector3(59.6, 0.1, -40.2))
	await _frames(3)
	tape.handle_input(_press("primary"))
	var dist := MeasureTool._world(tape._a).distance_to(MeasureTool._world(tape._b))
	var dl := MeasureTool.local_delta(tape._a, MeasureTool._world(tape._b))
	check(absf(dist - Vector2(0.75, 0.2).length()) < 1e-3 and absf(absf(dl.x) - 0.75) < 1e-3 and absf(absf(dl.z) - 0.2) < 1e-3, "trena: A → B = %.3f m (x 0,75 · z 0,20)" % dist)
	tape.handle_input(_press("secondary"))
	check(plate.marks.size() == 1, "botão direito põe uma marca na peça")
	tape.handle_input(_press("secondary"))
	check(plate.marks.is_empty(), "botão direito na marca tira ela")
	tape.handle_input(_press("secondary"))
	var mark_local: Vector3 = plate.marks[0][0]
	player.select_tool(2)
	var grinder: GrinderTool = player.tools[2]
	grinder.grid_on = true
	_aim(player, Vector3(60, 0, -38.5), plate.global_transform * (mark_local + Vector3(0.03, 0, 0.02)))
	await _frames(3)
	grinder._update_targets()
	check(grinder._target_part == plate and absf(grinder._target_plane.distance_to(mark_local)) < 1e-4, "a Esmerilhadeira encaixa o corte na marca")
	var pieces := Build.cut_part(plate, Plane(Vector3.RIGHT, 0.0))
	var with_mark := pieces.filter(func(p: Part) -> bool: return not p.marks.is_empty())
	check(with_mark.size() == 1 and with_mark[0] == pieces[0], "cortando, a marca fica no pedaço do lado dela")
	var md: Dictionary = JSON.parse_string(JSON.stringify(Saves.serialize([pieces[0].assembly()], Transform3D.IDENTITY)))
	var mcopy := Saves.restore(md, Transform3D(Basis(), Vector3(0, 0, 8)))
	check(mcopy.size() == 1 and (mcopy[0] as Part).marks.size() == 1, "as marcas são salvas")

	print("== Alinhador")
	var base := Build.spawn_box(Vector3(2.0, 0.1, 2.0), "aco", Transform3D(Basis(), Vector3(80, 0.05, -40)))
	base.assembly().set_frozen(true)
	var mover := Build.spawn_box(Vector3(0.4, 0.4, 0.1), "aluminio", Transform3D(Basis(Vector3(1, 1, 0).normalized(), 0.7), Vector3(83, 1.5, -40)))
	mover.assembly().set_frozen(true)
	await _frames(3)
	# Ponto A: centro da face grande (local Z+) da placa que vai se mover.
	var a := Snap.on_part(mover, mover.global_transform * Vector3(0.01, -0.02, 0.05), mover.global_basis * Vector3.BACK)
	# Ponto B: em cima da base, num ponto da grade.
	var b := Snap.on_part(base, base.global_transform * Vector3(0.32, 0.05, -0.41), Vector3.UP)
	# Prévia: com o 1º ponto marcado e mirando no destino, o fantasma aparece na pose final.
	var aligner: AlignTool = player.tools[6]
	player.select_tool(6)
	aligner._a = a
	aligner._update_ghost(b)
	var ghost_ok := aligner._ghost != null and aligner._ghost.visible and aligner._ghost.get_child_count() == 1 \
		and aligner._ghost.get_child(0).get_child_count() > 0
	var ghost_xf: Transform3D = (aligner._ghost.get_child(0) as Node3D).global_transform if ghost_ok else Transform3D()
	var msg := AlignTool.align(a, b)
	await _frames(2)
	check(ghost_ok and ghost_xf.origin.distance_to(mover.assembly().global_position) < 1e-3 \
		and ghost_xf.basis.is_equal_approx(mover.assembly().global_basis), "prévia do Alinhador mostra a peça exatamente onde ela vai ficar")
	aligner._a = {}
	aligner._update_ghost({})
	check(aligner._ghost == null, "cancelando, a prévia some")
	player.select_tool(0)
	var face_center: Vector3 = mover.global_transform * Vector3(0, 0, 0.05)
	var face_n := mover.global_basis.orthonormalized() * Vector3.BACK
	check(face_center.distance_to(base.global_transform * Vector3(0.3, 0.05, -0.4)) < 1e-3, "o ponto da peça vai exatamente no ponto da grade do destino (%s)" % msg)
	check(face_n.dot(Vector3.DOWN) > 0.999, "as faces ficam encostadas (a face da peça virada para a base)")
	var x_axis := mover.global_basis.orthonormalized().x
	check(absf(x_axis.dot(Vector3.RIGHT)) > 0.999 or absf(x_axis.dot(Vector3.BACK)) > 0.999, "giro em esquadro com a base")
	check(mover.assembly().frozen, "depois de alinhada, fica congelada para soldar")
	var rot_before := mover.global_basis
	var a2 := Snap.on_part(mover, mover.global_transform * Vector3(0, 0, 0.05), mover.global_basis * Vector3.BACK)
	var b2b := Snap.on_part(base, base.global_transform * Vector3(-0.5, 0.05, 0.5), Vector3.UP)
	AlignTool.align(a2, b2b, true)
	check(mover.global_basis.is_equal_approx(rot_before) and (mover.global_transform * Vector3(0, 0, 0.05)).distance_to(base.global_transform * Vector3(-0.5, 0.05, 0.5)) < 1e-3, "com Shift só move (o giro fica igual)")

	print("== Puxador")
	var door_hinge := Components.spawn("dobradica", Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(100, 1.2, -40)))
	door_hinge[0].assembly().set_anchored(true)
	var door := Build.spawn_box(Vector3(0.05, 1.0, 0.8), "aluminio", Transform3D(Basis(), door_hinge[1].global_position + Vector3(0, 0, 0.5)))
	Build.make_weld(door, door_hinge[1], door_hinge[1].global_position + Vector3(0, 0, 0.15))
	var handle: Part = Components.spawn("puxador", Transform3D(Basis(Vector3.BACK, -PI * 0.5), door.global_position + Vector3(0.0375, 0, 0.3)))[0]
	Build.make_weld(handle, door, door.global_position + Vector3(0.025, 0, 0.3))
	await _frames(20)
	var ang0 := door_hinge[0].mech.angle()
	_aim(player, door.global_position + Vector3(1.6, -1.2, 0.3), handle.global_position + Vector3(0.04, 0, 0))
	await _frames(3)
	player.select_tool(0)
	check(player.interact_hint().contains("puxar"), "mirando no puxador: 'E (segure): puxar'")
	player.use_interact()
	check(player.is_pulling(), "E começa a puxar")
	# anda para trás segurando o E: puxa a porta para fora
	for i in 60:
		player.global_position += Vector3(0.025, 0, 0)
		await get_tree().physics_frame
	var ang1 := door_hinge[0].mech.angle()
	check(absf(ang1 - ang0) > deg_to_rad(15.0), "puxando, a porta abre (%.0f°)" % rad_to_deg(absf(ang1 - ang0)))
	player._release_device()
	check(not player.is_pulling(), "soltar o E solta")
	var heavy := Build.spawn_box(Vector3(1, 1, 1), "aco", Transform3D(Basis(), Vector3(110, 0.5, -40)))
	var h2: Part = Components.spawn("puxador", Transform3D(Basis(), Vector3(110, 1.0 + 0.0125, -40)))[0]
	Build.make_weld(h2, heavy, Vector3(110, 1.0, -40))
	await _frames(10)
	_aim(player, Vector3(110, 0, -38.2), h2.global_position)
	await _frames(3)
	player.use_interact()
	player.pitch = 0.6
	await _frames(40)
	check(heavy.global_position.y < 0.6, "força fraca: não levanta um bloco de 785 kg (y %.2f)" % heavy.global_position.y)
	player._release_device()
	player.queue_free()


func _press(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev

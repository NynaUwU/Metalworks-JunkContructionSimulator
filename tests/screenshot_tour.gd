extends Node
## Tour automático para tirar screenshots (desenvolvimento).
## Uso: godot --path . -- --tour=/caminho/saida

var out_dir := ""
var world: Node3D
var player: Player


func _ready() -> void:
	world = get_parent()
	player = world.player
	world.hud._help.visible = false
	await _frames(120)  # deixa as pilhas assentarem
	var hand: HandTool = player.hand

	# 1) Visão geral do pátio a partir do spawn
	_look(Vector3(0, 0, 6), Vector3(0, 0.5, -16))
	await _frames(20)
	await _shot("01_patio")

	# 2) Vista aérea
	player.global_position = Vector3(40, 26, 40)
	_look_from_eye(Vector3(0, 0, 0))
	await _frames(20)
	await _shot("02_aerea")

	# 3) Segurando uma chapa (ela flutua)
	player.global_position = Vector3(0, 0.05, 2)
	var plate := Build.spawn_box(Vector3(2, 0.1, 2), "aco", Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.3, 0.06, -1.0)))
	await _frames(10)
	_look_from_eye(plate.global_position)
	await _frames(3)
	player.select_tool(0)
	hand._grab()
	hand.hold_distance = 3.0
	await _frames(40)
	player.pitch = deg_to_rad(-8)
	await _frames(40)
	await _shot("03_segurando")

	# 4) Solta o clique: a chapa continua flutuando; troca para a esmerilhadeira
	hand.holding = false
	player.select_tool(2)
	var grinder: GrinderTool = player.tools[2]
	grinder.cut_index = 5
	_look_from_eye(plate.global_transform * Vector3(0.3, 0, 0.2))
	await _frames(10)
	await _shot("04_preview_corte_45")

	# 5) Corta a chapa em diagonal
	var ev := InputEventAction.new()
	ev.action = "primary"
	ev.pressed = true
	grinder.handle_input(ev)
	await _frames(6)
	await _shot("05_cortada")
	await _frames(90)

	# 6) Monta um "L" soldado na bancada e mostra as bolinhas de solda
	hand.release()
	var base := Build.spawn_box(Vector3(1.5, 0.1, 1.0), "aco", Transform3D(Basis(), Vector3(8, 1.06, -6)))
	var wall := Build.spawn_box(Vector3(1.5, 0.8, 0.1), "ferro", Transform3D(Basis(), Vector3(8, 1.51, -6.45)))
	var beam := Build.spawn_box(Vector3(0.1, 0.1, 1.2), "aluminio", Transform3D(Basis(), Vector3(8.8, 1.06, -6.0)))
	await _frames(20)
	for x: float in [-0.6, 0.0, 0.6]:
		Build.weld_at(wall.assembly().get_parts()[0], Vector3(8 + x, 1.11, -6.4))
	Build.weld_at(beam, Vector3(8.75, 1.06, -5.7))
	Build.weld_at(beam, Vector3(8.75, 1.06, -6.3))
	await _frames(30)
	player.global_position = Vector3(9.4, 0.05, -3.6)
	_look_from_eye(Vector3(8.1, 1.2, -6.1))
	player.select_tool(1)
	await _frames(10)
	await _shot("06_solda")

	# 7) Esmerilhadeira mirando um bloco com corte reto
	player.select_tool(2)
	grinder.cut_index = 1
	var block := _nearest_part(Vector3(-18, 0, 6), Vector3(0.5, 0.5, 0.5))
	if block:
		player.global_position = block.global_position + Vector3(1.6, -block.global_position.y + 0.05, 1.6)
		_look_from_eye(block.global_position + Vector3(0, 0.05, 0))
		await _frames(10)
		await _shot("07_corte_reto")

	# 8) Os morros e uma pilha distante
	player.global_position = Vector3(0, 0.05, 60)
	_look_from_eye(Vector3(0, 8, 140))
	await _frames(20)
	await _shot("08_morros")

	get_tree().quit()


func _nearest_part(near: Vector3, size: Vector3) -> Part:
	var best: Part = null
	var best_d := INF
	for asm in world.get_children():
		if not asm is Assembly:
			continue
		for p: Part in asm.get_parts():
			if size != Vector3.ZERO and not p.bounds.size.is_equal_approx(size):
				continue
			var d := p.global_position.distance_to(near)
			if d < best_d:
				best_d = d
				best = p
	return best


func _look(feet: Vector3, target: Vector3) -> void:
	player.global_position = feet
	_look_from_eye(target)


func _look_from_eye(target: Vector3) -> void:
	var eye := player.global_position + Vector3(0, Player.EYE_HEIGHT, 0)
	var d := (target - eye).normalized()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = asin(clampf(d.y, -1, 1))
	player.velocity = Vector3.ZERO


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("screenshot: ", path)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

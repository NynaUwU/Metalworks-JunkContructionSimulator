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
	player.global_position = Vector3(8.6, 0.05, -4.4)
	_look_from_eye(Vector3(8.0, 1.11, -6.39))
	player.select_tool(1)
	await _frames(5)
	var welder: WeldTool = player.tools[1]
	welder.begin_use()
	for i in 40:
		await get_tree().physics_frame
	await _shot("q_weld_fog")
	assert(base != null and wall != null)


func _look_from_eye(target: Vector3) -> void:
	var eye := player.global_position + Vector3(0, Player.EYE_HEIGHT, 0)
	var d := (target - eye).normalized()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = asin(clampf(d.y, -1, 1))
	player.velocity = Vector3.ZERO


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))
	print("screenshot: ", shot_name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

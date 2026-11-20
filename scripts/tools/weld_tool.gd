class_name WeldTool
extends GameTool
## Máquina de solda: cria um ponto de solda onde duas peças estão encostadas/próximas.
## Mire na emenda entre duas peças (ou entre a peça e o chão) e clique.

var _marker: MeshInstance3D
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D
var _can_weld := false


func _init(p_player: Player) -> void:
	super(p_player)
	tool_name = "Solda"
	key_hint = "2"


func _ready() -> void:
	super()
	_marker = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	_marker.mesh = sm
	_ok_mat = glow_material(Color(0.3, 1.0, 0.45), 1.5)
	_ok_mat.no_depth_test = true
	_ok_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ok_mat.albedo_color.a = 0.75
	_bad_mat = glow_material(Color(1.0, 0.3, 0.25), 1.0)
	_bad_mat.no_depth_test = true
	_bad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bad_mat.albedo_color.a = 0.5
	_marker.top_level = true
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)


func _build_viewmodel() -> void:
	var handle := make_cylinder(0.035, 0.22, Color(0.15, 0.15, 0.16), 0.1, 0.8)
	handle.rotation.x = deg_to_rad(90)
	viewmodel.add_child(handle)
	var head := make_box(Vector3(0.07, 0.07, 0.12), Color(0.85, 0.55, 0.1), 0.4, 0.5)
	head.position = Vector3(0, 0, -0.15)
	viewmodel.add_child(head)
	var nozzle := make_cylinder(0.018, 0.14, Color(0.72, 0.5, 0.3), 0.9, 0.35)
	nozzle.rotation.x = deg_to_rad(110)
	nozzle.position = Vector3(0, -0.02, -0.26)
	viewmodel.add_child(nozzle)
	muzzle.position = Vector3(0, -0.045, -0.33)


func unequip() -> void:
	_marker.visible = false
	super()


func physics_update(_delta: float) -> void:
	var part := player.aim_part()
	if part == null:
		_marker.visible = false
		_can_weld = false
		return
	var point: Vector3 = player.aim["position"]
	_can_weld = Build.find_weld_target(part, point)["ok"]
	_marker.visible = true
	_marker.global_position = point
	_marker.material_override = _ok_mat if _can_weld else _bad_mat


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("primary"):
		var part := player.aim_part()
		if part == null:
			return true
		var point: Vector3 = player.aim["position"]
		if Build.weld_at(part, point):
			spawn_sparks(point, player.aim["normal"], 45)
		return true
	return false


func hint_text() -> String:
	if player.aim_part() == null:
		return "Mire em uma peça encostada em outra (ou no chão)"
	if _can_weld:
		return "Clique: soldar aqui"
	return "Nada perto deste ponto — mire na emenda entre as peças"

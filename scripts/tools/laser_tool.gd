class_name LaserTool
extends GameTool
## Ponteiro laser: segure o clique para apontar. Acende os receptores de laser que acertar
## (para portas com senha de luz, alvos, gatilhos...).

var _beam: MeshInstance3D
var _dot: MeshInstance3D
var firing := false


func _init(p_player: Player) -> void:
	super(p_player)
	tool_name = "Laser"
	key_hint = "8"


func _ready() -> void:
	super()
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.004
	cm.bottom_radius = 0.004
	cm.height = 1.0
	cm.radial_segments = 6
	_beam.mesh = cm
	_beam.material_override = glow_material(Color(1.0, 0.15, 0.1), 4.0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)
	_dot = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.015
	sm.height = 0.03
	_dot.mesh = sm
	_dot.material_override = glow_material(Color(1.0, 0.2, 0.15), 6.0)
	_dot.top_level = true
	_dot.visible = false
	add_child(_dot)


func _build_viewmodel() -> void:
	var body := make_cylinder(0.025, 0.2, Color(0.15, 0.15, 0.16), 0.3, 0.6)
	body.rotation.x = deg_to_rad(90)
	viewmodel.add_child(body)
	var tip := make_cylinder(0.012, 0.03, Color(0.9, 0.2, 0.15), 0.2, 0.3)
	tip.rotation.x = deg_to_rad(90)
	tip.position = Vector3(0, 0, -0.11)
	viewmodel.add_child(tip)
	muzzle.position = Vector3(0, 0, -0.13)


func unequip() -> void:
	firing = false
	_beam.visible = false
	_dot.visible = false
	super()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("primary"):
		firing = true
		return true
	if event.is_action_released("primary"):
		firing = false
		return true
	return false


func physics_update(_delta: float) -> void:
	if not firing:
		_beam.visible = false
		_dot.visible = false
		return
	var from := muzzle.global_position
	var to: Vector3 = player.aim["position"] if not player.aim.is_empty() else player.eye_position() + player.aim_direction() * player.REACH
	var part := player.aim_part()
	if part:
		SensorNode.laser_hit(part)
	var d := from.distance_to(to)
	_beam.visible = d > 0.01
	if _beam.visible:
		var dir := (to - from) / d
		var x := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
		_beam.global_transform = Transform3D(Basis(x, dir, x.cross(dir)), (from + to) * 0.5)
		_beam.scale = Vector3(1, d, 1)
	_dot.visible = not player.aim.is_empty()
	_dot.global_position = to


func hint_text() -> String:
	var part := player.aim_part()
	if part and part.node is SensorNode and (part.node as SensorNode).kind == "receptor":
		return "Segure o clique: acender o receptor de laser"
	return "Segure o clique: apontar o laser (acende receptores de laser)"

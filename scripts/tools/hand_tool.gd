class_name HandTool
extends GameTool
## Mão / "arma de física".
##
## - Clique esquerdo segurado: pega a peça mirada; ela flutua e segue a mira.
## - Soltar o clique: a peça FICA flutuando no lugar.
## - Ela só volta a ter gravidade ao apertar E ou ao pegar outra peça.
## - Shift + W/S/A/D/Q/E: gira a peça em passos de 15°.  T: alinha à grade.
## - Roda do mouse: aproxima/afasta.  Delete: apaga a peça mirada.

const ROT_STEP := deg_to_rad(15.0)
const ROT_REPEAT_DELAY := 0.28
const ROT_REPEAT_RATE := 0.09
const MIN_DIST := 1.2
const MAX_DIST := 18.0

var hold_part: Part = null
var grab_local := Vector3.ZERO     ## ponto de pega (coordenadas da peça)
var hold_basis := Basis()          ## orientação desejada da peça (mundo)
var hold_target := Transform3D()
var hold_distance := 3.0
var holding := false               ## botão pressionado agora

var _rot_timers := {}
var _excepted: Assembly = null
var _beam: MeshInstance3D
var _glow: MeshInstance3D


func _init(p_player: Player) -> void:
	super(p_player)
	tool_name = "Mão"
	key_hint = "1"


func _ready() -> void:
	super()
	Build.part_replaced.connect(_on_part_replaced)
	Build.part_removed.connect(_on_part_removed)
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
	_beam.mesh = cm
	_beam.material_override = glow_material(Color(0.35, 0.8, 1.0), 3.0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)


func _build_viewmodel() -> void:
	var body := make_box(Vector3(0.09, 0.11, 0.34), Color(0.2, 0.22, 0.26), 0.7, 0.4)
	viewmodel.add_child(body)
	var grip := make_box(Vector3(0.06, 0.16, 0.08), Color(0.12, 0.12, 0.13), 0.1, 0.8)
	grip.position = Vector3(0, -0.11, 0.08)
	grip.rotation.x = deg_to_rad(-15)
	viewmodel.add_child(grip)
	var barrel := make_cylinder(0.035, 0.18, Color(0.5, 0.52, 0.56), 0.9, 0.3)
	barrel.rotation.x = deg_to_rad(90)
	barrel.position = Vector3(0, 0.01, -0.24)
	viewmodel.add_child(barrel)
	_glow = MeshInstance3D.new()
	var tip := SphereMesh.new()
	tip.radius = 0.03
	tip.height = 0.06
	_glow.mesh = tip
	_glow.material_override = glow_material(Color(0.35, 0.8, 1.0), 2.0)
	_glow.position = Vector3(0, 0.01, -0.34)
	viewmodel.add_child(_glow)
	muzzle.position = Vector3(0, 0.01, -0.35)


func unequip() -> void:
	# Trocar de ferramenta não derruba a peça: ela continua flutuando.
	holding = false
	_set_player_exception(null)
	super()


func blocks_movement() -> bool:
	return holding and Input.is_action_pressed("modifier")


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("primary"):
		_grab()
		return true
	if event.is_action_released("primary"):
		holding = false
		return true
	if event.is_action_pressed("release") and not blocks_movement():
		release()
		return true
	if holding and event.is_action_pressed("wheel_up"):
		hold_distance = clampf(hold_distance + 0.4, MIN_DIST, MAX_DIST)
		return true
	if holding and event.is_action_pressed("wheel_down"):
		hold_distance = clampf(hold_distance - 0.4, MIN_DIST, MAX_DIST)
		return true
	if event.is_action_pressed("align") and hold_part:
		hold_basis = ConvexGeo.snap_basis(hold_basis)
		return true
	if event.is_action_pressed("delete_part") and not holding:
		var part := player.aim_part()
		if part:
			Build.delete_part(part)
			player.toast("Peça removida")
		return true
	return false


func _grab() -> void:
	var part := player.aim_part()
	if part == null:
		return
	var asm := part.assembly()
	if asm.anchored:
		player.toast("Está soldada no chão — use a esmerilhadeira (botão direito) na solda do chão")
		return
	if hold_part and is_instance_valid(hold_part) and hold_part.assembly() != asm:
		release()
	elif hold_part and is_instance_valid(hold_part):
		asm.clear_hold()
	var hit_pos: Vector3 = player.aim["position"]
	hold_part = part
	grab_local = part.global_transform.affine_inverse() * hit_pos
	hold_basis = part.global_transform.basis.orthonormalized()
	hold_distance = clampf(player.eye_position().distance_to(hit_pos), MIN_DIST, MAX_DIST)
	holding = true
	_rot_timers.clear()
	_update_target()


## Devolve a física (gravidade) à peça que estava flutuando.
func release() -> void:
	if hold_part and is_instance_valid(hold_part):
		var asm := hold_part.assembly()
		if asm:
			asm.clear_hold()
			asm.sleeping = false
	hold_part = null
	holding = false
	_set_player_exception(null)


func physics_update(delta: float) -> void:
	_tick_hold(delta)


## Chamado sempre (mesmo com outra ferramenta na mão), para manter a peça flutuando.
func _tick_hold(delta: float) -> void:
	if hold_part == null:
		return
	if not is_instance_valid(hold_part) or not hold_part.is_inside_tree():
		hold_part = null
		holding = false
		_set_player_exception(null)
		return
	var asm := hold_part.assembly()
	if asm == null or asm.anchored:
		release()
		return
	if holding:
		if Input.is_action_pressed("modifier"):
			_rotation_keys(delta)
		_update_target()
	asm.set_hold(hold_part, grab_local, hold_target)
	_set_player_exception(asm if holding else null)


func _update_target() -> void:
	var grab_world := player.eye_position() + player.aim_direction() * hold_distance
	hold_target = Transform3D(hold_basis, grab_world - hold_basis * grab_local)


func _rotation_keys(delta: float) -> void:
	var cam := player.aim_basis()
	var right := ConvexGeo.snap_axis(Vector3(cam.x.x, 0, cam.x.z))
	var fwd := ConvexGeo.snap_axis(Vector3(-cam.z.x, 0, -cam.z.z))
	var rotations := {
		"move_forward": [right, -ROT_STEP],
		"move_back": [right, ROT_STEP],
		"move_left": [Vector3.UP, ROT_STEP],
		"move_right": [Vector3.UP, -ROT_STEP],
		"roll_left": [fwd, -ROT_STEP],
		"roll_right": [fwd, ROT_STEP],
	}
	for action: String in rotations:
		if not Input.is_action_pressed(action):
			_rot_timers.erase(action)
			continue
		var fire := false
		if not _rot_timers.has(action):
			_rot_timers[action] = ROT_REPEAT_DELAY
			fire = true
		else:
			_rot_timers[action] -= delta
			if _rot_timers[action] <= 0.0:
				_rot_timers[action] = ROT_REPEAT_RATE
				fire = true
		if fire:
			var axis: Vector3 = rotations[action][0]
			var angle: float = rotations[action][1]
			hold_basis = (Basis(axis, angle) * hold_basis).orthonormalized()


func _set_player_exception(asm: Assembly) -> void:
	if _excepted == asm:
		return
	if _excepted and is_instance_valid(_excepted):
		player.remove_collision_exception_with(_excepted)
		_excepted.remove_collision_exception_with(player)
	_excepted = asm
	if asm:
		player.add_collision_exception_with(asm)
		asm.add_collision_exception_with(player)


func _process(_delta: float) -> void:
	var show := visible and holding and hold_part != null and is_instance_valid(hold_part)
	_beam.visible = show
	_glow.scale = Vector3.ONE * (1.6 if show else 1.0)
	if not show:
		return
	var a := muzzle.global_position
	var b := hold_part.get_global_transform_interpolated() * grab_local
	var d := b - a
	var length := d.length()
	if length < 0.01:
		_beam.visible = false
		return
	var y := d / length
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 1e-6:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	_beam.global_transform = Transform3D(Basis(x, y, z).scaled_local(Vector3(1, length, 1)), (a + b) * 0.5)


func _on_part_replaced(old_part: Part, pieces: Array, cut_local: Plane) -> void:
	if old_part != hold_part:
		return
	# Continua segurando o pedaço onde estava o ponto de pega.
	hold_part = pieces[0] if cut_local.distance_to(grab_local) <= 0.0 else pieces[1]


func _on_part_removed(part: Part) -> void:
	if part == hold_part:
		hold_part = null
		holding = false
		_set_player_exception(null)


func hint_text() -> String:
	if holding:
		return "Shift + W/S/A/D/Q/E: girar   ·   T: alinhar à grade   ·   Roda: distância"
	if hold_part:
		return "Peça flutuando   ·   E: soltar (volta a gravidade)   ·   Clique: pegar outra"
	return "Clique: pegar peça   ·   Delete: apagar peça mirada"

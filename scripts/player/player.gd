class_name Player
extends CharacterBody3D
## Jogador em primeira pessoa.
## WASD anda, toque duplo numa tecla de andar (ou Shift) corre, Espaço pula.

const WALK_SPEED := 4.6
const RUN_SPEED := 8.5
const JUMP_VELOCITY := 5.2
const GROUND_ACCEL := 14.0
const AIR_ACCEL := 3.0
const REACH := 14.0
const DOUBLE_TAP_TIME := 0.3
const EYE_HEIGHT := 1.62
const PUSH_FORCE := 45.0

signal tool_changed(index: int)
signal toast_requested(text: String)

var yaw := 0.0
var pitch := 0.0
var running := false
var spawn_point := Vector3(0, 1.5, 6)

var head: Node3D
var camera: Camera3D
var tools: Array[GameTool] = []
var hand: HandTool
var current_tool := 0
var aim: Dictionary = {}          ## resultado do raycast da mira (vazio se nada)

var _last_tap := {}
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _init() -> void:
	name = "Player"
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.PARTS
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_HEIGHT
	add_child(head)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.top_level = true
	camera.fov = 75.0
	camera.near = 0.03
	camera.far = 900.0
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)


func _ready() -> void:
	hand = HandTool.new(self)
	tools = [hand, WeldTool.new(self), GrinderTool.new(self)]
	for t in tools:
		camera.add_child(t)
	select_tool(0)
	global_position = spawn_point
	_sync_camera()


func select_tool(index: int) -> void:
	if index < 0 or index >= tools.size():
		return
	if tools.size() > current_tool:
		tools[current_tool].unequip()
	current_tool = index
	tools[current_tool].equip()
	tool_changed.emit(index)


func current() -> GameTool:
	return tools[current_tool]


func toast(text: String) -> void:
	toast_requested.emit(text)


# --- Mira ----------------------------------------------------------------------

func aim_basis() -> Basis:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0))


func aim_direction() -> Vector3:
	return -aim_basis().z


func eye_position() -> Vector3:
	return head.global_position


func aim_part() -> Part:
	if aim.is_empty():
		return null
	return Build.part_from_collision(aim["collider"], aim["shape"])


func _update_aim() -> void:
	var from := eye_position()
	var to := from + aim_direction() * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.AIM, [get_rid()])
	aim = get_world_3d().direct_space_state.intersect_ray(q)


# --- Entrada -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var sens := Settings.mouse_sensitivity
		yaw -= motion.relative.x * sens
		pitch = clampf(pitch - motion.relative.y * sens, deg_to_rad(-89), deg_to_rad(89))
		return
	for i in tools.size():
		if event.is_action_pressed("tool_%d" % (i + 1)):
			select_tool(i)
			get_viewport().set_input_as_handled()
			return
	if current().handle_input(event):
		get_viewport().set_input_as_handled()
		return
	# E solta a peça flutuando com qualquer ferramenta na mão.
	if event.is_action_pressed("release") and not current().blocks_movement():
		hand.release()
		get_viewport().set_input_as_handled()
		return
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		if event.is_action_pressed(action) and not event.is_echo():
			var now := Time.get_ticks_msec() / 1000.0
			if now - float(_last_tap.get(action, -10.0)) < DOUBLE_TAP_TIME:
				running = true
			_last_tap[action] = now


# --- Física --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	rotation.y = yaw
	head.rotation.x = pitch
	_update_aim()

	hand.physics_update(delta)
	if current() != hand:
		current().physics_update(delta)

	var input := Vector2.ZERO
	if not current().blocks_movement() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input == Vector2.ZERO:
		running = false
	var shift_run := Input.is_action_pressed("modifier") and not (hand.holding and current() == hand)
	var speed := RUN_SPEED if (running or shift_run) else WALK_SPEED
	var dir := (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y))
	var target := dir * speed

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		velocity.y = JUMP_VELOCITY

	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	var horizontal := Vector3(velocity.x, 0, velocity.z).lerp(target, clampf(accel * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	_push_bodies(delta)

	if global_position.y < -60.0:
		global_position = spawn_point
		velocity = Vector3.ZERO


func _push_bodies(delta: float) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider() as Assembly
		if body == null or body.freeze or body.is_held():
			continue
		var push := -c.get_normal()
		push.y = 0.0
		if push.length_squared() < 0.01:
			continue
		body.apply_impulse(push.normalized() * PUSH_FORCE * delta, c.get_position() - body.global_position)


func _process(_delta: float) -> void:
	_sync_camera()


func _sync_camera() -> void:
	var origin := head.get_global_transform_interpolated().origin if is_inside_tree() else head.position
	camera.global_transform = Transform3D(aim_basis(), origin)

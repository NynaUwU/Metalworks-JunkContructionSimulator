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
signal interact_requested(target: Node)
signal seat_changed(seated: bool)
signal edit_requested

const INTERACT_DISTANCE := 3.5
const SEAT_EYE := Vector3(0, 0.92, 0.04)   ## olhos em relação à base do assento

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
var seat: Part = null             ## assento em que está sentado
var _using: ControlDevice = null  ## botão sendo segurado
var _ghost_frames := 0            ## quadros sem colisão depois de um teleporte

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
	tools = [hand, WeldTool.new(self), GrinderTool.new(self), WireTool.new(self)]
	for t in tools:
		camera.add_child(t)
	select_tool(0)
	teleport(spawn_point)
	_sync_camera()


func select_tool(index: int) -> void:
	if index < 0 or index >= tools.size() or seat:
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
	var look := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	if is_seated():
		return seat.global_basis.orthonormalized() * look
	return look


func is_seated() -> bool:
	return seat != null and is_instance_valid(seat) and seat.is_inside_tree()


func aim_direction() -> Vector3:
	return -aim_basis().z


func eye_position() -> Vector3:
	if is_seated():
		return seat.global_transform * SEAT_EYE
	return head.global_position


func aim_part() -> Part:
	if aim.is_empty():
		return null
	return Build.part_from_collision(aim["collider"], aim["shape"])


## Objeto "usável" na mira (terminal da loja, futuramente assentos...).
func interact_target() -> Node:
	if aim.is_empty():
		return null
	if eye_position().distance_to(aim["position"]) > INTERACT_DISTANCE:
		return null
	var c: Object = aim["collider"]
	if c is Node and (c as Node).has_meta("interact"):
		return c
	var part := aim_part()
	if part and part.interact_kind != "":
		return part
	return null


## Texto da ação de "usar" o que está na mira (para o HUD).
func interact_hint() -> String:
	var t := interact_target()
	if t == null:
		return ""
	var key := "Clique" if is_seated() else "F"
	if t is Part:
		var part := t as Part
		if part.device:
			return "%s: %s" % [key, part.device.hint()]
		if part.interact_kind == "assento" and not is_seated():
			return "F: sentar"
		return ""
	return "F: %s" % t.get_meta("interact_label", "usar")


# --- Assento -------------------------------------------------------------------

func sit(p_seat: Part) -> void:
	if is_seated():
		return
	seat = p_seat
	_release_device()
	current().unequip()
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	yaw = 0.0
	pitch = deg_to_rad(-8.0)
	Build.active_seat = seat
	seat_changed.emit(true)
	toast("Sentado · Tab: modo edição (teclas) · F: levantar")


func stand_up() -> void:
	if seat == null:
		return
	var out := global_position
	var look_yaw := yaw
	if is_instance_valid(seat) and seat.is_inside_tree():
		var b := seat.global_basis.orthonormalized()
		out = _free_spot_near(seat)
		var fwd := b * Basis.from_euler(Vector3(0, yaw, 0)) * Vector3.FORWARD
		look_yaw = atan2(-fwd.x, -fwd.z)
	seat = null
	Build.active_seat = null
	teleport(out)
	yaw = look_yaw
	pitch = 0.0
	velocity = Vector3.ZERO
	current().equip()
	seat_changed.emit(false)


## Lugar livre (sem encostar em peças) em volta do assento para descer.
func _free_spot_near(p_seat: Part) -> Vector3:
	var b := p_seat.global_basis.orthonormalized()
	var flat_x := Vector3(b.x.x, 0, b.x.z).normalized()
	var flat_z := Vector3(b.z.x, 0, b.z.z).normalized()
	var base := p_seat.global_position
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = capsule
	params.collision_mask = Layers.WORLD | Layers.PARTS
	var space := get_world_3d().direct_space_state
	for dist: float in [1.4, 2.2, 3.2]:
		for dir: Vector3 in [flat_x, -flat_x, flat_z, -flat_z]:
			var feet := base + dir * dist
			# Apoia no chão logo abaixo (se houver)
			var down := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 1.5, feet + Vector3.DOWN * 3.0, Layers.WORLD | Layers.PARTS)
			var hit := space.intersect_ray(down)
			if not hit.is_empty():
				feet.y = (hit["position"] as Vector3).y + 0.02
			params.transform = Transform3D(Basis(), feet + Vector3.UP * 0.92)
			if space.intersect_shape(params, 1).is_empty():
				return feet
	return base + Vector3.UP * 1.6   # sem espaço: sai por cima


## Move o jogador sem "varrer" o caminho. (O Jolt empurra tudo que um corpo
## cinemático atravessa ao ser movido; por isso a colisão fica desligada por 2 quadros.)
func teleport(pos: Vector3) -> void:
	collision_layer = 0
	collision_mask = 0
	global_position = pos
	velocity = Vector3.ZERO
	_ghost_frames = 2


# --- Controles (botões, alavancas) ---------------------------------------------

## Tecla F: usar o que está na mira (controle, assento, terminal) ou levantar.
func use_interact() -> void:
	if is_seated():
		stand_up()
		return
	if _use_device_press():
		return
	var target := interact_target()
	if target is Part and (target as Part).interact_kind == "assento":
		var base: Part = (target as Part).get_meta("seat_base", target)
		sit(base if is_instance_valid(base) else target)
	elif target:
		interact_requested.emit(target)


func _use_device_press() -> bool:
	var t := interact_target()
	if t is Part and (t as Part).device:
		_using = (t as Part).device
		_using.press()
		return true
	return false


func _release_device() -> void:
	if _using:
		_using.release()
		_using = null


func _scroll_device(steps: int) -> bool:
	var t := interact_target()
	if t is Part and (t as Part).device:
		return (t as Part).device.scroll(steps)
	return false


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
		if is_seated():
			yaw = clampf(yaw, deg_to_rad(-160), deg_to_rad(160))
		return
	if is_seated():
		_seated_input(event)
		return
	if event.is_action_released("interact"):
		_release_device()
	for i in tools.size():
		if event.is_action_pressed("tool_%d" % (i + 1)):
			select_tool(i)
			get_viewport().set_input_as_handled()
			return
	if current().handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		use_interact()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("wheel_up") and _scroll_device(1):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("wheel_down") and _scroll_device(-1):
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

## Sentado: F levanta, Tab abre o modo edição, clique usa botões/alavancas.
func _seated_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		use_interact()
	elif event.is_action_pressed("seat_edit"):
		edit_requested.emit()
	elif event.is_action_pressed("primary"):
		_use_device_press()
	elif event.is_action_released("primary"):
		_release_device()
	elif event.is_action_pressed("wheel_up"):
		_scroll_device(1)
	elif event.is_action_pressed("wheel_down"):
		_scroll_device(-1)
	else:
		return
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if seat != null:
		if not is_seated():
			stand_up()   # o assento foi reciclado ou destruído
		else:
			# Acompanha o assento (a cápsula fica desligada enquanto sentado).
			global_position = eye_position() - Vector3(0, EYE_HEIGHT, 0)
			velocity = Vector3.ZERO
			_update_aim()
			hand.physics_update(delta)
			return
	rotation.y = yaw
	head.rotation.x = pitch
	_update_aim()
	if _ghost_frames > 0:
		_ghost_frames -= 1
		if _ghost_frames == 0:
			collision_layer = Layers.PLAYER
			collision_mask = Layers.WORLD | Layers.PARTS
		return

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
		teleport(spawn_point)


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
	if is_seated():
		var st := seat.get_global_transform_interpolated()
		var look := Basis.from_euler(Vector3(pitch, yaw, 0.0))
		camera.global_transform = Transform3D(st.basis.orthonormalized() * look, st * SEAT_EYE)
		return
	var origin := head.get_global_transform_interpolated().origin if is_inside_tree() else head.position
	camera.global_transform = Transform3D(aim_basis(), origin)

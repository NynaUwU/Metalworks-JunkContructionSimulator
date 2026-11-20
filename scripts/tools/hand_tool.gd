class_name HandTool
extends GameTool
## Gravitador (no estilo da physics gun do Garry's Mod).
##
## - Clique segurado: pega a peça; ela segue a mira e gira junto com você.
## - Soltar o clique: a peça volta a ter física (dá para arremessar).
## - Botão direito (segurando): CONGELA a peça no lugar.
## - E + mover o mouse: gira a peça. Com Shift: em passos de 15°.
## - Roda do mouse: aproxima/afasta.  T: alinha à grade do mundo.
## - R mirando numa peça congelada: descongela (e o que estiver ligado por juntas).
## - R duas vezes rápido: descongela tudo.

const MIN_DIST := 1.2
const MAX_DIST := 30.0
const ROTATE_SENS := 0.006          ## rad por pixel
const SNAP := deg_to_rad(15.0)
const DOUBLE_TAP := 0.35

var hold_part: Part = null
var grab_local := Vector3.ZERO     ## ponto de pega (coordenadas da peça)
var rel_basis := Basis()           ## orientação da peça em relação ao "giro" do jogador
var hold_target := Transform3D()
var hold_distance := 3.0
var holding := false
var rotating := false              ## E segurado: o mouse gira a peça

var _snap_accum := Vector2.ZERO
var _last_r := -10.0
var _excepted: Assembly = null
var _beam: MeshInstance3D
var _glow: MeshInstance3D


func _init(p_player: Player) -> void:
	super(p_player)
	tool_name = "Gravitador"
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
	drop()
	super()


## Enquanto gira a peça (E), o movimento do mouse é da ferramenta, não da câmera.
func captures_mouse() -> bool:
	return holding and rotating


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if captures_mouse():
			_rotate_by((event as InputEventMouseMotion).relative)
			return true
		return false
	if event.is_action_pressed("primary"):
		grab()
		return true
	if event.is_action_released("primary"):
		drop()
		return true
	if holding and event.is_action_pressed("secondary"):
		freeze_held()
		return true
	if holding and event.is_action_pressed("interact"):
		rotating = true
		_snap_accum = Vector2.ZERO
		return true
	if event.is_action_released("interact") and rotating:
		rotating = false
		return true
	if holding and event.is_action_pressed("wheel_up"):
		hold_distance = clampf(hold_distance + 0.5, MIN_DIST, MAX_DIST)
		return true
	if holding and event.is_action_pressed("wheel_down"):
		hold_distance = clampf(hold_distance - 0.5, MIN_DIST, MAX_DIST)
		return true
	if holding and event.is_action_pressed("align"):
		_set_world_basis(ConvexGeo.snap_basis(_world_basis()))
		return true
	if event.is_action_pressed("rotate_cut") and not holding:   # R
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_r < DOUBLE_TAP:
			unfreeze_all()
			_last_r = -10.0
		else:
			unfreeze_aimed()
			_last_r = now
		return true
	return false


## Pega a peça mirada.
func grab() -> void:
	var part := player.aim_part()
	if part == null:
		return
	var asm := part.assembly()
	if asm.anchored:
		player.toast("Está soldada no chão: segure a esmerilhadeira na bolinha da solda do chão")
		return
	if asm.frozen:
		asm.set_frozen(false)
	var hit_pos: Vector3 = player.aim["position"]
	hold_part = part
	grab_local = part.global_transform.affine_inverse() * hit_pos
	_set_world_basis(part.global_transform.basis.orthonormalized())
	hold_distance = clampf(player.eye_position().distance_to(hit_pos), MIN_DIST, MAX_DIST)
	holding = true
	rotating = false
	_update_target()


## Solta: a peça volta a ter física e mantém a velocidade (arremesso).
func drop() -> void:
	if hold_part and is_instance_valid(hold_part):
		var asm := hold_part.assembly()
		if asm:
			asm.clear_hold()
			asm.sleeping = false
	hold_part = null
	holding = false
	rotating = false
	_set_player_exception(null)


## Botão direito: congela a peça segurada onde ela está.
func freeze_held() -> void:
	if hold_part == null or not is_instance_valid(hold_part):
		return
	var asm := hold_part.assembly()
	var where := hold_part.global_transform * grab_local
	drop()
	if asm:
		asm.set_frozen(true)
		spawn_sparks(where, Vector3.UP, 25, Color(0.4, 0.8, 1.0))
		player.toast("Congelada (R mirando nela para descongelar)")


## R: descongela a peça mirada e tudo o que estiver ligado a ela por juntas.
func unfreeze_aimed() -> void:
	var part := player.aim_part()
	if part == null:
		return
	var n := 0
	for asm in Build.connected_assemblies(part.assembly()):
		if asm.frozen:
			asm.set_frozen(false)
			n += 1
	if n > 0:
		spawn_sparks(player.aim["position"], Vector3.UP, 20, Color(0.4, 0.8, 1.0))
		player.toast("Descongelada" if n == 1 else "%d partes descongeladas" % n)


## R duas vezes: descongela tudo no mundo.
func unfreeze_all() -> void:
	var n := Build.unfreeze_all()
	player.toast("Nada congelado" if n == 0 else "%d objeto%s descongelado%s" % [n, "" if n == 1 else "s", "" if n == 1 else "s"])


func physics_update(_delta: float) -> void:
	if hold_part == null:
		return
	if not is_instance_valid(hold_part) or not hold_part.is_inside_tree():
		hold_part = null
		holding = false
		rotating = false
		_set_player_exception(null)
		return
	var asm := hold_part.assembly()
	if asm == null or asm.anchored or asm.frozen:
		drop()
		return
	_update_target()
	asm.set_hold(hold_part, grab_local, hold_target)
	_set_player_exception(asm)


# --- Orientação: a peça gira junto com o "giro" (yaw) do jogador ------------------

func _yaw_basis() -> Basis:
	var f := player.aim_direction()
	return Basis(Vector3.UP, atan2(-f.x, -f.z))


func _world_basis() -> Basis:
	return (_yaw_basis() * rel_basis).orthonormalized()


func _set_world_basis(b: Basis) -> void:
	rel_basis = (_yaw_basis().inverse() * b).orthonormalized()


func _rotate_by(rel: Vector2) -> void:
	var cam := player.aim_basis()
	var right := Vector3(cam.x.x, 0, cam.x.z).normalized()
	var delta := rel * ROTATE_SENS
	if Input.is_action_pressed("modifier"):
		# Shift: acumula e gira em passos de 15°.
		_snap_accum += delta
		delta = Vector2.ZERO
		for i in 2:
			while absf(_snap_accum[i]) >= SNAP:
				var s := signf(_snap_accum[i])
				delta[i] += s * SNAP
				_snap_accum[i] -= s * SNAP
	if delta == Vector2.ZERO:
		return
	var b := _world_basis()
	b = Basis(Vector3.UP, delta.x) * b
	b = Basis(right, delta.y) * b
	_set_world_basis(b)


func _update_target() -> void:
	var grab_world := player.eye_position() + player.aim_direction() * hold_distance
	var b := _world_basis()
	hold_target = Transform3D(b, grab_world - b * grab_local)


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
	hold_part = pieces[0] if cut_local.distance_to(grab_local) <= 0.0 else pieces[1]


func _on_part_removed(part: Part) -> void:
	if part == hold_part:
		hold_part = null
		holding = false
		rotating = false
		_set_player_exception(null)


func hint_text() -> String:
	if holding and rotating:
		return "Movendo o mouse: girar   ·   Shift: passos de 15°   ·   solte E para parar"
	if holding:
		return "Botão direito: congelar   ·   E + mouse: girar   ·   Roda: distância   ·   T: alinhar à grade"
	var part := player.aim_part()
	if part and part.assembly().frozen:
		return "Peça congelada   ·   R: descongelar   ·   R R: descongelar tudo   ·   Clique: pegar"
	return "Clique: pegar   ·   R: descongelar mirada   ·   R R: descongelar tudo"

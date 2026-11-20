class_name GrinderTool
extends GameTool
## Esmerilhadeira: corta peças e remove soldas. Tudo segurando o clique esquerdo.
##
## - O corte é feito na face que está na mira: a linha de corte fica sobre ela
##   (plano perpendicular à face) e R gira essa linha: 0°, 45°, 90°, 135°.
## - Ao clicar, o corte TRAVA no lugar; é preciso segurar até a barra encher.
##   Soltar antes cancela. O tempo depende do tamanho do corte.
## - Mirando numa bolinha de solda, segurar o clique remove a solda.
## - A posição do corte encaixa numa grade de 5 cm (segure Ctrl para corte livre).

enum Mode { IDLE, CUTTING, UNWELDING, REMOVING }

const GRID := 0.05
const WELD_PICK_RADIUS := 0.1      ## mirar a até 10 cm de uma bolinha = remover solda
const WELD_REMOVE_TIME := 0.6
const CUT_BASE_TIME := 0.4
const CUT_TIME_PER_M2 := 4.0
const CUT_MAX_TIME := 3.5
const LOST_AIM_GRACE := 0.25       ## tempo que a mira pode sair da peça sem cancelar

var angle_index := 0
var mode := Mode.IDLE
var elapsed := 0.0
var duration := 1.0

var _preview: MeshInstance3D
var _imesh: ImmediateMesh
var _fill_mat: StandardMaterial3D
var _line_mat: StandardMaterial3D
var _bad_fill_mat: StandardMaterial3D
var _bad_line_mat: StandardMaterial3D
var _lock_fill_mat: StandardMaterial3D
var _weld_marker: MeshInstance3D
var _disc: MeshInstance3D
var _sparks: CPUParticles3D
var _light: OmniLight3D

var _target_part: Part = null
var _target_valid := false
var _target_plane := Plane()
var _target_weld: Weld = null
var _lock_part: Part = null
var _lock_plane := Plane()
var _lock_weld: Weld = null
var _target_insulator: Part = null
var _lost_aim := 0.0
var _spark_point := Vector3.ZERO
var _spark_normal := Vector3.UP


func _init(p_player: Player) -> void:
	super(p_player)
	tool_name = "Esmerilhadeira"
	key_hint = "3"


func _ready() -> void:
	super()
	_imesh = ImmediateMesh.new()
	_preview = MeshInstance3D.new()
	_preview.mesh = _imesh
	_preview.top_level = true
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview)
	_fill_mat = _overlay_mat(Color(1.0, 0.55, 0.1, 0.28), true)
	_line_mat = _overlay_mat(Color(1.0, 0.75, 0.2), false)
	_bad_fill_mat = _overlay_mat(Color(1.0, 0.15, 0.1, 0.22), true)
	_bad_line_mat = _overlay_mat(Color(1.0, 0.25, 0.2), false)
	_lock_fill_mat = _overlay_mat(Color(1.0, 0.85, 0.3, 0.45), true)

	_weld_marker = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = Build.WELD_BALL_RADIUS * 1.6
	sm.height = Build.WELD_BALL_RADIUS * 3.2
	_weld_marker.mesh = sm
	var wm := glow_material(Color(1.0, 0.25, 0.2), 1.2)
	wm.no_depth_test = true
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color.a = 0.6
	_weld_marker.material_override = wm
	_weld_marker.top_level = true
	_weld_marker.visible = false
	add_child(_weld_marker)

	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.amount = 90
	_sparks.lifetime = 0.5
	_sparks.spread = 35.0
	_sparks.initial_velocity_min = 2.0
	_sparks.initial_velocity_max = 4.5
	_sparks.gravity = Vector3(0, -9.8, 0)
	var spark := BoxMesh.new()
	spark.size = Vector3(0.012, 0.012, 0.06)
	_sparks.mesh = spark
	_sparks.material_override = glow_material(Color(1.0, 0.6, 0.18), 5.0)
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks.top_level = true
	_sparks.local_coords = false
	add_child(_sparks)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.25)
	_light.omni_range = 2.5
	_light.top_level = true
	_light.visible = false
	add_child(_light)


func _overlay_mat(color: Color, fill: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.albedo_color = color
	if fill:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _build_viewmodel() -> void:
	var body := make_cylinder(0.045, 0.26, Color(0.1, 0.35, 0.65), 0.2, 0.6)
	body.rotation.x = deg_to_rad(90)
	viewmodel.add_child(body)
	var head := make_box(Vector3(0.09, 0.08, 0.1), Color(0.25, 0.26, 0.28), 0.8, 0.4)
	head.position = Vector3(0, 0, -0.16)
	viewmodel.add_child(head)
	_disc = make_cylinder(0.075, 0.008, Color(0.45, 0.42, 0.38), 0.3, 0.9)
	_disc.rotation.z = deg_to_rad(90)
	_disc.position = Vector3(-0.055, 0, -0.17)
	viewmodel.add_child(_disc)
	muzzle.position = Vector3(-0.06, -0.06, -0.2)


func unequip() -> void:
	cancel()
	_imesh.clear_surfaces()
	_weld_marker.visible = false
	super()


## Progresso da ação atual (0..1), ou -1 se nada está acontecendo. Usado pela mira.
func progress() -> float:
	return clampf(elapsed / duration, 0.0, 1.0) if mode != Mode.IDLE else -1.0


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("rotate_cut"):
		if mode == Mode.IDLE:
			angle_index = (angle_index + 1) % ConvexGeo.CUT_ANGLES.size()
			player.toast("Ângulo do corte: %d°" % roundi(ConvexGeo.CUT_ANGLES[angle_index]))
		return true
	if event.is_action_pressed("primary"):
		begin_use()
		return true
	if event.is_action_released("primary"):
		cancel()
		return true
	return false


## Começa a cortar (ou a remover a solda) no que está na mira.
func begin_use() -> void:
	if mode != Mode.IDLE:
		return
	elapsed = 0.0
	_lost_aim = 0.0
	if _target_insulator:
		mode = Mode.REMOVING
		_lock_part = _target_insulator
		duration = WELD_REMOVE_TIME
	elif _target_weld:
		mode = Mode.UNWELDING
		_lock_weld = _target_weld
		duration = WELD_REMOVE_TIME
	elif _target_part and _target_valid:
		mode = Mode.CUTTING
		_lock_part = _target_part
		_lock_plane = _target_plane
		duration = cut_time(_lock_part, _lock_plane)
	elif _target_part:
		player.toast("Muito perto da borda: mire mais para dentro da face")


## Solta o botão: cancela o que estava em andamento.
func cancel() -> void:
	mode = Mode.IDLE
	elapsed = 0.0
	_lock_part = null
	_lock_weld = null


## Tempo para cortar: cresce com a área do corte.
static func cut_time(part: Part, plane: Plane) -> float:
	var poly := ConvexGeo.cut_polygon(part.planes, plane)
	var area := 0.0
	for i in range(1, poly.size() - 1):
		area += (poly[i] - poly[0]).cross(poly[i + 1] - poly[0]).length() * 0.5
	return clampf(CUT_BASE_TIME + area * CUT_TIME_PER_M2, CUT_BASE_TIME, CUT_MAX_TIME)


func physics_update(delta: float) -> void:
	_imesh.clear_surfaces()
	_weld_marker.visible = false
	if mode == Mode.IDLE:
		_update_targets()
		return
	_update_action(delta)


func _update_targets() -> void:
	_target_part = null
	_target_weld = null
	_target_insulator = null
	if player.aim.is_empty():
		return
	var point: Vector3 = player.aim["position"]
	var aimed := player.aim_part()
	if aimed and aimed.kind == "isolador":
		_target_insulator = aimed
		return

	# Mirando numa bolinha de solda: o clique remove a solda.
	_target_weld = Build.nearest_weld(point, WELD_PICK_RADIUS)
	if _target_weld:
		_weld_marker.visible = true
		_weld_marker.global_position = _target_weld.world_pos()
		return

	var part := player.aim_part()
	if part == null or not part.cuttable:
		return
	var inv := part.global_transform.affine_inverse()
	var local := inv * point
	var face_n := ConvexGeo.closest_face_normal(part.planes, (inv.basis * (player.aim["normal"] as Vector3)).normalized())
	if not Input.is_action_pressed("free_cut"):
		local = local.snapped(Vector3.ONE * GRID)
	var n := ConvexGeo.face_cut_normal(face_n, ConvexGeo.CUT_ANGLES[angle_index])
	_target_plane = Plane(n, n.dot(local))
	_target_part = part
	_target_valid = _cut_is_valid(part, _target_plane)
	_draw_preview(part, _target_plane, _fill_mat if _target_valid else _bad_fill_mat, _line_mat if _target_valid else _bad_line_mat)


func _update_action(delta: float) -> void:
	# A mira precisa continuar no alvo (com uma pequena tolerância).
	var on_target := false
	if mode == Mode.REMOVING:
		if not is_instance_valid(_lock_part) or not _lock_part.is_inside_tree():
			cancel()
			return
		on_target = player.aim_part() == _lock_part
	elif mode == Mode.CUTTING:
		if not is_instance_valid(_lock_part) or not _lock_part.is_inside_tree():
			cancel()
			return
		on_target = player.aim_part() == _lock_part
		_draw_preview(_lock_part, _lock_plane, _lock_fill_mat, _line_mat)
	else:
		if _lock_weld == null or not Build.welds.has(_lock_weld):
			cancel()
			return
		on_target = not player.aim.is_empty() and (player.aim["position"] as Vector3).distance_to(_lock_weld.world_pos()) < 0.35
		_weld_marker.visible = true
		_weld_marker.global_position = _lock_weld.world_pos()
	if not on_target:
		_lost_aim += delta
		if _lost_aim > LOST_AIM_GRACE:
			cancel()
		return
	_lost_aim = 0.0
	_spark_point = player.aim["position"]
	_spark_normal = player.aim["normal"]
	elapsed += delta
	if elapsed >= duration:
		_finish()


func _finish() -> void:
	if mode == Mode.CUTTING:
		var pieces := Build.cut_part(_lock_part, _lock_plane)
		if not pieces.is_empty():
			spawn_sparks(_spark_point, _spark_normal, 70)
	elif mode == Mode.REMOVING:
		var pos := _lock_part.global_position
		Build.delete_part(_lock_part)
		spawn_sparks(pos, Vector3.UP, 25)
		player.toast("Isolador removido")
	elif mode == Mode.UNWELDING:
		var pos := _lock_weld.world_pos()
		Build.remove_weld(_lock_weld)
		spawn_sparks(pos, Vector3.UP, 30)
		player.toast("Solda removida")
	cancel()


## O plano precisa passar por dentro da peça, deixando os dois lados com espessura.
func _cut_is_valid(part: Part, plane: Plane) -> bool:
	var pts: PackedVector3Array = (part.shape as ConvexPolygonShape3D).points
	var lo := INF
	var hi := -INF
	for v in pts:
		var d := plane.normal.dot(v)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return plane.d > lo + Build.MIN_PIECE_THICKNESS and plane.d < hi - Build.MIN_PIECE_THICKNESS


func _draw_preview(part: Part, plane: Plane, fill: Material, line: Material) -> void:
	var poly := ConvexGeo.cut_polygon(part.planes, plane)
	if poly.size() < 3:
		if part == _target_part:
			_target_part = null
		return
	var xf := part.global_transform
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, fill)
	for i in range(1, poly.size() - 1):
		_imesh.surface_add_vertex(xf * poly[0])
		_imesh.surface_add_vertex(xf * poly[i])
		_imesh.surface_add_vertex(xf * poly[i + 1])
	_imesh.surface_end()
	_imesh.surface_begin(Mesh.PRIMITIVE_LINES, line)
	for i in poly.size():
		_imesh.surface_add_vertex(xf * poly[i])
		_imesh.surface_add_vertex(xf * poly[(i + 1) % poly.size()])
	_imesh.surface_end()


func _process(delta: float) -> void:
	var working := visible and mode != Mode.IDLE and _lost_aim == 0.0 and elapsed > 0.0
	_sparks.emitting = working
	_light.visible = working
	if _disc:
		_disc.rotate_object_local(Vector3.UP, delta * (60.0 if mode != Mode.IDLE else 25.0))
	if working:
		var away := (_spark_normal + player.aim_basis().x * 0.6).normalized()
		_sparks.global_position = _spark_point
		_sparks.direction = away
		_light.global_position = _spark_point + _spark_normal * 0.2
		_light.light_energy = randf_range(1.5, 3.0)
		viewmodel.position = VIEW_POS + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.004
	elif viewmodel:
		viewmodel.position = VIEW_POS


func hint_text() -> String:
	if mode == Mode.CUTTING:
		return "Cortando… segure até completar (soltar cancela)"
	if mode == Mode.UNWELDING:
		return "Removendo a solda… segure até completar (soltar cancela)"
	if mode == Mode.REMOVING:
		return "Arrancando o isolador… segure até completar"
	if _target_insulator:
		return "Segure o clique para arrancar este isolador"
	if _target_weld:
		return "Segure o clique para remover esta solda"
	if _target_part and not _target_valid:
		return "Muito perto da borda (vermelho): mire mais para dentro da face   ·   R: girar o corte"
	return "Segure o clique para cortar a face mirada · ângulo %d°   ·   R: girar   ·   Ctrl: livre" \
		% roundi(ConvexGeo.CUT_ANGLES[angle_index])

class_name WeldTool
extends GameTool
## Máquina de solda.
##
## - Segure o clique na emenda entre duas peças (ou entre a peça e o chão).
## - A solda só alcança o que está dentro da bolinha: mire bem na emenda.
## - Segurando e arrastando, novos pontos nascem onde ainda não há bolinha.
## - Enquanto solda, a tela escurece como numa máscara de solda (ver Hud).

const FIRST_DELAY := 0.18     ## tempo segurando até o primeiro ponto
const INTERVAL := 0.08        ## intervalo mínimo entre pontos

var active := false           ## botão segurado
var _held := 0.0
var _since_last := 0.0
var _count := 0
var _arc := false
var _arc_point := Vector3.ZERO
var _arc_normal := Vector3.UP

var _marker: MeshInstance3D
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D
var _taken_mat: StandardMaterial3D
var _state := ""              ## "ok", "taken", "none" ou "" (sem peça)
var _light: OmniLight3D
var _sparks: CPUParticles3D
var _core: MeshInstance3D


func _init(p_player: Player) -> void:
	super(p_player)
	tool_name = "Solda"
	key_hint = "2"


func _ready() -> void:
	super()
	_marker = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = Build.WELD_BALL_RADIUS
	sm.height = Build.WELD_BALL_RADIUS * 2.0
	_marker.mesh = sm
	_ok_mat = _marker_mat(Color(0.3, 1.0, 0.45), 0.75)
	_bad_mat = _marker_mat(Color(1.0, 0.3, 0.25), 0.5)
	_taken_mat = _marker_mat(Color(1.0, 0.8, 0.2), 0.5)
	_marker.top_level = true
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.92, 0.75)
	_light.omni_range = 4.5
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.top_level = true
	add_child(_light)

	# Faíscas estrela brancas espalhando em volta do ponto (como no original)
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.amount = 40
	_sparks.lifetime = 0.7
	_sparks.direction = Vector3.UP
	_sparks.spread = 180.0
	_sparks.initial_velocity_min = 0.6
	_sparks.initial_velocity_max = 2.2
	_sparks.gravity = Vector3(0, -2.5, 0)
	_sparks.damping_min = 1.0
	_sparks.damping_max = 2.0
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.3
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	_sparks.scale_amount_curve = shrink
	var spark := QuadMesh.new()
	spark.size = Vector2(0.09, 0.09)
	_sparks.mesh = spark
	_sparks.material_override = star_material(Color(1.0, 0.97, 0.9))

	# Núcleo amarelo do arco
	_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.028
	core_mesh.height = 0.056
	_core.mesh = core_mesh
	var core_mat := glow_material(Color(1.0, 0.95, 0.25), 6.0)
	core_mat.disable_fog = true
	_core.material_override = core_mat
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core.top_level = true
	_core.visible = false
	add_child(_core)
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks.top_level = true
	_sparks.local_coords = false
	add_child(_sparks)


func _marker_mat(color: Color, alpha: float) -> StandardMaterial3D:
	var m := glow_material(color, 1.2)
	m.no_depth_test = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = alpha
	return m


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
	_stop()
	_marker.visible = false
	super()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("primary"):
		begin_use()
		return true
	if event.is_action_released("primary"):
		_stop()
		return true
	return false


func begin_use() -> void:
	active = true
	_held = 0.0
	_since_last = INTERVAL
	_count = 0


func _stop() -> void:
	if active and _count > 0:
		player.toast("%d ponto%s de solda" % [_count, "" if _count == 1 else "s"])
	active = false
	_arc = false
	_count = 0


## A tocha está acesa (para o efeito de máscara de solda).
func is_arc_active() -> bool:
	return _arc


func arc_point() -> Vector3:
	return _arc_point


func physics_update(delta: float) -> void:
	var part := player.aim_part()
	_state = ""
	if part:
		var point: Vector3 = player.aim["position"]
		if Build.weld_spot_taken(point):
			_state = "taken"
		elif Build.find_weld_target(part, point)["ok"]:
			_state = "ok"
		else:
			_state = "none"
		_marker.visible = not active
		_marker.global_position = point
		_marker.material_override = {"ok": _ok_mat, "taken": _taken_mat, "none": _bad_mat}[_state]
	else:
		_marker.visible = false

	_arc = active and part != null
	if _arc:
		_arc_point = player.aim["position"]
		_arc_normal = player.aim["normal"]
		_held += delta
		_since_last += delta
		if _state == "ok" and _held >= FIRST_DELAY and _since_last >= INTERVAL:
			if Build.weld_at(part, _arc_point):
				_since_last = 0.0
				_count += 1


func _process(_delta: float) -> void:
	_sparks.emitting = _arc and visible
	_light.visible = _arc and visible
	_core.visible = _arc and visible
	if _arc and visible:
		_sparks.global_position = _arc_point + _arc_normal * 0.02
		_sparks.direction = _arc_normal
		_core.global_position = _arc_point + _arc_normal * 0.01
		_core.scale = Vector3.ONE * randf_range(0.8, 1.25)
		_light.global_position = _arc_point + _arc_normal * 0.25
		_light.light_energy = randf_range(5.0, 8.0)
		viewmodel.position = VIEW_POS + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.002
	elif viewmodel:
		viewmodel.position = VIEW_POS


func hint_text() -> String:
	match _state:
		"ok":
			return "Segure o clique para soldar · arraste pela emenda para fazer vários pontos"
		"taken":
			return "Já tem solda neste ponto: mova a mira para fazer outro"
		"none":
			return "Mire bem na emenda: a solda só alcança o que estiver dentro da bolinha"
	return "Mire na emenda entre duas peças (ou entre a peça e o chão)"

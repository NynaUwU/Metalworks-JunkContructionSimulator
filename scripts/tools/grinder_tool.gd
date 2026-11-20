class_name GrinderTool
extends GameTool
## Esmerilhadeira: corta peças e remove soldas.
##
## - O corte é feito na face que está na mira: a linha de corte fica sobre ela
##   (plano perpendicular à face) e R gira essa linha: 0°, 45°, 90°, 135°.
## - A posição do corte encaixa numa grade de 5 cm (segure Ctrl para corte livre).
## - Botão direito: remove a solda mais próxima da mira.

const GRID := 0.05
const WELD_PICK_RADIUS := 0.3

var angle_index := 0
var _preview: MeshInstance3D
var _imesh: ImmediateMesh
var _fill_mat: StandardMaterial3D
var _line_mat: StandardMaterial3D
var _weld_marker: MeshInstance3D
var _disc: MeshInstance3D
var _bad_fill_mat: StandardMaterial3D
var _bad_line_mat: StandardMaterial3D
var _target_part: Part = null
var _target_valid := false
var _target_plane := Plane()
var _target_weld: Weld = null


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
	_fill_mat = StandardMaterial3D.new()
	_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_mat.no_depth_test = true
	_fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fill_mat.albedo_color = Color(1.0, 0.55, 0.1, 0.28)
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.no_depth_test = true
	_line_mat.albedo_color = Color(1.0, 0.75, 0.2)
	_bad_fill_mat = _fill_mat.duplicate()
	_bad_fill_mat.albedo_color = Color(1.0, 0.15, 0.1, 0.22)
	_bad_line_mat = _line_mat.duplicate()
	_bad_line_mat.albedo_color = Color(1.0, 0.25, 0.2)

	_weld_marker = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	_weld_marker.mesh = sm
	var wm := glow_material(Color(1.0, 0.25, 0.2), 1.2)
	wm.no_depth_test = true
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color.a = 0.6
	_weld_marker.material_override = wm
	_weld_marker.top_level = true
	_weld_marker.visible = false
	add_child(_weld_marker)


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
	_imesh.clear_surfaces()
	_weld_marker.visible = false
	super()


func _process(delta: float) -> void:
	if visible and _disc:
		_disc.rotate_object_local(Vector3.UP, delta * 25.0)


func physics_update(_delta: float) -> void:
	_target_part = null
	_target_weld = null
	_imesh.clear_surfaces()
	_weld_marker.visible = false
	if player.aim.is_empty():
		return
	var point: Vector3 = player.aim["position"]

	_target_weld = Build.nearest_weld(point, WELD_PICK_RADIUS)
	if _target_weld:
		_weld_marker.visible = true
		_weld_marker.global_position = _target_weld.world_pos()

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
	_draw_preview(part, _target_plane)


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


func _draw_preview(part: Part, plane: Plane) -> void:
	var poly := ConvexGeo.cut_polygon(part.planes, plane)
	if poly.size() < 3:
		_target_part = null
		return
	var xf := part.global_transform
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _fill_mat if _target_valid else _bad_fill_mat)
	for i in range(1, poly.size() - 1):
		_imesh.surface_add_vertex(xf * poly[0])
		_imesh.surface_add_vertex(xf * poly[i])
		_imesh.surface_add_vertex(xf * poly[i + 1])
	_imesh.surface_end()
	_imesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat if _target_valid else _bad_line_mat)
	for i in poly.size():
		_imesh.surface_add_vertex(xf * poly[i])
		_imesh.surface_add_vertex(xf * poly[(i + 1) % poly.size()])
	_imesh.surface_end()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("rotate_cut"):
		angle_index = (angle_index + 1) % ConvexGeo.CUT_ANGLES.size()
		player.toast("Ângulo do corte: %d°" % roundi(ConvexGeo.CUT_ANGLES[angle_index]))
		return true
	if event.is_action_pressed("primary"):
		if _target_part and not _target_valid:
			player.toast("Muito perto da borda — mire mais para dentro da face")
		elif _target_part:
			var point: Vector3 = player.aim["position"]
			var pieces := Build.cut_part(_target_part, _target_plane)
			if not pieces.is_empty():
				spawn_sparks(point, player.aim["normal"], 70)
		return true
	if event.is_action_pressed("secondary"):
		if _target_weld:
			var pos := _target_weld.world_pos()
			Build.remove_weld(_target_weld)
			spawn_sparks(pos, Vector3.UP, 30)
			player.toast("Solda removida")
		return true
	return false


func hint_text() -> String:
	if _target_part and not _target_valid:
		return "Muito perto da borda (vermelho) — mire mais para dentro da face   ·   R: girar o corte"
	return "Corta a face mirada · ângulo %d°   ·   R: girar   ·   Ctrl: livre   ·   Botão direito: remover solda" \
		% roundi(ConvexGeo.CUT_ANGLES[angle_index])

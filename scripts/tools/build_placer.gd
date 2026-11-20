class_name BuildPlacer
extends Node3D
## Colocar uma construção salva: mostra uma prévia "fantasma" na mira.
##   Clique         coloca (cobra os pontos, se não estiver no modo grátis)
##   Roda do mouse  distância · R: girar 15° (com Shift: 90°)
##   Botão direito / Esc: cancelar

signal finished(placed: bool)

const MIN_DIST := 2.0
const MAX_DIST := 25.0

var player: Player
var data: Dictionary = {}
var dist := 7.0
var turn := 0.0
var price := 0
var _ghost: Node3D
var _ghost_state := -1
static var _ghost_ok: StandardMaterial3D
static var _ghost_bad: StandardMaterial3D


func start(p_player: Player, p_data: Dictionary) -> void:
	player = p_player
	data = p_data
	price = Saves.build_price(data)
	turn = 0.0
	if _ghost:
		_ghost.queue_free()
	_ghost = make_ghost(data)
	_ghost_state = 1
	add_child(_ghost)
	_update_ghost()


func is_active() -> bool:
	return not data.is_empty()


func hint_text() -> String:
	var cost := "grátis (modo de teste)" if Saves.builds_free else "%d pontos" % price
	return "%s · %s   ·   Clique: colocar   ·   Roda: distância   ·   R: girar (Shift: 90°)   ·   Botão direito: cancelar" % [
		data.get("name", "Construção"), cost]


## Onde a construção vai ficar: base na superfície mirada (ou no ar, na distância escolhida),
## virada para onde o jogador olha + o giro escolhido.
func target_origin() -> Transform3D:
	var from := player.eye_position()
	var dir := player.aim_direction()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * dist, Layers.WORLD | Layers.PARTS, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var pos: Vector3 = (hit["position"] as Vector3) + Vector3.UP * 0.03 if not hit.is_empty() else from + dir * dist
	return Transform3D(Basis(Vector3.UP, player.yaw + turn), pos)


func place() -> bool:
	var made := Saves.place_build(data, target_origin())
	if made.is_empty():
		player.toast("Faltam %d pontos para esta construção" % (price - Economy.points()))
		return false
	player.toast("%s colocada (%d peças)%s" % [data.get("name", "Construção"), made.size(),
		"" if Saves.builds_free else " · -%d pontos" % price])
	_finish(true)
	return true


func cancel() -> void:
	_finish(false)


func _finish(placed: bool) -> void:
	data = {}
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	finished.emit(placed)


func _process(_delta: float) -> void:
	if is_active():
		_update_ghost()


func _update_ghost() -> void:
	if _ghost == null or player == null:
		return
	_ghost.global_transform = target_origin()
	var ok := 1 if Saves.builds_free or Economy.can_afford(price) else 0
	if ok != _ghost_state:
		_ghost_state = ok
		_set_material(_ghost, _ghost_ok if ok == 1 else _ghost_bad)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active():
		return
	var handled := true
	if event.is_action_pressed("primary"):
		place()
	elif event.is_action_pressed("secondary") or event.is_action_pressed("pause"):
		cancel()
		player.toast("Colocação cancelada")
	elif event.is_action_pressed("rotate_cut"):
		turn += deg_to_rad(90.0 if Input.is_action_pressed("modifier") else 15.0)
	elif event.is_action_pressed("wheel_up"):
		dist = minf(dist + 0.5, MAX_DIST)
	elif event.is_action_pressed("wheel_down"):
		dist = maxf(dist - 0.5, MIN_DIST)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


# --- Prévia ---------------------------------------------------------------------

## Malhas transparentes de todas as peças (componentes na pose em que nasceram).
static func make_ghost(p_data: Dictionary) -> Node3D:
	if _ghost_ok == null:
		_ghost_ok = _ghost_material(Color(0.35, 0.75, 1.0, 0.35))
		_ghost_bad = _ghost_material(Color(1.0, 0.3, 0.25, 0.35))
	var root := Node3D.new()
	for pd: Dictionary in p_data.get("parts", []):
		if pd.has("g"):
			continue
		var mi := MeshInstance3D.new()
		if pd.has("pl"):
			var planes: Array[Plane] = []
			for a: Array in pd["pl"]:
				planes.append(Plane(Vector3(a[0], a[1], a[2]), a[3]))
			var geo := ConvexGeo.solve(planes)
			if geo.is_empty():
				continue
			mi.mesh = ConvexGeo.build_mesh(geo)
		elif pd.has("cyl"):
			var cm := CylinderMesh.new()
			cm.top_radius = pd["cyl"][0]
			cm.bottom_radius = pd["cyl"][0]
			cm.height = pd["cyl"][1]
			mi.mesh = cm
		else:
			continue
		mi.transform = Saves._to_xf(pd["x"])
		root.add_child(mi)
	for gd: Dictionary in p_data.get("groups", []):
		var size := Saves._to_v(gd.get("size", [0, 0, 0]))
		var v: Node3D
		if gd["kind"] == "roda":
			# O ícone da loja deita a roda; aqui ela fica como a peça de verdade (eixo Y).
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = size.x if size.x > 0.0 else 0.35
			cm.bottom_radius = cm.top_radius
			cm.height = size.y if size.y > 0.0 else 0.2
			mi.mesh = cm
			v = mi
		else:
			v = Components.build_visual(gd["kind"], size)
		v.transform = Saves._to_xf(gd["o"])
		root.add_child(v)
	_set_material(root, _ghost_ok)
	return root


static func _set_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override != mat:
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_set_material(c, mat)


static func _ghost_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

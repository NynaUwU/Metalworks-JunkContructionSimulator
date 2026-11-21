class_name MeasureTool
extends GameTool
## Trena: medir e marcar (para facilitar cortes).
##   Clique              ponto A; depois mede até a mira; outro clique fixa o B
##   Botão direito       põe/tira uma marca (cruz vermelha) na peça. A Esmerilhadeira
##                       encaixa o corte nas marcas.
##   R                   limpa a medida · G: grade de 5 cm liga/desliga
## Mirando numa peça, mostra também a distância até as bordas.

var grid_on := true
var _a := {}
var _b := {}
var _cursor: MeshInstance3D
var _dot_a: MeshInstance3D
var _dot_b: MeshInstance3D
var _line: MeshInstance3D
var _imesh: ImmediateMesh
var _label: Label3D


func _init(p_player: Player) -> void:
	super(p_player)
	tool_name = "Trena"
	key_hint = "6"


func _ready() -> void:
	super()
	_cursor = _dot(Color(1.0, 0.85, 0.2))
	_dot_a = _dot(Color(0.2, 1.0, 0.4))
	_dot_b = _dot(Color(0.3, 0.7, 1.0))
	_imesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _imesh
	_line.top_level = true
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1.0, 0.9, 0.3)
	lm.no_depth_test = true
	_line.material_override = lm
	add_child(_line)
	_label = Label3D.new()
	_label.top_level = true
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 40
	_label.pixel_size = 0.0025
	_label.outline_size = 10
	_label.modulate = Color(1.0, 0.95, 0.6)
	_label.visible = false
	add_child(_label)


func _dot(c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	mi.mesh = sm
	mi.material_override = glow_material(c, 2.0)
	mi.top_level = true
	mi.visible = false
	add_child(mi)
	return mi


func _build_viewmodel() -> void:
	var body := make_box(Vector3(0.12, 0.12, 0.05), Color(0.95, 0.75, 0.1), 0.2, 0.5)
	viewmodel.add_child(body)
	var tape := make_box(Vector3(0.02, 0.004, 0.16), Color(0.95, 0.9, 0.6), 0.6, 0.4)
	tape.position = Vector3(0.0, -0.05, -0.1)
	viewmodel.add_child(tape)
	muzzle.position = Vector3(0, -0.05, -0.18)


func unequip() -> void:
	_cursor.visible = false
	_dot_a.visible = false
	_dot_b.visible = false
	_label.visible = false
	_imesh.clear_surfaces()
	super()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("toggle_grid"):
		grid_on = not grid_on
		player.toast("Trena · grade de 5 cm: %s" % ("ligada" if grid_on else "desligada"))
		return true
	if event.is_action_pressed("rotate_cut"):
		_a = {}
		_b = {}
		player.toast("Medida limpa")
		return true
	if event.is_action_pressed("primary"):
		var s := Snap.aimed(player, grid_on)
		if s.is_empty():
			return true
		if _a.is_empty() or not _b.is_empty():
			_a = s
			_b = {}
			player.toast("Ponto A marcado: mire no ponto B")
		else:
			_b = s
			player.toast("A → B: %s" % Snap.length_text(_world(_a).distance_to(_world(_b))))
		return true
	if event.is_action_pressed("secondary"):
		toggle_mark()
		return true
	return false


## Põe uma marca no ponto mirado (ou tira a que já estiver ali).
func toggle_mark() -> void:
	var s := Snap.aimed(player, grid_on)
	if s.is_empty() or s["part"] == null:
		player.toast("Marcas vão em peças (mire numa peça)")
		return
	var part: Part = s["part"]
	var near := part.nearest_mark(s["local"], 0.03)
	if near >= 0:
		part.remove_mark(near)
		player.toast("Marca removida")
	else:
		part.add_mark(s["local"], s["local_n"])
		player.toast("Marca posta (a Esmerilhadeira corta por ela)")


## Posição atual de um ponto medido (acompanha a peça se ela se mexer).
static func _world(p: Dictionary) -> Vector3:
	var part: Part = p.get("part")
	if part and is_instance_valid(part) and part.is_inside_tree():
		return part.global_transform * (p["local"] as Vector3)
	return p["world"]


## Diferença B − A nos eixos da peça do ponto A (ou do mundo).
static func local_delta(a: Dictionary, b_world: Vector3) -> Vector3:
	var d := b_world - _world(a)
	var part: Part = a.get("part")
	if part and is_instance_valid(part):
		return part.global_basis.orthonormalized().inverse() * d
	return d


func _process(_delta: float) -> void:
	if not visible:
		return
	var s := Snap.aimed(player, grid_on)
	_cursor.visible = not s.is_empty()
	if not s.is_empty():
		_cursor.global_position = s["world"] + (s["world_n"] as Vector3) * 0.004
	_dot_a.visible = not _a.is_empty()
	_dot_b.visible = not _b.is_empty()
	_imesh.clear_surfaces()
	_label.visible = false
	if _a.is_empty():
		return
	var pa := _world(_a)
	_dot_a.global_position = pa
	var pb: Vector3
	if not _b.is_empty():
		pb = _world(_b)
		_dot_b.global_position = pb
	elif not s.is_empty():
		pb = s["world"]
	else:
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_imesh.surface_add_vertex(pa)
	_imesh.surface_add_vertex(pb)
	_imesh.surface_end()
	_label.visible = true
	_label.global_position = (pa + pb) * 0.5 + Vector3.UP * 0.06
	_label.text = Snap.length_text(pa.distance_to(pb))


func hint_text() -> String:
	var s := Snap.aimed(player, grid_on)
	var tail := "Botão direito: marcar   ·   R: limpar   ·   G: grade %s" % ("ligada" if grid_on else "desligada")
	if not _a.is_empty():
		var pb: Vector3 = _world(_b) if not _b.is_empty() else (s["world"] if not s.is_empty() else _world(_a))
		var d := local_delta(_a, pb)
		return "%s: %s   (x %s · y %s · z %s)   ·   %s" % ["A → B" if not _b.is_empty() else "A → mira",
			Snap.length_text(_world(_a).distance_to(pb)), Snap.length_text(absf(d.x)), Snap.length_text(absf(d.y)),
			Snap.length_text(absf(d.z)), tail]
	if not s.is_empty() and s["part"] != null:
		return "%s   ·   Clique: ponto A   ·   %s" % [edges_text(s["part"], s["local"], s["local_n"]), tail]
	return "Clique: ponto A   ·   " + tail


## Distância do ponto até as bordas da peça, nos dois eixos da face.
static func edges_text(part: Part, local: Vector3, n: Vector3) -> String:
	var b := part.bounds
	var out: Array[String] = []
	for i in 3:
		var axis := Vector3.ZERO
		axis[i] = 1.0
		if absf(axis.dot(n)) > 0.7:
			continue
		var lo := local[i] - b.position[i]
		var hi := b.end[i] - local[i]
		out.append("%s: %s | %s" % ["xyz"[i], Snap.length_text(maxf(lo, 0.0)), Snap.length_text(maxf(hi, 0.0))])
	return "Até as bordas  " + "   ".join(out)

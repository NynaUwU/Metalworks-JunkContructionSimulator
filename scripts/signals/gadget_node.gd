class_name GadgetNode
extends SignalNode
## Peças especiais de sinal (Marco 4E):
##   hud_indicador   mostra um valor no canto da tela de quem está sentado na máquina (ou
##                   sempre, nos ajustes). Número, barra (Valor ÷ Máx) ou texto.
##   camera          com Ligar ligado, quem está sentado na máquina passa a ver pela câmera
##                   (olha para a frente da peça, -Z). Zoom: campo de visão em graus.
##   marcador        guarda UMA peça (marque com a Fiação: botão direito → Marcar peças).
##   marcador_lista  guarda VÁRIAS peças. Saídas: Peça (a primeira), Lista, Quantidade,
##                   Posição, Distância (até a primeira) e Massa.
##   pintor          pinta peças com a Cor (0 a 255): a da entrada Peça, as da Lista ou,
##                   sem fio nelas, a que estiver na frente do bico (até o alcance).
##                   Pintar sem fio = sempre. Limpar volta a cor do metal.

const KINDS := {
	"hud_indicador": "Indicador no HUD", "camera": "Câmera", "marcador": "Marcador de peça",
	"marcador_lista": "Marcador de peças (lista)", "pintor": "Pintor",
}
const STYLES := ["Número", "Barra", "Texto"]
const MACHINE_REFRESH := 0.5
const MAX_MARKED := 64

var part: Part
var kind := "hud_indicador"
var label: Label3D
var lamp: MeshInstance3D

# Indicador no HUD
var hud_title := "Valor"
var style := 0
var bar_max := 100.0
var decimals := 1
var always := false
var hud_color := Color(0.4, 0.9, 1.0)
var value: Variant = 0.0
var text := ""
var fraction := 0.0

# Câmera
var cam: Camera3D
var on := false
var fov := 70.0

# Marcador
var marked: Array = []           ## Part

# Pintor
var paint_range := 3.0
var color := Color(1, 1, 1)
var _edges := {}
var _lmat: StandardMaterial3D

var _mach_t := 0.0
var _mach: Array = []            ## montagens da máquina (cache)


func signal_part() -> Part:
	return part


func kind_label() -> String:
	return KINDS.get(kind, kind)


func inputs() -> Array:
	match kind:
		"hud_indicador":
			return [["Valor", NUM], ["Texto", TXT], ["Máx", NUM]]
		"camera":
			return [["Ligar", NUM], ["Zoom", NUM]]
		"pintor":
			return [["Cor", VEC], ["Pintar", NUM], ["Peça", PART], ["Lista", LIST], ["Limpar", NUM]]
	return []


func outputs() -> Array:
	match kind:
		"marcador", "marcador_lista":
			return [["Peça", PART], ["Lista", LIST], ["Quantidade", NUM], ["Posição", VEC], ["Distância", NUM], ["Massa", NUM]]
		"camera":
			return [["Ligada", NUM]]
	return []


func is_source() -> bool:
	return kind in ["marcador", "marcador_lista"]


func is_marker() -> bool:
	return kind in ["marcador", "marcador_lista"]


# --- Máquina do jogador -----------------------------------------------------------------

## A peça está na mesma máquina (soldas + juntas) do assento em que o jogador está.
func in_machine_of(player: Player) -> bool:
	if player == null or not player.is_seated() or player.seat == null or not is_instance_valid(player.seat):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - _mach_t > MACHINE_REFRESH or _mach.is_empty():
		_mach_t = now
		_mach = Carrier.machine(part.assembly(), true)["list"] if part and part.assembly() else []
	return _mach.has(player.seat.assembly())


# --- Fontes (marcador) ------------------------------------------------------------------

func update_outputs(_dt: float) -> void:
	if not is_marker():
		return
	marked = marked.filter(func(p: Variant) -> bool: return p != null and is_instance_valid(p) and (p as Part).is_inside_tree() and not (p as Part).is_queued_for_deletion())
	var first: Part = marked[0] if not marked.is_empty() else null
	out["Peça"] = first
	out["Lista"] = marked.duplicate()
	out["Quantidade"] = float(marked.size())
	out["Posição"] = first.global_position if first else Vector3.ZERO
	out["Distância"] = first.global_position.distance_to(part.global_position) if first else 0.0
	out["Massa"] = first.mass if first else 0.0
	if label and Engine.get_physics_frames() % 15 == 0:
		label.text = "%s\n%d peça%s" % ["MARCADOR" if kind == "marcador" else "LISTA", marked.size(), "" if marked.size() == 1 else "s"]


## Marca (ou desmarca) uma peça. Marcador simples: troca a peça. Retorna se ficou marcada.
func toggle_mark(p: Part) -> bool:
	if p == null or p == part:
		return false
	if marked.has(p):
		marked.erase(p)
		return false
	if kind == "marcador":
		marked = [p]
	elif marked.size() < MAX_MARKED:
		marked.append(p)
	else:
		return false
	update_outputs(0.0)
	return true


# --- Não-fontes ------------------------------------------------------------------------

func _rising(key: String, v: float) -> bool:
	var prev: float = _edges.get(key, 0.0)
	_edges[key] = v
	return prev <= 0.0 and v > 0.0


func evaluate(inp: Dictionary, wired: Dictionary, _dt: float) -> void:
	match kind:
		"hud_indicador":
			value = inp["Valor"]
			text = str(inp["Texto"])
			var mx := float(inp["Máx"]) if wired.has("Máx") and absf(float(inp["Máx"])) > 1e-6 else bar_max
			fraction = clampf(float(value) / mx, 0.0, 1.0) if absf(mx) > 1e-6 else 0.0
		"camera":
			on = float(inp["Ligar"]) > 0.0
			if wired.has("Zoom") and float(inp["Zoom"]) > 0.0:
				fov = clampf(float(inp["Zoom"]), 5.0, 120.0)
			if cam:
				cam.fov = fov
			out["Ligada"] = 1.0 if on else 0.0
			_set_lamp(Color(1.0, 0.2, 0.15) if on else Color(0.2, 0.05, 0.04), 3.0 if on else 0.2)
		"pintor":
			var c: Vector3 = inp["Cor"]
			color = Color(clampf(c.x / 255.0, 0, 1), clampf(c.y / 255.0, 0, 1), clampf(c.z / 255.0, 0, 1))
			_set_lamp(color, 1.5)
			var targets := _targets(inp, wired)
			if _rising("Limpar", float(inp["Limpar"])):
				for p: Part in targets:
					p.set_paint(Color(0, 0, 0, 0))
			elif not wired.has("Pintar") or float(inp["Pintar"]) > 0.0:
				for p: Part in targets:
					if not p.paint.is_equal_approx(color):
						p.set_paint(color)


## Pintor: peças a pintar agora.
func _targets(inp: Dictionary, wired: Dictionary) -> Array:
	var out_parts: Array = []
	if wired.has("Peça") and inp["Peça"] is Part and is_instance_valid(inp["Peça"]):
		out_parts.append(inp["Peça"])
	if wired.has("Lista"):
		for x in (inp["Lista"] as Array):
			if x is Part and is_instance_valid(x) and not out_parts.has(x):
				out_parts.append(x)
	if wired.has("Peça") or wired.has("Lista"):
		return out_parts
	var hit := nozzle_hit()
	if hit:
		out_parts.append(hit)
	return out_parts


## Pintor: a peça na frente do bico (face de cima, +Y), até o alcance.
func nozzle_hit() -> Part:
	if part == null or not part.is_inside_tree():
		return null
	var up := part.global_basis.orthonormalized().y
	var from := part.global_position + up * (part.bounds.end.y + 0.01)
	var q := PhysicsRayQueryParameters3D.create(from, from + up * paint_range)
	if part.assembly():
		q.exclude = [part.assembly().get_rid()]
	var r := part.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty() or not (r["collider"] is Assembly):
		return null
	var asm := r["collider"] as Assembly
	var shape := asm.shape_owner_get_owner(asm.shape_find_owner(int(r["shape"])))
	return shape as Part


func _set_lamp(c: Color, energy: float) -> void:
	if lamp == null:
		return
	if _lmat == null:
		_lmat = StandardMaterial3D.new()
		_lmat.emission_enabled = true
		lamp.material_override = _lmat
	_lmat.albedo_color = c.darkened(0.3)
	_lmat.emission = c
	_lmat.emission_energy_multiplier = energy


# --- Indicador no HUD -------------------------------------------------------------------

## Texto do valor, conforme o estilo.
func hud_value_text() -> String:
	match style:
		1:
			return "%d%%" % roundi(fraction * 100.0)
		2:
			return text
	var f := float(value)
	return ("%." + str(decimals) + "f") % f if decimals > 0 else str(roundi(f))


## Indicadores para mostrar agora: [[título, texto, fração (-1 = sem barra), cor], ...].
static func hud_items(player: Player) -> Array:
	var items: Array = []
	for n in Signals.nodes:
		var g := n as GadgetNode
		if g == null or g.kind != "hud_indicador" or not g.is_alive():
			continue
		if not g.always and not g.in_machine_of(player):
			continue
		items.append([g.title() if g.node_name != "" else g.hud_title, g.hud_value_text(), g.fraction if g.style == 1 else -1.0, g.hud_color])
	return items


## Câmera ligada na máquina em que o jogador está sentado (ou null).
static func view_camera(player: Player) -> Camera3D:
	for n in Signals.nodes:
		var g := n as GadgetNode
		if g and g.kind == "camera" and g.on and g.cam and g.is_alive() and g.in_machine_of(player):
			return g.cam
	return null


# --- Salvar ----------------------------------------------------------------------------

func save_state() -> Dictionary:
	match kind:
		"hud_indicador":
			return {"title": hud_title, "style": style, "max": bar_max, "dec": decimals, "always": always,
				"color": [hud_color.r, hud_color.g, hud_color.b]}
		"camera":
			return {"fov": fov}
		"pintor":
			return {"range": paint_range}
	return {}


func load_state(d: Dictionary) -> void:
	hud_title = str(d.get("title", hud_title))
	style = clampi(int(d.get("style", style)), 0, STYLES.size() - 1)
	bar_max = float(d.get("max", bar_max))
	decimals = clampi(int(d.get("dec", decimals)), 0, 4)
	always = bool(d.get("always", always))
	var c: Array = d.get("color", [])
	if c.size() == 3:
		hud_color = Color(float(c[0]), float(c[1]), float(c[2]))
	fov = clampf(float(d.get("fov", fov)), 5.0, 120.0)
	if cam:
		cam.fov = fov
	paint_range = clampf(float(d.get("range", paint_range)), 0.5, 20.0)

class_name RadioNode
extends SignalNode
## Rádio (Marco 4E): canais sem fio entre máquinas.
##   Cada rádio manda o que chega nas entradas ligadas (A, B, C, D, Vetor, Texto) no canal.
##   As saídas mostram o que os outros rádios do mesmo canal mandam: em cada porta, vale o
##   rádio mais perto que esteja mandando nela (dentro do alcance).
##   Canal: nos ajustes, ou pela entrada Canal (com fio). Alcance 0 = sem limite.
## Um rádio não ouve a si mesmo. Pode chegar com um tick de atraso.

const SEND := [["A", NUM], ["B", NUM], ["C", NUM], ["D", NUM], ["Vetor", VEC], ["Texto", TXT]]

var part: Part
var channel := 1
var range_m := 0.0
var label: Label3D
var light: MeshInstance3D
var cur_channel := 1
var sent := {}                    ## porta -> valor (só as entradas com fio)
var heard := 0
var _mat: StandardMaterial3D


func signal_part() -> Part:
	return part


func kind_label() -> String:
	return "Rádio"


func inputs() -> Array:
	return [["Canal", NUM]] + SEND


func outputs() -> Array:
	return SEND + [["Rádios", NUM]]


func is_source() -> bool:
	return false


func evaluate(inp: Dictionary, wired: Dictionary, _dt: float) -> void:
	cur_channel = int(roundf(float(inp["Canal"]))) if wired.has("Canal") else channel
	sent = {}
	for p: Array in SEND:
		if wired.has(p[0]):
			sent[p[0]] = inp[p[0]]
	var me := part.global_position
	var best := {}                  # porta -> [distância, valor]
	heard = 0
	for n in Signals.nodes:
		var r := n as RadioNode
		if r == null or r == self or not r.is_alive() or r.cur_channel != cur_channel:
			continue
		var d := me.distance_to(r.part.global_position)
		var lim := _limit(range_m, r.range_m)
		if lim > 0.0 and d > lim:
			continue
		heard += 1
		for port: String in r.sent:
			if not best.has(port) or d < float(best[port][0]):
				best[port] = [d, r.sent[port]]
	for p: Array in SEND:
		out[p[0]] = best[p[0]][1] if best.has(p[0]) else zero(p[1])
	out["Rádios"] = float(heard)
	_update_visual()


## Alcance da ligação: o menor dos dois (0 = sem limite).
static func _limit(a: float, b: float) -> float:
	if a <= 0.0:
		return b
	if b <= 0.0:
		return a
	return minf(a, b)


func _update_visual() -> void:
	if label and Engine.get_physics_frames() % 15 == 0:
		label.text = "CANAL %d" % cur_channel
	if light:
		if _mat == null:
			_mat = StandardMaterial3D.new()
			_mat.emission_enabled = true
			light.material_override = _mat
		var on := heard > 0
		var c := Color(0.3, 1.0, 0.4) if on else Color(0.35, 0.08, 0.06)
		_mat.albedo_color = c.darkened(0.4)
		_mat.emission = c
		_mat.emission_energy_multiplier = 2.5 if on else 0.3


func save_state() -> Dictionary:
	return {"ch": channel, "range": range_m}


func load_state(d: Dictionary) -> void:
	channel = int(d.get("ch", channel))
	cur_channel = channel
	range_m = float(d.get("range", range_m))
	if label:
		label.text = "CANAL %d" % channel

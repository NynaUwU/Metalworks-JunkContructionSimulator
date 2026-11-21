class_name ChipNode
extends SignalNode
## Chip lógico: uma peça só; o modo (E, OU, somar, memória, temporizador...) é escolhido
## nos ajustes. As portas mudam conforme o modo (ver Gates.DEFS).

var part: Part
var mode := "e"
var state := {}                  ## memória interna (latch, contador, tempo...)
var label: Label3D               ## símbolo em cima do chip


func signal_part() -> Part:
	return part


func kind_label() -> String:
	return "Chip · " + Gates.DEFS[mode]["name"]


func inputs() -> Array:
	return Gates.DEFS[mode]["ins"]


func outputs() -> Array:
	return Gates.DEFS[mode]["outs"]


func is_source() -> bool:
	return false


func set_mode(m: String) -> void:
	if not Gates.DEFS.has(m) or m == mode:
		return
	mode = m
	state = {}
	out = {}
	# Fios em portas que não existem mais (ou mudaram de tipo) somem no próximo tick.
	Signals._dirty = true
	if label:
		label.text = Gates.DEFS[mode]["sym"]


func evaluate(inp: Dictionary, wired: Dictionary, dt: float) -> void:
	out = Gates.run(mode, inp, wired, state, dt)


func save_state() -> Dictionary:
	var d := {"mode": mode}
	if not state.is_empty():
		d["state"] = _plain(state)
	return d


func load_state(d: Dictionary) -> void:
	set_mode(str(d.get("mode", mode)))
	if d.has("state"):
		state = (d["state"] as Dictionary).duplicate(true)


## Estado em tipos que o JSON aceita (números, listas, textos).
static func _plain(v: Variant) -> Variant:
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = _plain(v[k])
		return o
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(_plain(x))
		return a
	if v is bool:
		return v
	if v is float or v is int:
		return v
	return str(v)

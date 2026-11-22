class_name FpgaNode
extends SignalNode
## FPGA (Marco 4E): um chip com um circuito dentro, montado no editor visual (botão direito
## com a Fiação). Dentro dele vão portas lógicas (todos os modos do chip lógico), pinos de
## entrada e saída (que viram as portas do FPGA, na ordem de cima para baixo) e constantes.
##
## Tudo roda no mesmo tick, na ordem das ligações internas. Num ciclo (ex.: um latch
## realimentado), quem fecha o ciclo lê o valor do tick anterior, como fora do chip.
## Várias ligações na mesma entrada: números e vetores somam; nos outros tipos vale a primeira.
##
## Circuitos podem ser salvos com um nome e carregados em outro FPGA (user://circuitos).

const PIN_IN := "@in"
const PIN_OUT := "@out"
const PIN_CONST := "@const"
const MAX_GATES := 300
const CIRCUIT_DIR := "user://circuitos"
const PIN_NAMES := {"@in": "Entrada", "@out": "Saída", "@const": "Constante"}

var part: Part
var label: Label3D

## id -> {"mode", "pos": Vector2, "state": {}, "out": {}, e nos pinos "name"/"type",
## na constante "type"/"value"}
var gates := {}
## [{"f": id, "fp": porta, "t": id, "tp": porta}]
var edges: Array = []
var next_id := 1

var _order: Array = []           ## ids na ordem de avaliação
var _incoming := {}              ## id -> [[porta, id de origem, porta de origem]]
var _dirty := true
var _ins: Array = []             ## portas externas (cache)
var _outs: Array = []


func _init() -> void:
	reset_default()


## FPGA novo: entradas A e B, saída "Saída", nada no meio.
func reset_default() -> void:
	gates = {}
	edges = []
	next_id = 1
	add_gate(PIN_IN, Vector2(40, 60), {"name": "A", "type": NUM})
	add_gate(PIN_IN, Vector2(40, 200), {"name": "B", "type": NUM})
	add_gate(PIN_OUT, Vector2(700, 130), {"name": "Saída", "type": NUM})


func signal_part() -> Part:
	return part


func kind_label() -> String:
	return "FPGA"


func inputs() -> Array:
	if _dirty:
		_rebuild()
	return _ins


func outputs() -> Array:
	if _dirty:
		_rebuild()
	return _outs


func is_source() -> bool:
	return false


# --- Portas de cada porta lógica ------------------------------------------------------

func gate_ins(id: int) -> Array:
	var g: Dictionary = gates[id]
	match str(g["mode"]):
		PIN_IN, PIN_CONST:
			return []
		PIN_OUT:
			return [["Valor", g["type"]]]
	return Gates.DEFS[g["mode"]]["ins"]


func gate_outs(id: int) -> Array:
	var g: Dictionary = gates[id]
	match str(g["mode"]):
		PIN_IN, PIN_CONST:
			return [["Valor", g["type"]]]
		PIN_OUT:
			return []
	return Gates.DEFS[g["mode"]]["outs"]


static func _type_in(ports: Array, port: String) -> String:
	for p: Array in ports:
		if p[0] == port:
			return p[1]
	return ""


static func is_known_mode(mode: String) -> bool:
	return mode in [PIN_IN, PIN_OUT, PIN_CONST] or Gates.DEFS.has(mode)


## Nome de uma porta lógica para mostrar.
func gate_title(id: int) -> String:
	var m := str(gates[id]["mode"])
	if PIN_NAMES.has(m):
		return PIN_NAMES[m]
	return "%s  %s" % [Gates.DEFS[m]["sym"], Gates.DEFS[m]["name"]]


# --- Edição ---------------------------------------------------------------------------

## Põe uma porta lógica (ou pino/constante). Retorna o id (ou -1).
func add_gate(mode: String, pos: Vector2, extra := {}) -> int:
	if not is_known_mode(mode) or gates.size() >= MAX_GATES:
		return -1
	var id := next_id
	next_id += 1
	var g := {"mode": mode, "pos": pos, "state": {}, "out": {}}
	if mode == PIN_IN or mode == PIN_OUT:
		g["type"] = str(extra.get("type", NUM))
		g["name"] = _unique_name(str(extra.get("name", "A" if mode == PIN_IN else "Saída")), mode, id)
	elif mode == PIN_CONST:
		g["type"] = str(extra.get("type", NUM))
		g["value"] = _coerce(extra.get("value", 1.0), g["type"])
	gates[id] = g
	_changed(mode == PIN_IN or mode == PIN_OUT)
	return id


func remove_gate(id: int) -> void:
	if not gates.has(id):
		return
	var pin: bool = gates[id]["mode"] in [PIN_IN, PIN_OUT]
	gates.erase(id)
	edges = edges.filter(func(e: Dictionary) -> bool: return int(e["f"]) != id and int(e["t"]) != id)
	_changed(pin)


## Liga a saída `fp` de `f` na entrada `tp` de `t` (tipos iguais). Retorna se ligou.
## Pode ligar uma porta nela mesma (lê o valor do tick anterior: acumuladores, contadores).
func connect_gates(f: int, fp: String, t: int, tp: String) -> bool:
	if not gates.has(f) or not gates.has(t):
		return false
	var ft := _type_in(gate_outs(f), fp)
	if ft == "" or ft != _type_in(gate_ins(t), tp):
		return false
	if find_edge(f, fp, t, tp) >= 0:
		return true
	edges.append({"f": f, "fp": fp, "t": t, "tp": tp})
	_changed(false)
	return true


func disconnect_gates(f: int, fp: String, t: int, tp: String) -> void:
	var i := find_edge(f, fp, t, tp)
	if i >= 0:
		edges.remove_at(i)
		_changed(false)


func find_edge(f: int, fp: String, t: int, tp: String) -> int:
	for i in edges.size():
		var e: Dictionary = edges[i]
		if int(e["f"]) == f and e["fp"] == fp and int(e["t"]) == t and e["tp"] == tp:
			return i
	return -1


## Pino: muda o nome (fica único) e o tipo (ligações do tipo antigo saem).
func set_pin(id: int, pin_name: String, type: String) -> void:
	if not gates.has(id):
		return
	var g: Dictionary = gates[id]
	if g["mode"] == PIN_CONST:
		if type != g["type"]:
			g["type"] = type
			g["value"] = _coerce(g["value"], type)
			_drop_bad_edges()
		return
	var n := pin_name.strip_edges()
	if n == "":
		n = "A" if g["mode"] == PIN_IN else "Saída"
	g["name"] = _unique_name(n, str(g["mode"]), id)
	if type != g["type"]:
		g["type"] = type
		_drop_bad_edges()
	_changed(true)


func set_const(id: int, value: Variant) -> void:
	if gates.has(id) and gates[id]["mode"] == PIN_CONST:
		gates[id]["value"] = _coerce(value, gates[id]["type"])


func move_gate(id: int, pos: Vector2) -> void:
	if not gates.has(id):
		return
	gates[id]["pos"] = pos
	if gates[id]["mode"] in [PIN_IN, PIN_OUT]:
		_changed(true)       # a ordem das portas segue a altura dos pinos


func _drop_bad_edges() -> void:
	edges = edges.filter(func(e: Dictionary) -> bool:
		var f := int(e["f"])
		var t := int(e["t"])
		if not gates.has(f) or not gates.has(t):
			return false
		var ft := _type_in(gate_outs(f), str(e["fp"]))
		return ft != "" and ft == _type_in(gate_ins(t), str(e["tp"])))
	_changed(true)


func _unique_name(base: String, mode: String, self_id: int) -> String:
	var taken := {}
	for id: int in gates:
		if id != self_id and gates[id]["mode"] == mode:
			taken[gates[id]["name"]] = true
	if not taken.has(base):
		return base
	var k := 2
	while taken.has("%s%d" % [base, k]):
		k += 1
	return "%s%d" % [base, k]


static func _coerce(v: Variant, t: String) -> Variant:
	match t:
		NUM:
			if v is float or v is int:
				return float(v)
			return str(v).replace(",", ".").to_float()
		VEC:
			if v is Vector3:
				return v
			if v is Array and (v as Array).size() == 3:
				return Vector3(float(v[0]), float(v[1]), float(v[2]))
			var parts := str(v).replace(";", " ").replace(",", " ").split(" ", false)
			if parts.size() == 3:
				return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
			return Vector3.ZERO
	return "" if v == null else str(v)


## Alguma coisa mudou: refaz a ordem; se mudaram os pinos, os fios de fora são revistos.
func _changed(ports: bool) -> void:
	_dirty = true
	if ports:
		Signals._dirty = true
	update_label()


# --- Simulação ------------------------------------------------------------------------

func _rebuild() -> void:
	_dirty = false
	# Portas externas: pinos de cima para baixo.
	var ins: Array = []
	var outs: Array = []
	for id: int in gates:
		var g: Dictionary = gates[id]
		if g["mode"] == PIN_IN:
			ins.append([g["pos"].y, id, [g["name"], g["type"]]])
		elif g["mode"] == PIN_OUT:
			outs.append([g["pos"].y, id, [g["name"], g["type"]]])
	var by_height := func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])
	ins.sort_custom(by_height)
	outs.sort_custom(by_height)
	_ins = ins.map(func(x: Array) -> Array: return x[2])
	_outs = outs.map(func(x: Array) -> Array: return x[2])
	for p: Array in _outs:
		if not out.has(p[0]):
			out[p[0]] = zero(p[1])
	for k in out.keys():
		if _type_in(_outs, str(k)) == "":
			out.erase(k)
	# Ligações que chegam em cada porta lógica e ordem de avaliação (Kahn; ciclos no fim).
	_incoming = {}
	var deps := {}
	for id: int in gates:
		_incoming[id] = []
		deps[id] = {}
	for e: Dictionary in edges:
		var f := int(e["f"])
		var t := int(e["t"])
		if not gates.has(f) or not gates.has(t):
			continue
		_incoming[t].append([str(e["tp"]), f, str(e["fp"])])
		if f != t:
			deps[t][f] = true
	_order = []
	var done := {}
	var progress := true
	while progress:
		progress = false
		for id: int in gates:
			if done.has(id):
				continue
			var ready := true
			for d: int in deps[id]:
				if not done.has(d):
					ready = false
					break
			if ready:
				done[id] = true
				_order.append(id)
				progress = true
	for id: int in gates:
		if not done.has(id):
			_order.append(id)


func evaluate(inp: Dictionary, _wired: Dictionary, dt: float) -> void:
	if _dirty:
		_rebuild()
	for id: int in _order:
		var g: Dictionary = gates[id]
		match str(g["mode"]):
			PIN_IN:
				g["out"] = {"Valor": inp.get(g["name"], zero(g["type"]))}
			PIN_CONST:
				g["out"] = {"Valor": g["value"]}
			PIN_OUT:
				out[g["name"]] = _value_in(id, "Valor", str(g["type"]))
			_:
				var gi := {}
				var gw := {}
				for p: Array in gate_ins(id):
					gi[p[0]] = zero(p[1])
				for c: Array in _incoming[id]:
					gw[c[0]] = true
				for port: String in gw:
					gi[port] = _value_in(id, port, _type_in(gate_ins(id), port))
				g["out"] = Gates.run(str(g["mode"]), gi, gw, g["state"], dt)


## Valor numa entrada de uma porta lógica (soma de números/vetores; primeira nos outros).
func _value_in(id: int, port: String, t: String) -> Variant:
	var v: Variant = zero(t)
	var first := true
	for c: Array in _incoming[id]:
		if c[0] != port:
			continue
		var src: Dictionary = gates[c[1]]
		var x: Variant = (src["out"] as Dictionary).get(c[2], zero(t))
		if t == NUM:
			v = float(v) + float(x)
		elif t == VEC:
			v = (v as Vector3) + (x as Vector3)
		elif first:
			v = x
		first = false
	return v


## Valor atual numa saída de uma porta lógica (editor: mostra ao vivo).
func gate_value(id: int, port: String) -> Variant:
	if not gates.has(id):
		return null
	var g: Dictionary = gates[id]
	if g["mode"] == PIN_OUT:
		return out.get(g["name"], null)
	return (g["out"] as Dictionary).get(port, null)


func update_label() -> void:
	if label:
		var n := gates.size() - _count_pins()
		label.text = "FPGA\n%d porta%s" % [n, "" if n == 1 else "s"]


func _count_pins() -> int:
	var k := 0
	for id: int in gates:
		if gates[id]["mode"] in [PIN_IN, PIN_OUT, PIN_CONST]:
			k += 1
	return k


# --- Salvar / circuitos -----------------------------------------------------------------

## O circuito em tipos que o JSON aceita. `with_state`: inclui memórias e tempos.
func to_data(with_state := true) -> Dictionary:
	var list: Array = []
	for id: int in gates:
		var g: Dictionary = gates[id]
		var d := {"id": id, "m": g["mode"], "x": snappedf(g["pos"].x, 0.1), "y": snappedf(g["pos"].y, 0.1)}
		if g.has("name"):
			d["name"] = g["name"]
		if g.has("type"):
			d["type"] = g["type"]
		if g.has("value"):
			var v: Variant = g["value"]
			d["v"] = [v.x, v.y, v.z] if v is Vector3 else v
		if with_state and not (g["state"] as Dictionary).is_empty():
			d["st"] = ChipNode._plain(g["state"])
		list.append(d)
	return {"g": list, "e": edges.duplicate(true), "n": next_id}


func from_data(d: Dictionary) -> void:
	gates = {}
	edges = []
	var top := 0
	for gd: Dictionary in d.get("g", []):
		var mode := str(gd.get("m", ""))
		if not is_known_mode(mode):
			continue
		var id := int(gd.get("id", 0))
		var g := {"mode": mode, "pos": Vector2(float(gd.get("x", 0.0)), float(gd.get("y", 0.0))), "state": {}, "out": {}}
		if mode == PIN_IN or mode == PIN_OUT:
			g["name"] = str(gd.get("name", "A"))
			g["type"] = str(gd.get("type", NUM))
		elif mode == PIN_CONST:
			g["type"] = str(gd.get("type", NUM))
			g["value"] = _coerce(gd.get("v", 0.0), g["type"])
		if gd.has("st") and gd["st"] is Dictionary:
			g["state"] = (gd["st"] as Dictionary).duplicate(true)
		gates[id] = g
		top = maxi(top, id)
	next_id = maxi(int(d.get("n", top + 1)), top + 1)
	for e: Dictionary in d.get("e", []):
		connect_gates(int(e.get("f", 0)), str(e.get("fp", "")), int(e.get("t", 0)), str(e.get("tp", "")))
	_changed(true)


func save_state() -> Dictionary:
	return {"fpga": to_data(true)}


func load_state(d: Dictionary) -> void:
	if d.has("fpga") and d["fpga"] is Dictionary:
		from_data(d["fpga"])


static func _safe_name(n: String) -> String:
	var s := ""
	for ch in n.strip_edges():
		s += ch if (ch.is_valid_identifier() or ch.is_valid_int() or ch in " -áàâãéêíóôõúçÁÀÂÃÉÊÍÓÔÕÚÇ") else "_"
	return s.strip_edges().left(40)


static func list_circuits() -> Array[String]:
	var out_names: Array[String] = []
	var dir := DirAccess.open(CIRCUIT_DIR)
	if dir == null:
		return out_names
	for f in dir.get_files():
		if f.ends_with(".json"):
			out_names.append(f.trim_suffix(".json"))
	out_names.sort()
	return out_names


## Salva o circuito com um nome. Retorna o nome usado ("" se falhou).
func save_circuit(circuit_name: String) -> String:
	var n := _safe_name(circuit_name)
	if n == "":
		return ""
	DirAccess.make_dir_recursive_absolute(CIRCUIT_DIR)
	var f := FileAccess.open("%s/%s.json" % [CIRCUIT_DIR, n], FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify({"versao": 1, "circuito": to_data(false)}, "  "))
	return n


func load_circuit(circuit_name: String) -> bool:
	var path := "%s/%s.json" % [CIRCUIT_DIR, _safe_name(circuit_name)]
	if not FileAccess.file_exists(path):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary) or not (d as Dictionary).has("circuito"):
		return false
	from_data(d["circuito"])
	return true


static func delete_circuit(circuit_name: String) -> void:
	DirAccess.remove_absolute("%s/%s.json" % [CIRCUIT_DIR, _safe_name(circuit_name)])

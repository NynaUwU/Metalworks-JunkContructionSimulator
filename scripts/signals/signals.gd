extends Node
## Autoload "Signals": nós de sinal e fios entre eles (estilo Wiremod).
##
## A cada tick de física (chamado pelo Build, antes de mexer nas juntas):
##   1. as fontes (controles, teclas, componentes, sensores) atualizam as saídas;
##   2. os outros nós (chips, telas) rodam na ordem dos fios. Num ciclo (ex.: um
##      latch realimentado), quem fecha o ciclo lê o valor do tick anterior.
## Lógica é de graça: sinais não gastam energia.

class Wire:
	var from_node: SignalNode
	var from_port := ""
	var to_node: SignalNode
	var to_port := ""
	var via: Array = []          ## isoladores (Part) por onde o fio passa
	## Onde o fio encosta: a peça e o ponto (local) clicados. Sem isso, no meio da peça.
	var a_part: Part = null
	var a_local := Vector3.ZERO
	var b_part: Part = null
	var b_local := Vector3.ZERO

	func type() -> String:
		return from_node.port_type(from_port, true)

	func value() -> Variant:
		return from_node.out.get(from_port, SignalNode.zero(type()))

	func is_valid() -> bool:
		return from_node != null and to_node != null and from_node.is_alive() and to_node.is_alive()


var nodes: Array = []            ## SignalNode
var wires: Array = []            ## Wire
var _order: Array = []           ## não-fontes, na ordem de avaliação
var _dirty := true


func reset() -> void:
	nodes.clear()
	wires.clear()
	_order.clear()
	_dirty = true


func register(n: SignalNode) -> void:
	if not nodes.has(n):
		nodes.append(n)
		_dirty = true


## Remove o nó e todos os fios dele.
func unregister(n: SignalNode) -> void:
	if n == null:
		return
	nodes.erase(n)
	wires = wires.filter(func(w: Wire) -> bool: return w.from_node != n and w.to_node != n)
	_dirty = true


## O nó de sinal de uma peça (componente, controle, chip, tela, assento...).
static func node_of(part: Part) -> SignalNode:
	if part == null or not is_instance_valid(part):
		return null
	if part.node:
		return part.node
	if part.mech:
		return part.mech
	if part.device:
		return part.device
	if part.has_meta("seat_base"):
		var base: Part = part.get_meta("seat_base")
		if is_instance_valid(base):
			return base.node
	return null


# --- Fios -------------------------------------------------------------------------

func find_wire(from: SignalNode, fp: String, to: SignalNode, tp: String) -> Wire:
	for w: Wire in wires:
		if w.from_node == from and w.from_port == fp and w.to_node == to and w.to_port == tp:
			return w
	return null


func is_linked(from: SignalNode, fp: String, to: SignalNode, tp: String) -> bool:
	return find_wire(from, fp, to, tp) != null


## Liga a saída `fp` de `from` à entrada `tp` de `to`. Retorna o fio (ou null se os
## tipos não combinam / é o mesmo nó).
func connect_ports(from: SignalNode, fp: String, to: SignalNode, tp: String, via: Array = [], pin_a: Array = [], pin_b: Array = []) -> Wire:
	if from == null or to == null or from == to:
		return null
	var t := from.port_type(fp, true)
	if t == "" or t != to.port_type(tp, false):
		return null
	var existing := find_wire(from, fp, to, tp)
	if existing:
		return existing
	var w := Wire.new()
	w.from_node = from
	w.from_port = fp
	w.to_node = to
	w.to_port = tp
	w.via = via.duplicate()
	if pin_a.size() == 2:
		w.a_part = pin_a[0]
		w.a_local = pin_a[1]
	if pin_b.size() == 2:
		w.b_part = pin_b[0]
		w.b_local = pin_b[1]
	wires.append(w)
	_dirty = true
	return w


func disconnect_wire(w: Wire) -> void:
	wires.erase(w)
	_dirty = true


## Liga, ou desliga se já estava ligado. Retorna true se ficou ligado.
func toggle(from: SignalNode, fp: String, to: SignalNode, tp: String, via: Array = [], pin_a: Array = [], pin_b: Array = []) -> bool:
	var w := find_wire(from, fp, to, tp)
	if w:
		disconnect_wire(w)
		return false
	return connect_ports(from, fp, to, tp, via, pin_a, pin_b) != null


func wires_into(n: SignalNode, port := "") -> Array:
	return wires.filter(func(w: Wire) -> bool: return w.to_node == n and (port == "" or w.to_port == port))


func wires_from(n: SignalNode, port := "") -> Array:
	return wires.filter(func(w: Wire) -> bool: return w.from_node == n and (port == "" or w.from_port == port))


## Isolador apagado: sai do caminho dos fios (o fio continua ligado).
func remove_via(ins: Part) -> void:
	for w: Wire in wires:
		w.via.erase(ins)


## Pontos do fio: saída → isoladores → entrada (o fio encosta no topo das peças).
func wire_points(w: Wire) -> PackedVector3Array:
	var pts := PackedVector3Array([end_point(w.a_part, w.a_local, w.from_node.signal_part())])
	for ins in w.via:
		if is_instance_valid(ins) and (ins as Part).is_inside_tree():
			pts.append(Components.wire_anchor(ins))
	pts.append(end_point(w.b_part, w.b_local, w.to_node.signal_part()))
	return pts


## Ponta do fio: no ponto clicado da peça (se houver), senão no meio da face de cima.
static func end_point(pin_part: Part, pin_local: Vector3, fallback: Part) -> Vector3:
	if pin_part != null and is_instance_valid(pin_part) and pin_part.is_inside_tree():
		return pin_part.global_transform * pin_local
	return anchor(fallback)


## Onde o fio encosta numa peça: no meio da face de cima (Y local).
static func anchor(p: Part) -> Vector3:
	var b := p.bounds
	var c := b.get_center()
	return p.global_transform * Vector3(c.x, b.end.y + 0.005, c.z)


# --- Valores ----------------------------------------------------------------------

## Valor atual de uma entrada (soma de números/vetores; primeiro fio nos outros tipos).
func input(n: SignalNode, port: String) -> Variant:
	var t := n.port_type(port, false)
	var v: Variant = SignalNode.zero(t)
	var first := true
	for w: Wire in wires:
		if w.to_node != n or w.to_port != port or not w.from_node.is_alive():
			continue
		var x: Variant = w.value()
		if t == SignalNode.NUM:
			v = float(v) + float(x)
		elif t == SignalNode.VEC:
			v = (v as Vector3) + (x as Vector3)
		elif first:
			v = x
		first = false
	return v


func has_input(n: SignalNode, port: String) -> bool:
	for w: Wire in wires:
		if w.to_node == n and w.to_port == port:
			return true
	return false


## Um tick de sinais.
func tick(dt: float) -> void:
	if _dirty:
		_cleanup()
		_sort()
	for n: SignalNode in nodes:
		if n.is_source() and n.is_alive():
			n.update_outputs(dt)
	for n: SignalNode in _order:
		if not n.is_alive():
			continue
		var inp := {}
		var wired := {}
		for p: Array in n.inputs():
			inp[p[0]] = SignalNode.zero(p[1])
		for w: Wire in wires:
			if w.to_node == n and w.from_node.is_alive():
				wired[w.to_port] = true
		for port: String in wired:
			inp[port] = input(n, port)
		n.evaluate(inp, wired, dt)


func _cleanup() -> void:
	nodes = nodes.filter(func(n: SignalNode) -> bool: return n.is_alive())
	wires = wires.filter(func(w: Wire) -> bool: return nodes.has(w.from_node) and nodes.has(w.to_node) \
		and w.from_node.port_type(w.from_port, true) != "" \
		and w.from_node.port_type(w.from_port, true) == w.to_node.port_type(w.to_port, false))


## Ordem de avaliação dos não-fontes (Kahn). Os que ficam em ciclo vão no fim.
func _sort() -> void:
	_dirty = false
	var pending: Array = nodes.filter(func(n: SignalNode) -> bool: return not n.is_source())
	var deps := {}
	for n in pending:
		deps[n] = {}
	for w: Wire in wires:
		if deps.has(w.to_node) and deps.has(w.from_node) and w.from_node != w.to_node:
			deps[w.to_node][w.from_node] = true
	_order = []
	var done := {}
	var progress := true
	while progress:
		progress = false
		for n in pending:
			if done.has(n):
				continue
			var ready := true
			for d in deps[n]:
				if not done.has(d):
					ready = false
					break
			if ready:
				done[n] = true
				_order.append(n)
				progress = true
	for n in pending:
		if not done.has(n):
			_order.append(n)

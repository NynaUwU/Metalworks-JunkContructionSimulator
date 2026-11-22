extends Node
## Autoload "Power": fios de energia e redes elétricas (Marco 4B).
##
## Uma REDE é tudo o que está ligado pelos fios de energia (relé/chave desligados
## cortam a passagem). A rede divide a mesma carga: as baterias dela enchem e esvaziam
## juntas, na proporção do tamanho.
##
## A cada tick de física (depois dos sinais), em cada rede:
##   1. o painel solar (grátis) alimenta as luzes;
##   2. o que faltar vem do posto de recarga (pago com pontos), se houver um ligado;
##   3. o que ainda faltar sai das baterias; sem carga, as luzes ficam mais fracas;
##   4. sobrando energia (sol, ou o posto com pontos), as baterias carregam.

const WH_PER_POINT := PowerNode.WH_PER_POINT

class PWire:
	var a: PowerNode
	var b: PowerNode
	var via: Array = []          ## isoladores (Part) por onde o fio passa
	var amps := 0.0              ## |potência| passando (W), para o desenho do fio

	func is_valid() -> bool:
		return a != null and b != null and a.is_alive() and b.is_alive()

	func other(n: PowerNode) -> PowerNode:
		return b if n == a else a


var nodes: Array = []            ## PowerNode
var wires: Array = []            ## PWire
var networks: Array = []         ## Array de Array[PowerNode] (último tick)
var sun_dir := Vector3(-0.35, -0.8, -0.5).normalized()   ## direção da luz do sol (o mundo acerta)


func reset() -> void:
	nodes.clear()
	wires.clear()
	networks.clear()


func register(n: PowerNode) -> void:
	if not nodes.has(n):
		nodes.append(n)


func unregister(n: PowerNode) -> void:
	nodes.erase(n)
	wires = wires.filter(func(w: PWire) -> bool: return w.a != n and w.b != n)


static func node_of(part: Part) -> PowerNode:
	if part == null or not is_instance_valid(part):
		return null
	return part.node as PowerNode


# --- Fios -------------------------------------------------------------------------

func find_wire(a: PowerNode, b: PowerNode) -> PWire:
	for w: PWire in wires:
		if (w.a == a and w.b == b) or (w.a == b and w.b == a):
			return w
	return null


func connect_nodes(a: PowerNode, b: PowerNode, via: Array = []) -> PWire:
	if a == null or b == null or a == b:
		return null
	var existing := find_wire(a, b)
	if existing:
		return existing
	var w := PWire.new()
	w.a = a
	w.b = b
	w.via = via.duplicate()
	wires.append(w)
	return w


## Liga, ou desliga se já estava ligado. Retorna true se ficou ligado.
func toggle(a: PowerNode, b: PowerNode, via: Array = []) -> bool:
	var w := find_wire(a, b)
	if w:
		wires.erase(w)
		return false
	return connect_nodes(a, b, via) != null


func wires_of(n: PowerNode) -> Array:
	return wires.filter(func(w: PWire) -> bool: return w.a == n or w.b == n)


func remove_via(ins: Part) -> void:
	for w: PWire in wires:
		w.via.erase(ins)


func wire_points(w: PWire) -> PackedVector3Array:
	var pts := PackedVector3Array([Signals.anchor(w.a.signal_part())])
	for ins in w.via:
		if is_instance_valid(ins) and (ins as Part).is_inside_tree():
			pts.append(Components.wire_anchor(ins))
	pts.append(Signals.anchor(w.b.signal_part()))
	return pts


# --- Redes ------------------------------------------------------------------------

## Redes atuais: grupos de nós ligados por fio (relé/chave desligados não deixam passar).
func compute_networks() -> Array:
	var alive: Array = nodes.filter(func(n: PowerNode) -> bool: return n.is_alive())
	var parent := {}
	for n in alive:
		parent[n] = n
	var find := func(x: PowerNode) -> PowerNode:
		var r: PowerNode = x
		while parent[r] != r:
			r = parent[r]
		var y: PowerNode = x
		while parent[y] != r:
			var nx: PowerNode = parent[y]
			parent[y] = r
			y = nx
		return r
	for w: PWire in wires:
		if not w.is_valid() or not parent.has(w.a) or not parent.has(w.b) or w.a.blocks() or w.b.blocks():
			continue
		var ra: PowerNode = find.call(w.a)
		var rb: PowerNode = find.call(w.b)
		if ra != rb:
			parent[ra] = rb
	var groups := {}
	for n in alive:
		var r: PowerNode = find.call(n)
		if not groups.has(r):
			groups[r] = []
		groups[r].append(n)
	return groups.values()


## A rede de um nó (último tick).
func network_of(n: PowerNode) -> Array:
	for g: Array in networks:
		if g.has(n):
			return g
	return [n]


## Um tick de energia.
func tick(dt: float) -> void:
	wires = wires.filter(func(w: PWire) -> bool: return w.is_valid())
	if nodes.is_empty():
		networks = []
		return
	networks = compute_networks()
	var dt_h := dt / 3600.0
	var stats_of := {}
	for g: Array in networks:
		stats_of[g] = _solve(g, dt, dt_h)
	# Fios acesos: passa energia se a rede está consumindo ou carregando.
	for w: PWire in wires:
		var g := network_of(w.a)
		var st: Dictionary = stats_of.get(g, {})
		w.amps = float(st.get("flow", 0.0)) if g.has(w.b) else 0.0
	for n: PowerNode in nodes:
		if n.is_alive():
			n.update_visual()


## Resolve uma rede: quem gera, quem consome e quanto as baterias carregam.
func _solve(g: Array, dt: float, dt_h: float) -> Dictionary:
	var demand := 0.0
	var free := 0.0
	var grid_max := 0.0
	var capacity := 0.0
	var charge := 0.0
	var batteries: Array = []
	var grids: Array = []
	for n: PowerNode in g:
		demand += n.demand_w()
		var f := n.free_w()
		free += f
		if n.kind == "solar" or n.kind == "gerador":
			n.power_w = f
		if n.grid_ready():
			grid_max += PowerNode.GRID_W
			grids.append(n)
		if n.kind == "bateria":
			capacity += n.capacity()
			charge += n.charge
			batteries.append(n)
	var room_w := (capacity - charge) / dt_h if dt_h > 0.0 else 0.0
	# 1) sol nas cargas; 2) posto (pago) no que falta; 3) baterias.
	var from_sun := minf(free, demand)
	var missing := demand - from_sun
	var grid_cap := grid_max
	if grid_cap > 0.0:
		# Só usa o posto se houver pontos para pagar.
		var affordable := Economy.precise_points() * WH_PER_POINT / dt_h if dt_h > 0.0 else 0.0
		grid_cap = minf(grid_cap, affordable)
	var from_grid := minf(grid_cap, missing)
	missing -= from_grid
	var batt_w := charge / dt_h if dt_h > 0.0 else (INF if charge > 0.0 else 0.0)
	var from_batt := minf(missing, batt_w)
	missing -= from_batt
	var satisfaction := 1.0 if demand <= 0.0 else clampf((demand - missing) / demand, 0.0, 1.0)
	# Sobra: sol que não foi usado, e o posto enche as baterias.
	var spare_sun := free - from_sun
	var to_batt := minf(spare_sun, room_w)
	var grid_charge := minf(grid_cap - from_grid, room_w - to_batt)
	grid_charge = maxf(grid_charge, 0.0)
	to_batt += grid_charge
	var grid_used := from_grid + grid_charge
	if grid_used > 0.0:
		Economy.add(-grid_used * dt_h / WH_PER_POINT)
	charge = clampf(charge + (to_batt - from_batt) * dt_h, 0.0, capacity)
	# A carga é dividida entre as baterias da rede, na proporção do tamanho.
	for bnode: PowerNode in batteries:
		bnode.charge = charge * bnode.capacity() / capacity if capacity > 0.0 else 0.0
	for gnode: PowerNode in grids:
		gnode.power_w = grid_used / grids.size()
	var stats := {
		"charge": charge, "capacity": capacity, "percent": 100.0 * charge / capacity if capacity > 0.0 else 0.0,
		"demand": demand * satisfaction, "generation": free + grid_used, "flow": maxf(demand * satisfaction, to_batt),
	}
	for n: PowerNode in g:
		n.supply = satisfaction
		if n.kind in ["luz", "holofote"]:
			n.power_w = n.demand_w() * satisfaction
			n.out["Acesa"] = n.want * satisfaction
		if n.kind == "medidor":
			n.net = stats
	return stats

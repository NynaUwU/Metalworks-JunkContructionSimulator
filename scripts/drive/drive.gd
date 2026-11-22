extends Node
## Autoload "Drive": ligações de transmissão e simulação do trem de força (Marco 4D,
## estilo ACF). As ligações são invisíveis (a ferramenta Transmissão mostra) e livres:
## qualquer peça do trem de força liga em qualquer outra, a qualquer distância. A
## simulação usa as que fazem sentido (sem direção) e ignora o resto:
##   tanque ↔ motor (mesmo combustível) · bateria ↔ motor elétrico · motor ↔ gerador
##   motor ↔ embreagem ↔ câmbio (ou motor ↔ câmbio direto: sem embreagem, preso às rodas)
##   câmbio ↔ cubos de roda (o giro e o lado de cada cubo são ajustados nele)
## Ligação esticada além de 1,5× o comprimento de quando foi feita, quebra.
##
## A cada tick (depois dos sinais e da energia), para cada motor:
##   - liga/desliga (entrada Ligado ou sozinho; sem combustível, desliga);
##   - torque pela curva × acelerador (com marcha lenta automática e corte de giro);
##   - a embreagem (automática: pelo giro; manual: pelo Pedal) liga o giro do motor ao das
##     rodas: os cubos recebem a velocidade que o motor quer (giro ÷ relação) com torque
##     limitado pela embreagem; o motor sente a carga pela diferença de giro (patinação);
##   - freio, marchas (manual, automático, CVT) e esterço de tanque no câmbio;
##   - consumo de combustível (ou bateria, no elétrico) e o gerador.

signal link_broken(at: Vector3)

const STRETCH := 1.5              ## quebra se esticar mais que isso
const SLIP_BAND := 40.0           ## rad/s de patinação para a embreagem passar tudo
const CLUTCH_CAP := 2.5           ## embreagem aguenta 2,5× o torque máximo do motor
const BRAKE_TORQUE := 900.0       ## freio por cubo (N·m)
const SHIFT_COOLDOWN := 0.6

class DLink:
	var a: Object                ## onde o jogador clicou primeiro
	var b: Object
	var rest := 1.0              ## distância quando foi ligada

var links: Array = []
var _driven := {}                ## cubos acionados neste tick


func reset() -> void:
	links.clear()


## Peça onde a ligação encosta.
static func part_of(o: Object) -> Part:
	if o is DriveNode:
		return (o as DriveNode).part
	if o is PowerNode:
		return (o as PowerNode).part
	if o is MechJoint:
		return (o as MechJoint).part_a
	return null


static func alive(o: Object) -> bool:
	var p := part_of(o)
	return p != null and is_instance_valid(p) and p.is_inside_tree() and not p.is_queued_for_deletion() \
		and (not (o is MechJoint) or (o as MechJoint).is_valid())


## O que a ferramenta Transmissão liga numa peça: tanque, motor, embreagem, câmbio, bateria,
## gerador ou cubo de roda.
static func node_of(part: Part) -> Object:
	if part == null or not is_instance_valid(part):
		return null
	if part.node is DriveNode:
		return part.node
	if part.node is PowerNode and (part.node as PowerNode).kind in ["bateria", "gerador"]:
		return part.node
	if part.mech and part.mech.type == "cubo":
		return part.mech
	return null


static func describe(o: Object) -> String:
	if o is DriveNode:
		return (o as DriveNode).title()
	if o is PowerNode:
		return (o as PowerNode).title()
	if o is MechJoint:
		return "Cubo de roda"
	return "?"


## Liga qualquer peça em qualquer outra (só não liga uma peça nela mesma).
func check_link(x: Object, y: Object) -> Dictionary:
	if x == null or y == null or x == y:
		return {"ok": false, "msg": "Clique em outra peça"}
	return {"ok": true, "from": x, "to": y, "msg": ""}


## Diz se a ligação vai fazer algo (só para a dica da ferramenta).
static func link_meaning(x: Object, y: Object) -> String:
	for pair: Array in [[x, y], [y, x]]:
		var a: Object = pair[0]
		var b: Object = pair[1]
		if a is DriveNode and (a as DriveNode).is_tank() and b is DriveNode and (b as DriveNode).is_engine():
			return "combustível" if (a as DriveNode).fuel_type() == (b as DriveNode).fuel_type() else "(combustível diferente: não abastece)"
		if a is PowerNode and (a as PowerNode).kind == "bateria" and b is DriveNode and (b as DriveNode).kind == "motor_eletrico":
			return "energia do motor elétrico"
		if a is DriveNode and (a as DriveNode).is_engine() and b is PowerNode and (b as PowerNode).kind == "gerador":
			return "gerador"
		if a is DriveNode and (a as DriveNode).is_engine() and b is DriveNode and (b as DriveNode).is_clutch():
			return "motor → embreagem"
		if a is DriveNode and (a as DriveNode).is_engine() and b is DriveNode and (b as DriveNode).is_gearbox():
			return "motor → câmbio (sem embreagem: preso às rodas)"
		if a is DriveNode and (a as DriveNode).is_clutch() and b is DriveNode and (b as DriveNode).is_gearbox():
			return "embreagem → câmbio"
		if a is DriveNode and (a as DriveNode).is_gearbox() and b is MechJoint:
			return "câmbio → roda"
		if a is DriveNode and (a as DriveNode).is_transfer():
			return "caixa de transferência (alta/reduzida)"
		if a is DriveNode and (a as DriveNode).is_diff():
			return "diferencial (rodas giram diferente nas curvas)"
	return "(essa ligação não faz nada)"


func find_link(a: Object, b: Object) -> DLink:
	for l: DLink in links:
		if (l.a == a and l.b == b) or (l.a == b and l.b == a):
			return l
	return null


## Liga ou desliga. Retorna {"linked": bool, "msg"}.
func toggle(x: Object, y: Object) -> Dictionary:
	var existing := find_link(x, y)
	if existing:
		links.erase(existing)
		return {"linked": false, "msg": "Ligação removida"}
	var c := check_link(x, y)
	if not c["ok"]:
		return {"linked": false, "msg": c["msg"]}
	link(x, y)
	return {"linked": true, "msg": "Transmissão: %s → %s %s" % [describe(x), describe(y), link_meaning(x, y)]}


func link(a: Object, b: Object) -> DLink:
	var l := DLink.new()
	l.a = a
	l.b = b
	l.rest = maxf(part_of(a).global_position.distance_to(part_of(b).global_position), 0.3)
	links.append(l)
	return l


func links_of(o: Object) -> Array:
	return links.filter(func(l: DLink) -> bool: return l.a == o or l.b == o)


## Tudo o que está ligado em `o` (as ligações não têm direção).
func neighbors(o: Object) -> Array:
	var out: Array = []
	for l: DLink in links:
		if l.a == o and alive(l.b):
			out.append(l.b)
		elif l.b == o and alive(l.a):
			out.append(l.a)
	return out


# --- Tick ------------------------------------------------------------------------------

func tick(dt: float) -> void:
	if links.is_empty() and not _has_engines():
		return
	# Ligações mortas ou esticadas.
	for l: DLink in links.duplicate():
		if not alive(l.a) or not alive(l.b):
			links.erase(l)
			continue
		var pa := part_of(l.a).global_position
		var pb := part_of(l.b).global_position
		if pa.distance_to(pb) > maxf(l.rest * STRETCH, l.rest + 0.5):
			links.erase(l)
			link_broken.emit((pa + pb) * 0.5)
	_driven.clear()
	for n in Signals.nodes:
		if n is DriveNode and (n as DriveNode).is_engine() and (n as DriveNode).is_alive():
			_engine_tick(n as DriveNode, dt)
		elif n is DriveNode and (n as DriveNode).is_alive():
			(n as DriveNode).update_visual()
	# Cubos sem câmbio (ou desligados dele): eixo livre.
	for j in Build.joints:
		if j.type == "cubo" and j.is_valid() and not _driven.has(j):
			j.drive_spin(0.0, 0.0, dt)


func _has_engines() -> bool:
	for n in Signals.nodes:
		if n is DriveNode and (n as DriveNode).is_engine():
			return true
	return false


## Tudo o que está ligado ao motor, por qualquer caminho (sem passar por outro motor).
## Para cada cubo: os câmbios e embreagens do caminho. Retorna
## {"hubs": [{"j", "gbs", "clutches"}], "gens", "fuel", "gearboxes": {câmbio: [cubos]}}.
func explore(e: DriveNode) -> Dictionary:
	var electric: bool = e.spec()["fuel"] == "eletrico"
	var out := {"hubs": [], "gens": [], "fuel": [], "gearboxes": {}}
	var seen := {e: true}
	var queue: Array = [[e, [], []]]
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var node: Object = item[0]
		var gbs: Array = item[1]
		var clutches: Array = item[2]
		for o in neighbors(node):
			if seen.has(o):
				continue
			seen[o] = true
			if o is DriveNode and (o as DriveNode).is_engine():
				continue                                   # outro motor: não passa
			if o is PowerNode:
				var pn := o as PowerNode
				if pn.kind == "gerador":
					out["gens"].append(pn)
				elif pn.kind == "bateria" and electric:
					out["fuel"].append(pn)
				continue
			var d := o as DriveNode
			if d and d.is_tank():
				if not electric and d.fuel_type() == e.fuel_type():
					out["fuel"].append(d)
				continue
			var ngbs := gbs
			var ncl := clutches
			if d and d.is_gearbox():
				ngbs = gbs + [d]
				if not out["gearboxes"].has(d):
					out["gearboxes"][d] = []
			elif d and d.is_splitter():
				ngbs = gbs + [d]                            # transferência/diferencial: só a relação
			elif d and d.is_clutch():
				ncl = clutches + [d]
			elif o is MechJoint and (o as MechJoint).type == "cubo":
				var diff: DriveNode = null
				for g: DriveNode in gbs:
					if g.is_diff():
						diff = g                            # o diferencial mais perto da roda
				var entry := {"j": o, "gbs": gbs, "clutches": clutches, "diff": diff}
				out["hubs"].append(entry)
				for g in gbs:
					if out["gearboxes"].has(g):
						out["gearboxes"][g].append(entry)
			queue.append([o, ngbs, ncl])                    # passa por câmbios, divisores, embreagens e cubos
	return out


func _engine_tick(e: DriveNode, dt: float) -> void:
	var s := e.spec()
	var electric: bool = s["fuel"] == "eletrico"
	var net := explore(e)
	var tanks: Array = net["fuel"]
	var has_fuel := false
	for t in tanks:
		if (t is DriveNode and (t as DriveNode).fuel > 0.0) or (t is PowerNode and (t as PowerNode).charge > 0.0):
			has_fuel = true
			break
	var on := e.wants_on() and has_fuel
	if on and not e.running:
		e.omega = maxf(e.omega, e.idle_omega() * 0.7)     # motor de partida
	e.running = on
	var idle := e.idle_omega()
	var thr := e.throttle
	for gb: DriveNode in net["gearboxes"]:
		if gb.tank_steer:
			# Virando um tanque parado: o câmbio acelera um pouco sozinho.
			thr = maxf(thr, absf(_steer_of(gb)) * 0.7)
	if e.running and not electric and e.omega < idle:
		thr = maxf(thr, clampf((idle - e.omega) / maxf(idle * 0.15, 1.0), 0.0, 1.0))   # marcha lenta
	var te := e.engine_torque(e.omega, thr) if e.running else 0.0
	# Geradores
	var t_gen := 0.0
	for g: PowerNode in net["gens"]:
		var p := DriveNode.GEN_W * clampf(e.omega / maxf(idle * 2.5, 50.0), 0.0, 1.0) if e.running else 0.0
		g.drive_w = p
		t_gen += p / maxf(e.omega, 1.0)
	# Rodas
	var t_clutch := _drive_hubs(e, net, dt)
	var fric := e.engine_friction(e.omega) if e.omega > 0.0 else 0.0
	e.omega = maxf(e.omega + (te - t_clutch - t_gen - fric) / maxf(s["fly"] * e.size_scale, 0.001) * dt, 0.0)
	if not e.running and e.omega < 1.0:
		e.omega = 0.0
	e.torque_out = te
	e.load = t_clutch + t_gen
	# Consumo
	var p_out := maxf(te * e.omega, 0.0)
	if e.running:
		if electric:
			var wh := p_out / 0.9 * dt / 3600.0
			e.fuel_rate = p_out / 0.9
			for t in tanks:
				var b := t as PowerNode
				var take := minf(b.charge, wh)
				b.charge -= take
				wh -= take
		else:
			var lh := (p_out / 1000.0 + float(s["torque"]) * e.size_scale * idle * 0.002) * DriveNode.LITERS_PER_KWH
			e.fuel_rate = lh
			var liters := lh * dt / 3600.0
			for t in tanks:
				var tk := t as DriveNode
				var take := minf(tk.fuel, liters)
				tk.fuel -= take
				liters -= take
	else:
		e.fuel_rate = 0.0
	e.out["RPM"] = e.rpm()
	e.out["Torque"] = te
	e.out["Potência"] = p_out / 1000.0
	e.out["Consumo"] = e.fuel_rate
	e.out["Ligado"] = 1.0 if e.running else 0.0
	e.update_visual()
	e.update_sound()


static func _steer_of(gb: DriveNode) -> float:
	var i := gb.inp
	return clampf(float(i.get("Esterço", 0.0)) + float(i.get("Dir", 0.0)) - float(i.get("Esq", 0.0)), -1.0, 1.0)


## Marchas de um câmbio (manual, automático, CVT, ré). `w_avg`: giro das rodas dele (para a
## frente). Retorna true se precisa frear sozinho (pediu o sentido contrário andando).
func _gear_logic(gb: DriveNode, e: DriveNode, w_avg: float, dt: float) -> bool:
	var i := gb.inp
	gb._shift_cool = maxf(gb._shift_cool - dt, 0.0)
	var up := float(i.get("Sobe", 0.0)) > 0.5
	var down := float(i.get("Desce", 0.0)) > 0.5
	var want_rev := float(i.get("Ré", 0.0)) > 0.5
	var auto_brake := false
	if bool(i.get("_marcha_wired", false)):
		gb.gear = clampi(roundi(float(i.get("Marcha", 0.0))), -1, gb.gears)
	elif want_rev:
		if gb.gear >= 0:
			if absf(w_avg) < 2.0:
				gb.gear = -1
			else:
				auto_brake = true
	else:
		if gb.gear < 0:
			if absf(w_avg) < 2.0:
				gb.gear = 1
			elif e.throttle > 0.05:
				auto_brake = true
		if up and not gb._prev_up and gb.gear < gb.gears:
			gb.gear += 1
		if down and not gb._prev_down and gb.gear > (0 if gb.kind == "cambio_manual" else 1):
			gb.gear -= 1
		if gb.kind == "cambio_auto" and gb.gear > 0 and gb._shift_cool <= 0.0:
			if e.omega > e.red_omega() * gb.shift_up_frac and gb.gear < gb.gears:
				gb.gear += 1
				gb._shift_cool = SHIFT_COOLDOWN
			elif gb.gear > 1:
				var prev_ratio := gb.gear_ratio(gb.gear - 1) * gb.final_drive
				if absf(w_avg) * prev_ratio < e.red_omega() * gb.shift_up_frac * 0.6:
					gb.gear -= 1
					gb._shift_cool = SHIFT_COOLDOWN
		if gb.kind == "cvt" and gb.gear > 0:
			# CVT: escolhe a relação que deixa o motor no giro de mais força.
			var peak_rpm: float = e.spec()["peak"] if float(e.spec()["peak"]) > 0.0 else float(e.spec()["red"]) * 0.5
			var best: float = peak_rpm * TAU / 60.0
			gb.cvt_ratio = clampf(best / maxf(absf(w_avg) * gb.final_drive, 0.1), gb.top_ratio, gb.first_ratio)
	gb._prev_up = up
	gb._prev_down = down
	return auto_brake


## Aciona os cubos ligados ao motor (por qualquer caminho) e devolve o torque que as
## embreagens tiram do motor. Relação de cada cubo = produto dos câmbios do caminho (sem
## câmbio: direto, 1:1). Embreagem: a mais desengatada do caminho (sem embreagem: preso).
func _drive_hubs(e: DriveNode, net: Dictionary, dt: float) -> float:
	var hubs: Array = net["hubs"]
	var idle := e.idle_omega()
	var t_peak := float(e.spec()["torque"]) * e.size_scale
	var t_cap := t_peak * CLUTCH_CAP
	var launch := maxf(float(e.spec()["peak"]) * 0.6 * TAU / 60.0, idle * 1.6)
	var t_auto := t_cap if e.spec()["fuel"] == "eletrico" else clampf(t_peak * (e.omega - idle * 1.1) / maxf(launch - idle * 1.1, 1.0), 0.0, t_cap)
	# Giro (para a frente) de cada cubo; giro médio das rodas de cada câmbio; marchas.
	for h: Dictionary in hubs:
		var j: MechJoint = h["j"]
		h["sign"] = -1.0 if j.invert else 1.0          # ajustado no cubo (Inverter o giro)
		h["w"] = float(h["sign"]) * j.spin()
	var brakes := {}
	for gb: DriveNode in net["gearboxes"]:
		var mine: Array = net["gearboxes"][gb]
		var sum := 0.0
		for h: Dictionary in mine:
			sum += float(h["w"])
		var w_avg := sum / mine.size() if not mine.is_empty() else 0.0
		gb.wheel_speed = w_avg
		brakes[gb] = 1.0 if _gear_logic(gb, e, w_avg, dt) else clampf(float(gb.inp.get("Freio", 0.0)), 0.0, 1.0)
		gb.out["Marcha"] = float(gb.gear)
		gb.out["Relação"] = gb.total_ratio()
		gb.out["Giro das rodas"] = w_avg
	if hubs.is_empty():
		return 0.0
	# Diferenciais abertos: giro médio das rodas de cada um (as rodas podem girar diferente,
	# mas a média segue o motor).
	var diff_mean := {}
	var diff_span := {}
	for h: Dictionary in hubs:
		var df: DriveNode = h.get("diff")
		if df == null:
			continue
		if not diff_mean.has(df):
			diff_mean[df] = [0.0, 0]
			diff_span[df] = [INF, -INF]
		diff_mean[df][0] += float(h["w"])
		diff_mean[df][1] += 1
		diff_span[df][0] = minf(diff_span[df][0], float(h["w"]))
		diff_span[df][1] = maxf(diff_span[df][1], float(h["w"]))
	for df: DriveNode in diff_mean:
		diff_mean[df] = float(diff_mean[df][0]) / maxf(float(diff_mean[df][1]), 1.0)
		df.out["Diferença"] = float(diff_span[df][1]) - float(diff_span[df][0])
		df.update_visual()
	var n := float(hubs.size())
	var t_clutch := 0.0
	var clutch_shown := {}
	for h: Dictionary in hubs:
		var j: MechJoint = h["j"]
		var ratio := 1.0
		var brake := 0.0
		var steer := 0.0
		var tank := false
		var tank_w := 0.0
		for gb: DriveNode in h["gbs"]:
			ratio *= gb.total_ratio()
			brake = maxf(brake, float(brakes.get(gb, 0.0)))
			if gb.tank_steer and not tank:
				tank = true
				steer = _steer_of(gb)
				tank_w = gb.wheel_speed
		# Embreagens do caminho
		var t_eng := t_cap
		for c: DriveNode in h["clutches"]:
			var tc := t_auto if c.kind == "embreagem_auto" else t_cap * (1.0 - clampf(c.pedal, 0.0, 1.0))
			t_eng = minf(t_eng, tc)
		if tank:
			# Esterço: engata mesmo parado, sem afogar o motor abaixo da marcha lenta.
			var keep := 1.0 if e.spec()["fuel"] == "eletrico" else clampf((e.omega - idle * 0.9) / maxf(idle * 0.5, 1.0), 0.0, 1.0)
			t_eng = maxf(t_eng, absf(steer) * t_peak * keep)
		if absf(ratio) < 1e-4 or not e.running:
			t_eng = 0.0
		t_eng *= (1.0 - brake)
		for c: DriveNode in h["clutches"]:
			clutch_shown[c] = t_eng / maxf(t_cap, 0.001)
		if brake > 0.01:
			j.drive_spin(0.0, brake * BRAKE_TORQUE * j.size_scale, dt)
			_driven[j] = true
			continue
		# Esterço de tanque: a carga do motor vem do giro médio (um lado anda para trás).
		# Diferencial aberto: a carga vem do giro médio das rodas dele.
		var df: DriveNode = h.get("diff")
		var open := df != null and not df.locked and not tank
		var w := tank_w if tank else (float(diff_mean[df]) if open else float(h["w"]))
		var slip := e.omega - ratio * w
		t_clutch += t_eng / n * clampf(slip / SLIP_BAND, -1.0, 1.0)
		var mult := 1.0
		if tank:
			# Esterço + vira para a direita: o lado esquerdo anda mais (parado: gira no lugar).
			var moving := 1.0 if (e.throttle > 0.05 or absf(tank_w) > 0.5) else 0.0
			mult = moving + steer if j.hub_side < 0 else moving - steer
		var target := e.omega / ratio * mult if absf(ratio) > 1e-4 else 0.0
		if open:
			target = float(h["w"]) + (target - float(diff_mean[df]))   # cada roda no seu giro; a média segue o motor
		j.drive_spin(float(h["sign"]) * target, t_eng * absf(ratio) / n * (1.0 + absf(steer)), dt)
		_driven[j] = true
		for c: DriveNode in h["clutches"]:
			c.out["Patinação"] = slip * 60.0 / TAU
	for c: DriveNode in clutch_shown:
		c.engage_shown = clutch_shown[c]
		c.out["Engate"] = clutch_shown[c]
	return t_clutch


## Posto de combustível: enche os tanques num raio. Retorna {"liters", "cost"}.
func refuel(center: Vector3, radius: float, price_per_liter: float) -> Dictionary:
	var liters := 0.0
	var cost := 0.0
	for n in Signals.nodes:
		var t := n as DriveNode
		if t == null or not t.is_tank() or not t.is_alive():
			continue
		if t.part.global_position.distance_to(center) > radius:
			continue
		var room := t.capacity() - t.fuel
		var afford := Economy.precise_points() / price_per_liter if price_per_liter > 0.0 else room
		var put := minf(room, afford)
		if put <= 0.0:
			continue
		t.fuel += put
		liters += put
		Economy.add(-put * price_per_liter)
		cost += put * price_per_liter
		t.update_visual()
	return {"liters": liters, "cost": cost}

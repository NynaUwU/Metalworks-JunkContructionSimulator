extends Node
## Autoload "Drive": ligações de transmissão e simulação do trem de força (Marco 4D,
## estilo ACF). As ligações são invisíveis (a ferramenta Transmissão mostra):
##   tanque → motor (mesmo combustível) · bateria → motor elétrico
##   motor → câmbio (um para um) · motor → gerador
##   câmbio → cubo de roda (vários; lado esquerdo/direito pela posição)
## Ligação esticada além de 1,5× o comprimento de quando foi feita, quebra.
##
## A cada tick (depois dos sinais e da energia), para cada motor:
##   - liga/desliga (entrada Ligado ou sozinho; sem combustível, desliga);
##   - torque pela curva × acelerador (com marcha lenta automática e corte de giro);
##   - a embreagem (automática acima da marcha lenta) liga o giro do motor ao das rodas:
##     os cubos recebem a velocidade que o motor quer (giro ÷ relação) com torque limitado
##     pela embreagem; o motor sente a carga pela diferença de giro (patinação);
##   - freio, marchas (manual, automático, CVT) e esterço de tanque no câmbio;
##   - consumo de combustível (ou bateria, no elétrico) e o gerador.

signal link_broken(at: Vector3)

const MAX_LINK := 8.0             ## distância máxima ao ligar (m)
const STRETCH := 1.5              ## quebra se esticar mais que isso
const SLIP_BAND := 40.0           ## rad/s de patinação para a embreagem passar tudo
const CLUTCH_CAP := 2.5           ## embreagem aguenta 2,5× o torque máximo do motor
const BRAKE_TORQUE := 900.0       ## freio por cubo (N·m)
const SHIFT_COOLDOWN := 0.6

class DLink:
	var a: Object                ## origem (tanque, bateria, motor, câmbio)
	var b: Object                ## destino (motor, câmbio, gerador, cubo)
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


## O que a ferramenta Transmissão liga numa peça (nó do trem de força, bateria, gerador ou cubo).
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


## Ordena (origem, destino) e diz se pode ligar: {"ok", "from", "to", "msg"}.
func check_link(x: Object, y: Object) -> Dictionary:
	for pair: Array in [[x, y], [y, x]]:
		var a: Object = pair[0]
		var b: Object = pair[1]
		var msg := _rule(a, b)
		if msg == "":
			var dist := part_of(a).global_position.distance_to(part_of(b).global_position)
			if dist > MAX_LINK:
				return {"ok": false, "msg": "Longe demais (%.1f m; até %d m)" % [dist, roundi(MAX_LINK)]}
			return {"ok": true, "from": a, "to": b, "msg": ""}
	return {"ok": false, "msg": "Essa ligação não existe. Liga: tanque → motor, bateria → motor elétrico, motor → câmbio, motor → gerador, câmbio → cubo"}


func _rule(a: Object, b: Object) -> String:
	if a is DriveNode and (a as DriveNode).is_tank() and b is DriveNode and (b as DriveNode).is_engine():
		return "" if (a as DriveNode).fuel_type() == (b as DriveNode).fuel_type() else "x"
	if a is PowerNode and (a as PowerNode).kind == "bateria" and b is DriveNode and (b as DriveNode).kind == "motor_eletrico":
		return ""
	if a is DriveNode and (a as DriveNode).is_engine():
		if b is DriveNode and (b as DriveNode).is_gearbox():
			return ""
		if b is PowerNode and (b as PowerNode).kind == "gerador":
			return ""
	if a is DriveNode and (a as DriveNode).is_gearbox() and b is MechJoint and (b as MechJoint).type == "cubo":
		return ""
	return "x"


func find_link(a: Object, b: Object) -> DLink:
	for l: DLink in links:
		if (l.a == a and l.b == b) or (l.a == b and l.b == a):
			return l
	return null


## Liga (na ordem certa) ou desliga. Retorna {"linked": bool, "msg"}.
func toggle(x: Object, y: Object) -> Dictionary:
	var existing := find_link(x, y)
	if existing:
		links.erase(existing)
		return {"linked": false, "msg": "Ligação removida"}
	var c := check_link(x, y)
	if not c["ok"]:
		return {"linked": false, "msg": c["msg"]}
	var a: Object = c["from"]
	var b: Object = c["to"]
	# Um motor por câmbio; um câmbio por motor; um câmbio por cubo.
	if b is DriveNode and (b as DriveNode).is_gearbox() and not sources_of(b, "engine").is_empty():
		return {"linked": false, "msg": "Esse câmbio já tem motor"}
	if a is DriveNode and (a as DriveNode).is_engine() and b is DriveNode and (b as DriveNode).is_gearbox() and gearbox_of(a) != null:
		return {"linked": false, "msg": "Esse motor já tem câmbio"}
	if b is MechJoint and not sources_of(b, "gearbox").is_empty():
		return {"linked": false, "msg": "Esse cubo já está ligado num câmbio"}
	link(a, b)
	return {"linked": true, "msg": "Transmissão: %s → %s" % [describe(a), describe(b)]}


func link(a: Object, b: Object) -> DLink:
	var l := DLink.new()
	l.a = a
	l.b = b
	l.rest = maxf(part_of(a).global_position.distance_to(part_of(b).global_position), 0.3)
	links.append(l)
	return l


func links_of(o: Object) -> Array:
	return links.filter(func(l: DLink) -> bool: return l.a == o or l.b == o)


## Quem liga em `o`, filtrando: "engine", "gearbox", "tank", "battery".
func sources_of(o: Object, what: String) -> Array:
	var out: Array = []
	for l: DLink in links:
		if l.b != o:
			continue
		var s: Object = l.a
		match what:
			"engine":
				if s is DriveNode and (s as DriveNode).is_engine():
					out.append(s)
			"gearbox":
				if s is DriveNode and (s as DriveNode).is_gearbox():
					out.append(s)
			"tank":
				if s is DriveNode and (s as DriveNode).is_tank():
					out.append(s)
			"battery":
				if s is PowerNode:
					out.append(s)
	return out


func targets_of(o: Object) -> Array:
	return links.filter(func(l: DLink) -> bool: return l.a == o).map(func(l: DLink) -> Object: return l.b)


func gearbox_of(engine: Object) -> DriveNode:
	for t in targets_of(engine):
		if t is DriveNode and (t as DriveNode).is_gearbox():
			return t
	return null


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


func _engine_tick(e: DriveNode, dt: float) -> void:
	var s := e.spec()
	var electric: bool = s["fuel"] == "eletrico"
	var tanks := sources_of(e, "battery") if electric else sources_of(e, "tank")
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
	var gb0 := gearbox_of(e)
	if gb0 and gb0.tank_steer:
		# Virando um tanque parado: o câmbio acelera um pouco sozinho.
		var st := clampf(float(gb0.inp.get("Esterço", 0.0)) + float(gb0.inp.get("Dir", 0.0)) - float(gb0.inp.get("Esq", 0.0)), -1.0, 1.0)
		thr = maxf(thr, absf(st) * 0.7)
	if e.running and not electric and e.omega < idle:
		thr = maxf(thr, clampf((idle - e.omega) / maxf(idle * 0.15, 1.0), 0.0, 1.0))   # marcha lenta
	var te := e.engine_torque(e.omega, thr) if e.running else 0.0
	# Gerador
	var t_gen := 0.0
	for g in targets_of(e):
		if g is PowerNode and (g as PowerNode).kind == "gerador":
			var p := DriveNode.GEN_W * clampf(e.omega / maxf(idle * 2.5, 50.0), 0.0, 1.0) if e.running else 0.0
			(g as PowerNode).drive_w = p
			t_gen += p / maxf(e.omega, 1.0)
	# Câmbio e rodas
	var gb := gearbox_of(e)
	var t_clutch := 0.0
	if gb:
		t_clutch = _gearbox_tick(gb, e, dt)
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


## Marchas, embreagem, freio e esterço. Aciona os cubos e devolve o torque que a embreagem
## tira do motor.
func _gearbox_tick(gb: DriveNode, e: DriveNode, dt: float) -> float:
	var i := gb.inp
	var hubs: Array = targets_of(gb).filter(func(o: Object) -> bool: return o is MechJoint and (o as MechJoint).is_valid())
	var b := gb.part.global_basis.orthonormalized()
	var fwd_axis := b.y.cross(-b.z)                    # giro de "rodar para a frente" (-Z do câmbio)
	var info: Array = []
	var sum_w := 0.0
	for j: MechJoint in hubs:
		var ax := (j.part_a.global_basis.orthonormalized() * j.axis).normalized()
		var sign := 1.0 if ax.dot(fwd_axis) >= 0.0 else -1.0
		var side := 1.0 if (j.part_a.global_position - gb.part.global_position).dot(b.x) >= 0.0 else -1.0
		var w := sign * j.spin()
		info.append({"j": j, "sign": sign, "side": side, "w": w})
		sum_w += w
	var w_avg := sum_w / hubs.size() if not hubs.is_empty() else 0.0
	gb.wheel_speed = w_avg
	# Marchas
	gb._shift_cool = maxf(gb._shift_cool - dt, 0.0)
	var up := float(i.get("Sobe", 0.0)) > 0.5
	var down := float(i.get("Desce", 0.0)) > 0.5
	var want_rev := float(i.get("Ré", 0.0)) > 0.5
	var auto_brake := false          # pediu o sentido contrário andando: freia até parar
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
	var g := gb.total_ratio()
	gb.out["Marcha"] = float(gb.gear)
	gb.out["Relação"] = g
	gb.out["Giro das rodas"] = w_avg
	if hubs.is_empty():
		return 0.0
	# Embreagem: automática acima da marcha lenta (elétrico: sempre), menos a entrada Embreagem.
	var clutch_in := clampf(float(i.get("Embreagem", 0.0)), 0.0, 1.0)
	var idle := e.idle_omega()
	# Embreagem automática: o torque que ela passa cresce com o giro e chega ao torque máximo
	# do motor no giro de arrancada (60% do giro de torque máximo). Saindo com o pé no fundo,
	# o motor sobe até lá e sai patinando forte, como um carro de verdade.
	var t_peak := float(e.spec()["torque"]) * e.size_scale
	var t_cap := t_peak * CLUTCH_CAP
	var launch := maxf(float(e.spec()["peak"]) * 0.6 * TAU / 60.0, idle * 1.6)
	var t_auto := t_cap if e.spec()["fuel"] == "eletrico" else clampf(t_peak * (e.omega - idle * 1.1) / maxf(launch - idle * 1.1, 1.0), 0.0, t_cap)
	var steer := 0.0
	if gb.tank_steer:
		steer = clampf(float(i.get("Esterço", 0.0)) + float(i.get("Dir", 0.0)) - float(i.get("Esq", 0.0)), -1.0, 1.0)
	var t_eng := t_auto                                # torque que a embreagem passa
	if gb.tank_steer:
		# Esterço: engata mesmo parado, sem afogar o motor abaixo da marcha lenta.
		var keep := 1.0 if e.spec()["fuel"] == "eletrico" else clampf((e.omega - idle * 0.9) / maxf(idle * 0.5, 1.0), 0.0, 1.0)
		t_eng = maxf(t_eng, absf(steer) * t_peak * keep)
	t_eng *= (1.0 - clutch_in)
	if absf(g) < 1e-4 or not e.running:
		t_eng = 0.0
	var brake := clampf(float(i.get("Freio", 0.0)), 0.0, 1.0)
	if auto_brake:
		brake = 1.0
	t_eng *= (1.0 - brake)
	var w_eng_side := g * w_avg
	var slip := e.omega - w_eng_side
	var t_clutch := t_eng * clampf(slip / SLIP_BAND, -1.0, 1.0)
	var base := e.omega / g if absf(g) > 1e-4 else 0.0
	var moving := 1.0 if (e.throttle > 0.05 or absf(w_avg) > 0.5 or not gb.tank_steer) else 0.0
	var n := float(hubs.size())
	for h: Dictionary in info:
		var j: MechJoint = h["j"]
		if brake > 0.01:
			j.drive_spin(0.0, brake * BRAKE_TORQUE * j.size_scale, dt)
			_driven[j] = true
			continue
		var mult := 1.0
		if gb.tank_steer:
			# Esterço + vira para a direita: o lado esquerdo anda mais (ou para a frente e o
			# direito para trás, parado: gira no lugar).
			mult = moving + steer if float(h["side"]) < 0.0 else moving - steer
		var target := base * mult
		var tq := t_eng * absf(g) / n * (1.0 + absf(steer))
		j.drive_spin(float(h["sign"]) * target, tq, dt)
		_driven[j] = true
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

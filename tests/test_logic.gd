extends Node3D
## Testes da lógica (Marco 4A): chip lógico, fios porta a porta, entradas e mostradores.
##   godot --headless --path . res://tests/test_logic.tscn

const EXPECTED_CHECKS := 92

var _fails := 0
var _checks := 0


func check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		push_error("FALHOU: " + what)
		print("  FALHOU ", what)


func _ready() -> void:
	Build.reset(self)
	var ground := StaticBody3D.new()
	ground.collision_layer = Layers.WORLD
	ground.add_to_group("ground")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(400, 1, 400)
	cs.shape = bs
	ground.add_child(cs)
	add_child(ground)
	ground.position.y = -0.5
	Saves.world = self
	await _frames(2)
	_gates()
	await _graph()
	await _io()
	await _saves()
	await _tools()
	if _checks < EXPECTED_CHECKS:
		_fails += 1
		print("  FALHOU só %d de %d verificações rodaram (erro no meio do teste?)" % [_checks, EXPECTED_CHECKS])
	print("\n%d verificações, %d falhas" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Roda um modo do chip com as entradas dadas (as não citadas valem zero, sem fio).
func g(id: String, inp: Dictionary, state := {}, dt := 0.1) -> Dictionary:
	var full := {}
	for p: Array in Gates.DEFS[id]["ins"]:
		full[p[0]] = inp.get(p[0], SignalNode.zero(p[1]))
	var wired := {}
	for k in inp:
		wired[k] = true
	return Gates.run(id, full, wired, state, dt)


func near(a: float, b: float, tol := 1e-4) -> bool:
	return absf(a - b) <= tol


func _gates() -> void:
	print("== Chip: todos os modos rodam")
	var bad: Array = []
	for id: String in Gates.DEFS:
		var o := g(id, {})
		for p: Array in Gates.DEFS[id]["outs"]:
			if not o.has(p[0]):
				bad.append(id)
	check(bad.is_empty() and Gates.DEFS.size() >= 80, "%d modos, todos devolvem as saídas declaradas %s" % [Gates.DEFS.size(), bad])

	print("== Lógica")
	check(g("e", {"A": 1.0, "B": 1.0})["Saída"] == 1.0 and g("e", {"A": 1.0, "B": 0.0})["Saída"] == 0.0, "E")
	check(g("e", {})["Saída"] == 0.0, "E sem nada ligado dá 0")
	check(g("ou", {"A": 0.0, "B": 1.0})["Saída"] == 1.0 and g("ou", {"A": 0.0})["Saída"] == 0.0, "OU")
	check(g("nao", {"A": 0.0})["Saída"] == 1.0 and g("nao", {"A": 2.0})["Saída"] == 0.0, "NÃO")
	check(g("xou", {"A": 1.0, "B": 1.0, "C": 1.0})["Saída"] == 1.0 and g("xou", {"A": 1.0, "B": 1.0})["Saída"] == 0.0, "XOU (ímpar)")
	check(g("nao_e", {"A": 1.0, "B": 1.0})["Saída"] == 0.0 and g("nao_ou", {"A": 0.0, "B": 0.0})["Saída"] == 1.0, "NÃO-E e NÃO-OU")
	check(g("xnou", {"A": 1.0, "B": 1.0})["Saída"] == 1.0, "XNOR (par)")

	print("== Aritmética")
	check(g("soma", {"A": 2.0, "B": 3.5, "C": -1.0})["Saída"] == 4.5, "somar")
	check(g("subtrai", {"A": 5.0, "B": 7.0})["Saída"] == -2.0, "subtrair")
	check(g("multiplica", {"A": 2.0, "B": 3.0, "C": 4.0})["Saída"] == 24.0, "multiplicar (só as ligadas)")
	check(g("divide", {"A": 7.0, "B": 2.0})["Saída"] == 3.5 and g("divide", {"A": 7.0, "B": 0.0})["Saída"] == 0.0, "dividir (por 0 dá 0)")
	check(near(g("resto", {"A": 7.0, "B": 3.0})["Saída"], 1.0) and g("potencia", {"A": 2.0, "B": 10.0})["Saída"] == 1024.0, "resto e potência")
	check(g("raiz", {"A": 9.0})["Saída"] == 3.0 and g("raiz", {"A": -4.0})["Saída"] == 0.0, "raiz (negativo dá 0)")
	check(near(g("arredonda", {"A": 3.14159, "Casas": 2.0})["Saída"], 3.14), "arredondar com casas")
	check(g("piso", {"A": -1.5})["Saída"] == -2.0 and g("teto", {"A": 1.2})["Saída"] == 2.0 and g("sinal", {"A": -3.0})["Saída"] == -1.0, "piso, teto, sinal")
	check(g("minimo", {"A": 4.0, "B": -2.0})["Saída"] == -2.0 and g("maximo", {"A": 4.0, "B": -2.0})["Saída"] == 4.0, "mínimo e máximo (só as ligadas)")
	check(g("media", {"A": 1.0, "B": 2.0, "C": 6.0})["Saída"] == 3.0, "média")
	check(g("limita", {"Valor": 12.0, "Mín": 0.0, "Máx": 10.0})["Saída"] == 10.0, "limitar")
	check(near(g("remapeia", {"Valor": 0.0, "De mín": -1.0, "De máx": 1.0, "Para mín": 0.0, "Para máx": 90.0})["Saída"], 45.0), "converter faixa (-1..1 → 0..90)")
	check(g("porcentagem", {"Valor": 25.0, "Máx": 200.0})["Saída"] == 12.5, "porcentagem")
	var rnd: float = g("aleatorio", {"Mín": 5.0, "Máx": 6.0})["Saída"]
	check(rnd >= 5.0 and rnd <= 6.0 and near(g("pi", {})["Saída"], PI), "aleatório na faixa e pi")
	var ds := {}
	g("delta", {"A": 2.0}, ds)
	check(g("delta", {"A": 5.0}, ds)["Saída"] == 3.0, "diferença desde o tick anterior")

	print("== Comparação")
	check(g("igual", {"A": 2.0, "B": 2.0})["Saída"] == 1.0 and g("diferente", {"A": 2.0, "B": 2.0})["Saída"] == 0.0, "igual e diferente")
	check(g("menor", {"A": 1.0, "B": 2.0})["Saída"] == 1.0 and g("maior", {"A": 1.0, "B": 2.0})["Saída"] == 0.0, "menor e maior")
	check(g("menor_igual", {"A": 2.0, "B": 2.0})["Saída"] == 1.0 and g("maior_igual", {"A": 1.0, "B": 2.0})["Saída"] == 0.0, "menor/maior ou igual")
	check(g("na_faixa", {"Valor": 5.0, "Mín": 0.0, "Máx": 10.0})["Saída"] == 1.0 and g("na_faixa", {"Valor": 11.0, "Mín": 0.0, "Máx": 10.0})["Saída"] == 0.0, "está na faixa")

	print("== Memória")
	var ls := {}
	g("latch", {"Dado": 7.0, "Clk": 0.0}, ls)
	var a: float = g("latch", {"Dado": 7.0, "Clk": 1.0}, ls)["Saída"]
	var b: float = g("latch", {"Dado": 9.0, "Clk": 1.0}, ls)["Saída"]
	check(a == 7.0 and b == 7.0, "memória: guarda na borda de subida e mantém")
	var dl := {}
	check(g("d_latch", {"Dado": 3.0, "Clk": 1.0}, dl)["Saída"] == 3.0 and g("d_latch", {"Dado": 8.0, "Clk": 0.0}, dl)["Saída"] == 3.0, "D-latch: segue enquanto ligado")
	var sr := {}
	g("sr_latch", {"Ligar": 1.0}, sr)
	check(g("sr_latch", {"Ligar": 0.0}, sr)["Saída"] == 1.0 and g("sr_latch", {"Ligar": 1.0, "Desligar": 1.0}, sr)["Saída"] == 0.0, "liga/desliga (desligar ganha)")
	var tg := {}
	g("alternador", {"Clk": 1.0}, tg)
	var t1: float = g("alternador", {"Clk": 0.0}, tg)["Saída"]
	g("alternador", {"Clk": 1.0}, tg)
	check(t1 == 1.0 and g("alternador", {"Clk": 0.0}, tg)["Saída"] == 0.0, "alternador troca a cada pulso")
	var cn := {}
	for v in [1.0, 0.0, 1.0, 0.0, 1.0, 0.0]:
		g("contador", {"Somar": v}, cn)
	g("contador", {"Subtrair": 1.0}, cn)
	check(g("contador", {"Subtrair": 0.0}, cn)["Valor"] == 2.0 and g("contador", {"Zerar": 1.0}, cn)["Valor"] == 0.0, "contador: 3 pulsos − 1 = 2; zerar")
	var rm := {}
	g("ram", {"Escrever em": 3.0, "Dado": 5.5, "Gravar": 1.0}, rm)
	check(g("ram", {"Ler": 3.0}, rm)["Lido"] == 5.5 and g("ram", {"Ler": 2.0}, rm)["Lido"] == 0.0, "RAM: grava na posição 3 e lê")

	print("== Seleção")
	check(g("se", {"Condição": 1.0, "Então": 4.0, "Senão": 9.0})["Saída"] == 4.0 and g("se", {"Condição": 0.0, "Então": 4.0, "Senão": 9.0})["Saída"] == 9.0, "se/então/senão")
	check(g("seleciona", {"Escolha": 2.0, "A": 1.0, "B": 2.0, "C": 3.0})["Saída"] == 2.0 and g("seleciona", {"Escolha": 7.0, "A": 1.0})["Saída"] == 0.0, "selecionar")
	var rt := g("roteia", {"Caminho": 3.0, "Dado": 8.0})
	check(rt["C"] == 8.0 and rt["A"] == 0.0 and rt["D"] == 0.0, "rotear para a saída C")

	print("== Tempo")
	var tm := {}
	var tt := 0.0
	for i in 20:
		tt = g("temporizador", {}, tm)["Tempo"]
	check(near(tt, 2.0), "cronômetro: 20 ticks de 0,1 s = 2 s")
	var pl := {}
	var pulses := 0
	for i in 10:
		pulses += int(g("pulsador", {"Intervalo": 0.5}, pl)["Pulso"])
	check(pulses == 2, "pulsador: 2 pulsos em 1 s com intervalo 0,5 s (%d)" % pulses)
	var wv := {}
	var on_count := 0
	for i in 100:
		on_count += int(g("onda", {"Ligado (s)": 0.3, "Desligado (s)": 0.7}, wv)["Saída"])
	check(on_count >= 28 and on_count <= 32, "pisca ~30%% ligado (%d de 100 ticks)" % on_count)
	var ms := {}
	g("monoestavel", {"Disparar": 1.0, "Tempo": 0.5}, ms)
	var still_on := 0
	for i in 10:
		still_on += int(g("monoestavel", {"Disparar": 0.0, "Tempo": 0.5}, ms)["Saída"])
	check(still_on == 4, "temporizador fica ligado 0,5 s depois do disparo (%d ticks)" % still_on)
	var at := {}
	var outs: Array = []
	for i in 6:
		outs.append(g("atraso", {"Entrada": float(i), "Tempo": 0.3}, at)["Saída"])
	check(outs[5] == 2.0, "atraso de 0,3 s repete a entrada 3 ticks depois (%s)" % str(outs))
	var dv := {}
	g("derivada", {"A": 1.0}, dv)
	check(near(g("derivada", {"A": 1.5}, dv)["Saída"], 5.0), "taxa de variação: 0,5 em 0,1 s = 5/s")
	var ac := {}
	for i in 10:
		g("acumulador", {"Entrada": 2.0}, ac)
	check(near(g("acumulador", {"Entrada": 0.0}, ac)["Saída"], 2.0), "acumulador: 2/s por 1 s = 2")
	var sm := {}
	g("suaviza", {"Entrada": 0.0}, sm)
	check(near(g("suaviza", {"Entrada": 10.0, "Taxa": 5.0}, sm)["Saída"], 0.5), "suavizar sobe 5/s")

	print("== Trigonometria, bits, vetor, texto")
	check(near(g("sen", {"Graus": 30.0})["Saída"], 0.5) and near(g("atan2", {"Y": 1.0, "X": 1.0})["Saída"], 45.0), "seno e ângulo de X, Y em graus")
	check(near(g("dif_angulo", {"A": 350.0, "B": 10.0})["Saída"], -20.0), "diferença de ângulos dá a volta certa")
	check(g("bit_e", {"A": 6.0, "B": 3.0})["Saída"] == 2.0 and g("bit_ou", {"A": 6.0, "B": 3.0})["Saída"] == 7.0 \
		and g("bit_xou", {"A": 6.0, "B": 3.0})["Saída"] == 5.0 and g("bit_esq", {"A": 1.0, "B": 4.0})["Saída"] == 16.0, "bits")
	check(g("compor", {"X": 1.0, "Y": 2.0, "Z": 3.0})["Vetor"] == Vector3(1, 2, 3) and g("decompor", {"Vetor": Vector3(4, 5, 6)})["Y"] == 5.0, "montar e separar vetor")
	check(g("comprimento", {"Vetor": Vector3(3, 4, 0)})["Saída"] == 5.0 and g("escalar", {"A": Vector3(1, 2, 3), "B": Vector3(4, 5, 6)})["Saída"] == 32.0, "comprimento e produto escalar")
	check(g("vetorial", {"A": Vector3.RIGHT, "B": Vector3.UP})["Vetor"] == Vector3.BACK and g("distancia", {"A": Vector3.ZERO, "B": Vector3(0, 0, 2)})["Saída"] == 2.0, "produto vetorial e distância")
	check(g("juntar", {"A": "Olá", "B": ", ", "C": "mundo"})["Texto"] == "Olá, mundo" and g("num_texto", {"Número": 3.14159, "Casas": 2.0})["Texto"] == "3.14", "juntar textos e número → texto")
	check(g("texto_num", {"Texto": " 2,5 "})["Saída"] == 2.5 and g("tamanho", {"Texto": "abc"})["Saída"] == 3.0 \
		and g("maiusculas", {"Texto": "sim"})["Texto"] == "SIM" and g("texto_igual", {"A": "x", "B": "x"})["Saída"] == 1.0, "texto → número, tamanho, maiúsculas, iguais")


func _spawn(kind: String, pos: Vector3) -> Part:
	return Components.spawn(kind, Transform3D(Basis(), pos))[0]


func _graph() -> void:
	print("== Fios: constantes → chip somar → chip multiplicar → mostrador")
	var k1 := _spawn("constante", Vector3(0, 0.03, 0))
	var k2 := _spawn("constante", Vector3(0.5, 0.03, 0))
	(k1.node as ConstNode).set_value(SignalNode.NUM, 2.0)
	(k2.node as ConstNode).set_value(SignalNode.NUM, 3.0)
	var sum := _spawn("chip", Vector3(1.0, 0.03, 0))
	var mul := _spawn("chip", Vector3(1.5, 0.03, 0))
	(sum.node as ChipNode).set_mode("soma")
	(mul.node as ChipNode).set_mode("multiplica")
	var disp := _spawn("mostrador", Vector3(2.2, 0.03, 0))
	# Ligados "de trás para frente" de propósito: a ordem de cálculo vem dos fios.
	Signals.connect_ports(mul.node, "Saída", disp.node, "Valor")
	Signals.connect_ports(sum.node, "Saída", mul.node, "A")
	Signals.connect_ports(k2.node, "Valor", mul.node, "B")
	Signals.connect_ports(k1.node, "Valor", sum.node, "A")
	Signals.connect_ports(k2.node, "Valor", sum.node, "B")
	await _frames(1)
	check((mul.node as ChipNode).out["Saída"] == 15.0, "(2 + 3) × 3 = 15 já no primeiro tick (ordem dos fios)")
	await _frames(1)
	check((disp.node as DisplayNode).label.text == "15.0", "o mostrador mostra 15.0")
	check(Signals.connect_ports(k1.node, "Valor", disp.node, "Valor") != null, "duas saídas na mesma entrada numérica: soma")
	await _frames(2)
	check((disp.node as DisplayNode).label.text == "17.0", "mostrador = 15 + 2 = 17")
	var vecc := _spawn("constante", Vector3(0, 0.03, 1))
	(vecc.node as ConstNode).set_value(SignalNode.VEC, Vector3(1, 2, 3))
	check(Signals.connect_ports(vecc.node, "Valor", sum.node, "C") == null, "não liga vetor numa entrada de número")
	(sum.node as ChipNode).set_mode("compor")
	await _frames(1)
	check(Signals.wires_into(sum.node).is_empty() and Signals.wires_from(sum.node).is_empty(), "trocar o modo do chip tira os fios das portas que não existem mais")
	var k2n := k2.node
	Build.delete_part(k2)
	await _frames(1)
	check(Signals.wires_from(k2n).is_empty() and Signals.wires_into(mul.node, "B").is_empty(), "apagar uma peça apaga os fios dela")

	print("== Controle → chip NÃO → motor")
	var lever := _spawn("alavanca", Vector3(0, 0.04, 4))
	var inv := _spawn("chip", Vector3(1, 0.03, 4))
	(inv.node as ChipNode).set_mode("nao")
	var m := Components.spawn("motor", Transform3D(Basis(), Vector3(3, 1, 4)))
	m[0].assembly().set_anchored(true)
	Signals.connect_ports(lever.device, "Saída", inv.node, "A")
	Signals.connect_ports(inv.node, "Saída", m[0].mech, "Sinal")
	await _frames(40)
	var w := m[1].assembly().angular_velocity.length()
	lever.device.press()
	await _frames(40)
	var w2 := m[1].assembly().angular_velocity.length()
	check(w > 5.0 and w2 < 1.0, "alavanca desligada → NÃO dá 1 → motor gira; ligada → para (%.1f → %.1f rad/s)" % [w, w2])
	check(m[0].mech.out.has("Ângulo") and m[0].mech.out.has("Giro"), "o motor tem saídas Ângulo e Giro")

	print("== Componentes como sensores: pistão → tela")
	var pis := Components.spawn("pistao", Transform3D(Basis(), Vector3(6, 0.36, 4)))
	pis[0].assembly().set_anchored(true)
	var b1 := _spawn("botao", Transform3D(Basis(), Vector3(7, 0.04, 6)).origin)
	var tela := _spawn("tela", Vector3(8, 0.03, 4))
	Signals.connect_ports(b1.device, "Saída", pis[0].mech, "Sinal")
	Signals.connect_ports(pis[0].mech, "Extensão", tela.node, "A")
	b1.device.press()
	await _frames(60)
	var ext := float(pis[0].mech.out["Extensão"])
	await _frames(1)
	check(ext > 0.4 and (tela.node as DisplayNode).label.text.begins_with("A: 0.4") or (tela.node as DisplayNode).label.text.begins_with("A: 0.5"), "tela mostra a extensão do pistão (%s)" % (tela.node as DisplayNode).label.text.replace("\n", " "))
	b1.device.release()

	print("== Ciclo: pulsador → alternador → indicador (realimentação não trava)")
	var pul := _spawn("chip", Vector3(0, 0.03, 8))
	(pul.node as ChipNode).set_mode("pulsador")
	var tog := _spawn("chip", Vector3(1, 0.03, 8))
	(tog.node as ChipNode).set_mode("alternador")
	var ind := _spawn("indicador", Vector3(2, 0.03, 8))
	var kint := _spawn("constante", Vector3(0, 0.03, 9))
	(kint.node as ConstNode).set_value(SignalNode.NUM, 0.25)
	Signals.connect_ports(kint.node, "Valor", pul.node, "Intervalo")
	Signals.connect_ports(pul.node, "Pulso", tog.node, "Clk")
	Signals.connect_ports(tog.node, "Saída", ind.node, "Valor")
	# realimentação: a saída do alternador volta para "Desligado" dele mesmo (vale 0 ou 1)
	Signals.connect_ports(tog.node, "Saída", tog.node, "Desligado")
	var changes := 0
	var last := -1.0
	for i in 60:
		await get_tree().physics_frame
		var v: float = (tog.node as ChipNode).out.get("Saída", 0.0)
		if v != last:
			changes += 1
			last = v
	check(Signals.wires_into(tog.node, "Desligado").is_empty(), "não liga uma peça nela mesma")
	check(changes >= 3, "o alternador troca com os pulsos (%d trocas em 1 s)" % changes)
	var c_on := (ind.node as DisplayNode)._mat.albedo_color
	check(c_on != Color(0, 0, 0), "o indicador acende")


func _io() -> void:
	print("== Teclas (a pé, teclado numérico)")
	var keys := _spawn("teclas", Vector3(0, 0.03, 12))
	var kn := keys.node as KeysNode
	kn.bind_pos = [{"key": KEY_KP_8}]
	kn.bind_neg = [{"key": KEY_KP_2}]
	await _frames(2)
	check(kn.out.get("Valor", 0.0) == 0.0, "sem estar sentado e sem 'sempre': não vale")
	kn.always = true
	Input.parse_input_event(_key(KEY_KP_8, true))
	await _frames(2)
	check(kn.out["Valor"] == 1.0, "com 'sempre', a tecla vale a pé (+1)")
	Input.parse_input_event(_key(KEY_KP_8, false))
	Input.parse_input_event(_key(KEY_KP_2, true))
	await _frames(2)
	check(kn.out["Valor"] == -1.0, "tecla − dá −1")
	Input.parse_input_event(_key(KEY_KP_2, false))
	await _frames(1)

	print("== Assento como controle")
	var seat := Components.spawn("assento", Transform3D(Basis(), Vector3(4, 0.07, 12)))
	var sn := Signals.node_of(seat[0])
	check(sn is SeatNode and Signals.node_of(seat[1]) == sn, "o assento (e o encosto) é um nó de sinal")
	Build.active_seat = seat[0]
	Input.parse_input_event(_key(KEY_W, true))
	await _frames(2)
	check(sn.out["W"] == 1.0 and sn.out["Ocupado"] == 1.0 and sn.out["S"] == 0.0, "sentado: W = 1, Ocupado = 1")
	Input.parse_input_event(_key(KEY_W, false))
	Build.active_seat = null
	await _frames(2)
	check(sn.out["W"] == 0.0 and sn.out["Ocupado"] == 0.0, "levantou: tudo 0")

	print("== Teclado de senha")
	var kp := _spawn("teclado", Vector3(6, 0.03, 12))
	var kpn := kp.node as KeypadNode
	kpn.code = "4321"
	kpn.hold_time = 0.5
	check(not kpn.enter("1111"), "senha errada")
	await _frames(2)
	check(kpn.out["Errado"] == 1.0 and kpn.out["Certo"] == 0.0, "senha errada liga 'Errado'")
	check(kpn.enter("4321"), "senha certa")
	await _frames(2)
	check(kpn.out["Certo"] == 1.0, "senha certa liga 'Certo'")
	await _frames(40)
	check(kpn.out["Certo"] == 0.0, "'Certo' desliga depois do tempo aberto")

	print("== Mostradores")
	var px := _spawn("pixel", Vector3(8, 0.03, 12))
	var pc := _spawn("constante", Vector3(8, 0.03, 13))
	(pc.node as ConstNode).set_value(SignalNode.VEC, Vector3(255, 0, 0))
	Signals.connect_ports(pc.node, "Valor", px.node, "Cor")
	await _frames(2)
	var col := (px.node as DisplayNode)._mat.albedo_color
	check(col.r > 0.99 and col.g < 0.01, "pixel fica vermelho com (255; 0; 0)")
	var tt := _spawn("tela_texto", Vector3(10, 0.03, 12))
	var tdn := tt.node as DisplayNode
	tdn.template = "Vel: {A} km/h · {texto}"
	var ka := _spawn("constante", Vector3(10, 0.03, 13))
	(ka.node as ConstNode).set_value(SignalNode.NUM, 42.0)
	var ks := _spawn("constante", Vector3(11, 0.03, 13))
	(ks.node as ConstNode).set_value(SignalNode.TXT, "ok")
	Signals.connect_ports(ka.node, "Valor", tt.node, "A")
	Signals.connect_ports(ks.node, "Valor", tt.node, "Texto")
	await _frames(2)
	check(tdn.label.text == "Vel: 42 km/h · ok", "tela de texto troca {A} e {texto} (%s)" % tdn.label.text)


func _saves() -> void:
	print("== Salvar e carregar a lógica")
	Saves.clear_world()
	await _frames(2)
	var k := _spawn("constante", Vector3(0, 0.03, 20))
	(k.node as ConstNode).set_value(SignalNode.NUM, 6.0)
	k.node.node_name = "Seis"
	var latch := _spawn("chip", Vector3(1, 0.03, 20))
	(latch.node as ChipNode).set_mode("latch")
	var clk := _spawn("constante", Vector3(1, 0.03, 21))
	(clk.node as ConstNode).set_value(SignalNode.NUM, 1.0)
	var disp := _spawn("tela_texto", Vector3(2, 0.03, 20))
	(disp.node as DisplayNode).template = "Guardado: {A}"
	var lever := _spawn("alavanca", Vector3(0, 0.04, 22))
	var m := Components.spawn("motor", Transform3D(Basis(), Vector3(3, 0.17, 22)))
	var ins := Build.place_insulator(null, Vector3(1.5, 0.0, 22), Vector3.UP)
	Signals.connect_ports(k.node, "Valor", latch.node, "Dado")
	Signals.connect_ports(clk.node, "Valor", latch.node, "Clk")
	Signals.connect_ports(latch.node, "Saída", disp.node, "A")
	Signals.connect_ports(lever.device, "Saída", m[0].mech, "Sinal", [ins])
	m[0].mech.node_name = "Roda esquerda"
	await _frames(3)
	check((latch.node as ChipNode).out["Saída"] == 6.0, "a memória guardou 6")
	var n_wires := Signals.wires.size()
	var data: Dictionary = JSON.parse_string(JSON.stringify(Saves.serialize(Saves.world_assemblies(), Transform3D.IDENTITY)))
	Saves.clear_world()
	await _frames(2)
	check(Signals.wires.is_empty() and Signals.nodes.is_empty(), "apagar o mundo apaga nós e fios")
	Saves.restore(data, Transform3D.IDENTITY)
	await _frames(1)
	var chips := Signals.nodes.filter(func(n: SignalNode) -> bool: return n is ChipNode)
	var consts := Signals.nodes.filter(func(n: SignalNode) -> bool: return n is ConstNode)
	var motors := Signals.nodes.filter(func(n: SignalNode) -> bool: return n is MechJoint)
	check(Signals.wires.size() == n_wires, "todos os fios voltam (%d)" % Signals.wires.size())
	check(chips.size() == 1 and (chips[0] as ChipNode).mode == "latch" and (chips[0] as ChipNode).state.get("v", 0.0) == 6.0, "o chip volta no mesmo modo e com a memória (6)")
	var six := consts.filter(func(n: ConstNode) -> bool: return n.node_name == "Seis")
	check(six.size() == 1 and (six[0] as ConstNode).value == 6.0, "a constante volta com nome e valor")
	check(motors.size() == 1 and (motors[0] as MechJoint).node_name == "Roda esquerda", "o nome do motor volta")
	var mw := Signals.wires_into(motors[0], "Sinal")
	check(mw.size() == 1 and mw[0].via.size() == 1, "o fio do motor passa pelo mesmo isolador")

	print("== Saves antigos (formato 1)")
	var old := {"format": Saves.FORMAT, "version": 1, "links": [{"j": 1, "d": 0, "via": [5]}]}
	var mig := Saves._migrate(old)
	check(mig["version"] == 2 and mig["wires"][0]["fp"] == "Saída" and mig["wires"][0]["tp"] == "Sinal" and not mig.has("links"), "fios antigos (controle → componente) viram fios Saída → Sinal")


func _tools() -> void:
	print("== Fiação com menu de portas")
	var player := Player.new()
	add_child(player)
	await _frames(2)
	var o := Vector3(40, 0, 0)
	var router := _spawn("chip", o + Vector3(0, 0.03, 0))
	(router.node as ChipNode).set_mode("roteia")
	var tela := _spawn("tela", o + Vector3(1.2, 0.03, 0))
	await _frames(5)
	var menus: Array = []
	var pick := [1]
	player.port_menu_requested.connect(func(title: String, items: Array, cb: Callable) -> void:
		menus.append([title, items.size()])
		cb.call(pick[0]))
	player.select_tool(3)
	var wire: WireTool = player.tools[3]
	_aim(player, o + Vector3(0, 0, 1.6), router.global_position)
	await _frames(3)
	pick[0] = 1                                    # saída B
	wire.handle_input(_press("primary"))
	_aim(player, o + Vector3(1.2, 0, 1.6), tela.global_position)
	await _frames(3)
	pick[0] = 1                                    # entrada B
	wire.handle_input(_press("primary"))
	check(menus.size() == 2 and menus[0][1] == 4 and menus[1][1] == 2, "a Fiação pergunta a saída (4) e a entrada (2)")
	check(Signals.is_linked(router.node, "B", tela.node, "B"), "fio do chip (B) até a tela (B)")
	wire.handle_input(_press("primary"))           # começa de novo na tela? tela não tem saída
	_aim(player, o + Vector3(0, 0, 1.6), router.global_position)
	await _frames(3)
	wire.handle_input(_press("primary"))
	_aim(player, o + Vector3(1.2, 0, 1.6), tela.global_position)
	await _frames(3)
	wire.handle_input(_press("primary"))
	check(not Signals.is_linked(router.node, "B", tela.node, "B"), "escolher a mesma ligação de novo desliga o fio")
	# Uma saída só e uma entrada só: o menu aparece do mesmo jeito (pedido do jogador).
	var lev := _spawn("alavanca", o + Vector3(0, 0.03, 2.5))
	var ind := _spawn("indicador", o + Vector3(1.2, 0.03, 2.5))
	await _frames(3)
	var before := menus.size()
	pick[0] = 0
	_aim(player, o + Vector3(0, 0, 4.0), lev.global_position)
	await _frames(3)
	wire.handle_input(_press("primary"))
	_aim(player, o + Vector3(1.2, 0, 4.0), ind.global_position)
	await _frames(3)
	wire.handle_input(_press("primary"))
	check(menus.size() == before + 2 and menus[before][1] == 1 and menus[before + 1][1] == 1 and Signals.is_linked(lev.device, "Saída", ind.node, "Valor"),
		"com uma saída e uma entrada só, o menu aparece mesmo assim (e liga)")

	print("== Depurador")
	player.select_tool(4)
	var dbg: DebugTool = player.tools[4]
	_aim(player, o + Vector3(0, 0, 1.6), router.global_position)
	await _frames(3)
	var txt := dbg.panel_text()
	check(txt.contains("Rotear") and txt.contains("ENTRADAS") and txt.contains("Caminho") and txt.contains("SAÍDAS"), "o Depurador mostra o chip, as entradas e as saídas")
	var opened: Array = []
	player.node_config_requested.connect(func(n: SignalNode) -> void: opened.append(n))
	dbg.handle_input(_press("secondary"))
	check(opened.size() == 1 and opened[0] == router.node, "botão direito do Depurador abre os ajustes (nome)")
	player.queue_free()


func _key(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	return ev


func _press(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _aim(player: Player, feet: Vector3, target: Vector3) -> void:
	player.teleport(feet)
	player.velocity = Vector3.ZERO
	var d := (target - (feet + Vector3(0, Player.EYE_HEIGHT, 0))).normalized()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = asin(clampf(d.y, -1.0, 1.0))

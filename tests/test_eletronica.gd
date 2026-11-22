extends Node3D
## Eletrônica avançada (Marco 4E): FPGA (circuito interno, pinos, ciclos, constantes,
## salvar, circuitos em arquivo, editor visual), memórias (RAM, ROM, HD) e rádio.
##   godot --headless --path . res://tests/test_eletronica.tscn

const EXPECTED_CHECKS := 28

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
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1000, 1, 1000)
	cs.shape = bs
	ground.add_child(cs)
	add_child(ground)
	ground.position.y = -0.5
	await _frames(2)
	await _run()
	if _checks < EXPECTED_CHECKS:
		_fails += 1
		print("  FALHOU só %d de %d verificações rodaram (erro no meio do teste?)" % [_checks, EXPECTED_CHECKS])
	print("\n%d verificações, %d falhas" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _spawn(kind: String, at: Vector3) -> SignalNode:
	var p: Part = Components.spawn(kind, Transform3D(Basis(), at))[0]
	Build.make_weld(p, null, at + Vector3(0, -0.02, 0))
	return p.node


func _const(v: Variant, at: Vector3) -> ConstNode:
	var k := _spawn("constante", at) as ConstNode
	k.set_value(SignalNode.VEC if v is Vector3 else (SignalNode.TXT if v is String else SignalNode.NUM), v)
	return k


func _id(f: FpgaNode, mode: String, pin_name := "") -> int:
	for id: int in f.gates:
		if f.gates[id]["mode"] == mode and (pin_name == "" or f.gates[id].get("name", "") == pin_name):
			return id
	return -1


func _run() -> void:
	print("== FPGA")
	var f := _spawn("fpga", Vector3(0, 0.03, 0)) as FpgaNode
	check(f.inputs() == [["A", "n"], ["B", "n"]] and f.outputs() == [["Saída", "n"]], "FPGA novo: entradas A e B, saída Saída")
	var a_in := _id(f, FpgaNode.PIN_IN, "A")
	var b_in := _id(f, FpgaNode.PIN_IN, "B")
	var o := _id(f, FpgaNode.PIN_OUT, "Saída")
	var sum := f.add_gate("soma", Vector2(250, 100))
	var ok1 := f.connect_gates(a_in, "Valor", sum, "A")
	var ok2 := f.connect_gates(b_in, "Valor", sum, "B")
	var ok3 := f.connect_gates(sum, "Saída", o, "Valor")
	var ka := _const(3.0, Vector3(1, 0.03, 0))
	var kb := _const(4.5, Vector3(2, 0.03, 0))
	Signals.connect_ports(ka, "Valor", f, "A")
	Signals.connect_ports(kb, "Valor", f, "B")
	await _frames(3)
	check(ok1 and ok2 and ok3 and is_equal_approx(float(f.out["Saída"]), 7.5), "A + B dentro do FPGA (%s)" % SignalNode.format(f.out["Saída"]))
	# Tipos diferentes não ligam
	var vec := f.add_gate("compor", Vector2(250, 300))
	check(not f.connect_gates(vec, "Vetor", o, "Valor"), "vetor não liga em entrada de número")
	f.remove_gate(vec)
	# Ordem das portas segue a altura dos pinos
	f.move_gate(b_in, Vector2(40, 0))
	check(f.inputs()[0][0] == "B", "pinos de cima para baixo viram a ordem das portas")
	f.move_gate(b_in, Vector2(40, 200))
	# Renomear um pino: o fio de fora do nome antigo sai
	f.set_pin(b_in, "Fator", SignalNode.NUM)
	await _frames(2)
	check(f.port_type("Fator", false) == "n" and Signals.wires_into(f, "B").is_empty(), "renomear pino: a porta muda e o fio antigo sai")
	Signals.connect_ports(kb, "Valor", f, "Fator")
	# Nome repetido fica único
	var c_in := f.add_gate(FpgaNode.PIN_IN, Vector2(40, 400), {"name": "A"})
	check(f.gates[c_in]["name"] == "A2", "nome repetido vira A2")
	f.remove_gate(c_in)
	# Constante dentro e saída nova
	var k5 := f.add_gate(FpgaNode.PIN_CONST, Vector2(250, 400), {"value": 5})
	var o2 := f.add_gate(FpgaNode.PIN_OUT, Vector2(560, 400), {"name": "Cinco"})
	f.connect_gates(k5, "Valor", o2, "Valor")
	# Ciclo: contador feito com soma realimentada (lê o valor do tick anterior)
	var acc := f.add_gate("soma", Vector2(250, 600))
	var one := f.add_gate(FpgaNode.PIN_CONST, Vector2(40, 600), {"value": 1})
	f.connect_gates(one, "Valor", acc, "A")
	f.connect_gates(acc, "Saída", acc, "B")
	var o3 := f.add_gate(FpgaNode.PIN_OUT, Vector2(560, 600), {"name": "Conta"})
	f.connect_gates(acc, "Saída", o3, "Valor")
	await _frames(1)
	var c0 := float(f.out.get("Conta", 0.0))
	await _frames(10)
	var c1 := float(f.out.get("Conta", 0.0))
	check(float(f.out["Cinco"]) == 5.0 and is_equal_approx(c1 - c0, 10.0), "constante dentro (5) e ciclo realimentado conta 1 por tick (+%d em 10)" % roundi(c1 - c0))
	# Vários fios na mesma entrada somam
	f.connect_gates(k5, "Valor", sum, "C")
	await _frames(2)
	check(is_equal_approx(float(f.out["Saída"]), 12.5), "duas ligações na mesma entrada somam (3 + 4,5 + 5 = %s)" % SignalNode.format(f.out["Saída"]))
	# Limite
	var g := FpgaNode.new()
	var added := 0
	for i in FpgaNode.MAX_GATES + 10:
		if g.add_gate("e", Vector2.ZERO) >= 0:
			added += 1
	check(g.gates.size() == FpgaNode.MAX_GATES, "limite de %d peças no FPGA" % FpgaNode.MAX_GATES)
	# Chip lógico dentro: memória (latch) guardando
	var h := _spawn("fpga", Vector3(0, 0.03, 3)) as FpgaNode
	var hl := h.add_gate("latch", Vector2(250, 100))
	h.connect_gates(_id(h, FpgaNode.PIN_IN, "A"), "Valor", hl, "Dado")
	h.connect_gates(_id(h, FpgaNode.PIN_IN, "B"), "Valor", hl, "Clk")
	h.connect_gates(hl, "Saída", _id(h, FpgaNode.PIN_OUT), "Valor")
	var hd := _const(9.0, Vector3(1, 0.03, 3))
	var hc := _const(0.0, Vector3(2, 0.03, 3))
	Signals.connect_ports(hd, "Valor", h, "A")
	Signals.connect_ports(hc, "Valor", h, "B")
	await _frames(2)
	hc.set_value(SignalNode.NUM, 1.0)
	await _frames(2)
	hd.set_value(SignalNode.NUM, 2.0)
	await _frames(2)
	check(float(h.out["Saída"]) == 9.0, "modos do chip lógico funcionam dentro (latch guarda 9)")

	print("== FPGA: salvar e circuitos")
	var n_g := f.gates.size()
	var n_e := f.edges.size()
	var data: Dictionary = JSON.parse_string(JSON.stringify(Saves.serialize(Saves.world_assemblies(), Transform3D.IDENTITY)))
	Saves.clear_world()
	await _frames(3)
	Saves.restore(data, Transform3D.IDENTITY)
	await _frames(4)
	var f2: FpgaNode = null
	var h2: FpgaNode = null
	for n in Signals.nodes:
		if n is FpgaNode and (n as FpgaNode).gates.size() == n_g:
			f2 = n
		elif n is FpgaNode:
			h2 = n
	check(f2 != null and f2.edges.size() == n_e and is_equal_approx(float(f2.out["Saída"]), 12.5) and float(f2.out["Cinco"]) == 5.0,
		"FPGA volta do save com o circuito e os fios de fora")
	check(h2 != null and float(h2.out["Saída"]) == 9.0, "estado interno volta junto (o latch continua com 9, sem regravar)")
	var saved := f2.save_circuit("teste automático")
	var f3 := _spawn("fpga", Vector3(0, 0.03, 6)) as FpgaNode
	var loaded := f3.load_circuit(saved)
	check(saved != "" and loaded and f3.gates.size() == n_g and FpgaNode.list_circuits().has(saved), "circuito salvo num arquivo e carregado em outro FPGA")
	FpgaNode.delete_circuit(saved)
	check(not FpgaNode.list_circuits().has(saved), "circuito salvo pode ser apagado")

	print("== Editor visual")
	var ed := FpgaEditor.new()
	add_child(ed)
	await _frames(1)
	ed.open(null, f3)
	await _frames(2)
	var nodes := 0
	for c in ed.graph.get_children():
		if c is GraphNode:
			nodes += 1
	check(nodes == f3.gates.size() and ed.graph.get_connection_list().size() == f3.edges.size(),
		"editor mostra %d peças e %d ligações" % [nodes, ed.graph.get_connection_list().size()])
	var gnew := f3.next_id
	ed._add("multiplica", Vector2(300, 300))
	var ins_a := _id(f3, FpgaNode.PIN_IN, "A")
	ed._on_connect(StringName("g%d" % ins_a), 0, StringName("g%d" % gnew), 0)
	check(f3.gates.has(gnew) and f3.find_edge(ins_a, "Valor", gnew, "A") >= 0, "editor: pôr uma porta e ligar arrastando")
	ed._on_delete([StringName("g%d" % gnew)] as Array[StringName])
	await _frames(1)
	check(not f3.gates.has(gnew) and f3.find_edge(ins_a, "Valor", gnew, "A") < 0, "editor: Delete apaga a peça e as ligações dela")
	ed.close()

	print("== Memórias")
	var ram := _spawn("memoria", Vector3(10, 0.03, 0)) as MemoryNode
	var addr := _const(3.0, Vector3(11, 0.03, 0))
	var dat := _const(42.0, Vector3(12, 0.03, 0))
	var wr := _const(1.0, Vector3(13, 0.03, 0))
	Signals.connect_ports(addr, "Valor", ram, "Endereço")
	Signals.connect_ports(dat, "Valor", ram, "Dado")
	Signals.connect_ports(wr, "Valor", ram, "Gravar")
	await _frames(2)
	wr.set_value(SignalNode.NUM, 0.0)
	dat.set_value(SignalNode.NUM, 7.0)
	await _frames(2)
	var r3 := float(ram.out["Lido"])
	addr.set_value(SignalNode.NUM, 4.0)
	await _frames(2)
	var r4 := float(ram.out["Lido"])
	addr.set_value(SignalNode.NUM, 999.0)
	await _frames(2)
	check(r3 == 42.0 and r4 == 0.0 and float(ram.out["Lido"]) == 0.0 and float(ram.out["Tamanho"]) == 64.0,
		"RAM: grava 42 na posição 3, lê de volta; fora da faixa dá 0")
	var zr := _const(1.0, Vector3(14, 0.03, 0))
	Signals.connect_ports(zr, "Valor", ram, "Zerar")
	addr.set_value(SignalNode.NUM, 3.0)
	await _frames(2)
	check(float(ram.out["Lido"]) == 0.0, "RAM: Zerar apaga")
	zr.set_value(SignalNode.NUM, 0.0)
	var rom := _spawn("rom", Vector3(10, 0.03, 3)) as MemoryNode
	rom.set_rom_text("10; 20; 30")
	var raddr := _const(1.0, Vector3(11, 0.03, 3))
	Signals.connect_ports(raddr, "Valor", rom, "Endereço")
	await _frames(2)
	var rom_ok := float(rom.out["Lido"]) == 20.0 and rom.size == 3
	rom.set_rom_text("1, 2, 3, 4")
	var n_comma := rom.size
	rom.set_rom_text("1,5 2,5")
	check(rom_ok and n_comma == 4 and rom.data == [1.5, 2.5] and rom.inputs().size() == 1, "ROM: tabela escrita nos ajustes (vírgula como separador ou decimal)")
	# HD: guarda em arquivo e é compartilhado pelo nome do disco
	var disk := "teste_auto_%d" % (Time.get_ticks_usec() % 100000)
	var hd1 := _spawn("hd", Vector3(10, 0.03, 6)) as MemoryNode
	hd1.set_disk(disk)
	var hd2 := _spawn("hd", Vector3(10, 0.03, 9)) as MemoryNode
	hd2.set_disk(disk)
	var ha := _const(5.0, Vector3(11, 0.03, 6))
	var hdat := _const(123.0, Vector3(12, 0.03, 6))
	var hwr := _const(1.0, Vector3(13, 0.03, 6))
	Signals.connect_ports(ha, "Valor", hd1, "Endereço")
	Signals.connect_ports(hdat, "Valor", hd1, "Dado")
	Signals.connect_ports(hwr, "Valor", hd1, "Gravar")
	Signals.connect_ports(ha, "Valor", hd2, "Endereço")
	await _frames(3)
	hwr.set_value(SignalNode.NUM, 0.0)
	await _frames(2)
	check(float(hd2.out["Lido"]) == 123.0, "HD: outro HD com o mesmo disco vê o valor")
	MemoryNode.flush_disks()
	MemoryNode.disks.clear()
	var fresh := MemoryNode.disk_data(disk)
	check(float(fresh[5]) == 123.0, "HD: o valor fica no arquivo (lido de novo do disco)")
	DirAccess.remove_absolute("%s/%s.json" % [MemoryNode.HD_DIR, disk])
	# RAM vai junto no save
	var ram_data := ram.save_state()
	var ram2 := MemoryNode.new()
	ram2.kind = "memoria"
	ram.data[10] = 77.0
	ram2.load_state(ram.save_state())
	check(ram2.data[10] == 77.0 and ram2.size == 64 and ram_data.has("data"), "RAM: os valores vão junto no save")

	print("== Rádio")
	var r1 := _spawn("radio", Vector3(30, 0.03, 0)) as RadioNode
	var r2 := _spawn("radio", Vector3(40, 0.03, 0)) as RadioNode
	var r3n := _spawn("radio", Vector3(32, 0.03, 0)) as RadioNode
	r3n.channel = 2
	var sa := _const(8.0, Vector3(30, 0.03, 2))
	var st := _const("olá", Vector3(31, 0.03, 2))
	Signals.connect_ports(sa, "Valor", r1, "A")
	Signals.connect_ports(st, "Valor", r1, "Texto")
	await _frames(3)
	check(float(r2.out["A"]) == 8.0 and str(r2.out["Texto"]) == "olá" and float(r2.out["Rádios"]) == 1.0,
		"rádio: o outro rádio do canal 1 recebe A = 8 e o texto")
	check(float(r3n.out["A"]) == 0.0 and float(r1.out["A"]) == 0.0, "rádio: canal 2 não recebe; ninguém ouve a si mesmo")
	# O mais perto ganha
	var r4n := _spawn("radio", Vector3(38, 0.03, 0)) as RadioNode
	var sb := _const(1.0, Vector3(38, 0.03, 2))
	Signals.connect_ports(sb, "Valor", r4n, "A")
	await _frames(3)
	check(float(r2.out["A"]) == 1.0, "rádio: vale o rádio mais perto mandando na porta")
	# Alcance e canal por fio
	r2.range_m = 5.0
	var chn := _const(2.0, Vector3(31, 0.03, 4))
	Signals.connect_ports(chn, "Valor", r1, "Canal")
	await _frames(3)
	check(float(r3n.out["A"]) == 8.0 and float(r2.out["A"]) == 1.0, "rádio: entrada Canal troca o canal (agora o canal 2 recebe)")
	r4n.part.assembly().global_position += Vector3(0, 0, 50)
	await _frames(3)
	check(float(r2.out["A"]) == 0.0 and float(r2.out["Rádios"]) == 0.0, "rádio: fora do alcance não recebe")

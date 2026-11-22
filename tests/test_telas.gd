extends Node3D
## Telas avançadas, indicador no HUD, câmera, marcadores e pintor (Marco 4E, parte 2).
##   godot --headless --path . res://tests/test_telas.tscn

const EXPECTED_CHECKS := 22

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


func _spawn(kind: String, at: Vector3, weld := true) -> SignalNode:
	var b := Components.bounds(kind)
	var p: Part = Components.spawn(kind, Transform3D(Basis(), at + Vector3(0, -b.position.y, 0)))[0]
	if weld:
		Build.make_weld(p, null, at)
	return p.node


func _const(v: Variant, at: Vector3) -> ConstNode:
	var k := _spawn("constante", at) as ConstNode
	k.set_value(SignalNode.VEC if v is Vector3 else (SignalNode.TXT if v is String else SignalNode.NUM), v)
	return k


func _run() -> void:
	print("== Console de letras")
	var con := _spawn("console", Vector3(0, 0, 0)) as ScreenNode
	var txt := _const("OLÁ", Vector3(1, 0, 1))
	var lin := _const(2.0, Vector3(2, 0, 1))
	var col := _const(3.0, Vector3(3, 0, 1))
	var wr := _const(0.0, Vector3(4, 0, 1))
	Signals.connect_ports(txt, "Valor", con, "Texto")
	Signals.connect_ports(lin, "Valor", con, "Linha")
	Signals.connect_ports(col, "Valor", con, "Coluna")
	Signals.connect_ports(wr, "Valor", con, "Escrever")
	await _frames(2)
	var before := str(con.lines[2]).strip_edges()
	wr.set_value(SignalNode.NUM, 1.0)
	await _frames(2)
	check(before == "" and str(con.lines[2]).substr(3, 3) == "OLÁ", "escreve só no pulso de Escrever, na linha 2, coluna 3")
	txt.set_value(SignalNode.TXT, "AB\nCD")
	wr.set_value(SignalNode.NUM, 0.0)
	await _frames(2)
	wr.set_value(SignalNode.NUM, 1.0)
	await _frames(2)
	check(str(con.lines[2]).substr(3, 2) == "AB" and str(con.lines[3]).substr(3, 2) == "CD", "\\n pula para a linha de baixo, na mesma coluna")
	con.write("X".repeat(50), 0, 30)
	check(str(con.lines[0]).length() == ScreenNode.COLS and str(con.lines[0]).substr(30) == "XX", "texto longo é cortado no fim da linha")
	var clr := _const(1.0, Vector3(5, 0, 1))
	Signals.connect_ports(clr, "Valor", con, "Limpar")
	await _frames(2)
	check(con.console_text().strip_edges() == "", "Limpar apaga a tela")
	con.write("SALVO", 5, 0)
	var con2 := ScreenNode.new()
	con2.setup("console")
	con2.load_state(JSON.parse_string(JSON.stringify(con.save_state())))
	check(str(con2.lines[5]).begins_with("SALVO"), "o texto vai junto no save")

	print("== Tela de pixels")
	var px := _spawn("tela_pixels", Vector3(0, 0, 4)) as ScreenNode
	var kx := _const(5.0, Vector3(1, 0, 5))
	var ky := _const(6.0, Vector3(2, 0, 5))
	var kc := _const(Vector3(255, 0, 0), Vector3(3, 0, 5))
	var kd := _const(1.0, Vector3(4, 0, 5))
	Signals.connect_ports(kx, "Valor", px, "X")
	Signals.connect_ports(ky, "Valor", px, "Y")
	Signals.connect_ports(kc, "Valor", px, "Cor")
	Signals.connect_ports(kd, "Valor", px, "Desenhar")
	await _frames(2)
	var red := px.image.get_pixel(5, 6)
	kx.set_value(SignalNode.NUM, 99.0)
	await _frames(2)
	check(red.r > 0.95 and red.g < 0.05 and px.image.get_pixel(6, 6).r < 0.05, "Desenhar pinta o pixel (5, 6) de vermelho; fora da tela é ignorado")
	var px2 := ScreenNode.new()
	px2.setup("tela_pixels")
	px2.load_state(JSON.parse_string(JSON.stringify(px.save_state())))
	check(px2.image.get_pixel(5, 6).r > 0.95, "os pixels vão junto no save")
	var kf := _const(1.0, Vector3(5, 0, 5))
	Signals.connect_ports(kf, "Valor", px, "Preencher")
	await _frames(2)
	check(px.image.get_pixel(31, 31).r > 0.95 and px.image.get_pixel(0, 0).r > 0.95, "Preencher pinta a tela inteira")

	print("== Osciloscópio")
	var osc := _spawn("osciloscopio", Vector3(0, 0, 8)) as ScreenNode
	var ka := _const(0.5, Vector3(1, 0, 9))
	Signals.connect_ports(ka, "Valor", osc, "A")
	await _frames(90)
	var y := int(roundf((1.0 - 0.5) * 0.5 * (ScreenNode.OSC_H - 1)))
	var c := osc.image.get_pixel(ScreenNode.OSC_W - 2, y)
	check(osc._sa.size() > 30 and c.g > 0.8 and c.r < 0.5, "A = 0,5 aparece na altura certa (meio do caminho até o topo)")

	print("== Indicador no HUD e câmera")
	var base: Part = Build.spawn_box(Vector3(2, 0.1, 2), "aco", Transform3D(Basis(), Vector3(20, 0.05, 0)))
	var seat: Part = Components.spawn("assento", Transform3D(Basis(), Vector3(20, 0.16, 0)))[0]
	Build.make_weld(seat, base, Vector3(20, 0.1, 0))
	var ind := _spawn("hud_indicador", Vector3(20.6, 0.1, 0.6), false) as GadgetNode
	Build.make_weld(ind.part, base, Vector3(20.6, 0.1, 0.6))
	var cam := _spawn("camera", Vector3(19.4, 0.1, 0.6), false) as GadgetNode
	Build.make_weld(cam.part, base, Vector3(19.4, 0.1, 0.6))
	var kv := _const(42.0, Vector3(23, 0, 3))
	Signals.connect_ports(kv, "Valor", ind, "Valor")
	await _frames(3)
	var pl := Player.new()
	var hidden := GadgetNode.hud_items(pl).is_empty()
	pl.seat = seat
	var items := GadgetNode.hud_items(pl)
	check(hidden and items.size() == 1 and str(items[0][1]) == "42.0", "indicador: só aparece para quem está sentado na máquina (%s)" % str(items))
	ind.style = 1
	ind.bar_max = 84.0
	await _frames(2)
	items = GadgetNode.hud_items(pl)
	check(is_equal_approx(float(items[0][2]), 0.5) and str(items[0][1]) == "50%", "indicador em barra: 42 de 84 = 50%")
	pl.seat = null
	ind.always = true
	check(GadgetNode.hud_items(pl).size() == 1, "indicador marcado como sempre aparece mesmo sem sentar")
	var lig := _const(0.0, Vector3(24, 0, 3))
	Signals.connect_ports(lig, "Valor", cam, "Ligar")
	pl.seat = seat
	await _frames(2)
	var off_cam := GadgetNode.view_camera(pl)
	lig.set_value(SignalNode.NUM, 1.0)
	await _frames(2)
	var on_cam := GadgetNode.view_camera(pl)
	pl.seat = null
	check(off_cam == null and on_cam == cam.cam and GadgetNode.view_camera(pl) == null and float(cam.out["Ligada"]) == 1.0,
		"câmera: com Ligar e sentado na máquina, a visão passa para ela")
	pl.free()

	print("== Marcadores")
	var mk := _spawn("marcador", Vector3(30, 0, 0)) as GadgetNode
	var ml := _spawn("marcador_lista", Vector3(31, 0, 0)) as GadgetNode
	var b1: Part = Build.spawn_box(Vector3(0.3, 0.3, 0.3), "aco", Transform3D(Basis(), Vector3(33, 0.15, 0)))
	var b2: Part = Build.spawn_box(Vector3(0.3, 0.3, 0.3), "aluminio", Transform3D(Basis(), Vector3(35, 0.15, 0)))
	mk.toggle_mark(b1)
	mk.toggle_mark(b2)
	ml.toggle_mark(b1)
	ml.toggle_mark(b2)
	await _frames(2)
	check(mk.marked == [b2] and ml.marked.size() == 2 and float(ml.out["Quantidade"]) == 2.0, "marcador simples troca a peça; o de lista guarda as duas")
	check(mk.out["Peça"] == b2 and absf(float(mk.out["Distância"]) - b2.global_position.distance_to(mk.part.global_position)) < 0.01 \
		and (mk.out["Posição"] as Vector3).distance_to(b2.global_position) < 0.01 and is_equal_approx(float(mk.out["Massa"]), b2.mass),
		"saídas do marcador: Peça, Posição, Distância e Massa")
	ml.toggle_mark(b1)
	check(ml.marked == [b2], "clicar de novo desmarca")
	ml.toggle_mark(b1)

	print("== Pintor")
	var pin := _spawn("pintor", Vector3(40, 0, 0)) as GadgetNode
	var pc := _const(Vector3(0, 0, 255), Vector3(41, 0, 2))
	Signals.connect_ports(pc, "Valor", pin, "Cor")
	Signals.connect_ports(mk, "Peça", pin, "Peça")
	await _frames(2)
	check(b2.paint.is_equal_approx(Color(0, 0, 1)) and b1.paint.a == 0.0, "pinta a peça da entrada Peça (a do marcador) de azul")
	Signals.connect_ports(ml, "Lista", pin, "Lista")
	pc.set_value(SignalNode.VEC, Vector3(255, 255, 0))
	await _frames(2)
	check(b1.paint.is_equal_approx(Color(1, 1, 0)) and b2.paint.is_equal_approx(Color(1, 1, 0)), "e as peças da Lista")
	# Bico: sem fio em Peça/Lista, pinta o que está em cima
	var pin2 := _spawn("pintor", Vector3(40, 0, 6)) as GadgetNode
	var top: Part = Build.spawn_box(Vector3(0.4, 0.1, 0.4), "aco", Transform3D(Basis(), Vector3(40, 0.6, 6)))
	top.assembly().set_frozen(true)
	var pc2 := _const(Vector3(0, 255, 0), Vector3(42, 0, 7))
	Signals.connect_ports(pc2, "Valor", pin2, "Cor")
	await _frames(3)
	check(top.paint.is_equal_approx(Color(0, 1, 0)), "sem fio em Peça, pinta a peça na frente do bico")
	var lim := _const(0.0, Vector3(43, 0, 7))
	Signals.connect_ports(lim, "Valor", pin2, "Limpar")
	var pint := _const(0.0, Vector3(44, 0, 7))
	Signals.connect_ports(pint, "Valor", pin2, "Pintar")
	await _frames(2)
	lim.set_value(SignalNode.NUM, 1.0)
	await _frames(2)
	check(top.paint.a == 0.0, "Limpar volta a cor do metal")
	# Corte mantém a pintura
	b1.set_paint(Color(1, 0, 0))
	var pieces := Build.cut_part(b1, Plane(Vector3.RIGHT, 0.0))
	check(pieces.size() == 2 and (pieces[0] as Part).paint.is_equal_approx(Color(1, 0, 0)) and (pieces[1] as Part).paint.is_equal_approx(Color(1, 0, 0)),
		"cortar uma peça pintada: os dois pedaços continuam pintados")

	print("== Salvar")
	await _frames(2)
	var data: Dictionary = JSON.parse_string(JSON.stringify(Saves.serialize(Saves.world_assemblies(), Transform3D.IDENTITY)))
	Saves.clear_world()
	await _frames(3)
	Saves.restore(data, Transform3D.IDENTITY)
	await _frames(4)
	var painted := 0
	var lists := 0
	for a in Saves.world_assemblies():
		for p: Part in (a as Assembly).get_parts():
			if p.paint.a > 0.0:
				painted += 1
	for n in Signals.nodes:
		if n is GadgetNode and (n as GadgetNode).kind == "marcador_lista":
			lists = (n as GadgetNode).marked.size()
	check(painted >= 3 and lists >= 1, "pintura e peças marcadas voltam do save (%d pintadas, lista com %d)" % [painted, lists])

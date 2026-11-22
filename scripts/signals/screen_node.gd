class_name ScreenNode
extends SignalNode
## Telas avançadas (Marco 4E):
##   console       grade de letras (32 × 12). Escreve Texto na Linha/Coluna (a cada pulso em
##                 Escrever; sem fio em Escrever, escreve todo tick). "\n" pula de linha.
##                 Limpar apaga. Cor (0 a 255) muda a cor das letras.
##   tela_pixels   32 × 32 pixels. Com Desenhar ligado, pinta o pixel X, Y com a Cor (0 a 255).
##                 Preencher pinta tudo; Limpar apaga (preto). Origem (0, 0) no canto de cima,
##                 à esquerda.
##   osciloscopio  desenha A (verde) e B (amarelo) ao longo do tempo. Escala: o valor que
##                 encosta no topo (padrão 1). Tempo: segundos na largura (padrão 2).

const KINDS := {"console": "Console de letras", "tela_pixels": "Tela de pixels", "osciloscopio": "Osciloscópio"}
const COLS := 32
const ROWS := 12
const PIX := 32
const OSC_W := 128
const OSC_H := 64

var part: Part
var kind := "console"
var label: Label3D                ## console
var quad: MeshInstance3D          ## tela de pixels / osciloscópio
var text_color := Color(0.55, 1.0, 0.6)
var osc_scale := 1.0              ## osciloscópio: escala padrão (sem fio)
var osc_time := 2.0               ## osciloscópio: segundos na largura (sem fio)

var lines: Array = []             ## console: ROWS textos de COLS letras
var image: Image
var _tex: ImageTexture
var _mat: StandardMaterial3D
var _dirty := false
var _edges := {}
var _sa: Array = []               ## osciloscópio: amostras de A
var _sb: Array = []
var _acc := 0.0
var _draw_t := 0


func signal_part() -> Part:
	return part


func kind_label() -> String:
	return KINDS.get(kind, kind)


func inputs() -> Array:
	match kind:
		"console":
			return [["Texto", TXT], ["Linha", NUM], ["Coluna", NUM], ["Escrever", NUM], ["Limpar", NUM], ["Cor", VEC]]
		"tela_pixels":
			return [["X", NUM], ["Y", NUM], ["Cor", VEC], ["Desenhar", NUM], ["Preencher", NUM], ["Limpar", NUM]]
		"osciloscopio":
			return [["A", NUM], ["B", NUM], ["Escala", NUM], ["Tempo", NUM]]
	return []


func is_source() -> bool:
	return false


func setup(k: String) -> void:
	kind = k
	match kind:
		"console":
			clear_console()
		"tela_pixels":
			image = Image.create(PIX, PIX, false, Image.FORMAT_RGB8)
			image.fill(Color.BLACK)
			_dirty = true
		"osciloscopio":
			image = Image.create(OSC_W, OSC_H, false, Image.FORMAT_RGB8)
			_sa = []
			_sb = []
			_draw_osc()


## Liga a malha da tela (um quadrado em cima da peça) à imagem.
func attach_quad(q: MeshInstance3D) -> void:
	quad = q
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	quad.material_override = _mat
	_dirty = true
	_upload()


func _rising(key: String, v: float) -> bool:
	var prev: float = _edges.get(key, 0.0)
	_edges[key] = v
	return prev <= 0.0 and v > 0.0


func evaluate(inp: Dictionary, wired: Dictionary, dt: float) -> void:
	match kind:
		"console":
			if _rising("Limpar", float(inp["Limpar"])):
				clear_console()
			if wired.has("Cor"):
				var c: Vector3 = inp["Cor"]
				text_color = Color(clampf(c.x / 255.0, 0, 1), clampf(c.y / 255.0, 0, 1), clampf(c.z / 255.0, 0, 1))
			var go := _rising("Escrever", float(inp["Escrever"])) if wired.has("Escrever") else wired.has("Texto")
			if go:
				write(str(inp["Texto"]), int(floor(float(inp["Linha"]))), int(floor(float(inp["Coluna"]))))
			if label and (_dirty or Engine.get_physics_frames() % 20 == 0):
				label.text = console_text()
				label.modulate = text_color
				_dirty = false
		"tela_pixels":
			var c2: Vector3 = inp["Cor"]
			var col := Color(clampf(c2.x / 255.0, 0, 1), clampf(c2.y / 255.0, 0, 1), clampf(c2.z / 255.0, 0, 1))
			if _rising("Limpar", float(inp["Limpar"])):
				image.fill(Color.BLACK)
				_dirty = true
			if _rising("Preencher", float(inp["Preencher"])):
				image.fill(col)
				_dirty = true
			if float(inp["Desenhar"]) > 0.0:
				set_pixel(int(floor(float(inp["X"]))), int(floor(float(inp["Y"]))), col)
			_upload()
		"osciloscopio":
			var tm := float(inp["Tempo"]) if wired.has("Tempo") and float(inp["Tempo"]) > 0.0 else osc_time
			var sc := absf(float(inp["Escala"])) if wired.has("Escala") and absf(float(inp["Escala"])) > 1e-6 else osc_scale
			_acc += dt
			var step := maxf(tm / OSC_W, 1e-4)
			while _acc >= step:
				_acc -= step
				_sa.append(float(inp["A"]) / sc if wired.has("A") else NAN)
				_sb.append(float(inp["B"]) / sc if wired.has("B") else NAN)
				if _sa.size() > OSC_W:
					_sa.pop_front()
					_sb.pop_front()
			_draw_t += 1
			if _draw_t >= 3:
				_draw_t = 0
				_draw_osc()


# --- Console ---------------------------------------------------------------------------

func clear_console() -> void:
	lines = []
	for r in ROWS:
		lines.append(" ".repeat(COLS))
	_dirty = true


## Escreve a partir da linha/coluna; "\n" vai para o começo da linha de baixo.
func write(t: String, row: int, col: int) -> void:
	if lines.size() != ROWS:
		clear_console()
	var r := clampi(row, 0, ROWS - 1)
	var c := clampi(col, 0, COLS - 1)
	for ch in t:
		if ch == "\n":
			r += 1
			c = clampi(col, 0, COLS - 1)
			if r >= ROWS:
				break
			continue
		if c >= COLS:
			continue
		var line: String = lines[r]
		lines[r] = line.substr(0, c) + ch + line.substr(c + 1)
		c += 1
	_dirty = true


func console_text() -> String:
	return "\n".join(lines.map(func(l: String) -> String: return l.rstrip(" ")))


# --- Pixels ----------------------------------------------------------------------------

func set_pixel(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= PIX or y >= PIX:
		return
	if image.get_pixel(x, y) != c:
		image.set_pixel(x, y, c)
		_dirty = true


func _upload() -> void:
	if not _dirty or quad == null or image == null:
		return
	_dirty = false
	if _tex == null:
		_tex = ImageTexture.create_from_image(image)
		_mat.albedo_texture = _tex
	else:
		_tex.update(image)


# --- Osciloscópio ----------------------------------------------------------------------

func _draw_osc() -> void:
	if image == null:
		return
	image.fill(Color(0.02, 0.05, 0.04))
	var grid := Color(0.08, 0.2, 0.12)
	for gx in range(0, OSC_W, 16):
		for y in OSC_H:
			image.set_pixel(gx, y, grid)
	for gy in [OSC_H / 4, OSC_H * 3 / 4]:
		for x in OSC_W:
			image.set_pixel(x, gy, grid)
	for x in OSC_W:
		image.set_pixel(x, OSC_H / 2, Color(0.15, 0.35, 0.2))
	_trace(_sb, Color(1.0, 0.85, 0.2))
	_trace(_sa, Color(0.35, 1.0, 0.45))
	_dirty = true
	_upload()


func _trace(samples: Array, c: Color) -> void:
	var off := OSC_W - samples.size()
	var prev_y := -1
	for i in samples.size():
		var v := float(samples[i])
		if is_nan(v):
			prev_y = -1
			continue
		var y := clampi(int(roundf((1.0 - clampf(v, -1.0, 1.0)) * 0.5 * (OSC_H - 1))), 0, OSC_H - 1)
		var x := off + i
		if prev_y >= 0:
			for yy in range(mini(prev_y, y), maxi(prev_y, y) + 1):
				image.set_pixel(x, yy, c)
		else:
			image.set_pixel(x, y, c)
		prev_y = y


# --- Salvar ----------------------------------------------------------------------------

func save_state() -> Dictionary:
	match kind:
		"console":
			return {"lines": lines.duplicate(), "color": [text_color.r, text_color.g, text_color.b]}
		"tela_pixels":
			return {"px": Marshalls.raw_to_base64(image.get_data())}
		"osciloscopio":
			return {"scale": osc_scale, "time": osc_time}
	return {}


func load_state(d: Dictionary) -> void:
	match kind:
		"console":
			var src: Array = d.get("lines", [])
			clear_console()
			for r in mini(src.size(), ROWS):
				var l := str(src[r]).left(COLS)
				lines[r] = l + " ".repeat(COLS - l.length())
			var c: Array = d.get("color", [])
			if c.size() == 3:
				text_color = Color(float(c[0]), float(c[1]), float(c[2]))
			if label:
				label.text = console_text()
				label.modulate = text_color
		"tela_pixels":
			if d.has("px"):
				var raw := Marshalls.base64_to_raw(str(d["px"]))
				if raw.size() == PIX * PIX * 3:
					image = Image.create_from_data(PIX, PIX, false, Image.FORMAT_RGB8, raw)
					_tex = null
					_dirty = true
					_upload()
		"osciloscopio":
			osc_scale = maxf(float(d.get("scale", osc_scale)), 1e-6)
			osc_time = maxf(float(d.get("time", osc_time)), 0.05)

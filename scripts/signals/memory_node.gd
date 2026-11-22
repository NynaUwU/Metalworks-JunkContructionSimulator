class_name MemoryNode
extends SignalNode
## Memórias (Marco 4E):
##   memoria  RAM: guarda números em posições (8 a 1024). Gravar ligado escreve Dado no
##            Endereço; Lido mostra o que tem no Endereço. Zerar apaga tudo.
##   rom      só leitura: os valores são escritos nos ajustes (botão direito com a Fiação).
##   hd       disco rígido: como a RAM (1024 posições), mas guarda num arquivo com o nome
##            do disco: os valores ficam mesmo depois de sair do jogo ou trocar de mundo.
##            Dois HDs com o mesmo nome de disco veem os mesmos dados.
## Endereços começam em 0. Fora da faixa: Lido = 0 e nada é gravado.

const KINDS := {"memoria": "Memória (RAM)", "rom": "Memória só de leitura (ROM)", "hd": "Disco rígido (HD)"}
const SIZES := [8, 16, 32, 64, 128, 256, 512, 1024]
const HD_SIZE := 1024
const ROM_MAX := 1024
const HD_DIR := "user://hd"
const HD_FLUSH := 0.5

## HD: nome do disco -> Array de números (o mesmo Array para todos os HDs desse disco).
static var disks := {}
static var _dirty_disks := {}
static var _flush_t := 0.0

var part: Part
var kind := "memoria"
var size := 64
var data: Array = []
var disk := "disco1"
var label: Label3D
var _addr := 0


func _init() -> void:
	_resize(size)


func signal_part() -> Part:
	return part


func kind_label() -> String:
	return KINDS.get(kind, kind)


func inputs() -> Array:
	if kind == "rom":
		return [["Endereço", NUM]]
	return [["Endereço", NUM], ["Dado", NUM], ["Gravar", NUM], ["Zerar", NUM]]


func outputs() -> Array:
	return [["Lido", NUM], ["Tamanho", NUM]]


func is_source() -> bool:
	return false


func setup(k: String) -> void:
	kind = k
	if kind == "hd":
		set_disk(disk)
	elif kind == "rom":
		data = [0.0, 1.0, 2.0, 3.0]
		size = data.size()
	update_label()


func _resize(n: int) -> void:
	size = clampi(n, 1, ROM_MAX)
	while data.size() < size:
		data.append(0.0)
	if data.size() > size:
		data.resize(size)


func set_size(n: int) -> void:
	if kind == "memoria":
		_resize(n)
		update_label()


## ROM: valores separados por espaço, vírgula, ponto e vírgula ou linha ("1,5" vira 1.5
## quando separado por ponto e vírgula ou espaço).
func set_rom_text(t: String) -> void:
	var vals: Array = []
	var clean := t.replace("\n", " ").replace("\t", " ").replace(";", " ")
	# "1, 2, 3" → vírgula como separador; "1,5 2,5" → vírgula decimal.
	if clean.contains(", ") or not clean.contains(" "):
		clean = clean.replace(",", " ")
	for tok in clean.split(" ", false):
		if vals.size() >= ROM_MAX:
			break
		vals.append(tok.replace(",", ".").to_float())
	if vals.is_empty():
		vals = [0.0]
	data = vals
	size = data.size()
	update_label()


func rom_text() -> String:
	return " ".join(data.map(func(v: float) -> String: return SignalNode.format(v)))


func set_disk(n: String) -> void:
	disk = _safe(n)
	if disk == "":
		disk = "disco1"
	data = disk_data(disk)
	size = HD_SIZE
	update_label()


static func _safe(n: String) -> String:
	var s := ""
	for ch in n.strip_edges():
		s += ch if (ch.is_valid_identifier() or ch.is_valid_int() or ch == "-") else "_"
	return s.left(32)


## Os dados de um disco (lidos do arquivo na primeira vez).
static func disk_data(n: String) -> Array:
	if disks.has(n):
		return disks[n]
	var arr: Array = []
	var path := "%s/%s.json" % [HD_DIR, n]
	if FileAccess.file_exists(path):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary and (d as Dictionary).get("data") is Array:
			for v in d["data"]:
				arr.append(float(v))
	while arr.size() < HD_SIZE:
		arr.append(0.0)
	arr.resize(HD_SIZE)
	disks[n] = arr
	return arr


static func flush_disks() -> void:
	if _dirty_disks.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(HD_DIR)
	for n: String in _dirty_disks:
		var arr: Array = disks.get(n, [])
		var last := arr.size()
		while last > 0 and float(arr[last - 1]) == 0.0:
			last -= 1
		var f := FileAccess.open("%s/%s.json" % [HD_DIR, n], FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"versao": 1, "data": arr.slice(0, last)}))
	_dirty_disks.clear()


func evaluate(inp: Dictionary, wired: Dictionary, dt: float) -> void:
	_addr = int(floor(float(inp.get("Endereço", 0.0))))
	var ok := _addr >= 0 and _addr < data.size()
	if kind != "rom":
		if wired.has("Zerar") and float(inp["Zerar"]) > 0.0:
			for i in data.size():
				data[i] = 0.0
			_touch()
		elif ok and wired.has("Gravar") and float(inp["Gravar"]) > 0.0:
			var v := float(inp.get("Dado", 0.0))
			if data[_addr] != v:
				data[_addr] = v
				_touch()
	out["Lido"] = float(data[_addr]) if ok else 0.0
	out["Tamanho"] = float(data.size())
	if kind == "hd":
		_flush_t += dt
		if _flush_t >= HD_FLUSH:
			_flush_t = 0.0
			flush_disks()
	if label and Engine.get_physics_frames() % 10 == 0:
		update_label()


func _touch() -> void:
	if kind == "hd":
		_dirty_disks[disk] = true


func update_label() -> void:
	if label == null:
		return
	match kind:
		"memoria":
			label.text = "RAM %d\n[%d] %s" % [data.size(), _addr, SignalNode.format(out.get("Lido", 0.0))]
		"rom":
			label.text = "ROM %d\n[%d] %s" % [data.size(), _addr, SignalNode.format(out.get("Lido", 0.0))]
		"hd":
			label.text = "HD · %s\n[%d] %s" % [disk, _addr, SignalNode.format(out.get("Lido", 0.0))]


func save_state() -> Dictionary:
	match kind:
		"memoria":
			var last := data.size()
			while last > 0 and float(data[last - 1]) == 0.0:
				last -= 1
			return {"size": size, "data": data.slice(0, last)}
		"rom":
			return {"data": data.duplicate()}
		"hd":
			flush_disks()
			return {"disk": disk}
	return {}


func load_state(d: Dictionary) -> void:
	match kind:
		"memoria":
			_resize(int(d.get("size", size)))
			var src: Array = d.get("data", [])
			for i in mini(src.size(), size):
				data[i] = float(src[i])
		"rom":
			var src2: Array = d.get("data", [])
			if not src2.is_empty():
				data = src2.map(func(v: Variant) -> float: return float(v)).slice(0, ROM_MAX)
				size = data.size()
		"hd":
			set_disk(str(d.get("disk", disk)))
	update_label()

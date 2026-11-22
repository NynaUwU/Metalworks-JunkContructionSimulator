class_name Catalog
extends RefCounted
## Itens vendidos na loja.
##
## - Alguns itens têm medidas ajustáveis ("params"), sempre dentro de um limite.
## - O preço sai do peso e do metal: sempre mais caro do que o reciclador paga pela
##   mesma peça (PRICE_FACTOR), para não dar pontos infinitos.

const PRICE_FACTOR := 1.6
const DIAG_XZ := Vector3(0.70710678, 0, 0.70710678)
const DIAG_YZ := Vector3(0, 0.70710678, 0.70710678)

const LEN_BEAM := {"nome": "Comprimento", "axes": [2], "min": 0.5, "max": 6.0, "step": 0.25}
const PLATE_W := {"nome": "Largura", "axes": [0], "min": 0.5, "max": 4.0, "step": 0.25}
const PLATE_L := {"nome": "Comprimento", "axes": [2], "min": 0.5, "max": 4.0, "step": 0.25}
## Escolha de tamanho das peças mecânicas (vai em size.x: 0,6 / 1 / 1,6).
const SIZE := {"nome": "Tamanho", "axes": [0], "choices": [["Pequeno", 0.6], ["Médio", 1.0], ["Grande", 1.6]]}
## Roda: o tamanho preenche raio e largura (que ainda dá para ajustar).
const WHEEL_SIZE := {"nome": "Tamanho", "axes": [0, 1], "choices": [["Pequena", [0.35, 0.2]], ["Média", [0.55, 0.3]], ["Grande", [0.8, 0.4]]]}

const ITEMS := [
	{"id": "chapa", "nome": "Chapa", "cat": "Chapas", "mat": "aco", "box": Vector3(1, 0.1, 1),
		"params": [PLATE_W, PLATE_L]},
	{"id": "chapa_fina", "nome": "Chapa fina", "cat": "Chapas", "mat": "aluminio", "box": Vector3(2, 0.05, 2),
		"params": [PLATE_W, PLATE_L]},
	{"id": "chapa_grossa", "nome": "Chapa grossa", "cat": "Chapas", "mat": "ferro", "box": Vector3(1, 0.2, 1),
		"params": [{"nome": "Largura", "axes": [0], "min": 0.5, "max": 3.0, "step": 0.25},
			{"nome": "Comprimento", "axes": [2], "min": 0.5, "max": 3.0, "step": 0.25}]},
	{"id": "chapa_tri", "nome": "Chapa triangular", "cat": "Chapas", "mat": "aco", "box": Vector3(2, 0.1, 2), "cut": DIAG_XZ,
		"params": [{"nome": "Lado", "axes": [0, 2], "min": 0.5, "max": 3.0, "step": 0.25}]},
	{"id": "viga", "nome": "Viga", "cat": "Vigas e barras", "mat": "aco", "box": Vector3(0.2, 0.2, 2),
		"params": [LEN_BEAM]},
	{"id": "viga_leve", "nome": "Viga leve", "cat": "Vigas e barras", "mat": "aluminio", "box": Vector3(0.2, 0.2, 2),
		"params": [LEN_BEAM]},
	{"id": "barra", "nome": "Barra", "cat": "Vigas e barras", "mat": "aluminio", "box": Vector3(0.1, 0.1, 2),
		"params": [LEN_BEAM]},
	{"id": "barra_aco", "nome": "Barra de aço", "cat": "Vigas e barras", "mat": "aco", "box": Vector3(0.1, 0.1, 2),
		"params": [LEN_BEAM]},
	{"id": "bloco_05", "nome": "Bloco 0,5 m", "cat": "Blocos", "mat": "aco", "box": Vector3(0.5, 0.5, 0.5)},
	{"id": "bloco_1", "nome": "Bloco 1 m", "cat": "Blocos", "mat": "ferro", "box": Vector3(1, 1, 1)},
	{"id": "tarugo", "nome": "Tarugo", "cat": "Blocos", "mat": "ferro", "box": Vector3(1, 0.5, 0.5),
		"params": [{"nome": "Comprimento", "axes": [0], "min": 0.5, "max": 3.0, "step": 0.25}]},
	{"id": "cilindro", "nome": "Cilindro (octogonal)", "cat": "Cilindros", "mat": "aco", "box": Vector3(0.3, 0.3, 2), "shape": "oct",
		"params": [{"nome": "Diâmetro", "axes": [0, 1], "min": 0.1, "max": 1.2, "step": 0.05}, LEN_BEAM]},
	{"id": "cilindro_al", "nome": "Cilindro de alumínio", "cat": "Cilindros", "mat": "aluminio", "box": Vector3(0.2, 0.2, 2), "shape": "oct",
		"params": [{"nome": "Diâmetro", "axes": [0, 1], "min": 0.1, "max": 1.2, "step": 0.05}, LEN_BEAM]},
	{"id": "tambor", "nome": "Tambor (cilindro curto)", "cat": "Cilindros", "mat": "ferro", "box": Vector3(0.8, 0.8, 0.5), "shape": "oct",
		"params": [{"nome": "Diâmetro", "axes": [0, 1], "min": 0.3, "max": 1.6, "step": 0.1},
			{"nome": "Comprimento", "axes": [2], "min": 0.1, "max": 1.5, "step": 0.05}]},
	{"id": "cunha", "nome": "Cunha (rampa)", "cat": "Blocos", "mat": "aco", "box": Vector3(1, 1, 1), "cut": DIAG_YZ,
		"params": [{"nome": "Tamanho", "axes": [0, 1, 2], "min": 0.5, "max": 2.0, "step": 0.25}]},
	{"id": "motor", "nome": "Motor", "cat": "Componentes", "component": "motor", "box": Vector3(1, 0, 0), "params": [SIZE]},
	{"id": "servo", "nome": "Servo", "cat": "Componentes", "component": "servo", "box": Vector3(1, 0, 0), "params": [SIZE]},
	{"id": "pistao", "nome": "Pistão", "cat": "Componentes", "component": "pistao", "box": Vector3(1, 0, 0), "params": [SIZE]},
	{"id": "servo_linear", "nome": "Servo linear", "cat": "Componentes", "component": "servo_linear", "box": Vector3(1, 0, 0), "params": [SIZE]},
	{"id": "dobradica", "nome": "Dobradiça", "cat": "Componentes", "component": "dobradica", "box": Vector3(1, 0, 0), "params": [SIZE]},
	{"id": "pino", "nome": "Dobradiça de pino", "cat": "Componentes", "component": "pino", "box": Vector3(1, 0, 0), "params": [SIZE]},
	{"id": "pino_oct", "nome": "Dobradiça de pino octogonal", "cat": "Componentes", "component": "pino_oct", "box": Vector3(1, 0, 0), "params": [SIZE]},
	{"id": "esferica", "nome": "Junta esférica", "cat": "Componentes", "component": "esferica", "box": Vector3(1, 0, 0), "params": [SIZE]},
	{"id": "trava", "nome": "Dobradiça com trava", "cat": "Componentes", "component": "trava", "box": Vector3(1, 0, 0), "params": [SIZE]},
	{"id": "torcao", "nome": "Dobradiça de torção", "cat": "Componentes", "component": "torcao", "box": Vector3(1, 0, 0), "params": [SIZE]},
	{"id": "mola", "nome": "Mola", "cat": "Componentes", "component": "mola", "box": Vector3(1, 0, 0), "params": [SIZE]},
	{"id": "guincho", "nome": "Guincho", "cat": "Componentes", "component": "guincho", "box": Vector3(1, 0, 0), "params": [SIZE]},
	{"id": "propulsor", "nome": "Propulsor", "cat": "Componentes", "component": "propulsor"},
	{"id": "ima", "nome": "Eletroímã", "cat": "Componentes", "component": "ima"},
	{"id": "engate", "nome": "Engate rápido", "cat": "Componentes", "component": "engate"},
	{"id": "roda", "nome": "Roda", "cat": "Componentes", "component": "roda", "box": Vector3(0.35, 0.2, 0),
		"params": [WHEEL_SIZE, {"nome": "Raio", "axes": [0], "min": 0.2, "max": 1.2, "step": 0.05},
			{"nome": "Largura", "axes": [1], "min": 0.1, "max": 0.6, "step": 0.05}]},
	{"id": "assento", "nome": "Assento", "cat": "Componentes", "component": "assento"},
	{"id": "botao", "nome": "Botão", "cat": "Controles", "component": "botao"},
	{"id": "alavanca", "nome": "Alavanca", "cat": "Controles", "component": "alavanca"},
	{"id": "potenciometro", "nome": "Alavanca variável", "cat": "Controles", "component": "potenciometro"},
	{"id": "teclas", "nome": "Teclas", "cat": "Controles", "component": "teclas"},
	{"id": "puxador", "nome": "Puxador", "cat": "Controles", "component": "puxador"},
	{"id": "teclado", "nome": "Teclado de senha", "cat": "Controles", "component": "teclado"},
	{"id": "bateria", "nome": "Bateria", "cat": "Energia", "component": "bateria", "box": Vector3(1, 0, 0), "params": [SIZE]},
	{"id": "solar", "nome": "Painel solar", "cat": "Energia", "component": "solar"},
	{"id": "recarga", "nome": "Posto de recarga", "cat": "Energia", "component": "recarga"},
	{"id": "luz", "nome": "Luz", "cat": "Energia", "component": "luz"},
	{"id": "holofote", "nome": "Holofote", "cat": "Energia", "component": "holofote"},
	{"id": "rele", "nome": "Relé de potência", "cat": "Energia", "component": "rele"},
	{"id": "chave", "nome": "Chave de energia", "cat": "Energia", "component": "chave"},
	{"id": "medidor", "nome": "Medidor de energia", "cat": "Energia", "component": "medidor"},
	{"id": "chip", "nome": "Chip lógico", "cat": "Lógica", "component": "chip"},
	{"id": "constante", "nome": "Valor constante", "cat": "Lógica", "component": "constante"},
	{"id": "indicador", "nome": "Indicador", "cat": "Mostradores", "component": "indicador"},
	{"id": "pixel", "nome": "Pixel", "cat": "Mostradores", "component": "pixel"},
	{"id": "mostrador", "nome": "Mostrador numérico", "cat": "Mostradores", "component": "mostrador"},
	{"id": "tela", "nome": "Tela de valores", "cat": "Mostradores", "component": "tela"},
	{"id": "tela_texto", "nome": "Tela de texto", "cat": "Mostradores", "component": "tela_texto"},
]

static var _geo_cache := {}


static func get_item(id: String) -> Dictionary:
	for it: Dictionary in ITEMS:
		if it["id"] == id:
			return it
	return {}


static func categories() -> Array[String]:
	var out: Array[String] = []
	for it: Dictionary in ITEMS:
		if not out.has(it["cat"]):
			out.append(it["cat"])
	return out


static func is_locked(item: Dictionary) -> bool:
	return item.get("locked", false)


static func is_component(item: Dictionary) -> bool:
	return item.has("component")


static func params(item: Dictionary) -> Array:
	return item.get("params", [])


static func default_size(item: Dictionary) -> Vector3:
	return item.get("box", Vector3.ONE)


## Valor atual de um parâmetro dentro de um tamanho.
static func param_value(size: Vector3, param: Dictionary) -> float:
	return size[param["axes"][0]]


## Escolha (Pequeno/Médio/Grande) mais perto do valor atual. Retorna o índice.
static func choice_index(size: Vector3, param: Dictionary) -> int:
	var best := 0
	var best_d := INF
	var choices: Array = param["choices"]
	for i in choices.size():
		var v = choices[i][1]
		var first: float = v[0] if v is Array else v
		var d := absf(size[param["axes"][0]] - first)
		if d < best_d:
			best_d = d
			best = i
	return best


## Aplica uma escolha (índice) de um parâmetro de escolhas.
static func with_choice(size: Vector3, param: Dictionary, index: int) -> Vector3:
	var v = param["choices"][clampi(index, 0, (param["choices"] as Array).size() - 1)][1]
	var axes: Array = param["axes"]
	for i in axes.size():
		size[axes[i]] = (v[i] if v is Array else v)
	return size


## Aplica um valor (já limitado e arredondado ao passo) a um parâmetro.
static func with_param(size: Vector3, param: Dictionary, value: float) -> Vector3:
	if param.has("choices"):
		var probe := size
		probe[param["axes"][0]] = value
		return with_choice(size, param, choice_index(probe, param))
	var v := clampf(snappedf(value, param["step"]), param["min"], param["max"])
	for axis: int in param["axes"]:
		size[axis] = v
	return size


## Garante que um tamanho pedido respeita os limites do item.
static func clamp_size(item: Dictionary, size: Vector3) -> Vector3:
	var base := default_size(item)
	if size == Vector3.ZERO:
		return base
	var out := base
	for p: Dictionary in params(item):
		out = with_param(out, p, param_value(size, p))
	return out


## Caixa (coordenadas locais) que o item ocupa ao aparecer.
static func spawn_bounds(item: Dictionary, size := Vector3.ZERO) -> AABB:
	if is_component(item):
		return Components.bounds(item["component"], clamp_size(item, size))
	return geometry(item, size)["aabb"]


static func planes(item: Dictionary, size := Vector3.ZERO) -> Array[Plane]:
	if item.get("shape", "") == "oct":
		var s := clamp_size(item, size)
		return ConvexGeo.oct_prism_planes(s.x, s.z)
	var p := ConvexGeo.box_planes(clamp_size(item, size))
	if item.has("cut"):
		p.append(Plane(item["cut"], 0.0))
	return p


static func geometry(item: Dictionary, size := Vector3.ZERO) -> Dictionary:
	var s := clamp_size(item, size)
	var key := "%s|%s" % [item["id"], s]
	if not _geo_cache.has(key):
		_geo_cache[key] = ConvexGeo.solve(planes(item, s))
	return _geo_cache[key]


static func mass(item: Dictionary, size := Vector3.ZERO) -> float:
	if is_locked(item) or is_component(item):
		return 0.0
	return geometry(item, size)["volume"] * MetalMaterials.density(item["mat"])


static func price(item: Dictionary, size := Vector3.ZERO) -> int:
	if is_locked(item):
		return 0
	if is_component(item):
		return Components.price(item["component"], clamp_size(item, size))
	return maxi(1, ceili(Economy.recycle_value(item["mat"], mass(item, size)) * PRICE_FACTOR))


## "2,50 m" (com vírgula).
static func meters(v: float) -> String:
	return ("%.2f m" % v).replace(".", ",")


## Medidas para mostrar na loja, ex.: "0,20 × 0,20 × 3,00 m".
static func size_text(size: Vector3) -> String:
	return ("%.2f × %.2f × %.2f m" % [size.x, size.y, size.z]).replace(".", ",")

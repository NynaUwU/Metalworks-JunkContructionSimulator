class_name MetalMaterials
extends RefCounted
## Tipos de metal: nome, densidade (kg/m³, escala de jogo) e aparência.

const DATA := {
	"aco": {
		"nome": "Aço",
		"densidade": 785.0,
		"valor": 0.10,          # pontos por kg no reciclador
		"cor": Color(0.55, 0.57, 0.61),
		"metal": 0.85,
		"rugosidade": 0.42,
		"sujeira": 0.18,
	},
	"aluminio": {
		"nome": "Alumínio",
		"densidade": 270.0,
		"valor": 0.30,
		"cor": Color(0.80, 0.82, 0.85),
		"metal": 0.8,
		"rugosidade": 0.3,
		"sujeira": 0.08,
	},
	"borracha": {
		"nome": "Borracha",
		"densidade": 120.0,
		"valor": 0.04,
		"cor": Color(0.07, 0.07, 0.075),
		"metal": 0.0,
		"rugosidade": 0.95,
		"sujeira": 0.15,
	},
	"carcaca": {
		"nome": "Carcaça",
		"densidade": 600.0,
		"valor": 0.08,
		"cor": Color(0.85, 0.6, 0.12),
		"metal": 0.3,
		"rugosidade": 0.5,
		"sujeira": 0.12,
	},
	"carcaca_azul": {
		"nome": "Carcaça",
		"densidade": 600.0,
		"valor": 0.08,
		"cor": Color(0.15, 0.35, 0.7),
		"metal": 0.3,
		"rugosidade": 0.5,
		"sujeira": 0.12,
	},
	"plastico": {
		"nome": "Plástico",
		"densidade": 150.0,
		"valor": 0.02,
		"cor": Color(0.16, 0.17, 0.19),
		"metal": 0.0,
		"rugosidade": 0.7,
		"sujeira": 0.05,
	},
	"ferro": {
		"nome": "Ferro velho",
		"densidade": 720.0,
		"valor": 0.06,
		"cor": Color(0.50, 0.30, 0.18),
		"metal": 0.35,
		"rugosidade": 0.85,
		"sujeira": 0.35,
	},
}

static var _cache: Dictionary = {}
static var _edge_material: StandardMaterial3D


static func density(id: String) -> float:
	return DATA[id]["densidade"]


static func value_per_kg(id: String) -> float:
	return DATA[id]["valor"]


static func display_name(id: String) -> String:
	return DATA[id]["nome"]


static func get_material(id: String) -> StandardMaterial3D:
	if _cache.has(id):
		return _cache[id]
	var d: Dictionary = DATA[id]
	var m := StandardMaterial3D.new()
	m.albedo_color = d["cor"]
	m.metallic = d["metal"]
	m.metallic_specular = 0.6
	m.roughness = d["rugosidade"]

	# Textura procedural de "sujeira": variação de cor e de rugosidade.
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.fractal_octaves = 4
	noise.seed = id.hash()
	var ramp := Gradient.new()
	var dirt: float = d["sujeira"]
	ramp.set_color(0, Color(1.0 - dirt, 1.0 - dirt * 1.1, 1.0 - dirt * 1.2))
	ramp.set_color(1, Color(1, 1, 1))
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	m.albedo_texture = tex

	var rough_tex := NoiseTexture2D.new()
	rough_tex.width = 256
	rough_tex.height = 256
	rough_tex.seamless = true
	rough_tex.noise = noise
	m.roughness_texture = rough_tex

	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	_cache[id] = m
	return m


## Material das arestas desenhadas sobre as peças (ajuda a ler a forma).
## Tinta (Pintor): material liso da cor pedida (cache por cor, 8 bits por canal).
static var _paint_cache: Dictionary = {}


static func paint_material(c: Color) -> StandardMaterial3D:
	var key := c.to_rgba32() | 0xff
	if _paint_cache.has(key):
		return _paint_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b)
	m.metallic = 0.15
	m.roughness = 0.45
	if _paint_cache.size() > 512:
		_paint_cache.clear()
	_paint_cache[key] = m
	return m


static func edge_material() -> StandardMaterial3D:
	if _edge_material:
		return _edge_material
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.08, 0.08, 0.09, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_edge_material = m
	return m

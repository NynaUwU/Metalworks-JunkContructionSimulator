class_name Catalog
extends RefCounted
## Itens vendidos na loja. O preço sai do peso e do metal: sempre mais caro do que
## o reciclador paga pela mesma peça (PRICE_FACTOR), para não dar pontos infinitos.

const PRICE_FACTOR := 1.6
const DIAG_XZ := Vector3(0.70710678, 0, 0.70710678)
const DIAG_YZ := Vector3(0, 0.70710678, 0.70710678)

const ITEMS := [
	{"id": "chapa_1x1", "nome": "Chapa 1×1", "cat": "Chapas", "mat": "aco", "box": Vector3(1, 0.1, 1)},
	{"id": "chapa_2x2", "nome": "Chapa 2×2", "cat": "Chapas", "mat": "aco", "box": Vector3(2, 0.1, 2)},
	{"id": "chapa_3x1", "nome": "Chapa 3×1", "cat": "Chapas", "mat": "aco", "box": Vector3(3, 0.1, 1)},
	{"id": "chapa_fina", "nome": "Chapa fina 2×2", "cat": "Chapas", "mat": "aluminio", "box": Vector3(2, 0.05, 2)},
	{"id": "chapa_tri", "nome": "Chapa triangular", "cat": "Chapas", "mat": "aco", "box": Vector3(2, 0.1, 2), "cut": DIAG_XZ},
	{"id": "viga_2", "nome": "Viga 2 m", "cat": "Vigas e barras", "mat": "aco", "box": Vector3(0.2, 0.2, 2)},
	{"id": "viga_4", "nome": "Viga 4 m", "cat": "Vigas e barras", "mat": "aco", "box": Vector3(0.2, 0.2, 4)},
	{"id": "barra_2", "nome": "Barra 2 m", "cat": "Vigas e barras", "mat": "aluminio", "box": Vector3(0.1, 0.1, 2)},
	{"id": "barra_4", "nome": "Barra 4 m", "cat": "Vigas e barras", "mat": "aluminio", "box": Vector3(0.1, 0.1, 4)},
	{"id": "bloco_05", "nome": "Bloco 0,5 m", "cat": "Blocos", "mat": "aco", "box": Vector3(0.5, 0.5, 0.5)},
	{"id": "bloco_1", "nome": "Bloco 1 m", "cat": "Blocos", "mat": "ferro", "box": Vector3(1, 1, 1)},
	{"id": "tarugo", "nome": "Tarugo 1 m", "cat": "Blocos", "mat": "ferro", "box": Vector3(1, 0.5, 0.5)},
	{"id": "cunha", "nome": "Cunha (rampa)", "cat": "Blocos", "mat": "aco", "box": Vector3(1, 1, 1), "cut": DIAG_YZ},
	{"id": "motor", "nome": "Motor", "cat": "Componentes", "locked": true},
	{"id": "roda", "nome": "Roda", "cat": "Componentes", "locked": true},
	{"id": "assento", "nome": "Assento", "cat": "Componentes", "locked": true},
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


static func planes(item: Dictionary) -> Array[Plane]:
	var p := ConvexGeo.box_planes(item["box"])
	if item.has("cut"):
		p.append(Plane(item["cut"], 0.0))
	return p


static func geometry(item: Dictionary) -> Dictionary:
	var id: String = item["id"]
	if not _geo_cache.has(id):
		_geo_cache[id] = ConvexGeo.solve(planes(item))
	return _geo_cache[id]


static func mass(item: Dictionary) -> float:
	if is_locked(item):
		return 0.0
	return geometry(item)["volume"] * MetalMaterials.density(item["mat"])


static func price(item: Dictionary) -> int:
	if is_locked(item):
		return 0
	return maxi(1, ceili(Economy.recycle_value(item["mat"], mass(item)) * PRICE_FACTOR))

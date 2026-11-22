class_name PowerNode
extends SignalNode
## Peça da rede elétrica (Marco 4B). Também é um nó de sinal: tem portas de lógica.
##
##   bateria   guarda energia (Wh). Tamanhos P/M/G. Saídas: Carga (Wh), % (0 a 100)
##   solar     painel solar: gera de graça, conforme está virado para o sol
##   recarga   posto de recarga: energia paga com pontos; só funciona soldado no chão
##   luz       lâmpada (cor, brilho, alcance). Entradas: Liga, Cor
##   holofote  luz em cone, mais forte, que gasta mais
##   rele      um sinal de lógica (Liga) liga e desliga a passagem de energia
##   chave     E liga e desliga a passagem de energia
##   medidor   lê a rede: Carga, Capacidade, %, Consumo, Geração
##
## A rede (o que está ligado pelo mesmo fio de energia) é calculada pelo autoload Power.

const KINDS := {
	"bateria": "Bateria", "solar": "Painel solar", "recarga": "Posto de recarga",
	"luz": "Luz", "holofote": "Holofote", "rele": "Relé de potência", "chave": "Chave de energia",
	"medidor": "Medidor de energia", "gerador": "Gerador",
}
const BATTERY_WH := 50.0          ## bateria média (pequena e grande: × tamanho³)
const SOLAR_W := 25.0             ## painel solar ao sol a pino
const GRID_W := 1500.0            ## posto de recarga
const LIGHT_W := 15.0             ## luz no brilho máximo
const SPOT_W := 50.0              ## holofote no brilho máximo
const WH_PER_POINT := 10.0        ## posto de recarga: 1 ponto a cada 10 Wh

var part: Part
var kind := "bateria"
var size_scale := 1.0

# Estado
var charge := 0.0                 ## bateria: Wh guardados
var closed := false               ## relé/chave: deixa passar energia
var want := 0.0                   ## luz/holofote: brilho pedido (0 a 1) depois das entradas
var supply := 0.0                 ## fração da energia pedida que chegou (0 a 1)
var power_w := 0.0                ## gerando (+) ou consumindo (W) neste tick
var net := {}                     ## medidor: números da rede (Power preenche)
var drive_w := 0.0                ## gerador: potência que o motor ligado nele dá agora (Drive)

# Ajustes
var color := Color(1.0, 0.9, 0.7)
var brightness := 1.0             ## luz/holofote: brilho máximo (0 a 1)
var light_range := 8.0            ## luz/holofote: alcance (m)
var always_on := true             ## luz/holofote: sem fio na entrada Liga, fica acesa

# Aparência
var light: Light3D
var glow: MeshInstance3D          ## parte que acende (lâmpada, tela, barra de carga)
var label: Label3D
var lever: Node3D                 ## chave: alavanca
var _mat: StandardMaterial3D


func signal_part() -> Part:
	return part


func kind_label() -> String:
	if kind == "bateria":
		return "Bateria %s" % ["pequena", "média", "grande"][1 if is_equal_approx(size_scale, 1.0) else (0 if size_scale < 1.0 else 2)]
	return KINDS.get(kind, kind)


func capacity() -> float:
	return BATTERY_WH * size_scale * size_scale * size_scale if kind == "bateria" else 0.0


func inputs() -> Array:
	match kind:
		"luz", "holofote":
			return [["Liga", NUM], ["Cor", VEC]]
		"rele":
			return [["Liga", NUM]]
		"recarga":
			return [["Desliga", NUM]]
	return []


func outputs() -> Array:
	match kind:
		"bateria":
			return [["Carga", NUM], ["%", NUM]]
		"solar":
			return [["Geração", NUM]]
		"recarga":
			return [["Recarregando", NUM]]
		"luz", "holofote":
			return [["Acesa", NUM]]
		"rele":
			return [["Ligado", NUM]]
		"chave":
			return [["Ligada", NUM]]
		"medidor":
			return [["Carga", NUM], ["Capacidade", NUM], ["%", NUM], ["Consumo", NUM], ["Geração", NUM]]
		"gerador":
			return [["Geração", NUM]]
	return []


## Os que leem entradas de lógica rodam depois das fontes.
func is_source() -> bool:
	return not kind in ["luz", "holofote", "rele", "recarga"]


func update_outputs(_dt: float) -> void:
	match kind:
		"bateria":
			out["Carga"] = charge
			out["%"] = 100.0 * charge / capacity() if capacity() > 0.0 else 0.0
		"solar", "gerador":
			out["Geração"] = power_w
		"chave":
			out["Ligada"] = 1.0 if closed else 0.0
		"medidor":
			out["Carga"] = float(net.get("charge", 0.0))
			out["Capacidade"] = float(net.get("capacity", 0.0))
			out["%"] = float(net.get("percent", 0.0))
			out["Consumo"] = float(net.get("demand", 0.0))
			out["Geração"] = float(net.get("generation", 0.0))


func evaluate(inp: Dictionary, wired: Dictionary, _dt: float) -> void:
	match kind:
		"luz", "holofote":
			var on: float = clampf(float(inp.get("Liga", 0.0)), 0.0, 1.0) if wired.has("Liga") else (1.0 if always_on else 0.0)
			want = on * brightness
			if wired.has("Cor"):
				var c: Vector3 = inp["Cor"]
				color = Color(clampf(c.x / 255.0, 0, 1), clampf(c.y / 255.0, 0, 1), clampf(c.z / 255.0, 0, 1))
			out["Acesa"] = want * supply
		"rele":
			closed = float(inp.get("Liga", 0.0)) > 0.5
			out["Ligado"] = 1.0 if closed else 0.0
			_set_glow(Color(0.3, 1.0, 0.4) if closed else Color(0.25, 0.05, 0.04), 2.0 if closed else 0.0)
		"recarga":
			closed = not (wired.has("Desliga") and float(inp["Desliga"]) > 0.5)
			out["Recarregando"] = power_w


## Consumo pedido agora (W).
func demand_w() -> float:
	match kind:
		"luz":
			return LIGHT_W * want
		"holofote":
			return SPOT_W * want
	return 0.0


## Geração grátis agora (W): painel solar conforme o ângulo com o sol.
func free_w() -> float:
	if kind == "gerador":
		return drive_w
	if kind != "solar" or part == null:
		return 0.0
	var up := part.global_basis.orthonormalized().y
	return SOLAR_W * maxf(0.0, up.dot(-Power.sun_dir))


## Posto de recarga ligado à rede elétrica da cidade (soldado no chão).
func grid_ready() -> bool:
	return kind == "recarga" and closed and part != null and part.assembly() != null and part.assembly().anchored


## Interrompe a passagem de energia (relé/chave desligados).
func blocks() -> bool:
	return kind in ["rele", "chave"] and not closed


## Chave: E liga/desliga.
func toggle() -> void:
	closed = not closed
	update_visual()


## Aparência depois do tick de energia.
func update_visual() -> void:
	match kind:
		"luz", "holofote":
			var level := want * supply
			if light:
				light.visible = level > 0.01
				light.light_color = color
				light.light_energy = level * (2.5 if kind == "luz" else 6.0)
				if light is OmniLight3D:
					(light as OmniLight3D).omni_range = light_range
				elif light is SpotLight3D:
					(light as SpotLight3D).spot_range = light_range * 2.0
			_set_glow(color, 0.2 + level * 4.0)
		"chave":
			if lever:
				lever.rotation.x = deg_to_rad(-30.0 if closed else 30.0)
			_set_glow(Color(0.3, 1.0, 0.4) if closed else Color(0.25, 0.05, 0.04), 2.0 if closed else 0.0)
		"bateria":
			if glow:
				var f := charge / capacity() if capacity() > 0.0 else 0.0
				glow.scale.x = maxf(f, 0.02)
				glow.position.x = glow.get_meta("x0", 0.0) - (1.0 - f) * float(glow.get_meta("w", 0.0)) * 0.5
				_set_glow(Color(1.0, 0.3, 0.2).lerp(Color(0.3, 1.0, 0.4), f), 1.5)
		"recarga":
			_set_glow(Color(0.3, 1.0, 0.4) if power_w > 1.0 else (Color(1.0, 0.7, 0.2) if grid_ready() else Color(0.3, 0.06, 0.05)), 2.0)
			if label:
				label.text = "RECARGA\n%s\n1 ponto a cada %d Wh" % [("%d W" % roundi(power_w)) if power_w > 1.0 else ("pronto" if grid_ready() else "solde no chão"), roundi(WH_PER_POINT)]
		"medidor":
			if label:
				label.text = "%d%%\n%s / %s\n-%d W  +%d W" % [roundi(float(net.get("percent", 0.0))), _wh(float(net.get("charge", 0.0))),
					_wh(float(net.get("capacity", 0.0))), roundi(float(net.get("demand", 0.0))), roundi(float(net.get("generation", 0.0)))]


static func _wh(x: float) -> String:
	return ("%.1f Wh" % x).replace(".", ",") if x < 100.0 else "%d Wh" % roundi(x)


func _set_glow(c: Color, energy: float) -> void:
	if glow == null:
		return
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.emission_enabled = true
		glow.material_override = _mat
	_mat.albedo_color = c.darkened(0.4)
	_mat.emission = c
	_mat.emission_energy_multiplier = energy


func save_state() -> Dictionary:
	var d := {}
	match kind:
		"bateria":
			d["charge"] = snappedf(charge, 0.001)
		"chave":
			d["closed"] = closed
		"luz", "holofote":
			d["color"] = [color.r, color.g, color.b]
			d["bright"] = brightness
			d["range"] = light_range
			d["always"] = always_on
	return d


func load_state(d: Dictionary) -> void:
	charge = clampf(float(d.get("charge", charge)), 0.0, capacity())
	closed = bool(d.get("closed", closed))
	if d.has("color"):
		var c: Array = d["color"]
		color = Color(c[0], c[1], c[2])
	brightness = float(d.get("bright", brightness))
	light_range = float(d.get("range", light_range))
	always_on = bool(d.get("always", always_on))
	update_visual()

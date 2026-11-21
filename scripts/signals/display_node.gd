class_name DisplayNode
extends SignalNode
## Mostradores (não gastam energia):
##   indicador   lâmpada que muda de cor conforme o Valor (entre Mín e Máx)
##   pixel       cor RGB (vetor 0 a 255)
##   mostrador   número grande (estilo 7 segmentos), com casas decimais
##   tela        dois valores com nome (A e B)
##   tela_texto  texto com modelo: {texto}, {A}, {B}, {C}, {D} são trocados pelos valores

const KINDS := {
	"indicador": "Indicador", "pixel": "Pixel", "mostrador": "Mostrador numérico",
	"tela": "Tela de valores", "tela_texto": "Tela de texto",
}

var part: Part
var kind := "indicador"
var label: Label3D               ## texto das telas / mostrador
var lamp: MeshInstance3D         ## parte que acende (indicador, pixel)
var _mat: StandardMaterial3D

# Ajustes
var min_value := 0.0
var max_value := 1.0
var color_off := Color(0.15, 0.04, 0.03)
var color_on := Color(0.2, 1.0, 0.3)
var decimals := 1
var name_a := "A"
var name_b := "B"
var template := "{texto}"

var _shown := ""                 ## para só refazer o texto quando muda


func signal_part() -> Part:
	return part


func kind_label() -> String:
	return KINDS.get(kind, kind)


func inputs() -> Array:
	match kind:
		"indicador", "mostrador":
			return [["Valor", NUM]]
		"pixel":
			return [["Cor", VEC]]
		"tela":
			return [["A", NUM], ["B", NUM]]
		"tela_texto":
			return [["Texto", TXT], ["A", NUM], ["B", NUM], ["C", NUM], ["D", NUM]]
	return []


func is_source() -> bool:
	return false


func setup_lamp(mi: MeshInstance3D) -> void:
	lamp = mi
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	_mat.roughness = 0.4
	lamp.material_override = _mat
	_set_lamp(color_off)


func _set_lamp(c: Color) -> void:
	if _mat == null:
		return
	_mat.albedo_color = c
	_mat.emission = c
	_mat.emission_energy_multiplier = 0.4 + 2.2 * c.get_luminance()


func evaluate(inp: Dictionary, _wired: Dictionary, _dt: float) -> void:
	match kind:
		"indicador":
			var span := max_value - min_value
			var t := 0.0 if is_zero_approx(span) else clampf((float(inp["Valor"]) - min_value) / span, 0.0, 1.0)
			_set_lamp(color_off.lerp(color_on, t))
		"pixel":
			var c: Vector3 = inp["Cor"]
			_set_lamp(Color(clampf(c.x / 255.0, 0, 1), clampf(c.y / 255.0, 0, 1), clampf(c.z / 255.0, 0, 1)))
		"mostrador":
			_show(("%." + str(clampi(decimals, 0, 6)) + "f") % float(inp["Valor"]))
		"tela":
			_show("%s: %s\n%s: %s" % [name_a, format(inp["A"]), name_b, format(inp["B"])])
		"tela_texto":
			var txt := template
			txt = txt.replace("{texto}", str(inp["Texto"]))
			for k in ["A", "B", "C", "D"]:
				txt = txt.replace("{%s}" % k, format(inp[k]))
			_show(txt)


func _show(text: String) -> void:
	if text == _shown or label == null:
		return
	_shown = text
	label.text = text


func save_state() -> Dictionary:
	return {"min": min_value, "max": max_value, "off": color_off.to_html(), "on": color_on.to_html(),
		"dec": decimals, "na": name_a, "nb": name_b, "tpl": template}


func load_state(d: Dictionary) -> void:
	min_value = float(d.get("min", min_value))
	max_value = float(d.get("max", max_value))
	color_off = Color.from_string(str(d.get("off", "")), color_off)
	color_on = Color.from_string(str(d.get("on", "")), color_on)
	decimals = int(d.get("dec", decimals))
	name_a = str(d.get("na", name_a))
	name_b = str(d.get("nb", name_b))
	template = str(d.get("tpl", template))
	_shown = ""
	_set_lamp(color_off)

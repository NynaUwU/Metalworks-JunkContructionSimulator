class_name ControlDevice
extends RefCounted
## Controle físico que gera um sinal para componentes ligados por fio.
##
##   botao        — vale 1 enquanto está apertado (F a pé, clique sentado)
##   alavanca     — liga/desliga (0 ou 1) a cada uso
##   potenciometro — alavanca variável: roda do mouse ajusta de -1 a 1; usar zera

var kind := "botao"
var part: Part
var value := 0.0
var held := false

var _moving: Node3D       ## parte visual que se mexe (capa do botão, haste, cursor)
var _light: MeshInstance3D
var _label: Label3D
var _on_mat: StandardMaterial3D
var _off_mat: StandardMaterial3D


func display_name() -> String:
	return {"botao": "Botão", "alavanca": "Alavanca", "potenciometro": "Alavanca variável"}[kind]


func hint() -> String:
	match kind:
		"botao":
			return "apertar o botão (segure)"
		"alavanca":
			return "virar a alavanca (%s)" % ("ligada" if value > 0.5 else "desligada")
	return "zerar · Roda do mouse: ajustar (%+.1f)" % value


## Começou a usar (F apertado ou clique sentado).
func press() -> void:
	held = true
	match kind:
		"botao":
			value = 1.0
		"alavanca":
			value = 0.0 if value > 0.5 else 1.0
		"potenciometro":
			value = 0.0
	update_visual()


## Parou de usar.
func release() -> void:
	held = false
	if kind == "botao":
		value = 0.0
	update_visual()


## Roda do mouse (só no potenciômetro).
func scroll(steps: int) -> bool:
	if kind != "potenciometro":
		return false
	value = clampf(snappedf(value + steps * 0.1, 0.1), -1.0, 1.0)
	update_visual()
	return true


func setup_visuals(moving: Node3D, light: MeshInstance3D, label: Label3D = null) -> void:
	_moving = moving
	_light = light
	_label = label
	_on_mat = GameTool.glow_material(Color(0.3, 1.0, 0.4), 2.5)
	_off_mat = GameTool.glow_material(Color(0.25, 0.08, 0.06), 0.3)
	update_visual()


func update_visual() -> void:
	if _moving == null or not is_instance_valid(_moving):
		return
	match kind:
		"botao":
			_moving.position.y = 0.055 - (0.02 if value > 0.5 else 0.0)
		"alavanca":
			_moving.rotation.x = deg_to_rad(-35.0 if value > 0.5 else 35.0)
		"potenciometro":
			_moving.position.z = -value * 0.14
	if _light:
		_light.material_override = _on_mat if absf(value) > 0.05 else _off_mat
	if _label:
		_label.text = "%+.1f" % value

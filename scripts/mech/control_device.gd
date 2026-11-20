class_name ControlDevice
extends RefCounted
## Controle físico que gera um sinal para componentes ligados por fio.
##
##   botao         — vale 1 enquanto está apertado (E a pé, clique sentado)
##   alavanca      — liga/desliga (0 ou 1) a cada uso
##   potenciometro — alavanca variável: segure E (ou o clique, sentado) e mova o mouse
##                   para cima/baixo. Faixa: -1 a 1, ou só 0 a 1 (`positive_only`,
##                   trocado com o botão direito da Fiação).

const POT_PIXELS_FULL_RANGE := 300.0   ## pixels de mouse para ir de um extremo ao outro

var kind := "botao"
var part: Part
var value := 0.0
var held := false
var positive_only := false

var _moving: Node3D       ## parte visual que se mexe (capa do botão, haste, cursor)
var _light: MeshInstance3D
var _on_mat: StandardMaterial3D
var _off_mat: StandardMaterial3D


func display_name() -> String:
	return {"botao": "Botão", "alavanca": "Alavanca", "potenciometro": "Alavanca variável"}[kind]


func min_value() -> float:
	return 0.0 if positive_only else -1.0


func hint() -> String:
	match kind:
		"botao":
			return "apertar o botão (segure)"
		"alavanca":
			return "virar a alavanca (%s)" % ("ligada" if value > 0.5 else "desligada")
	return "segure e mova o mouse para cima/baixo (%+.1f · faixa %s)" % [value, "0 a 1" if positive_only else "-1 a 1"]


## Começou a usar (E apertado, ou clique sentado).
func press() -> void:
	held = true
	match kind:
		"botao":
			value = 1.0
		"alavanca":
			value = 0.0 if value > 0.5 else 1.0
	update_visual()


## Parou de usar.
func release() -> void:
	held = false
	if kind == "botao":
		value = 0.0
	update_visual()


## Potenciômetro: movimento vertical do mouse enquanto segura (para cima = aumenta).
func drag(mouse_dy: float) -> void:
	if kind != "potenciometro":
		return
	var span := 1.0 - min_value()
	value = clampf(value - mouse_dy / POT_PIXELS_FULL_RANGE * span, min_value(), 1.0)
	update_visual()


## Alterna a faixa do potenciômetro entre -1..1 e 0..1.
func toggle_range() -> void:
	positive_only = not positive_only
	value = clampf(value, min_value(), 1.0)
	update_visual()


func setup_visuals(moving: Node3D, light: MeshInstance3D) -> void:
	_moving = moving
	_light = light
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
			# Só positivo: o curso todo vai de 0 (atrás) a 1 (na frente).
			var t := (value - min_value()) / (1.0 - min_value())
			_moving.position.z = 0.14 - t * 0.28
	if _light:
		_light.material_override = _on_mat if absf(value) > 0.05 else _off_mat

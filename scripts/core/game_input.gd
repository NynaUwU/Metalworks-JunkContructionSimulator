extends Node
## Registra o mapa de teclas em código (mais fácil de manter do que no project.godot).
## Usa teclas físicas, então funciona igual em ABNT2, US, etc.

const KEYS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"jump": [KEY_SPACE],
	"modifier": [KEY_SHIFT],      # Shift: girar a peça segurada / correr
	"roll_left": [KEY_Q],         # Shift+Q: girar peça
	"roll_right": [KEY_E],        # Shift+E: girar peça
	"release": [KEY_E],           # E: devolve a física à peça flutuando
	"rotate_cut": [KEY_R],        # R: muda o ângulo do corte
	"align": [KEY_T],             # T: alinha a peça segurada à grade do mundo
	"free_cut": [KEY_CTRL],       # Ctrl: corte livre (sem grade)
	"tool_1": [KEY_1],
	"tool_2": [KEY_2],
	"tool_3": [KEY_3],
	"interact": [KEY_F],           # F: usar (loja, assentos...)
	"help": [KEY_H],
	"pause": [KEY_ESCAPE],
	"toggle_fps": [KEY_F3],
	"fullscreen": [KEY_F11],
}

const MOUSE := {
	"primary": [MOUSE_BUTTON_LEFT],
	"secondary": [MOUSE_BUTTON_RIGHT],
	"wheel_up": [MOUSE_BUTTON_WHEEL_UP],
	"wheel_down": [MOUSE_BUTTON_WHEEL_DOWN],
}


func _enter_tree() -> void:
	for action: String in KEYS:
		_ensure(action)
		for key: Key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action: String in MOUSE:
		_ensure(action)
		for button: MouseButton in MOUSE[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)


func _ensure(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)

class_name SeatNode
extends SignalNode
## O assento como controle (estilo "Pod Controller" do Wiremod): com alguém sentado nele,
## as saídas mostram as teclas apertadas e para onde a pessoa está mirando.
## As teclas configuradas no modo edição (Tab) continuam funcionando junto.

const KEYS := {"W": KEY_W, "A": KEY_A, "S": KEY_S, "D": KEY_D, "Espaço": KEY_SPACE, "Shift": KEY_SHIFT}

var part: Part                     ## base do assento


func signal_part() -> Part:
	return part


func kind_label() -> String:
	return "Assento"


func outputs() -> Array:
	var o: Array = []
	for k: String in KEYS:
		o.append([k, NUM])
	o.append(["Clique esq.", NUM])
	o.append(["Clique dir.", NUM])
	o.append(["Ocupado", NUM])
	o.append(["Mira", VEC])
	return o


func is_occupied() -> bool:
	return Build.active_seat == part and Build.seat_keys_enabled


func update_outputs(_dt: float) -> void:
	var on := is_occupied()
	for k: String in KEYS:
		out[k] = 1.0 if on and Input.is_physical_key_pressed(KEYS[k]) else 0.0
	out["Clique esq."] = 1.0 if on and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.0
	out["Clique dir."] = 1.0 if on and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 0.0
	out["Ocupado"] = 1.0 if Build.active_seat == part else 0.0
	var p: Node = Build.seat_player
	if on and p and is_instance_valid(p) and not (p.get("aim") as Dictionary).is_empty():
		out["Mira"] = (p.get("aim") as Dictionary)["position"]
	else:
		out["Mira"] = Vector3.ZERO

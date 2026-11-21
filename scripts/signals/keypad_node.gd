class_name KeypadNode
extends SignalNode
## Teclado de senha: E nele abre o teclado na tela. Senha certa → "Certo" fica 1 por
## alguns segundos; errada → "Errado" fica 1 por 1 segundo.

var part: Part
var code := "1234"
var hold_time := 2.0
var label: Label3D
var _ok_left := 0.0
var _err_left := 0.0


func signal_part() -> Part:
	return part


func kind_label() -> String:
	return "Teclado de senha"


func outputs() -> Array:
	return [["Certo", NUM], ["Errado", NUM]]


## Senha digitada pelo jogador. Retorna true se estava certa.
func enter(typed: String) -> bool:
	var ok := typed == code and code != ""
	if ok:
		_ok_left = maxf(hold_time, 0.1)
		_err_left = 0.0
	else:
		_err_left = 1.0
		_ok_left = 0.0
	return ok


func update_outputs(dt: float) -> void:
	out["Certo"] = 1.0 if _ok_left > 0.0 else 0.0
	out["Errado"] = 1.0 if _err_left > 0.0 else 0.0
	_ok_left = maxf(_ok_left - dt, 0.0)
	_err_left = maxf(_err_left - dt, 0.0)
	if label:
		var t := "ABERTO" if _ok_left > 0.0 else ("ERRO" if _err_left > 0.0 else "SENHA")
		if label.text != t:
			label.text = t
			label.modulate = Color(0.3, 1.0, 0.4) if _ok_left > 0.0 else (Color(1.0, 0.3, 0.25) if _err_left > 0.0 else Color(0.8, 0.85, 0.9))


func save_state() -> Dictionary:
	return {"code": code, "hold": hold_time}


func load_state(d: Dictionary) -> void:
	code = str(d.get("code", code))
	hold_time = float(d.get("hold", hold_time))

class_name KeysNode
extends SignalNode
## Controle por teclas: até 2 teclas (ou botões do mouse) para +1 e para −1.
## Por padrão só vale com alguém sentado num assento da mesma máquina; com "sempre",
## vale também a pé (bom com o teclado numérico).

var part: Part
var bind_pos: Array = []
var bind_neg: Array = []
var toggle := false               ## alternar: um toque liga, outro desliga
var always := false               ## vale a pé também
var value := 0.0
var label: Label3D
var _latched := 0.0
var _prev_pos := false
var _prev_neg := false


func signal_part() -> Part:
	return part


func kind_label() -> String:
	return "Teclas"


func outputs() -> Array:
	return [["Valor", NUM]]


func is_enabled() -> bool:
	if always:
		return true
	var seat := Build.active_seat
	if seat == null or not is_instance_valid(seat) or not seat.is_inside_tree() or not Build.seat_keys_enabled:
		return false
	return Build.connected_assemblies(seat.assembly()).has(part.assembly())


func update_outputs(_dt: float) -> void:
	var enabled := is_enabled()
	var pos := enabled and MechJoint._any_pressed(bind_pos)
	var neg := enabled and MechJoint._any_pressed(bind_neg)
	if toggle:
		if pos and not _prev_pos:
			_latched = 0.0 if _latched > 0.5 else 1.0
		if neg and not _prev_neg:
			_latched = 0.0 if _latched < -0.5 else -1.0
		value = _latched
	else:
		value = (1.0 if pos else 0.0) - (1.0 if neg else 0.0)
	_prev_pos = pos
	_prev_neg = neg
	out["Valor"] = value


func keys_text() -> String:
	var p := ", ".join(bind_pos.map(func(b: Dictionary) -> String: return MechJoint.binding_text(b)))
	var n := ", ".join(bind_neg.map(func(b: Dictionary) -> String: return MechJoint.binding_text(b)))
	return "+ %s  − %s" % [p if p != "" else "—", n if n != "" else "—"]


func refresh_label() -> void:
	if label:
		label.text = keys_text()


func save_state() -> Dictionary:
	return {"pos": bind_pos.duplicate(true), "neg": bind_neg.duplicate(true), "toggle": toggle,
		"always": always, "latch": _latched}


func load_state(d: Dictionary) -> void:
	bind_pos = Saves._to_binds(d.get("pos", []))
	bind_neg = Saves._to_binds(d.get("neg", []))
	toggle = bool(d.get("toggle", false))
	always = bool(d.get("always", false))
	_latched = float(d.get("latch", 0.0))
	refresh_label()

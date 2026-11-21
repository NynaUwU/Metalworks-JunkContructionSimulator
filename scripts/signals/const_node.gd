class_name ConstNode
extends SignalNode
## Valor constante: sai sempre o mesmo número, vetor ou texto (escolhido nos ajustes).

var part: Part
var value_type := NUM
var value: Variant = 1.0
var label: Label3D


func signal_part() -> Part:
	return part


func kind_label() -> String:
	return "Valor constante"


func outputs() -> Array:
	return [["Valor", value_type]]


func update_outputs(_dt: float) -> void:
	out["Valor"] = value


func set_value(t: String, v: Variant) -> void:
	if t != value_type:
		value_type = t
		Signals._dirty = true   # fios do tipo antigo saem
	match t:
		NUM:
			value = float(v) if (v is float or v is int) else (str(v).replace(",", ".").to_float())
		VEC:
			value = v if v is Vector3 else Vector3.ZERO
		_:
			value = str(v)
	if label:
		label.text = format(value)


func save_state() -> Dictionary:
	var v: Variant = value
	if value is Vector3:
		v = [value.x, value.y, value.z]
	return {"t": value_type, "v": v}


func load_state(d: Dictionary) -> void:
	var t := str(d.get("t", NUM))
	var v: Variant = d.get("v", 0.0)
	if t == VEC and v is Array and (v as Array).size() == 3:
		v = Vector3(v[0], v[1], v[2])
	set_value(t, v)

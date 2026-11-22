class_name DriveNode
extends SignalNode
## Trem de força (Marco 4D, estilo ACF): motores, câmbios e tanques. Também é nó de sinal.
## As ligações (tanque → motor → câmbio → cubos de roda, motor → gerador) são invisíveis e
## ficam no autoload Drive; a simulação de cada tick também está lá.
##
## Unidades: giro em rad/s (RPM só nas saídas e telas), torque em N·m, potência em W,
## combustível em litros. As forças são ajustadas às massas do jogo (mais leves que as reais).

## Motores: torque máximo (N·m), RPM do torque máximo, marcha lenta, corte de giro,
## inércia do volante (kg·m²), combustível ("gasolina", "diesel" ou "eletrico").
const ENGINES := {
	"motor_mono": {"nome": "Motor monocilíndrico", "torque": 15.0, "peak": 4000.0, "idle": 1100.0, "red": 7000.0, "fly": 0.036, "fuel": "gasolina", "cyl": 1},
	"motor_4l": {"nome": "Motor 4 em linha", "torque": 40.0, "peak": 3800.0, "idle": 850.0, "red": 6500.0, "fly": 0.09, "fuel": "gasolina", "cyl": 4},
	"motor_v8": {"nome": "Motor V8", "torque": 120.0, "peak": 3200.0, "idle": 700.0, "red": 6000.0, "fly": 0.24, "fuel": "gasolina", "cyl": 8},
	"motor_v12": {"nome": "Motor V12", "torque": 180.0, "peak": 4000.0, "idle": 800.0, "red": 7200.0, "fly": 0.36, "fuel": "gasolina", "cyl": 12},
	"motor_diesel": {"nome": "Motor diesel", "torque": 220.0, "peak": 1800.0, "idle": 600.0, "red": 3600.0, "fly": 0.6, "fuel": "diesel", "cyl": 6},
	"motor_rotativo": {"nome": "Motor rotativo", "torque": 45.0, "peak": 6000.0, "idle": 1200.0, "red": 9000.0, "fly": 0.075, "fuel": "gasolina", "cyl": 2},
	"motor_eletrico": {"nome": "Motor elétrico", "torque": 90.0, "peak": 0.0, "idle": 0.0, "red": 12000.0, "fly": 0.09, "fuel": "eletrico", "cyl": 0},
	"turbina": {"nome": "Turbina", "torque": 100.0, "peak": 18000.0, "idle": 6000.0, "red": 24000.0, "fly": 0.18, "fuel": "diesel", "cyl": 0},
}
const GEARBOXES := {
	"cambio_manual": "Câmbio manual", "cambio_auto": "Câmbio automático", "cvt": "Câmbio CVT",
}
const TANKS := {"tanque_gasolina": "Tanque de gasolina", "tanque_diesel": "Tanque de diesel"}
const CLUTCHES := {"embreagem_auto": "Embreagem automática", "embreagem_manual": "Embreagem manual"}
## Divisores (Marco 4E): multiplicam a relação no caminho, como um câmbio sem marchas.
const SPLITTERS := {"transferencia": "Caixa de transferência", "diferencial": "Diferencial"}
const TANK_L := 40.0              ## tanque médio (pequeno/grande: × tamanho³)
const LITERS_PER_KWH := 3.0       ## consumo (escala do jogo)
const GEN_W := 400.0              ## gerador: potência máxima (W)

var part: Part
var kind := ""
var size_scale := 1.0

# --- Motor
var running := false
var omega := 0.0                  ## giro do motor (rad/s)
var throttle := 0.0               ## acelerador depois das entradas (0 a 1)
var torque_out := 0.0             ## torque do motor neste tick (N·m)
var fuel_rate := 0.0              ## consumo (L/h; elétrico: W)
var load := 0.0                   ## torque que as rodas/gerador puxaram (N·m)
var auto_start := true            ## sem fio na entrada Ligado, liga sozinho
var _ligado_in := 0.0
var _has_ligado := false

# --- Câmbio
var gear := 1                     ## 0 = neutro, -1 = ré
var gears := 5
var first_ratio := 3.6
var top_ratio := 1.0
var final_drive := 6.0
var reverse_ratio := 3.4
var tank_steer := false           ## diferencial duplo: esterço de tanque
var shift_up_frac := 0.85         ## automático: troca para cima a 85% do corte de giro
var cvt_ratio := 3.0
var _shift_cool := 0.0
var _prev_up := false
var _prev_down := false
var inp := {}                     ## últimas entradas do câmbio
var wheel_speed := 0.0            ## giro médio das rodas, para a frente (rad/s)

# --- Caixa de transferência
var high_ratio := 1.0             ## alta
var low_ratio := 2.6              ## reduzida
var low := false                  ## engatada na reduzida agora
var low_default := false          ## sem fio na entrada Reduzida
# --- Diferencial
var diff_ratio := 1.0
var locked := false               ## travado agora (as rodas giram iguais)
var lock_default := false         ## sem fio na entrada Travar

# --- Tanque
var fuel := 0.0                   ## litros

# --- Embreagem
var pedal := 0.0                  ## manual: 1 = pedal no fundo (desengatada)
var engage_shown := 0.0           ## quanto está engatada (para a luz)

# Aparência e som
var label: Label3D
var glow: MeshInstance3D
var _mat: StandardMaterial3D
var sound: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0


func signal_part() -> Part:
	return part


func is_engine() -> bool:
	return ENGINES.has(kind)


func is_gearbox() -> bool:
	return GEARBOXES.has(kind)


func is_tank() -> bool:
	return TANKS.has(kind)


func is_clutch() -> bool:
	return CLUTCHES.has(kind)


func is_transfer() -> bool:
	return kind == "transferencia"


func is_diff() -> bool:
	return kind == "diferencial"


func is_splitter() -> bool:
	return SPLITTERS.has(kind)


func spec() -> Dictionary:
	return ENGINES.get(kind, {})


func kind_label() -> String:
	if is_engine():
		return spec()["nome"]
	if is_gearbox():
		return GEARBOXES[kind] + (" (tanque)" if tank_steer else "")
	if is_tank():
		return "%s %s" % [TANKS[kind], ["pequeno", "médio", "grande"][1 if is_equal_approx(size_scale, 1.0) else (0 if size_scale < 1.0 else 2)]]
	if is_clutch():
		return CLUTCHES[kind]
	if is_splitter():
		return SPLITTERS[kind]
	return kind


func fuel_type() -> String:
	if is_tank():
		return "gasolina" if kind == "tanque_gasolina" else "diesel"
	return spec().get("fuel", "")


func capacity() -> float:
	return TANK_L * size_scale * size_scale * size_scale if is_tank() else 0.0


func rpm() -> float:
	return omega * 60.0 / TAU


func inputs() -> Array:
	if is_engine():
		return [["Acelerador", NUM], ["Ligado", NUM]]
	if is_gearbox():
		return [["Marcha", NUM], ["Sobe", NUM], ["Desce", NUM], ["Ré", NUM], ["Freio", NUM],
			["Esq", NUM], ["Dir", NUM], ["Esterço", NUM]]
	if kind == "embreagem_manual":
		return [["Pedal", NUM]]
	if is_transfer():
		return [["Reduzida", NUM]]
	if is_diff():
		return [["Travar", NUM]]
	return []


func outputs() -> Array:
	if is_engine():
		return [["RPM", NUM], ["Torque", NUM], ["Potência", NUM], ["Consumo", NUM], ["Ligado", NUM]]
	if is_gearbox():
		return [["Marcha", NUM], ["Relação", NUM], ["Giro das rodas", NUM]]
	if is_tank():
		return [["Combustível", NUM], ["%", NUM]]
	if is_clutch():
		return [["Engate", NUM], ["Patinação", NUM]]
	if is_transfer():
		return [["Reduzida", NUM], ["Relação", NUM]]
	if is_diff():
		return [["Travado", NUM], ["Diferença", NUM]]
	return []


## Lê as entradas (motor e câmbio); a simulação roda no Drive, depois dos sinais.
func is_source() -> bool:
	return is_tank() or kind == "embreagem_auto"


func update_outputs(_dt: float) -> void:
	if is_tank():
		out["Combustível"] = fuel
		out["%"] = 100.0 * fuel / capacity() if capacity() > 0.0 else 0.0


func evaluate(i: Dictionary, wired: Dictionary, _dt: float) -> void:
	if is_engine():
		throttle = clampf(float(i.get("Acelerador", 0.0)), 0.0, 1.0)
		_has_ligado = wired.has("Ligado")
		_ligado_in = float(i.get("Ligado", 0.0))
	elif is_gearbox():
		inp = i.duplicate()
		inp["_marcha_wired"] = wired.has("Marcha")
	elif kind == "embreagem_manual":
		pedal = clampf(float(i.get("Pedal", 0.0)), 0.0, 1.0)
	elif is_transfer():
		low = float(i["Reduzida"]) > 0.5 if wired.has("Reduzida") else low_default
		out["Reduzida"] = 1.0 if low else 0.0
		out["Relação"] = total_ratio()
	elif is_diff():
		locked = float(i["Travar"]) > 0.5 if wired.has("Travar") else lock_default
		out["Travado"] = 1.0 if locked else 0.0


## Quer estar ligado (entrada Ligado, ou sozinho se não tiver fio).
func wants_on() -> bool:
	return _ligado_in > 0.5 if _has_ligado else auto_start


# --- Motor -----------------------------------------------------------------------------

## Torque do motor no giro `w` com acelerador `t` (0 a 1).
func engine_torque(w: float, t: float) -> float:
	var s := spec()
	var r := w * 60.0 / TAU
	var tmax: float = s["torque"] * size_scale
	if s["fuel"] == "eletrico":
		# Elétrico: torque cheio do zero, cai depois da metade do giro máximo.
		var f := 1.0 if r < s["red"] * 0.5 else maxf(0.0, 1.0 - (r - s["red"] * 0.5) / (s["red"] * 0.5))
		return tmax * f * t
	if r > s["red"]:
		return 0.0                     # corte de giro
	var peak: float = s["peak"]
	var span: float = maxf(peak - s["idle"] * 0.5, 1.0) if r < peak else maxf(s["red"] * 1.15 - peak, 1.0)
	var shape := clampf(1.0 - pow((r - peak) / span, 2.0) * 0.7, 0.25, 1.0)
	return tmax * shape * t


## Atrito interno (freio motor): cresce com o giro.
func engine_friction(w: float) -> float:
	var tmax: float = spec()["torque"] * size_scale
	return tmax * (0.04 + 0.1 * w / maxf(spec()["red"] * TAU / 60.0, 1.0))


func idle_omega() -> float:
	return spec()["idle"] * TAU / 60.0


func red_omega() -> float:
	return spec()["red"] * TAU / 60.0


# --- Câmbio ----------------------------------------------------------------------------

## Relação da marcha `g` (sem o diferencial). Marchas em progressão geométrica.
func gear_ratio(g: int) -> float:
	if kind == "cvt":
		return cvt_ratio if g > 0 else (-reverse_ratio if g < 0 else 0.0)
	if g == 0:
		return 0.0
	if g < 0:
		return -reverse_ratio
	if gears <= 1:
		return first_ratio
	var f := float(clampi(g, 1, gears) - 1) / float(gears - 1)
	return first_ratio * pow(top_ratio / first_ratio, f)


## Relação total (marcha × diferencial). 0 = neutro. Divisores: a relação deles.
func total_ratio() -> float:
	if is_transfer():
		return low_ratio if low else high_ratio
	if is_diff():
		return diff_ratio
	return gear_ratio(gear) * final_drive


func update_visual() -> void:
	if label == null:
		return
	if is_engine():
		label.text = "%s\n%d rpm" % [spec()["nome"].replace("Motor ", "").to_upper(), roundi(rpm())] if running else "%s\ndesligado" % spec()["nome"].replace("Motor ", "").to_upper()
		_set_glow(Color(0.3, 1.0, 0.4) if running else Color(0.3, 0.06, 0.05), 2.0 if running else 0.0)
	elif is_gearbox():
		label.text = "%s\n%s" % ["CVT" if kind == "cvt" else ("AUTO" if kind == "cambio_auto" else "MANUAL"),
			"R" if gear < 0 else ("N" if gear == 0 else str(gear)) if kind != "cvt" else ("R" if gear < 0 else ("N" if gear == 0 else "%.2f" % cvt_ratio))]
	elif is_tank():
		label.text = "%s\n%d / %d L" % [fuel_type().to_upper(), roundi(fuel), roundi(capacity())]
	elif is_transfer():
		label.text = "TRANSFER\n%s %.1f" % ["REDUZIDA" if low else "ALTA", total_ratio()]
		_set_glow(Color(1.0, 0.6, 0.1) if low else Color(0.3, 1.0, 0.4), 1.5)
	elif is_diff():
		label.text = "DIFERENCIAL\n%s %.1f" % ["TRAVADO" if locked else "ABERTO", diff_ratio]
		_set_glow(Color(1.0, 0.3, 0.2) if locked else Color(0.3, 0.7, 1.0), 1.5)
	elif is_clutch():
		label.text = "EMBREAGEM\n%s · %d%%" % ["AUTO" if kind == "embreagem_auto" else "MANUAL", roundi(engage_shown * 100.0)]
		_set_glow(Color(0.3, 1.0, 0.4).lerp(Color(1.0, 0.6, 0.1), 1.0 - engage_shown), 0.4 + engage_shown * 2.0)


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


## Som do motor: onda gerada seguindo o RPM (explosões por segundo = rpm/60 × cilindros/2).
func update_sound() -> void:
	if sound == null or not is_inside_tree_safe():
		return
	if not running:
		if sound.playing:
			sound.stop()
		return
	if not sound.playing:
		sound.play()
		_playback = sound.get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback == null:
		return
	var s := spec()
	var cyl := maxf(float(s["cyl"]), 1.0)
	var freq := maxf(rpm() / 60.0 * cyl * 0.5, 20.0) if s["fuel"] != "eletrico" else maxf(rpm() / 60.0 * 4.0, 30.0)
	if kind == "turbina":
		freq = rpm() / 60.0 * 0.12
	var rate := (sound.stream as AudioStreamGenerator).mix_rate
	var n := _playback.get_frames_available()
	var vol := 0.18 + 0.22 * throttle
	for k in n:
		_phase = fmod(_phase + freq / rate, 1.0)
		var saw := 2.0 * _phase - 1.0
		var v := (saw * 0.6 + sin(_phase * TAU * 2.0) * 0.3 + randf_range(-0.15, 0.15) * (0.3 + throttle)) * vol
		if s["fuel"] == "eletrico":
			v = sin(_phase * TAU) * vol * 0.6
		_playback.push_frame(Vector2(v, v))


func is_inside_tree_safe() -> bool:
	return part != null and is_instance_valid(part) and part.is_inside_tree()


# --- Salvar ----------------------------------------------------------------------------

func save_state() -> Dictionary:
	if is_tank():
		return {"fuel": snappedf(fuel, 0.01)}
	if is_engine():
		return {"auto": auto_start}
	if is_gearbox():
		return {"gear": gear, "gears": gears, "first": first_ratio, "top": top_ratio, "final": final_drive,
			"rev": reverse_ratio, "tank": tank_steer, "up": shift_up_frac}
	if is_transfer():
		return {"high": high_ratio, "low": low_ratio, "low_def": low_default}
	if is_diff():
		return {"dr": diff_ratio, "lock_def": lock_default}
	return {}


func load_state(d: Dictionary) -> void:
	fuel = clampf(float(d.get("fuel", fuel)), 0.0, capacity())
	auto_start = bool(d.get("auto", auto_start))
	gear = int(d.get("gear", gear))
	gears = clampi(int(d.get("gears", gears)), 1, 10)
	first_ratio = float(d.get("first", first_ratio))
	top_ratio = float(d.get("top", top_ratio))
	final_drive = float(d.get("final", final_drive))
	reverse_ratio = float(d.get("rev", reverse_ratio))
	tank_steer = bool(d.get("tank", tank_steer))
	shift_up_frac = float(d.get("up", shift_up_frac))
	high_ratio = float(d.get("high", high_ratio))
	low_ratio = float(d.get("low", low_ratio))
	low_default = bool(d.get("low_def", low_default))
	low = low_default
	diff_ratio = float(d.get("dr", diff_ratio))
	lock_default = bool(d.get("lock_def", lock_default))
	locked = lock_default
	update_visual()

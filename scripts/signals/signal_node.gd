class_name SignalNode
extends RefCounted
## Algo com entradas e saídas de sinal (estilo Wiremod): controles, componentes, chips,
## telas, assento... Os fios ligam uma SAÍDA de um nó a uma ENTRADA de outro, do mesmo tipo.
##
## Tipos de porta:
##   n  número   (verdadeiro = maior que 0)
##   v  vetor    (X, Y, Z; também usado para ângulos e cores)
##   s  texto
##   p  peça     (referência a uma peça do mundo)
##   l  lista
##
## Entradas sem fio valem zero ("", vetor zero...). Vários fios na mesma entrada:
## números e vetores somam; nos outros tipos vale o primeiro.

const NUM := "n"
const VEC := "v"
const TXT := "s"
const PART := "p"
const LIST := "l"
const TYPE_NAMES := {"n": "número", "v": "vetor", "s": "texto", "p": "peça", "l": "lista"}
const TYPE_COLORS := {
	"n": Color(1.0, 0.55, 0.1), "v": Color(0.2, 0.8, 1.0), "s": Color(0.35, 0.95, 0.4),
	"p": Color(0.8, 0.45, 1.0), "l": Color(0.92, 0.92, 0.92),
}

var node_name := ""     ## nome dado pelo jogador (Depurador / ajustes)
var out := {}           ## porta de saída -> valor atual


## Peça onde os fios encostam (e que é clicada com a Fiação).
func signal_part() -> Part:
	return null


func is_alive() -> bool:
	var p := signal_part()
	return p != null and is_instance_valid(p) and p.is_inside_tree() and not p.is_queued_for_deletion()


## Nome do tipo (ex.: "Motor", "Chip · E (AND)").
func kind_label() -> String:
	return "?"


## Nome para mostrar: o nome dado pelo jogador ou o do tipo.
func title() -> String:
	return node_name if node_name != "" else kind_label()


## [[nome, tipo], ...]
func inputs() -> Array:
	return []


func outputs() -> Array:
	return []


## Fontes calculam as saídas sem depender das entradas no mesmo tick (controles, teclas,
## sensores, componentes). Os outros (chips, telas) rodam depois, na ordem dos fios.
func is_source() -> bool:
	return true


## Fontes: atualiza `out` (chamado todo tick, antes dos chips).
func update_outputs(_dt: float) -> void:
	pass


## Não-fontes: lê as entradas (`inp`: porta -> valor; `wired`: portas com fio) e
## atualiza `out` / a aparência.
func evaluate(_inp: Dictionary, _wired: Dictionary, _dt: float) -> void:
	pass


func port_type(port: String, outputs_side: bool) -> String:
	for p: Array in (outputs() if outputs_side else inputs()):
		if p[0] == port:
			return p[1]
	return ""


## Ajustes próprios para salvar (o nome é salvo à parte).
func save_state() -> Dictionary:
	return {}


func load_state(_d: Dictionary) -> void:
	pass


static func zero(t: String) -> Variant:
	match t:
		NUM:
			return 0.0
		VEC:
			return Vector3.ZERO
		TXT:
			return ""
		PART:
			return null
		LIST:
			return []
	return 0.0


## Texto curto de um valor (Depurador, telas).
static func format(v: Variant) -> String:
	if v == null:
		return "—"
	if v is float or v is int:
		var f := float(v)
		if is_equal_approx(f, roundf(f)) and absf(f) < 1e9:
			return str(int(roundf(f)))
		return ("%.3f" % f).rstrip("0").rstrip(".")
	if v is Vector3:
		return "(%s; %s; %s)" % [format(v.x), format(v.y), format(v.z)]
	if v is String:
		return "\"%s\"" % v
	if v is Part:
		return (v as Part).display_name() if is_instance_valid(v) else "—"
	if v is Array:
		return "[%d itens]" % (v as Array).size()
	return str(v)

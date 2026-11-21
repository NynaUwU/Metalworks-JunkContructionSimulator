class_name Carrier
extends RefCounted
## Leva uma peça até um alvo (Gravitador) e carrega junto tudo o que está ligado a ela
## por juntas.
##
## A peça segurada é guiada por velocidade: corrige quase todo o erro a cada tick e
## antecipa o movimento do alvo (sem efeito de "pendurado numa corda"). A MESMA mudança
## de movimento é aplicada, como corpo rígido, às outras montagens da máquina. Assim as
## juntas não precisam arrastar nada e não são arrancadas em movimentos bruscos.
##
## O que conta como "máquina": montagens ligadas por juntas e por engates/ímãs travados.
## O cabo do guincho NÃO conta (cabo não é rígido: o gancho fica pendurado e balança).
## Se a máquina está presa a algo congelado ou ancorado, ela não pode se mover como um
## bloco: aí só a peça segurada é puxada e o resto acompanha pelas juntas (mecanismo).

const LINEAR_GAIN := 0.75           ## fração do erro de posição corrigida por tick
const ANGULAR_GAIN := 0.7
const MAX_SPEED := 40.0                ## arremesso máximo (m/s)
const MAX_SPIN := 40.0
const MAX_DV := 2.0                 ## mudança máxima de velocidade por tick (m/s): 120 m/s²
const MAX_DW := 2.5                 ## idem, rotação (rad/s)

var carried: Array = []             ## montagens carregadas agora
var on_add := Callable()            ## chamado com cada montagem que passa a ser carregada
var on_remove := Callable()         ## e com cada uma que sai
var _last_target := Transform3D.IDENTITY
var _has_last_target := false


## Um tick: leva `part` (ponto `grab_local`) para `target`.
func step(part: Part, grab_local: Vector3, target: Transform3D, dt: float) -> void:
	var asm := part.assembly()
	if asm == null:
		release()
		return
	var m := machine(asm)
	_set_carried(m["list"] if not m["pinned"] else [asm])
	if asm.freeze:
		return
	var cur := asm.global_transform * part.transform

	# Antecipação: quanto o alvo andou/girou desde o último tick.
	var q_tgt := target.basis.orthonormalized().get_rotation_quaternion()
	var ff_v := Vector3.ZERO
	var ff_w := Vector3.ZERO
	if _has_last_target:
		ff_v = (target * grab_local - _last_target * grab_local) / dt
		ff_w = _angular_velocity_between(_last_target.basis.orthonormalized().get_rotation_quaternion(), q_tgt, dt)
	_last_target = target
	_has_last_target = true

	var q_cur := cur.basis.orthonormalized().get_rotation_quaternion()
	var q_err := (q_tgt * q_cur.inverse()).normalized()
	if q_err.w < 0.0:
		q_err = -q_err
	# Correção do erro: rápida de perto, e de longe no máximo a velocidade que ainda
	# dá para frear com a aceleração permitida (não passa do alvo nem fica oscilando).
	var w := ff_w
	var axis := Vector3(q_err.x, q_err.y, q_err.z)
	if axis.length_squared() > 1e-12:
		var ang := 2.0 * acos(clampf(q_err.w, -1.0, 1.0))
		w += axis.normalized() * minf(ang / dt * ANGULAR_GAIN, sqrt(2.0 * MAX_DW / dt * ang))
	w = w.limit_length(MAX_SPIN)

	var grab_cur := cur * grab_local
	var err := target * grab_local - grab_cur
	var e := err.length()
	var v_point := ff_v
	if e > 1e-6:
		v_point += err / e * minf(e / dt * LINEAR_GAIN, sqrt(2.0 * MAX_DV / dt * e))
	v_point = v_point.limit_length(MAX_SPEED)
	var com := asm.world_center_of_mass()
	var v := v_point - w.cross(grab_cur - com)

	var dv := (v - asm.linear_velocity).limit_length(MAX_DV)
	var dw := (w - asm.angular_velocity).limit_length(MAX_DW)
	for a: Assembly in carried:
		if a.freeze:
			continue
		a.linear_velocity += dv + dw.cross(a.world_center_of_mass() - com)
		a.angular_velocity += dw


## Montagens que se movem junto com `asm` como um bloco. Não atravessa montagens
## congeladas/ancoradas; "pinned" = a máquina está presa a alguma delas.
static func machine(asm: Assembly) -> Dictionary:
	var out: Array = [asm]
	var pinned := false
	var i := 0
	while i < out.size():
		var cur: Assembly = out[i]
		for j in Build.joints:
			if not j.is_valid() or j.type == "guincho":
				continue
			var a := j.part_a.assembly()
			var b: Assembly = null
			if j.type in MechJoint.SINGLE:
				if j.lock_target == null or not is_instance_valid(j.lock_target) or not j.lock_target.is_inside_tree():
					continue
				b = j.lock_target.assembly()      # engate / ímã travado: preso de verdade
			else:
				b = j.part_b.assembly()
			var other: Assembly = b if a == cur else (a if b == cur else null)
			if other == null or other == cur or out.has(other):
				continue
			if other.freeze:
				pinned = true
				continue
			out.append(other)
		i += 1
	return {"list": out, "pinned": pinned}


## Para de carregar (tudo volta a ter gravidade; as velocidades ficam: dá para arremessar).
func release() -> void:
	_set_carried([])
	_has_last_target = false


static func _angular_velocity_between(q_from: Quaternion, q_to: Quaternion, dt: float) -> Vector3:
	var d := (q_to * q_from.inverse()).normalized()
	if d.w < 0.0:
		d = -d
	var ax := Vector3(d.x, d.y, d.z)
	if ax.length_squared() < 1e-12:
		return Vector3.ZERO
	return ax.normalized() * 2.0 * acos(clampf(d.w, -1.0, 1.0)) / dt


func _set_carried(list: Array) -> void:
	for a: Assembly in carried:
		if is_instance_valid(a) and not list.has(a):
			a.set_carried(false)
			a.sleeping = false
			if on_remove.is_valid():
				on_remove.call(a)
	for a: Assembly in list:
		if not a.carried or not carried.has(a):
			a.set_carried(true)
			if on_add.is_valid():
				on_add.call(a)
	carried = list.filter(func(a: Assembly) -> bool: return is_instance_valid(a))

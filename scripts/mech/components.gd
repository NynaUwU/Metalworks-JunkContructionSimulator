class_name Components
extends RefCounted
## Cria componentes mecânicos e controles (peças + juntas + aparência).
##
## Os componentes giram/deslizam no eixo Y local do ponto onde são criados:
##   motor/servo: carcaça embaixo, disco em cima.
##   pistão/servo linear: base embaixo, haste sai para cima.
##   dobradiça/dobradiça de pino: eixo X.
##   junta esférica: base embaixo, placa em cima, inclina para qualquer lado.

const INFO := {
	"motor": {"nome": "Motor", "preco": 40, "desc": "Gira sem parar. Solde a carcaça na estrutura e a roda no disco. Sem sinal: rígido ou solto."},
	"servo": {"nome": "Servo", "preco": 35, "desc": "Gira até um ângulo e segura. Bom para direção."},
	"pistao": {"nome": "Pistão", "preco": 45, "desc": "Empurra 0,5 m em linha reta. Sem sinal: volta ao início ou fica parado."},
	"servo_linear": {"nome": "Servo linear", "preco": 40, "desc": "Vai até uma posição e segura (sinal -1 = recolhido, 0 = meio, 1 = esticado)."},
	"dobradica": {"nome": "Dobradiça", "preco": 10, "desc": "Duas folhas que giram livres até quase dobrar uma sobre a outra."},
	"pino": {"nome": "Dobradiça de pino", "preco": 8, "desc": "Dois blocos num pino: giram livres, volta inteira (eixo livre)."},
	"esferica": {"nome": "Junta esférica", "preco": 12, "desc": "Inclina para qualquer lado e gira em volta do próprio eixo."},
	"trava": {"nome": "Dobradiça com trava", "preco": 18, "desc": "Gira livre; com sinal trava no ângulo em que está (ou o contrário, nos ajustes)."},
	"torcao": {"nome": "Dobradiça de torção", "preco": 15, "desc": "Gira, mas sempre volta sozinha à posição inicial, como uma mola."},
	"mola": {"nome": "Mola", "preco": 20, "desc": "Suspensão: comprime com o peso e volta. Rigidez ajustável."},
	"guincho": {"nome": "Guincho", "preco": 50, "desc": "Cabo entre o corpo e o gancho. Sinal + recolhe o cabo, − solta, sem sinal segura."},
	"propulsor": {"nome": "Propulsor", "preco": 60, "desc": "Empurra na direção da ponta lisa (a chama sai pelo bocal). Sinal negativo empurra ao contrário."},
	"ima": {"nome": "Eletroímã", "preco": 45, "desc": "Ligado, puxa e gruda aço e ferro na face de metal. Alumínio não é atraído."},
	"engate": {"nome": "Engate rápido", "preco": 25, "desc": "Trava no que encostar na face listrada. Liga com E ou com sinal."},
	"roda": {"nome": "Roda", "preco": 0, "desc": "Pneu de borracha. Solde no disco de um motor."},
	"assento": {"nome": "Assento", "preco": 15, "desc": "Sente (E) para controlar a máquina. Tab: modo edição."},
	"botao": {"nome": "Botão", "preco": 4, "desc": "Liga enquanto está apertado. Ligue com a Fiação."},
	"alavanca": {"nome": "Alavanca", "preco": 5, "desc": "Liga e desliga. Ligue com a Fiação."},
	"potenciometro": {"nome": "Alavanca variável", "preco": 8, "desc": "Segure E e mova o mouse para cima/baixo. Na Fiação, botão direito: só positivo ou -1 a 1."},
	"isolador": {"nome": "Isolador", "preco": 0, "desc": "Guia os fios. Criado com a ferramenta de Fiação."},
	"puxador": {"nome": "Puxador", "preco": 2, "desc": "Solde numa porta ou gaveta: segure E mirando nele para puxar (força fraca)."},
	"chip": {"nome": "Chip lógico", "preco": 6, "desc": "E, OU, somar, comparar, memória, temporizador... (86 modos). Escolha o modo no botão direito da Fiação."},
	"constante": {"nome": "Valor constante", "preco": 3, "desc": "Sai sempre o mesmo número, vetor ou texto."},
	"teclas": {"nome": "Teclas", "preco": 5, "desc": "Teclas + e − viram um sinal (-1 a 1). Sentado na máquina, ou sempre (a pé)."},
	"teclado": {"nome": "Teclado de senha", "preco": 8, "desc": "E nele para digitar a senha: Certo ou Errado."},
	"indicador": {"nome": "Indicador", "preco": 3, "desc": "Lâmpada que muda de cor conforme o valor."},
	"pixel": {"nome": "Pixel", "preco": 3, "desc": "Mostra uma cor RGB (vetor de 0 a 255)."},
	"mostrador": {"nome": "Mostrador numérico", "preco": 6, "desc": "Mostra um número grande."},
	"tela": {"nome": "Tela de valores", "preco": 8, "desc": "Mostra dois valores com nome."},
	"tela_texto": {"nome": "Tela de texto", "preco": 10, "desc": "Mostra um texto; {A}, {B}, {C}, {D} e {texto} viram os valores."},
}

const INSULATOR_ANCHOR := Vector3(0, 0.055, 0)   ## onde o fio encosta no isolador (no "pescoço")
const MOTOR_APOTHEM := 0.17
const MOTOR_HALF_H := 0.15
const SERVO_SIZE := Vector3(0.26, 0.28, 0.4)
const SERVO_SHAFT_Z := -0.08                       ## o eixo do servo fica perto de uma ponta


static func wire_anchor(insulator: Part) -> Vector3:
	return insulator.global_transform * INSULATOR_ANCHOR


## Peças mecânicas que vêm em tamanhos (pequeno / médio / grande). O tamanho vai em
## size.x (0 = médio, o padrão de sempre).
const SCALED := ["motor", "servo", "pistao", "servo_linear", "dobradica", "pino", "esferica", "trava", "torcao", "mola", "guincho"]
const SIZE_SMALL := 0.6
const SIZE_LARGE := 1.6


static func scale_of(kind: String, size: Vector3) -> float:
	return size.x if kind in SCALED and size.x > 0.0 else 1.0


static func size_name(kind: String, size: Vector3) -> String:
	var k := scale_of(kind, size)
	return "pequeno" if k < 0.8 else ("grande" if k > 1.2 else "médio")


static func price(kind: String, size := Vector3.ZERO) -> int:
	if kind in SCALED:
		return maxi(1, roundi(float(INFO[kind]["preco"]) * pow(scale_of(kind, size), 1.5)))
	if kind == "roda":
		var r := size.x if size.x > 0.0 else 0.35
		var w := size.y if size.y > 0.0 else 0.2
		return 6 + ceili(r * r * w * 120.0)
	return INFO[kind]["preco"]


## Caixa que envolve o componente (coordenadas do ponto de criação), para achar espaço.
static func bounds(kind: String, size := Vector3.ZERO) -> AABB:
	if kind in SCALED and scale_of(kind, size) != 1.0:
		var b := bounds(kind, Vector3.ZERO)
		var k := scale_of(kind, size)
		return AABB(b.position * k, b.size * k)
	match kind:
		"motor":
			var r := MOTOR_APOTHEM / cos(PI / 8.0)
			return AABB(Vector3(-r, -MOTOR_HALF_H, -r), Vector3(r * 2.0, 0.4, r * 2.0))
		"servo":
			return AABB(Vector3(-0.13, -0.14, -0.2), Vector3(0.26, 0.34, 0.4))
		"pistao":
			return AABB(Vector3(-0.13, -0.35, -0.13), Vector3(0.26, 0.75, 0.26))
		"servo_linear":
			return AABB(Vector3(-0.11, -0.3, -0.16), Vector3(0.22, 0.65, 0.32))
		"dobradica":
			return AABB(Vector3(-0.2, -0.03, -0.28), Vector3(0.4, 0.06, 0.56))
		"pino":
			return AABB(Vector3(-0.15, -0.06, -0.1), Vector3(0.3, 0.12, 0.2))
		"esferica":
			return AABB(Vector3(-0.11, -0.04, -0.11), Vector3(0.22, 0.31, 0.22))
		"trava", "torcao":
			return AABB(Vector3(-0.2, -0.03, -0.28), Vector3(0.4, 0.06, 0.56))
		"mola":
			return AABB(Vector3(-0.14, -0.02, -0.14), Vector3(0.28, 0.34, 0.28))
		"guincho":
			return AABB(Vector3(-0.17, -0.14, -0.2), Vector3(0.67, 0.42, 0.4))
		"propulsor":
			return AABB(Vector3(-0.12, -0.3, -0.12), Vector3(0.24, 0.48, 0.24))
		"ima":
			return AABB(Vector3(-0.22, -0.07, -0.22), Vector3(0.44, 0.17, 0.44))
		"engate":
			return AABB(Vector3(-0.13, -0.04, -0.13), Vector3(0.26, 0.1, 0.26))
		"roda":
			var r := size.x if size.x > 0.0 else 0.35
			var w := size.y if size.y > 0.0 else 0.2
			return AABB(Vector3(-r, -w * 0.5, -r), Vector3(r * 2.0, w, r * 2.0))
		"assento":
			return AABB(Vector3(-0.3, -0.06, -0.3), Vector3(0.6, 0.72, 0.6))
		"botao":
			return AABB(Vector3(-0.12, -0.04, -0.12), Vector3(0.24, 0.13, 0.24))
		"alavanca":
			return AABB(Vector3(-0.1, -0.04, -0.15), Vector3(0.2, 0.38, 0.3))
		"potenciometro":
			return AABB(Vector3(-0.1, -0.04, -0.2), Vector3(0.2, 0.14, 0.4))
		"isolador":
			return AABB(Vector3(-0.07, -0.08, -0.07), Vector3(0.14, 0.18, 0.14))
		"puxador":
			return AABB(Vector3(-0.09, -0.0125, -0.03), Vector3(0.18, 0.09, 0.06))
	if SIGNAL_SIZES.has(kind):
		var s: Vector3 = SIGNAL_SIZES[kind]
		return AABB(-s * 0.5, s + Vector3(0, 0.06 if kind == "indicador" else 0.0, 0))
	return AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)


static var _next_group := 1


## Cria o componente. Retorna as peças criadas (a primeira é a "base").
## Cada peça guarda de que componente veio e a pose em que nasceu (para salvar/carregar).
static func spawn(kind: String, xform: Transform3D, size := Vector3.ZERO) -> Array[Part]:
	var parts := _spawn_kind(kind, xform, size)
	var inv := xform.affine_inverse()
	for i in parts.size():
		var p := parts[i]
		p.comp_kind = kind
		p.comp_index = i
		p.comp_group = _next_group
		p.comp_offset = inv * p.global_transform
		p.comp_size = size
	_next_group += 1
	return parts


static func _spawn_kind(kind: String, xform: Transform3D, size: Vector3) -> Array[Part]:
	match kind:
		"motor":
			return _spawn_motor(xform, scale_of(kind, size))
		"servo":
			return _spawn_servo(xform, scale_of(kind, size))
		"pistao", "servo_linear":
			return _spawn_linear(kind, xform, scale_of(kind, size))
		"dobradica", "trava", "torcao":
			return _spawn_hinge(xform, kind, scale_of(kind, size))
		"mola":
			return _spawn_spring(xform, scale_of(kind, size))
		"guincho":
			return _spawn_winch(xform, scale_of(kind, size))
		"propulsor", "ima", "engate":
			return [_spawn_single(kind, xform)]
		"pino":
			return _spawn_pin(xform, scale_of(kind, size))
		"esferica":
			return _spawn_ball(xform, scale_of(kind, size))
		"roda":
			return [_spawn_wheel(xform, size)]
		"assento":
			return _spawn_seat(xform)
		"botao", "alavanca", "potenciometro":
			return [_spawn_device(kind, xform)]
		"isolador":
			return [_spawn_insulator(xform)]
		"puxador":
			return [_spawn_handle(xform)]
		"chip", "constante", "teclas", "teclado", "indicador", "pixel", "mostrador", "tela", "tela_texto":
			return [_spawn_signal(kind, xform)]
	return []


# --- Formas ----------------------------------------------------------------------

## Prisma octogonal (eixo Y) — carcaça do motor.
static func octagon_planes(apothem: float, half_h: float) -> Array[Plane]:
	var out: Array[Plane] = [Plane(Vector3.UP, half_h), Plane(Vector3.DOWN, half_h)]
	for k in 8:
		var a := k * PI / 4.0
		out.append(Plane(Vector3(cos(a), 0, sin(a)), apothem))
	return out


# --- Peças básicas -------------------------------------------------------------

static func _box(size: Vector3, mat: String, xform: Transform3D, label: String, kind: String) -> Part:
	var p := Build.spawn_box(size, mat, xform)
	_component(p, label, kind)
	return p


static func _component(p: Part, label: String, kind: String) -> void:
	p.cuttable = false
	p.label = label
	p.kind = kind


static func _cyl(radius: float, height: float, mat: String, xform: Transform3D, label: String, kind: String) -> Part:
	var p := Part.new()
	p.setup_cylinder(radius, height, mat)
	p.label = label
	p.kind = kind
	Build.spawn_part(p, xform)
	return p


## Peça octogonal (o "cilindro" do jogo): eixo = Y local, faces nos eixos X/Z.
static func _oct(apothem: float, height: float, mat: String, xform: Transform3D, label: String, kind: String) -> Part:
	var p := Build.spawn_planes(octagon_planes(apothem, height * 0.5), mat, xform)
	_component(p, label, kind)
	return p


## Planos de um prisma octogonal deslocado para `center`.
static func _oct_planes_at(apothem: float, height: float, center: Vector3) -> Array[Plane]:
	var out: Array[Plane] = []
	for pl in octagon_planes(apothem, height * 0.5):
		out.append(Plane(pl.normal, pl.d + pl.normal.dot(center)))
	return out


static func _deco_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = GameTool.glow_material(color, emission) if emission > 0.0 else StationBuilder.mat(color, 0.6, 0.3)
	parent.add_child(mi)
	return mi


## Detalhe "cilíndrico": octogonal (8 lados, faces nos eixos), menos a roda (`sides` alto).
## `radius` = distância do centro até uma face.
static func _deco_cyl(parent: Node3D, radius: float, height: float, xform: Transform3D, color: Color, metal := 0.5, sides := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var r := radius / cos(PI / sides) if sides == 8 else radius
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.transform = xform * Transform3D(Basis(Vector3.UP, PI / 8.0), Vector3.ZERO) if sides == 8 else xform
	mi.material_override = StationBuilder.mat(color, 0.45, metal)
	parent.add_child(mi)
	return mi


static func _deco_sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.position = pos
	mi.material_override = StationBuilder.mat(color, 0.35, 0.85)
	parent.add_child(mi)
	return mi


static func _light(parent: Node3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.022
	sm.height = 0.044
	mi.mesh = sm
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _joint(type: String, a: Part, b: Part, pivot: Vector3, axis: Vector3) -> MechJoint:
	var j := MechJoint.new()
	j.type = type
	j.part_a = a
	j.part_b = b
	j.pivot = pivot
	j.axis = axis
	return j


# --- Componentes ---------------------------------------------------------------

static func _spawn_motor(xform: Transform3D, k := 1.0) -> Array[Part]:
	var stator := Build.spawn_planes(octagon_planes(MOTOR_APOTHEM * k, MOTOR_HALF_H * k), "carcaca", xform)
	_component(stator, "Motor (carcaça)", "motor")
	var rotor := _oct(0.15 * k, 0.06 * k, "aco", xform * Transform3D(Basis(), Vector3(0, (MOTOR_HALF_H + 0.034) * k, 0)), "Motor (disco)", "motor")
	_deco_box(rotor, Vector3(0.2, 0.012, 0.03) * k, Vector3(0, 0.032, 0) * k, Color(0.9, 0.2, 0.15))
	var j := _joint("motor", stator, rotor, Vector3(0, MOTOR_HALF_H * k, 0), Vector3.UP)
	j.size_scale = k
	j.speed = 10.0
	j.strength = 1500.0 * k * k * k
	j.bind_pos = [{"key": KEY_W}]
	j.bind_neg = [{"key": KEY_S}]
	j.capture_rest()
	Build.add_joint(j)
	return [stator, rotor]


static func _spawn_servo(xform: Transform3D, k := 1.0) -> Array[Part]:
	var top := SERVO_SIZE.y * 0.5 * k
	var shaft_z := SERVO_SHAFT_Z * k
	var stator := _box(SERVO_SIZE * k, "carcaca_azul", xform, "Servo (carcaça)", "servo")
	var disc := _oct(0.12 * k, 0.05 * k, "aco", xform * Transform3D(Basis(), Vector3(0, top + 0.029 * k, shaft_z)), "Servo (disco)", "servo")
	_deco_box(disc, Vector3(0.16, 0.012, 0.03) * k, Vector3(0, 0.027, 0) * k, Color(0.95, 0.95, 0.95))
	_deco_cyl(stator, 0.035 * k, 0.012 * k, Transform3D(Basis(), Vector3(0, top + 0.002 * k, shaft_z)), Color(0.2, 0.2, 0.22), 0.6)
	var j := _joint("servo", stator, disc, Vector3(0, top, shaft_z), Vector3.UP)
	j.size_scale = k
	j.speed = 4.0
	j.strength = 2500.0 * k * k * k
	j.bind_pos = [{"key": KEY_A}]
	j.bind_neg = [{"key": KEY_D}]
	j.capture_rest()
	Build.add_joint(j)
	return [stator, disc]


## Pistão e servo linear: a base e a camisa são uma peça só (dá para soldar em qualquer
## lugar dela); a haste corre por dentro (os dois lados nunca colidem entre si).
static func _spawn_linear(kind: String, xform: Transform3D, k := 1.0) -> Array[Part]:
	var linear := kind == "servo_linear"
	var base_size := (Vector3(0.22, 0.1, 0.32) if linear else Vector3(0.26, 0.1, 0.26)) * k
	var base_y := (-0.25 if linear else -0.3) * k
	var sleeve := (Vector3(0.2, 0.45, 0.3) if linear else Vector3(0.24, 0.55, 0.24)) * k
	var rod_size := (Vector3(0.1, 0.5, 0.1) if linear else Vector3(0.14, 0.6, 0.14)) * k
	var rod_y := 0.055 * k
	var color := Color(0.15, 0.35, 0.7) if linear else Color(0.85, 0.6, 0.12)
	var name := "Servo linear" if linear else "Pistão"
	# A peça "base" continua com a origem no centro da base (saves antigos encaixam),
	# mas a forma vai do fundo da base até o topo da camisa.
	var body_h := base_size.y + sleeve.y
	var body_center := Vector3(0, body_h * 0.5 - base_size.y * 0.5, 0)
	var planes: Array[Plane] = []
	if linear:
		for pl in ConvexGeo.box_planes(Vector3(base_size.x, body_h, base_size.z)):
			planes.append(Plane(pl.normal, pl.d + pl.normal.dot(body_center)))
	else:
		planes = _oct_planes_at(base_size.x * 0.5, body_h, body_center)   # pistão: corpo octogonal
	var base := Build.spawn_planes(planes, "carcaca_azul" if linear else "carcaca", xform * Transform3D(Basis(), Vector3(0, base_y, 0)))
	_component(base, name, kind)
	var ring_y := base_size.y * 0.5 + sleeve.y - 0.015 * k
	if linear:
		_deco_box(base, Vector3(base_size.x + 0.02 * k, 0.03 * k, base_size.z + 0.02 * k), Vector3(0, ring_y, 0), color.darkened(0.35))
	else:
		_deco_cyl(base, base_size.x * 0.5 + 0.01 * k, 0.03 * k, Transform3D(Basis(), Vector3(0, ring_y, 0)), color.darkened(0.35), 0.5)
	var rod := _oct(rod_size.x * 0.5, rod_size.y, "aco", xform * Transform3D(Basis(), Vector3(0, rod_y, 0)), name + " (haste)", kind)
	_deco_cyl(rod, rod_size.x * 0.5 + 0.03 * k, 0.04 * k, Transform3D(Basis(), Vector3(0, rod_size.y * 0.5, 0)), Color(0.3, 0.32, 0.35), 0.6)
	var j := _joint(kind, base, rod, Vector3(0, -base_y, 0), Vector3.UP)
	j.size_scale = k
	j.stroke = (0.4 if linear else 0.5) * k
	j.speed = (0.8 if linear else 1.0) * k
	j.strength = (8000.0 if linear else 12000.0) * k * k * k
	j.stiffness = 10000.0 * k * k
	j.damping = 1000.0 * k * k
	j.capture_rest()
	Build.add_joint(j)
	return [base, rod]


const HINGE_KNUCKLE := {"dobradica": Color(0.4, 0.42, 0.45), "trava": Color(0.85, 0.15, 0.1), "torcao": Color(0.2, 0.45, 0.9)}


## Dobradiça (e variações com trava / torção): folhas afastadas 3 cm do eixo.
static func _spawn_hinge(xform: Transform3D, type := "dobradica", k := 1.0) -> Array[Part]:
	var label: String = MechJoint.NAMES[type]
	var leaf := Vector3(0.4, 0.04, 0.25) * k
	var off := 0.155 * k
	var leaf_a := _box(leaf, "aco", xform * Transform3D(Basis(), Vector3(0, 0, -off)), label, type)
	var leaf_b := _box(leaf, "aco", xform * Transform3D(Basis(), Vector3(0, 0, off)), label, type)
	_deco_cyl(leaf_a, 0.025 * k, 0.42 * k, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0, off)), HINGE_KNUCKLE[type], 0.8)
	var j := _joint(type, leaf_a, leaf_b, Vector3(0, 0, off), Vector3.RIGHT)
	j.size_scale = k
	match type:
		"trava":
			j.strength = 3000.0 * k * k * k
			j.indicator = _light(leaf_a, Vector3(0.16, 0.03, 0.0) * k)
		"torcao":
			j.strength = 60.0 * k * k * k * k   # rigidez (N·m por radiano)
			j.speed = 6.0
			_deco_box(leaf_a, Vector3(0.1, 0.02, 0.06) * k, Vector3(0, 0.03, 0.09) * k, Color(0.2, 0.45, 0.9))
	j.capture_rest()
	Build.add_joint(j)
	return [leaf_a, leaf_b]


## Mola (suspensão): duas placas e a espiral entre elas; curso de -0,2 / +0,12 m.
static func _spawn_spring(xform: Transform3D, k := 1.0) -> Array[Part]:
	var a := _box(Vector3(0.28, 0.04, 0.28) * k, "aco", xform, "Mola", "mola")
	var b := _box(Vector3(0.28, 0.04, 0.28) * k, "aco", xform * Transform3D(Basis(), Vector3(0, 0.3 * k, 0)), "Mola", "mola")
	var coil := Node3D.new()
	coil.position = Vector3(0, 0.02 * k, 0)
	a.add_child(coil)
	for i in 6:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.07 * k
		tm.outer_radius = 0.09 * k
		tm.rings = 8               # espiral octogonal, como o resto do jogo
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = StationBuilder.mat(Color(0.9, 0.75, 0.15), 0.4, 0.8)
		ring.position = Vector3(0, (0.022 + i * 0.043) * k, 0)
		ring.rotation.x = deg_to_rad(8.0 if i % 2 == 0 else -8.0)
		coil.add_child(ring)
	var j := _joint("mola", a, b, Vector3.ZERO, Vector3.UP)
	j.size_scale = k
	j.strength = 5000.0 * k * k     # rigidez (N/m)
	j.coil = coil
	j.coil_gap = 0.26 * k
	j.capture_rest()
	Build.add_joint(j)
	return [a, b]


## Guincho: corpo com tambor; o cabo sai por baixo e vai até o gancho.
static func _spawn_winch(xform: Transform3D, k := 1.0) -> Array[Part]:
	var body := _box(Vector3(0.34, 0.28, 0.4) * k, "carcaca", xform, "Guincho", "guincho")
	_deco_cyl(body, 0.1 * k, 0.3 * k, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.16, 0) * k), Color(0.3, 0.32, 0.35), 0.8)
	_deco_cyl(body, 0.03 * k, 0.02 * k, Transform3D(Basis(), Vector3(0, -0.145, 0) * k), Color(0.15, 0.15, 0.16), 0.5)
	var hook := _box(Vector3(0.12, 0.1, 0.12) * k, "aco", xform * Transform3D(Basis(), Vector3(0.4, -0.09, 0) * k), "Guincho (gancho)", "guincho")
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.025 * k
	tm.outer_radius = 0.045 * k
	ring.mesh = tm
	ring.material_override = StationBuilder.mat(Color(0.75, 0.77, 0.8), 0.35, 0.9)
	ring.rotation.x = PI * 0.5
	ring.position = Vector3(0, 0.08, 0) * k
	hook.add_child(ring)
	var j := _joint("guincho", body, hook, Vector3(0, -0.14, 0) * k, Vector3.DOWN)
	j.size_scale = k
	j.hook_anchor = Vector3(0, 0.1, 0) * k
	j.rope_len = j.rope_start().distance_to(j.rope_end()) + 0.05 * k
	j.speed = 1.0
	j.strength = 5000.0 * k * k * k
	j.max_rope = 20.0
	j.bind_pos = []
	j.bind_neg = []
	j.capture_rest()
	Build.add_joint(j)
	return [body, hook]


## Componentes de uma peça só: propulsor, eletroímã e engate rápido.
static func _spawn_single(kind: String, xform: Transform3D) -> Part:
	var p: Part
	var j := MechJoint.new()
	j.type = kind
	match kind:
		"propulsor":
			p = _oct(0.12, 0.36, "aco", xform, "Propulsor", kind)
			_deco_cyl(p, 0.125, 0.04, Transform3D(Basis(), Vector3(0, 0.1, 0)), Color(0.95, 0.5, 0.1), 0.3)
			var nozzle := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.07 / cos(PI / 8.0)
			cm.bottom_radius = 0.11 / cos(PI / 8.0)
			cm.height = 0.12
			cm.radial_segments = 8
			cm.rings = 1
			nozzle.mesh = cm
			nozzle.material_override = StationBuilder.mat(Color(0.2, 0.2, 0.22), 0.4, 0.8)
			nozzle.position = Vector3(0, -0.24, 0)
			nozzle.rotation.y = PI / 8.0
			p.add_child(nozzle)
			j.fx = _flame(p, Vector3(0, -0.31, 0))
			j.axis = Vector3.UP          # empurra para a ponta lisa
			j.pivot = Vector3.ZERO
			j.strength = 300.0
		"ima":
			p = _oct(0.22, 0.1, "plastico", xform, "Eletroímã", kind)
			var face := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.2 / cos(PI / 8.0)
			fm.bottom_radius = 0.2 / cos(PI / 8.0)
			fm.height = 0.012
			fm.radial_segments = 8
			fm.rings = 1
			face.mesh = fm
			face.rotation.y = PI / 8.0
			face.position = Vector3(0, -0.056, 0)
			p.add_child(face)
			j.indicator = face             # a face acende quando liga
			_deco_cyl(p, 0.04, 0.06, Transform3D(Basis(), Vector3(0, 0.08, 0)), Color(0.6, 0.62, 0.66), 0.9)
			j.axis = Vector3.DOWN          # a face de metal fica embaixo
			j.pivot = Vector3(0, -0.05, 0)
			j.strength = 800.0
		"engate":
			p = _box(Vector3(0.26, 0.08, 0.26), "plastico", xform, "Engate rápido", kind)
			for i in 3:
				_deco_box(p, Vector3(0.26, 0.004, 0.04), Vector3(0, 0.041, -0.08 + i * 0.08), Color(0.95, 0.75, 0.1))
			j.indicator = _light(p, Vector3(0.1, 0.045, 0.1))
			j.axis = Vector3.UP            # face listrada em cima
			j.pivot = Vector3(0, 0.04, 0)
			p.interact_kind = "engate"
	p.cuttable = false
	j.part_a = p
	j.part_b = p
	j.capture_rest()
	Build.add_joint(j)
	j.update(0.0)   # acerta a luz/efeito inicial
	return p


static var _flame_mat: StandardMaterial3D


## Chama do propulsor (sai para -Y): bolhas de luz que nascem branco-amareladas
## no bocal e viram laranja/vermelho até sumir.
static func _flame(parent: Node3D, pos: Vector3) -> CPUParticles3D:
	if _flame_mat == null:
		var soft := Gradient.new()
		soft.set_color(0, Color(1, 1, 1, 1))
		soft.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = soft
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_flame_mat = StandardMaterial3D.new()
		_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_flame_mat.albedo_texture = tex
		_flame_mat.vertex_color_use_as_albedo = true
		_flame_mat.disable_fog = true
	var f := CPUParticles3D.new()
	f.emitting = false
	f.amount = 90
	f.lifetime = 0.22
	f.direction = Vector3.DOWN
	f.spread = 6.0
	f.initial_velocity_min = 4.5
	f.initial_velocity_max = 6.5
	f.gravity = Vector3.ZERO
	f.scale_amount_min = 1.4
	f.scale_amount_max = 2.2
	var shape := Curve.new()
	shape.add_point(Vector2(0, 0.7))
	shape.add_point(Vector2(0.3, 1.0))
	shape.add_point(Vector2(1, 0.3))
	f.scale_amount_curve = shape
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
	ramp.set_color(1, Color(0.6, 0.08, 0.02, 0.0))
	ramp.add_point(0.35, Color(1.0, 0.55, 0.12, 0.9))
	f.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.13)
	f.mesh = quad
	f.material_override = _flame_mat
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.position = pos
	f.local_coords = false
	parent.add_child(f)
	return f


static func _spawn_pin(xform: Transform3D, k := 1.0) -> Array[Part]:
	var a := _box(Vector3(0.12, 0.12, 0.2) * k, "aco", xform * Transform3D(Basis(), Vector3(-0.065 * k, 0, 0)), "Dobradiça de pino", "pino")
	var b := _box(Vector3(0.12, 0.12, 0.2) * k, "ferro", xform * Transform3D(Basis(), Vector3(0.065 * k, 0, 0)), "Dobradiça de pino", "pino")
	_deco_cyl(a, 0.025 * k, 0.3 * k, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.065 * k, 0, 0)), Color(0.75, 0.77, 0.8), 0.9)
	var j := _joint("pino", a, b, Vector3(0.065 * k, 0, 0), Vector3.RIGHT)
	j.size_scale = k
	j.capture_rest()
	Build.add_joint(j)
	return [a, b]


static func _spawn_ball(xform: Transform3D, k := 1.0) -> Array[Part]:
	var base := _box(Vector3(0.22, 0.08, 0.22) * k, "carcaca", xform, "Junta esférica (base)", "esferica")
	var plate := _box(Vector3(0.22, 0.06, 0.22) * k, "aco", xform * Transform3D(Basis(), Vector3(0, 0.24 * k, 0)), "Junta esférica (placa)", "esferica")
	_deco_cyl(base, 0.065 * k, 0.04 * k, Transform3D(Basis(), Vector3(0, 0.06 * k, 0)), Color(0.3, 0.3, 0.32), 0.7)
	_deco_sphere(base, 0.05 * k, Vector3(0, 0.12 * k, 0), Color(0.75, 0.77, 0.8))
	_deco_cyl(plate, 0.02 * k, 0.09 * k, Transform3D(Basis(), Vector3(0, -0.075 * k, 0)), Color(0.75, 0.77, 0.8), 0.9)
	var j := _joint("esferica", base, plate, Vector3(0, 0.12 * k, 0), Vector3.UP)
	j.size_scale = k
	j.max_angle = deg_to_rad(50.0)
	j.capture_rest()
	Build.add_joint(j)
	return [base, plate]


static func _spawn_wheel(xform: Transform3D, size: Vector3) -> Part:
	var r := clampf(size.x if size.x > 0.0 else 0.35, 0.15, 1.2)
	var w := clampf(size.y if size.y > 0.0 else 0.2, 0.08, 0.6)
	var wheel := _cyl(r, w, "borracha", xform, "Roda", "roda")
	_deco_cyl(wheel, r * 0.6, w + 0.008, Transform3D.IDENTITY, Color(0.62, 0.64, 0.68), 0.85, 28)
	_deco_cyl(wheel, r * 0.18, w + 0.016, Transform3D.IDENTITY, Color(0.25, 0.26, 0.28), 0.6, 20)
	wheel.assembly().recompute()
	return wheel


static func _spawn_seat(xform: Transform3D) -> Array[Part]:
	var base := _box(Vector3(0.6, 0.12, 0.6), "plastico", xform, "Assento", "assento")
	base.interact_kind = "assento"
	var back := _box(Vector3(0.6, 0.6, 0.1), "plastico", xform * Transform3D(Basis(), Vector3(0, 0.36, 0.25)), "Assento (encosto)", "assento")
	back.interact_kind = "assento"
	back.set_meta("seat_base", base)   # mirar no encosto também senta
	_deco_box(base, Vector3(0.5, 0.03, 0.5), Vector3(0, 0.07, -0.02), Color(0.45, 0.12, 0.1))
	_deco_box(base, Vector3(0.12, 0.02, 0.04), Vector3(0, 0.0, -0.31), Color(1.0, 0.75, 0.2), 1.5)
	Build.make_weld(base, back, xform * Vector3(0, 0.06, 0.25), false).internal = true
	var sn := SeatNode.new()
	sn.part = base
	Build.add_node(sn)
	return [base, back]


static func _spawn_device(kind: String, xform: Transform3D) -> Part:
	var dev := ControlDevice.new()
	dev.kind = kind
	var part: Part
	match kind:
		"botao":
			part = _box(Vector3(0.24, 0.08, 0.24), "plastico", xform, "Botão", "botao")
			var cap := Node3D.new()
			part.add_child(cap)
			_deco_cyl(cap, 0.07, 0.04, Transform3D.IDENTITY, Color(0.85, 0.12, 0.1), 0.1)
			dev.setup_visuals(cap, _light(part, Vector3(0.085, 0.045, 0.085)))
		"alavanca":
			part = _box(Vector3(0.2, 0.08, 0.3), "plastico", xform, "Alavanca", "alavanca")
			var arm := Node3D.new()
			arm.position = Vector3(0, 0.04, 0)
			part.add_child(arm)
			_deco_box(arm, Vector3(0.035, 0.28, 0.035), Vector3(0, 0.14, 0), Color(0.6, 0.62, 0.66))
			_deco_box(arm, Vector3(0.07, 0.07, 0.07), Vector3(0, 0.29, 0), Color(0.85, 0.12, 0.1))
			dev.setup_visuals(arm, _light(part, Vector3(0.07, 0.045, 0.12)))
		_:
			part = _box(Vector3(0.2, 0.08, 0.4), "plastico", xform, "Alavanca variável", "potenciometro")
			_deco_box(part, Vector3(0.04, 0.01, 0.32), Vector3(0, 0.041, 0), Color(0.05, 0.05, 0.05))
			var knob := Node3D.new()
			knob.position = Vector3(0, 0.07, 0)
			part.add_child(knob)
			_deco_box(knob, Vector3(0.1, 0.06, 0.05), Vector3.ZERO, Color(0.95, 0.65, 0.1))
			dev.setup_visuals(knob, _light(part, Vector3(0.07, 0.045, 0.17)))
	part.interact_kind = kind
	dev.part = part
	Build.add_device(dev)
	return part


## Puxador: base fina + alça em "U". E segurado puxa (ver Player._update_pull).
static func _spawn_handle(xform: Transform3D) -> Part:
	var p := _box(Vector3(0.18, 0.025, 0.05), "aco", xform, "Puxador", "puxador")
	_handle_visual(p)
	p.interact_kind = "puxador"
	return p


static func _handle_visual(parent: Node3D) -> void:
	var c := Color(0.75, 0.77, 0.8)
	for x: float in [-0.065, 0.065]:
		_deco_box(parent, Vector3(0.018, 0.06, 0.018), Vector3(x, 0.04, 0), c)
	_deco_box(parent, Vector3(0.16, 0.02, 0.022), Vector3(0, 0.07, 0), Color(0.15, 0.15, 0.16))


## Isolador (como os de cerca elétrica): base, "pescoço" onde o fio passa e a tampa.
static func _spawn_insulator(xform: Transform3D) -> Part:
	var p := _oct(0.07, 0.16, "plastico", xform, "Isolador", "isolador")
	p.mesh_instance.visible = false   # a aparência vem das peças abaixo
	_insulator_visual(p)
	p.assembly().recompute()
	return p


static func _insulator_visual(parent: Node3D) -> void:
	var black := Color(0.06, 0.06, 0.065)
	_deco_cyl(parent, 0.07, 0.08, Transform3D(Basis(), Vector3(0, -0.04, 0)), black, 0.0)
	_deco_cyl(parent, 0.04, 0.06, Transform3D(Basis(), Vector3(0, 0.03, 0)), black, 0.0)
	_deco_cyl(parent, 0.072, 0.02, Transform3D(Basis(), Vector3(0, 0.07, 0)), black, 0.0)
	_deco_cyl(parent, 0.012, 0.004, Transform3D(Basis(), Vector3(0, 0.081, 0)), Color(0.7, 0.72, 0.75), 0.9)
	_deco_cyl(parent, 0.006, 0.08, Transform3D(Basis(), Vector3(0, -0.12, 0)), Color(0.6, 0.62, 0.66), 0.9)


# --- Lógica e mostradores ----------------------------------------------------------

const SIGNAL_SIZES := {
	"chip": Vector3(0.24, 0.05, 0.18), "constante": Vector3(0.18, 0.06, 0.18),
	"teclas": Vector3(0.22, 0.05, 0.16), "teclado": Vector3(0.18, 0.04, 0.24),
	"indicador": Vector3(0.12, 0.05, 0.12), "pixel": Vector3(0.2, 0.04, 0.2),
	"mostrador": Vector3(0.4, 0.05, 0.16), "tela": Vector3(0.5, 0.04, 0.32),
	"tela_texto": Vector3(0.7, 0.04, 0.45),
}
const SIGNAL_LABELS := {
	"chip": "Chip lógico", "constante": "Valor constante", "teclas": "Teclas", "teclado": "Teclado de senha",
	"indicador": "Indicador", "pixel": "Pixel", "mostrador": "Mostrador numérico", "tela": "Tela de valores",
	"tela_texto": "Tela de texto",
}
const BOARD_DARK := Color(0.07, 0.08, 0.09)
const SCREEN_DARK := Color(0.02, 0.04, 0.06)


static func _spawn_signal(kind: String, xform: Transform3D) -> Part:
	var size: Vector3 = SIGNAL_SIZES[kind]
	var top := size.y * 0.5
	var p := _box(size, "plastico", xform, SIGNAL_LABELS[kind], kind)
	var node: SignalNode
	match kind:
		"chip":
			var c := ChipNode.new()
			c.part = p
			for i in 4:
				for side: float in [-1.0, 1.0]:
					_deco_box(p, Vector3(0.025, 0.012, 0.02), Vector3(-0.09 + i * 0.06, -0.012, side * (size.z * 0.5 + 0.008)), Color(0.85, 0.7, 0.25))
			c.label = _label3d(p, Gates.DEFS[c.mode]["sym"], top, 64, Color(0.95, 0.95, 0.95))
			node = c
		"constante":
			var k := ConstNode.new()
			k.part = p
			_deco_box(p, Vector3(size.x - 0.02, 0.004, size.z - 0.02), Vector3(0, top, 0), Color(0.12, 0.3, 0.7))
			k.label = _label3d(p, "1", top + 0.003, 48, Color.WHITE)
			node = k
		"teclas":
			var t := KeysNode.new()
			t.part = p
			for x: float in [-0.05, 0.05]:
				_deco_box(p, Vector3(0.07, 0.02, 0.07), Vector3(x, top + 0.008, -0.025), Color(0.85, 0.85, 0.88))
			t.label = _label3d(p, t.keys_text(), top + 0.002, 24, Color(1.0, 0.8, 0.3), Vector3(0, 0, 0.055))
			node = t
		"teclado":
			var kp := KeypadNode.new()
			kp.part = p
			for r in 4:
				for col in 3:
					_deco_box(p, Vector3(0.04, 0.012, 0.035), Vector3(-0.05 + col * 0.05, top + 0.004, -0.04 + r * 0.045), Color(0.75, 0.77, 0.8))
			kp.label = _label3d(p, "SENHA", top + 0.002, 26, Color(0.8, 0.85, 0.9), Vector3(0, 0, -0.088))
			p.interact_kind = "teclado"
			node = kp
		"indicador", "pixel", "mostrador", "tela", "tela_texto":
			var d := DisplayNode.new()
			d.part = p
			d.kind = kind
			match kind:
				"indicador":
					d.setup_lamp(_deco_sphere(p, 0.05, Vector3(0, top, 0), Color.WHITE))
				"pixel":
					d.setup_lamp(_deco_box(p, Vector3(size.x - 0.02, 0.006, size.z - 0.02), Vector3(0, top, 0), Color.WHITE))
				"mostrador":
					_deco_box(p, Vector3(size.x - 0.03, 0.004, size.z - 0.03), Vector3(0, top, 0), SCREEN_DARK)
					d.label = _label3d(p, "0.0", top + 0.003, 110, Color(1.0, 0.22, 0.12))
					d.decimals = 1
				"tela":
					_deco_box(p, Vector3(size.x - 0.04, 0.004, size.z - 0.04), Vector3(0, top, 0), SCREEN_DARK)
					d.label = _label3d(p, "A: 0\nB: 0", top + 0.003, 84, Color(0.75, 0.95, 1.0))
				"tela_texto":
					_deco_box(p, Vector3(size.x - 0.04, 0.004, size.z - 0.04), Vector3(0, top, 0), SCREEN_DARK)
					d.label = _label3d(p, "", top + 0.003, 64, Color(0.75, 1.0, 0.8), Vector3.ZERO, size.x - 0.08)
			node = d
	Build.add_node(node)
	return p


## Texto deitado em cima da peça (lido de quem está na frente, olhando para -Z).
static func _label3d(parent: Node3D, text: String, top_y: float, font_size: int, color: Color, offset := Vector3.ZERO, width := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.0011
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.position = Vector3(0, top_y + 0.002, 0) + offset
	l.rotation.x = -PI * 0.5
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = width / l.pixel_size
	parent.add_child(l)
	return l


# --- Aparência para a loja (sem física) ---------------------------------------

static func build_visual(kind: String, size := Vector3.ZERO) -> Node3D:
	var root := Node3D.new()
	var steel := Color(0.6, 0.62, 0.66)
	match kind:
		"motor":
			var octo := MeshInstance3D.new()
			var geo := ConvexGeo.solve(octagon_planes(MOTOR_APOTHEM, MOTOR_HALF_H))
			octo.mesh = ConvexGeo.build_mesh(geo)
			octo.mesh.surface_set_material(0, MetalMaterials.get_material("carcaca"))
			octo.mesh.surface_set_material(1, MetalMaterials.edge_material())
			root.add_child(octo)
			_deco_cyl(root, 0.15, 0.06, Transform3D(Basis(), Vector3(0, MOTOR_HALF_H + 0.034, 0)), steel, 0.85)
			_deco_box(root, Vector3(0.2, 0.012, 0.03), Vector3(0, MOTOR_HALF_H + 0.066, 0), Color(0.9, 0.2, 0.15))
		"servo":
			_deco_box(root, SERVO_SIZE, Vector3.ZERO, Color(0.15, 0.35, 0.7))
			_deco_cyl(root, 0.12, 0.05, Transform3D(Basis(), Vector3(0, SERVO_SIZE.y * 0.5 + 0.029, SERVO_SHAFT_Z)), steel, 0.85)
			_deco_box(root, Vector3(0.16, 0.012, 0.03), Vector3(0, SERVO_SIZE.y * 0.5 + 0.056, SERVO_SHAFT_Z), Color(0.95, 0.95, 0.95))
		"pistao", "servo_linear":
			var linear := kind == "servo_linear"
			var color := Color(0.15, 0.35, 0.7) if linear else Color(0.85, 0.6, 0.12)
			if linear:
				_deco_box(root, Vector3(0.22, 0.1, 0.32), Vector3(0, -0.25, 0), color)
				_deco_box(root, Vector3(0.2, 0.45, 0.3), Vector3(0, 0.025, 0), color)
				_deco_cyl(root, 0.05, 0.5, Transform3D(Basis(), Vector3(0, 0.055, 0)), steel, 0.8)
				_deco_cyl(root, 0.08, 0.04, Transform3D(Basis(), Vector3(0, 0.305, 0)), Color(0.3, 0.32, 0.35))
			else:
				_deco_cyl(root, 0.13, 0.65, Transform3D(Basis(), Vector3(0, -0.025, 0)), color, 0.4)
				_deco_cyl(root, 0.07, 0.6, Transform3D(Basis(), Vector3(0, 0.055, 0)), steel, 0.8)
				_deco_cyl(root, 0.1, 0.04, Transform3D(Basis(), Vector3(0, 0.355, 0)), Color(0.3, 0.32, 0.35))
		"dobradica":
			_deco_box(root, Vector3(0.4, 0.04, 0.25), Vector3(0, 0, -0.155), steel)
			_deco_box(root, Vector3(0.4, 0.04, 0.25), Vector3(0, 0, 0.155), steel)
			_deco_cyl(root, 0.025, 0.42, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), Color(0.4, 0.42, 0.45))
		"trava", "torcao":
			_deco_box(root, Vector3(0.4, 0.04, 0.25), Vector3(0, 0, -0.155), steel)
			_deco_box(root, Vector3(0.4, 0.04, 0.25), Vector3(0, 0, 0.155), steel)
			_deco_cyl(root, 0.025, 0.42, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), HINGE_KNUCKLE[kind])
		"mola":
			_deco_box(root, Vector3(0.28, 0.04, 0.28), Vector3.ZERO, steel)
			_deco_box(root, Vector3(0.28, 0.04, 0.28), Vector3(0, 0.3, 0), steel)
			_deco_cyl(root, 0.08, 0.26, Transform3D(Basis(), Vector3(0, 0.15, 0)), Color(0.9, 0.75, 0.15), 0.8)
		"guincho":
			_deco_box(root, Vector3(0.34, 0.28, 0.4), Vector3.ZERO, Color(0.85, 0.6, 0.12))
			_deco_cyl(root, 0.1, 0.3, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.16, 0)), Color(0.3, 0.32, 0.35))
			_deco_box(root, Vector3(0.12, 0.1, 0.12), Vector3(0.4, -0.09, 0), steel)
		"propulsor":
			_deco_cyl(root, 0.12, 0.36, Transform3D.IDENTITY, steel, 0.8)
			_deco_cyl(root, 0.125, 0.04, Transform3D(Basis(), Vector3(0, 0.1, 0)), Color(0.95, 0.5, 0.1))
			_deco_cyl(root, 0.1, 0.12, Transform3D(Basis(), Vector3(0, -0.24, 0)), Color(0.2, 0.2, 0.22))
		"ima":
			_deco_cyl(root, 0.22, 0.1, Transform3D.IDENTITY, Color(0.16, 0.17, 0.19), 0.2)
			_deco_cyl(root, 0.2, 0.012, Transform3D(Basis(), Vector3(0, -0.056, 0)), steel, 0.9)
			_deco_cyl(root, 0.04, 0.06, Transform3D(Basis(), Vector3(0, 0.08, 0)), steel, 0.9)
		"engate":
			_deco_box(root, Vector3(0.26, 0.08, 0.26), Vector3.ZERO, Color(0.16, 0.17, 0.19))
			for i in 3:
				_deco_box(root, Vector3(0.26, 0.004, 0.04), Vector3(0, 0.041, -0.08 + i * 0.08), Color(0.95, 0.75, 0.1))
		"pino":
			_deco_box(root, Vector3(0.12, 0.12, 0.2), Vector3(-0.065, 0, 0), steel)
			_deco_box(root, Vector3(0.12, 0.12, 0.2), Vector3(0.065, 0, 0), Color(0.5, 0.32, 0.2))
			_deco_cyl(root, 0.025, 0.3, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), Color(0.75, 0.77, 0.8))
		"esferica":
			_deco_box(root, Vector3(0.22, 0.08, 0.22), Vector3.ZERO, Color(0.85, 0.6, 0.12))
			_deco_sphere(root, 0.05, Vector3(0, 0.12, 0), Color(0.75, 0.77, 0.8))
			_deco_cyl(root, 0.02, 0.09, Transform3D(Basis(), Vector3(0, 0.165, 0)), Color(0.75, 0.77, 0.8))
			_deco_box(root, Vector3(0.22, 0.06, 0.22), Vector3(0, 0.24, 0), steel)
		"roda":
			var r := size.x if size.x > 0.0 else 0.35
			var w := size.y if size.y > 0.0 else 0.2
			var tilt := Basis(Vector3.RIGHT, PI * 0.5)
			_deco_cyl(root, r, w, Transform3D(tilt, Vector3.ZERO), Color(0.08, 0.08, 0.085), 0.0, 28)
			_deco_cyl(root, r * 0.6, w + 0.01, Transform3D(tilt, Vector3.ZERO), steel, 0.85, 28)
		"assento":
			_deco_box(root, Vector3(0.6, 0.12, 0.6), Vector3.ZERO, Color(0.16, 0.17, 0.19))
			_deco_box(root, Vector3(0.6, 0.6, 0.1), Vector3(0, 0.36, 0.25), Color(0.16, 0.17, 0.19))
			_deco_box(root, Vector3(0.5, 0.03, 0.5), Vector3(0, 0.07, -0.02), Color(0.45, 0.12, 0.1))
		"botao":
			_deco_box(root, Vector3(0.24, 0.08, 0.24), Vector3.ZERO, Color(0.16, 0.17, 0.19))
			_deco_cyl(root, 0.07, 0.04, Transform3D(Basis(), Vector3(0, 0.055, 0)), Color(0.85, 0.12, 0.1), 0.1)
		"alavanca":
			_deco_box(root, Vector3(0.2, 0.08, 0.3), Vector3.ZERO, Color(0.16, 0.17, 0.19))
			var arm := Node3D.new()
			arm.position = Vector3(0, 0.04, 0)
			arm.rotation.x = deg_to_rad(30)
			root.add_child(arm)
			_deco_box(arm, Vector3(0.035, 0.28, 0.035), Vector3(0, 0.14, 0), steel)
			_deco_box(arm, Vector3(0.07, 0.07, 0.07), Vector3(0, 0.29, 0), Color(0.85, 0.12, 0.1))
		"potenciometro":
			_deco_box(root, Vector3(0.2, 0.08, 0.4), Vector3.ZERO, Color(0.16, 0.17, 0.19))
			_deco_box(root, Vector3(0.1, 0.06, 0.05), Vector3(0, 0.07, -0.07), Color(0.95, 0.65, 0.1))
		"isolador":
			_insulator_visual(root)
		"puxador":
			_deco_box(root, Vector3(0.18, 0.025, 0.05), Vector3.ZERO, steel)
			_handle_visual(root)
		"chip", "constante", "teclas", "teclado", "indicador", "pixel", "mostrador", "tela", "tela_texto":
			var ssz: Vector3 = SIGNAL_SIZES[kind]
			_deco_box(root, ssz, Vector3.ZERO, BOARD_DARK)
			var top := ssz.y * 0.5
			match kind:
				"chip":
					_label3d(root, "E", top, 64, Color.WHITE)
					for i in 4:
						for side: float in [-1.0, 1.0]:
							_deco_box(root, Vector3(0.025, 0.012, 0.02), Vector3(-0.09 + i * 0.06, -0.012, side * (ssz.z * 0.5 + 0.008)), Color(0.85, 0.7, 0.25))
				"constante":
					_deco_box(root, Vector3(ssz.x - 0.02, 0.004, ssz.z - 0.02), Vector3(0, top, 0), Color(0.12, 0.3, 0.7))
					_label3d(root, "1", top + 0.003, 48, Color.WHITE)
				"teclas":
					for x: float in [-0.05, 0.05]:
						_deco_box(root, Vector3(0.07, 0.02, 0.07), Vector3(x, top + 0.008, -0.025), Color(0.85, 0.85, 0.88))
				"teclado":
					for r in 4:
						for col in 3:
							_deco_box(root, Vector3(0.04, 0.012, 0.035), Vector3(-0.05 + col * 0.05, top + 0.004, -0.04 + r * 0.045), Color(0.75, 0.77, 0.8))
				"indicador":
					_deco_sphere(root, 0.05, Vector3(0, top, 0), Color(0.2, 1.0, 0.3))
				"pixel":
					_deco_box(root, Vector3(ssz.x - 0.02, 0.006, ssz.z - 0.02), Vector3(0, top, 0), Color(0.9, 0.3, 0.8), 1.0)
				"mostrador":
					_deco_box(root, Vector3(ssz.x - 0.03, 0.004, ssz.z - 0.03), Vector3(0, top, 0), SCREEN_DARK)
					_label3d(root, "12.5", top + 0.003, 110, Color(1.0, 0.22, 0.12))
				"tela", "tela_texto":
					_deco_box(root, Vector3(ssz.x - 0.04, 0.004, ssz.z - 0.04), Vector3(0, top, 0), SCREEN_DARK)
					_label3d(root, "A: 1\nB: 0" if kind == "tela" else "Olá!", top + 0.003, 56, Color(0.75, 0.95, 1.0))
	if kind in SCALED:
		root.scale = Vector3.ONE * scale_of(kind, size)
	return root

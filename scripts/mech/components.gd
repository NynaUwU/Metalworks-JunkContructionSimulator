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
	"roda": {"nome": "Roda", "preco": 0, "desc": "Pneu de borracha. Solde no disco de um motor."},
	"assento": {"nome": "Assento", "preco": 15, "desc": "Sente (E) para controlar a máquina. Tab: modo edição."},
	"botao": {"nome": "Botão", "preco": 4, "desc": "Liga enquanto está apertado. Ligue com a Fiação."},
	"alavanca": {"nome": "Alavanca", "preco": 5, "desc": "Liga e desliga. Ligue com a Fiação."},
	"potenciometro": {"nome": "Alavanca variável", "preco": 8, "desc": "Segure E e mova o mouse para cima/baixo. Na Fiação, botão direito: só positivo ou -1 a 1."},
	"isolador": {"nome": "Isolador", "preco": 0, "desc": "Guia os fios. Criado com a ferramenta de Fiação."},
}

const INSULATOR_ANCHOR := Vector3(0, 0.055, 0)   ## onde o fio encosta no isolador (no "pescoço")
const MOTOR_APOTHEM := 0.17
const MOTOR_HALF_H := 0.15
const SERVO_SIZE := Vector3(0.26, 0.28, 0.4)
const SERVO_SHAFT_Z := -0.08                       ## o eixo do servo fica perto de uma ponta


static func wire_anchor(insulator: Part) -> Vector3:
	return insulator.global_transform * INSULATOR_ANCHOR


static func price(kind: String, size := Vector3.ZERO) -> int:
	if kind == "roda":
		var r := size.x if size.x > 0.0 else 0.35
		var w := size.y if size.y > 0.0 else 0.2
		return 6 + ceili(r * r * w * 120.0)
	return INFO[kind]["preco"]


## Caixa que envolve o componente (coordenadas do ponto de criação), para achar espaço.
static func bounds(kind: String, size := Vector3.ZERO) -> AABB:
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
	return AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)


## Cria o componente. Retorna as peças criadas (a primeira é a "base").
static func spawn(kind: String, xform: Transform3D, size := Vector3.ZERO) -> Array[Part]:
	match kind:
		"motor":
			return _spawn_motor(xform)
		"servo":
			return _spawn_servo(xform)
		"pistao":
			return _spawn_linear("pistao", xform)
		"servo_linear":
			return _spawn_linear("servo_linear", xform)
		"dobradica":
			return _spawn_hinge(xform)
		"pino":
			return _spawn_pin(xform)
		"esferica":
			return _spawn_ball(xform)
		"roda":
			return [_spawn_wheel(xform, size)]
		"assento":
			return _spawn_seat(xform)
		"botao", "alavanca", "potenciometro":
			return [_spawn_device(kind, xform)]
		"isolador":
			return [_spawn_insulator(xform)]
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


static func _deco_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = GameTool.glow_material(color, emission) if emission > 0.0 else StationBuilder.mat(color, 0.6, 0.3)
	parent.add_child(mi)
	return mi


static func _deco_cyl(parent: Node3D, radius: float, height: float, xform: Transform3D, color: Color, metal := 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 20
	mi.mesh = cm
	mi.transform = xform
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

static func _spawn_motor(xform: Transform3D) -> Array[Part]:
	var stator := Build.spawn_planes(octagon_planes(MOTOR_APOTHEM, MOTOR_HALF_H), "carcaca", xform)
	_component(stator, "Motor (carcaça)", "motor")
	var rotor := _cyl(0.15, 0.06, "aco", xform * Transform3D(Basis(), Vector3(0, MOTOR_HALF_H + 0.034, 0)), "Motor (disco)", "motor")
	_deco_box(rotor, Vector3(0.2, 0.012, 0.03), Vector3(0, 0.032, 0), Color(0.9, 0.2, 0.15))
	var j := _joint("motor", stator, rotor, Vector3(0, MOTOR_HALF_H, 0), Vector3.UP)
	j.speed = 10.0
	j.strength = 1500.0
	j.bind_pos = [{"key": KEY_W}]
	j.bind_neg = [{"key": KEY_S}]
	j.capture_rest()
	Build.add_joint(j)
	return [stator, rotor]


static func _spawn_servo(xform: Transform3D) -> Array[Part]:
	var top := SERVO_SIZE.y * 0.5
	var stator := _box(SERVO_SIZE, "carcaca_azul", xform, "Servo (carcaça)", "servo")
	var disc := _cyl(0.12, 0.05, "aco", xform * Transform3D(Basis(), Vector3(0, top + 0.029, SERVO_SHAFT_Z)), "Servo (disco)", "servo")
	_deco_box(disc, Vector3(0.16, 0.012, 0.03), Vector3(0, 0.027, 0), Color(0.95, 0.95, 0.95))
	_deco_cyl(stator, 0.035, 0.012, Transform3D(Basis(), Vector3(0, top + 0.002, SERVO_SHAFT_Z)), Color(0.2, 0.2, 0.22), 0.6)
	var j := _joint("servo", stator, disc, Vector3(0, top, SERVO_SHAFT_Z), Vector3.UP)
	j.speed = 4.0
	j.strength = 2500.0
	j.bind_pos = [{"key": KEY_A}]
	j.bind_neg = [{"key": KEY_D}]
	j.capture_rest()
	Build.add_joint(j)
	return [stator, disc]


## Pistão e servo linear: só a BASE tem colisão do corpo (a "camisa" é visual), assim a
## haste pode ficar dentro dela e os dois lados ainda colidem com o resto do mundo.
static func _spawn_linear(kind: String, xform: Transform3D) -> Array[Part]:
	var linear := kind == "servo_linear"
	var base_size := Vector3(0.22, 0.1, 0.32) if linear else Vector3(0.26, 0.1, 0.26)
	var base_y := -0.25 if linear else -0.3
	var sleeve := Vector3(0.2, 0.45, 0.3) if linear else Vector3(0.24, 0.55, 0.24)
	var rod_size := Vector3(0.1, 0.5, 0.1) if linear else Vector3(0.14, 0.6, 0.14)
	var rod_y := 0.055
	var color := Color(0.15, 0.35, 0.7) if linear else Color(0.85, 0.6, 0.12)
	var name := "Servo linear" if linear else "Pistão"
	var base := _box(base_size, "carcaca_azul" if linear else "carcaca", xform * Transform3D(Basis(), Vector3(0, base_y, 0)), name + " (base)", kind)
	var sleeve_bottom := base_size.y * 0.5
	_deco_box(base, sleeve, Vector3(0, sleeve_bottom + sleeve.y * 0.5, 0), color)
	var rod := _box(rod_size, "aco", xform * Transform3D(Basis(), Vector3(0, rod_y, 0)), name + " (haste)", kind)
	_deco_box(rod, Vector3(rod_size.x + 0.06, 0.04, rod_size.z + 0.06), Vector3(0, rod_size.y * 0.5, 0), Color(0.3, 0.32, 0.35))
	var j := _joint(kind, base, rod, Vector3(0, -base_y, 0), Vector3.UP)
	j.stroke = 0.4 if linear else 0.5
	j.speed = 0.8 if linear else 1.0
	j.strength = 8000.0 if linear else 12000.0
	j.capture_rest()
	Build.add_joint(j)
	return [base, rod]


static func _spawn_hinge(xform: Transform3D) -> Array[Part]:
	# Folhas afastadas 3 cm do eixo: giram sem se tocar até quase dobrar.
	var leaf_a := _box(Vector3(0.4, 0.04, 0.25), "aco", xform * Transform3D(Basis(), Vector3(0, 0, -0.155)), "Dobradiça", "dobradica")
	var leaf_b := _box(Vector3(0.4, 0.04, 0.25), "aco", xform * Transform3D(Basis(), Vector3(0, 0, 0.155)), "Dobradiça", "dobradica")
	_deco_cyl(leaf_a, 0.025, 0.42, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0, 0.155)), Color(0.4, 0.42, 0.45), 0.8)
	var j := _joint("dobradica", leaf_a, leaf_b, Vector3(0, 0, 0.155), Vector3.RIGHT)
	j.capture_rest()
	Build.add_joint(j)
	return [leaf_a, leaf_b]


static func _spawn_pin(xform: Transform3D) -> Array[Part]:
	var a := _box(Vector3(0.12, 0.12, 0.2), "aco", xform * Transform3D(Basis(), Vector3(-0.065, 0, 0)), "Dobradiça de pino", "pino")
	var b := _box(Vector3(0.12, 0.12, 0.2), "ferro", xform * Transform3D(Basis(), Vector3(0.065, 0, 0)), "Dobradiça de pino", "pino")
	_deco_cyl(a, 0.025, 0.3, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.065, 0, 0)), Color(0.75, 0.77, 0.8), 0.9)
	var j := _joint("pino", a, b, Vector3(0.065, 0, 0), Vector3.RIGHT)
	j.capture_rest()
	Build.add_joint(j)
	return [a, b]


static func _spawn_ball(xform: Transform3D) -> Array[Part]:
	var base := _box(Vector3(0.22, 0.08, 0.22), "carcaca", xform, "Junta esférica (base)", "esferica")
	var plate := _box(Vector3(0.22, 0.06, 0.22), "aco", xform * Transform3D(Basis(), Vector3(0, 0.24, 0)), "Junta esférica (placa)", "esferica")
	_deco_cyl(base, 0.065, 0.04, Transform3D(Basis(), Vector3(0, 0.06, 0)), Color(0.3, 0.3, 0.32), 0.7)
	_deco_sphere(base, 0.05, Vector3(0, 0.12, 0), Color(0.75, 0.77, 0.8))
	_deco_cyl(plate, 0.02, 0.09, Transform3D(Basis(), Vector3(0, -0.075, 0)), Color(0.75, 0.77, 0.8), 0.9)
	var j := _joint("esferica", base, plate, Vector3(0, 0.12, 0), Vector3.UP)
	j.max_angle = deg_to_rad(50.0)
	j.capture_rest()
	Build.add_joint(j)
	return [base, plate]


static func _spawn_wheel(xform: Transform3D, size: Vector3) -> Part:
	var r := clampf(size.x if size.x > 0.0 else 0.35, 0.15, 1.0)
	var w := clampf(size.y if size.y > 0.0 else 0.2, 0.08, 0.5)
	var wheel := _cyl(r, w, "borracha", xform, "Roda", "roda")
	_deco_cyl(wheel, r * 0.6, w + 0.008, Transform3D.IDENTITY, Color(0.62, 0.64, 0.68), 0.85)
	_deco_cyl(wheel, r * 0.18, w + 0.016, Transform3D.IDENTITY, Color(0.25, 0.26, 0.28), 0.6)
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
	Build.make_weld(base, back, xform * Vector3(0, 0.06, 0.25))
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


## Isolador (como os de cerca elétrica): base, "pescoço" onde o fio passa e a tampa.
static func _spawn_insulator(xform: Transform3D) -> Part:
	var p := _cyl(0.07, 0.16, "plastico", xform, "Isolador", "isolador")
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
				_deco_box(root, Vector3(0.1, 0.5, 0.1), Vector3(0, 0.055, 0), steel)
				_deco_box(root, Vector3(0.16, 0.04, 0.16), Vector3(0, 0.305, 0), Color(0.3, 0.32, 0.35))
			else:
				_deco_box(root, Vector3(0.26, 0.1, 0.26), Vector3(0, -0.3, 0), color)
				_deco_box(root, Vector3(0.24, 0.55, 0.24), Vector3(0, 0.025, 0), color)
				_deco_box(root, Vector3(0.14, 0.6, 0.14), Vector3(0, 0.055, 0), steel)
				_deco_box(root, Vector3(0.2, 0.04, 0.2), Vector3(0, 0.355, 0), Color(0.3, 0.32, 0.35))
		"dobradica":
			_deco_box(root, Vector3(0.4, 0.04, 0.25), Vector3(0, 0, -0.155), steel)
			_deco_box(root, Vector3(0.4, 0.04, 0.25), Vector3(0, 0, 0.155), steel)
			_deco_cyl(root, 0.025, 0.42, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), Color(0.4, 0.42, 0.45))
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
			_deco_cyl(root, r, w, Transform3D(tilt, Vector3.ZERO), Color(0.08, 0.08, 0.085), 0.0)
			_deco_cyl(root, r * 0.6, w + 0.01, Transform3D(tilt, Vector3.ZERO), steel, 0.85)
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
	return root

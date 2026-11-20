class_name Components
extends RefCounted
## Cria componentes mecânicos e controles (peças + juntas + aparência).
##
## Todos os componentes giram/deslizam no eixo Y local do ponto onde são criados:
##   motor/servo: carcaça embaixo, rotor/braço em cima.
##   pistão: corpo embaixo, haste sai para cima (curso de 0,5 m).

const INFO := {
	"motor": {"nome": "Motor", "preco": 40, "desc": "Gira sem parar. Solde a carcaça na estrutura e a roda no disco."},
	"servo": {"nome": "Servo", "preco": 35, "desc": "Gira até um ângulo e segura. Bom para direção."},
	"pistao": {"nome": "Pistão", "preco": 45, "desc": "Empurra e puxa em linha reta (curso de 0,5 m)."},
	"dobradica": {"nome": "Dobradiça", "preco": 10, "desc": "Junta que gira livre, sem motor."},
	"roda": {"nome": "Roda", "preco": 0, "desc": "Pneu de borracha. Solde no disco de um motor."},
	"assento": {"nome": "Assento", "preco": 15, "desc": "Sente (F) para controlar a máquina. Tab: modo edição."},
	"botao": {"nome": "Botão", "preco": 4, "desc": "Liga enquanto está apertado. Ligue com a Fiação."},
	"alavanca": {"nome": "Alavanca", "preco": 5, "desc": "Liga e desliga. Ligue com a Fiação."},
	"potenciometro": {"nome": "Alavanca variável", "preco": 8, "desc": "Valor de -1 a 1 na roda do mouse. Ligue com a Fiação."},
}


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
			return AABB(Vector3(-0.18, -0.15, -0.18), Vector3(0.36, 0.4, 0.36))
		"servo":
			return AABB(Vector3(-0.25, -0.15, -0.15), Vector3(0.5, 0.36, 0.3))
		"pistao":
			return AABB(Vector3(-0.12, -0.3, -0.12), Vector3(0.24, 0.9, 0.24))
		"dobradica":
			return AABB(Vector3(-0.2, -0.03, -0.26), Vector3(0.4, 0.06, 0.52))
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
			return AABB(Vector3(-0.1, -0.04, -0.2), Vector3(0.2, 0.2, 0.4))
	return AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)


## Cria o componente. Retorna as peças criadas (a primeira é a "base").
static func spawn(kind: String, xform: Transform3D, size := Vector3.ZERO) -> Array[Part]:
	match kind:
		"motor":
			return _spawn_rotary("motor", xform)
		"servo":
			return _spawn_rotary("servo", xform)
		"pistao":
			return _spawn_piston(xform)
		"dobradica":
			return _spawn_hinge(xform)
		"roda":
			return [_spawn_wheel(xform, size)]
		"assento":
			return _spawn_seat(xform)
		"botao", "alavanca", "potenciometro":
			return [_spawn_device(kind, xform)]
	return []


# --- Peças básicas -------------------------------------------------------------

static func _box(size: Vector3, mat: String, xform: Transform3D, label: String, kind: String) -> Part:
	var p := Build.spawn_box(size, mat, xform)
	p.cuttable = false
	p.label = label
	p.kind = kind
	return p


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


static func _light(parent: Node3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.022
	sm.height = 0.044
	mi.mesh = sm
	mi.position = pos
	parent.add_child(mi)
	return mi


# --- Componentes ---------------------------------------------------------------

static func _spawn_rotary(kind: String, xform: Transform3D) -> Array[Part]:
	var servo := kind == "servo"
	var body_size := Vector3(0.3, 0.3, 0.3) if servo else Vector3(0.36, 0.3, 0.36)
	var stator := _box(body_size, "carcaca_azul" if servo else "carcaca", xform,
		"Servo (carcaça)" if servo else "Motor (carcaça)", kind)
	var top := body_size.y * 0.5
	var rotor: Part
	if servo:
		rotor = _box(Vector3(0.5, 0.05, 0.12), "aco", xform * Transform3D(Basis(), Vector3(0, top + 0.029, 0)), "Servo (braço)", kind)
	else:
		rotor = _cyl(0.15, 0.06, "aco", xform * Transform3D(Basis(), Vector3(0, top + 0.034, 0)), "Motor (disco)", kind)
		_deco_box(rotor, Vector3(0.2, 0.012, 0.03), Vector3(0, 0.032, 0), Color(0.9, 0.2, 0.15))
	# Faixa escura na carcaça (mostra o "lado de cima")
	_deco_box(stator, Vector3(body_size.x + 0.004, 0.03, body_size.z + 0.004), Vector3(0, top - 0.03, 0), Color(0.1, 0.1, 0.11))
	var j := MechJoint.new()
	j.type = kind
	j.part_a = stator
	j.part_b = rotor
	j.pivot = Vector3(0, top, 0)
	j.axis = Vector3.UP
	if servo:
		j.speed = 4.0
		j.strength = 2500.0
		j.bind_pos = [{"key": KEY_A}]
		j.bind_neg = [{"key": KEY_D}]
	else:
		j.speed = 10.0
		j.strength = 1500.0
		j.bind_pos = [{"key": KEY_W}]
		j.bind_neg = [{"key": KEY_S}]
	j.capture_rest()
	Build.add_joint(j)
	return [stator, rotor]


static func _spawn_piston(xform: Transform3D) -> Array[Part]:
	var body := _box(Vector3(0.24, 0.6, 0.24), "carcaca", xform, "Pistão (corpo)", "pistao")
	# Haste longa: mesmo toda esticada (0,5 m) continua um pouco dentro do corpo.
	var rod := _box(Vector3(0.14, 0.85, 0.14), "aco", xform * Transform3D(Basis(), Vector3(0, 0.175, 0)), "Pistão (haste)", "pistao")
	_deco_box(rod, Vector3(0.2, 0.04, 0.2), Vector3(0, 0.405, 0), Color(0.3, 0.32, 0.35))
	var j := MechJoint.new()
	j.type = "pistao"
	j.part_a = body
	j.part_b = rod
	j.pivot = Vector3.ZERO
	j.axis = Vector3.UP
	j.speed = 1.0
	j.strength = 12000.0
	j.stroke = 0.5
	j.capture_rest()
	Build.add_joint(j)
	return [body, rod]


static func _spawn_hinge(xform: Transform3D) -> Array[Part]:
	var leaf_a := _box(Vector3(0.4, 0.04, 0.25), "aco", xform * Transform3D(Basis(), Vector3(0, 0, -0.13)), "Dobradiça", "dobradica")
	var leaf_b := _box(Vector3(0.4, 0.04, 0.25), "aco", xform * Transform3D(Basis(), Vector3(0, 0, 0.13)), "Dobradiça", "dobradica")
	_deco_cyl(leaf_a, 0.03, 0.42, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0, 0.13)), Color(0.4, 0.42, 0.45), 0.8)
	var j := MechJoint.new()
	j.type = "dobradica"
	j.part_a = leaf_a
	j.part_b = leaf_b
	j.pivot = Vector3(0, 0, 0.13)
	j.axis = Vector3.RIGHT
	j.capture_rest()
	Build.add_joint(j)
	return [leaf_a, leaf_b]


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
			var lbl := Label3D.new()
			lbl.font_size = 48
			lbl.pixel_size = 0.003
			lbl.outline_size = 10
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.position = Vector3(0, 0.16, 0)
			part.add_child(lbl)
			dev.setup_visuals(knob, _light(part, Vector3(0.07, 0.045, 0.17)), lbl)
	part.interact_kind = kind
	dev.part = part
	Build.add_device(dev)
	return part


# --- Aparência para a loja (sem física) ---------------------------------------

static func build_visual(kind: String, size := Vector3.ZERO) -> Node3D:
	var root := Node3D.new()
	var steel := Color(0.6, 0.62, 0.66)
	match kind:
		"motor":
			_deco_box(root, Vector3(0.36, 0.3, 0.36), Vector3.ZERO, Color(0.85, 0.6, 0.12))
			_deco_cyl(root, 0.15, 0.06, Transform3D(Basis(), Vector3(0, 0.184, 0)), steel, 0.85)
		"servo":
			_deco_box(root, Vector3(0.3, 0.3, 0.3), Vector3.ZERO, Color(0.15, 0.35, 0.7))
			_deco_box(root, Vector3(0.5, 0.05, 0.12), Vector3(0, 0.179, 0), steel)
		"pistao":
			_deco_box(root, Vector3(0.24, 0.6, 0.24), Vector3.ZERO, Color(0.85, 0.6, 0.12))
			_deco_box(root, Vector3(0.14, 0.85, 0.14), Vector3(0, 0.175, 0), steel)
			_deco_box(root, Vector3(0.2, 0.04, 0.2), Vector3(0, 0.58, 0), Color(0.3, 0.32, 0.35))
		"dobradica":
			_deco_box(root, Vector3(0.4, 0.04, 0.25), Vector3(0, 0, -0.13), steel)
			_deco_box(root, Vector3(0.4, 0.04, 0.25), Vector3(0, 0, 0.13), steel)
			_deco_cyl(root, 0.03, 0.42, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), Color(0.4, 0.42, 0.45))
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
	return root

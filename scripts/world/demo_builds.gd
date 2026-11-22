class_name DemoBuilds
extends RefCounted
## Construções prontas do mapa (exemplos para aprender).


## Carrinho com assento e 4 motores com rodas, direção tipo tanque:
## W/S anda, A/D vira (cada lado tem 2 teclas por direção).
## Fica de frente para -Z (para onde o assento olha). Retorna o assento.
static func build_car(origin: Vector3) -> Part:
	var chassis := Build.spawn_box(Vector3(1.6, 0.1, 2.4), "aco", Transform3D(Basis(), origin + Vector3(0, 0.6, 0)))
	var seat: Array[Part] = Components.spawn("assento", Transform3D(Basis(), origin + Vector3(0, 0.71, 0.35)))
	Build.make_weld(seat[0], chassis, origin + Vector3(0, 0.65, 0.35))
	Build.make_weld(seat[0], chassis, origin + Vector3(0.25, 0.65, 0.1))
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.9, 0.9]:
			var basis := Basis(Vector3.BACK, -side * PI * 0.5)   # eixo do motor para fora (±X)
			var motor_pos := origin + Vector3(side * 0.95, 0.6, z)
			var motor: Array[Part] = Components.spawn("motor", Transform3D(basis, motor_pos))
			Build.make_weld(motor[0], chassis, origin + Vector3(side * 0.8, 0.6, z))
			Build.make_weld(motor[0], chassis, origin + Vector3(side * 0.8, 0.6, z + 0.12))
			var wheel_pos := motor_pos + basis.y * 0.314
			var wheel: Part = Components.spawn("roda", Transform3D(basis, wheel_pos), Vector3(0.4, 0.2, 0))[0]
			Build.make_weld(wheel, motor[1], motor_pos + basis.y * 0.214)
			var j: MechJoint = motor[0].mech
			j.invert = side > 0.0
			if side < 0.0:   # lado esquerdo: + W ou D, − S ou A
				j.bind_pos = [{"key": KEY_W}, {"key": KEY_D}]
				j.bind_neg = [{"key": KEY_S}, {"key": KEY_A}]
			else:            # lado direito: + W ou A, − S ou D
				j.bind_pos = [{"key": KEY_W}, {"key": KEY_A}]
				j.bind_neg = [{"key": KEY_S}, {"key": KEY_D}]
	return seat[0]


## Carro com trem de força (Marco 4D): tanque, motor 4 em linha, embreagem automática,
## câmbio automático e 4 cubos de roda, esterço de tanque. Assento: W acelera, S dá ré,
## A/D viram, Espaço freia. Fica de frente para -Z. Cubos da direita com o giro invertido
## (o eixo deles aponta para o outro lado). Retorna {"seat", "engine", "clutch", "gearbox",
## "tank", "hubs", "chassis"}. `clutch_kind` "" = sem embreagem.
static func build_engine_car(origin: Vector3, engine_kind := "motor_4l", gearbox_kind := "cambio_auto", tank_steer := true, clutch_kind := "embreagem_auto") -> Dictionary:
	var h := 0.42                                         # altura do eixo das rodas
	var chassis := Build.spawn_box(Vector3(1.6, 0.1, 2.4), "aco", Transform3D(Basis(), origin + Vector3(0, h, 0)))
	var top := h + 0.05
	var seat: Array[Part] = Components.spawn("assento", Transform3D(Basis(), origin + Vector3(0, top + 0.06, 0.35)))
	Build.make_weld(seat[0], chassis, origin + Vector3(0, top, 0.35))
	Build.make_weld(seat[0], chassis, origin + Vector3(0.25, top, 0.1))
	var hubs: Array = []
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.9, 0.9]:
			var basis := Basis(Vector3.BACK, -side * PI * 0.5)    # eixo do cubo para fora (±X)
			var hub_pos := origin + Vector3(side * 0.86, h, z)
			var hub: Array[Part] = Components.spawn("cubo", Transform3D(basis, hub_pos))
			Build.make_weld(hub[0], chassis, origin + Vector3(side * 0.8, h, z))
			Build.make_weld(hub[0], chassis, origin + Vector3(side * 0.8, h, z + 0.06))
			var wheel: Part = Components.spawn("roda", Transform3D(basis, hub_pos + basis.y * 0.214), Vector3(0.4, 0.2, 0))[0]
			Build.make_weld(wheel, hub[1], hub_pos + basis.y * 0.114)
			var hj: MechJoint = hub[0].mech
			hj.invert = side > 0.0          # eixo da direita aponta para +X: gira ao contrário
			hj.hub_side = -1 if side < 0.0 else 1
			hubs.append(hj)
	var es: Vector3 = Components.DRIVE_SIZES[engine_kind]
	var engine: Part = Components.spawn(engine_kind, Transform3D(Basis(), origin + Vector3(0, top + es.y * 0.5, -0.75)))[0]
	Build.make_weld(engine, chassis, origin + Vector3(0, top, -0.75))
	Build.make_weld(engine, chassis, origin + Vector3(0.1, top, -0.65))
	var gs: Vector3 = Components.DRIVE_SIZES[gearbox_kind]
	var gearbox: Part = Components.spawn(gearbox_kind, Transform3D(Basis(), origin + Vector3(0, top + gs.y * 0.5, -0.15)))[0]
	Build.make_weld(gearbox, chassis, origin + Vector3(0, top, -0.15))
	var cn: DriveNode = null
	if clutch_kind != "":
		var cl_s: Vector3 = Components.DRIVE_SIZES[clutch_kind]
		var clutch: Part = Components.spawn(clutch_kind, Transform3D(Basis(), origin + Vector3(0, top + cl_s.y * 0.5, -0.42)))[0]
		Build.make_weld(clutch, chassis, origin + Vector3(0, top, -0.42))
		cn = clutch.node as DriveNode
	var tank: Part = Components.spawn("tanque_gasolina", Transform3D(Basis(), origin + Vector3(0, top + 0.2, 0.95)))[0]
	Build.make_weld(tank, chassis, origin + Vector3(0, top, 0.95))
	var en := engine.node as DriveNode
	var gn := gearbox.node as DriveNode
	var tn := tank.node as DriveNode
	gn.tank_steer = tank_steer
	Drive.link(tn, en)
	if cn:
		Drive.link(en, cn)
		Drive.link(cn, gn)
	else:
		Drive.link(en, gn)
	for j in hubs:
		Drive.link(gn, j)
	var sn: SignalNode = seat[0].node
	Signals.connect_ports(sn, "W", en, "Acelerador")
	Signals.connect_ports(sn, "S", en, "Acelerador")
	Signals.connect_ports(sn, "S", gn, "Ré")
	Signals.connect_ports(sn, "Espaço", gn, "Freio")
	Signals.connect_ports(sn, "A", gn, "Esq")
	Signals.connect_ports(sn, "D", gn, "Dir")
	return {"seat": seat[0], "engine": en, "clutch": cn, "gearbox": gn, "tank": tn, "hubs": hubs, "chassis": chassis}

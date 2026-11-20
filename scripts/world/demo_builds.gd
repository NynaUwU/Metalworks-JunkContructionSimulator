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

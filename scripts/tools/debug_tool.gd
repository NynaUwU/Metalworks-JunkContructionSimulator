class_name DebugTool
extends GameTool
## Depurador: mire numa peça com sinais para ver, ao vivo, todas as entradas e saídas.
## Botão direito: nome e ajustes da peça.


func _init(p_player: Player) -> void:
	super(p_player)
	tool_name = "Depurador"
	key_hint = "5"


func _build_viewmodel() -> void:
	var body := make_box(Vector3(0.12, 0.2, 0.05), Color(0.18, 0.2, 0.24), 0.3, 0.5)
	viewmodel.add_child(body)
	var screen := make_box(Vector3(0.1, 0.1, 0.01), Color(0.1, 0.5, 0.35), 0.0, 0.2)
	screen.position = Vector3(0, 0.03, -0.028)
	screen.material_override = glow_material(Color(0.2, 0.9, 0.55), 1.2)
	viewmodel.add_child(screen)
	var probe := make_cylinder(0.006, 0.12, Color(0.85, 0.2, 0.15), 0.6, 0.4)
	probe.rotation.x = deg_to_rad(90)
	probe.position = Vector3(0, -0.06, -0.08)
	viewmodel.add_child(probe)
	muzzle.position = Vector3(0, -0.06, -0.15)


func aimed_node() -> SignalNode:
	return Signals.node_of(player.aim_part())


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("secondary"):
		var n := aimed_node()
		if n is MechJoint:
			player.config_requested.emit(n)
		elif n:
			player.node_config_requested.emit(n)
		return true
	return event.is_action_pressed("primary")


func hint_text() -> String:
	return "Mire numa peça com sinais para ver os valores   ·   Botão direito: nome e ajustes"


## Texto do painel do Depurador (vazio se não estiver mirando num nó).
func panel_text() -> String:
	var n := aimed_node()
	if n == null:
		return ""
	var lines: Array[String] = []
	lines.append(n.title() + ("" if n.node_name == "" else "  (%s)" % n.kind_label()))
	var ins := n.inputs()
	if not ins.is_empty():
		lines.append("ENTRADAS")
		for p: Array in ins:
			var nw := Signals.wires_into(n, p[0]).size()
			lines.append("  %s = %s   [%s%s]" % [p[0], SignalNode.format(Signals.input(n, p[0])), SignalNode.TYPE_NAMES[p[1]],
				"" if nw == 0 else " · %d fio%s" % [nw, "" if nw == 1 else "s"]])
	var outs := n.outputs()
	if not outs.is_empty():
		lines.append("SAÍDAS")
		for p: Array in outs:
			var nw := Signals.wires_from(n, p[0]).size()
			lines.append("  %s = %s   [%s%s]" % [p[0], SignalNode.format(n.out.get(p[0], SignalNode.zero(p[1]))), SignalNode.TYPE_NAMES[p[1]],
				"" if nw == 0 else " · %d fio%s" % [nw, "" if nw == 1 else "s"]])
	if ins.is_empty() and outs.is_empty():
		lines.append("(sem entradas nem saídas)")
	return "\n".join(lines)

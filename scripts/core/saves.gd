extends Node
## Autoload "Saves": salvar e carregar o mundo inteiro e construções individuais.
##
## Formato (JSON, com versão):
##   parts      peças comuns (forma por planos, material, posição) e peças de componentes
##              (só o componente de origem e a posição; a forma vem de Components.spawn)
##   groups     componentes: tipo, medidas, onde nasceram, quais peças ainda existem,
##              ajustes da junta (motor, pistão...) e do controle (alavanca...)
##   welds      soldas (a ancoragem no chão é uma solda sem a segunda peça)
##   bodies     estado das montagens: congelada, velocidades
##   links      fios: controle → componente, passando pelos isoladores
## Mundo: também pontos e jogador. Construção: posições relativas a um ponto de origem
## (centro da base), para colocar em outro lugar e girar.

signal changed   ## a lista de saves mudou

const FORMAT := "junk-construction-simulator"
const VERSION := 2
const DIR_WORLDS := "user://saves/mundos"
const DIR_BUILDS := "user://saves/construcoes"
const AUTOSAVE_INTERVAL := 300.0
const AUTOSAVE_KEEP := 3
const AUTOSAVE_PREFIX := "_auto"
const THUMB_SIZE := Vector2i(320, 180)

## Colocar uma construção salva custa os pontos das peças (preço de loja).
## Por enquanto é grátis, para testes: mude para false para cobrar.
var builds_free := true

var world: Node = null            ## mundo atual (registra-se ao iniciar)
var autosave_enabled := false
var _autosave_time := 0.0
var _frame: Image = null          ## última imagem da tela (miniatura)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not autosave_enabled or world == null or not is_instance_valid(world) or get_tree().paused:
		return
	_autosave_time += delta
	if _autosave_time >= AUTOSAVE_INTERVAL:
		_autosave_time = 0.0
		capture_frame()
		autosave()


# =============================================================================
# Arquivos
# =============================================================================

## Guarda a imagem atual da tela para usar como miniatura (chamar antes de abrir menus).
func capture_frame() -> void:
	var vp := get_viewport()
	if vp == null or DisplayServer.get_name() == "headless":
		return
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.resize(THUMB_SIZE.x, THUMB_SIZE.y, Image.INTERPOLATE_BILINEAR)
	_frame = img


static func slug(text: String) -> String:
	var out := ""
	for ch in text.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif ch in "áàâãä":
			out += "a"
		elif ch in "éèêë":
			out += "e"
		elif ch in "íìîï":
			out += "i"
		elif ch in "óòôõö":
			out += "o"
		elif ch in "úùûü":
			out += "u"
		elif ch == "ç":
			out += "c"
		elif not out.ends_with("_"):
			out += "_"
	out = out.trim_prefix("_").trim_suffix("_")
	return out if out != "" else "sem_nome"


func _write(dir: String, file_name: String, data: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(file_name + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Não deu para salvar em %s" % path)
		return ""
	f.store_string(JSON.stringify(data))
	f.close()
	var thumb := dir.path_join(file_name + ".png")
	if _frame != null:
		_frame.save_png(thumb)
	elif FileAccess.file_exists(thumb):
		DirAccess.remove_absolute(thumb)
	changed.emit()
	return path


static func read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary or (parsed as Dictionary).get("format", "") != FORMAT:
		return {}
	return _migrate(parsed)


## Atualiza saves de versões antigas do formato.
static func _migrate(data: Dictionary) -> Dictionary:
	# Versão 1: fios só de controle → componente ("links").
	if int(data.get("version", 1)) < 2:
		var wires: Array = []
		for ld: Dictionary in data.get("links", []):
			wires.append({"f": ld["d"], "fp": "Saída", "t": ld["j"], "tp": "Sinal", "via": ld.get("via", [])})
		data["wires"] = wires
		data.erase("links")
		data["version"] = 2
	# Na 0.7.2 o padrão era "lados sem colisão" (o jogador não escolheu): volta a colidir.
	if str(data.get("game", "")) == "0.7.2":
		for gd: Dictionary in data.get("groups", []):
			if gd.has("j"):
				(gd["j"] as Dictionary)["collide"] = true
	return data


## Lista os saves de uma pasta, mais recentes primeiro.
## Cada item: {path, file, name, time, thumb, parts, price (construções), auto}.
static func list(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var path := dir.path_join(f)
		var data := read(path)
		if data.is_empty():
			continue
		var base := f.get_basename()
		var thumb := dir.path_join(base + ".png")
		out.append({
			"path": path, "file": base, "name": data.get("name", base),
			"time": int(data.get("time", 0)), "parts": (data.get("parts", []) as Array).size(),
			"thumb": thumb if FileAccess.file_exists(thumb) else "",
			"price": build_price(data), "auto": base.begins_with(AUTOSAVE_PREFIX),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] > b["time"])
	return out


static func delete(path: String) -> void:
	DirAccess.remove_absolute(path)
	var thumb := path.get_basename() + ".png"
	if FileAccess.file_exists(thumb):
		DirAccess.remove_absolute(thumb)


static func date_text(unix: int) -> String:
	var t := Time.get_datetime_dict_from_unix_time(unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	return "%02d/%02d/%04d %02d:%02d" % [t["day"], t["month"], t["year"], t["hour"], t["minute"]]


static func open_folder() -> void:
	DirAccess.make_dir_recursive_absolute("user://saves")
	OS.shell_open(ProjectSettings.globalize_path("user://saves"))


# =============================================================================
# Mundo inteiro
# =============================================================================

func save_world(save_name: String, file_name := "") -> String:
	var data := serialize(world_assemblies(), Transform3D.IDENTITY)
	data["type"] = "world"
	data["name"] = save_name
	data["points"] = Economy.precise_points()
	var player: Player = _player()
	if player:
		data["player"] = {"pos": _v(player.global_position), "yaw": player.yaw, "pitch": player.pitch,
			"tool": player.current_tool}
	return _write(DIR_WORLDS, file_name if file_name != "" else slug(save_name), data)


func autosave() -> void:
	if world == null:
		return
	# Gira os automáticos: _auto1 (mais novo) … _auto3 (mais velho).
	for i in range(AUTOSAVE_KEEP - 1, 0, -1):
		for ext in [".json", ".png"]:
			var from := DIR_WORLDS.path_join(AUTOSAVE_PREFIX + str(i) + ext)
			if FileAccess.file_exists(from):
				DirAccess.rename_absolute(from, DIR_WORLDS.path_join(AUTOSAVE_PREFIX + str(i + 1) + ext))
	save_world("Salvamento automático", AUTOSAVE_PREFIX + "1")


## Apaga tudo o que é dinâmico (peças, soldas, juntas) e carrega o save.
func load_world(path: String) -> bool:
	var data := read(path)
	if data.is_empty() or data.get("type", "") != "world":
		return false
	clear_world()
	restore(data, Transform3D.IDENTITY)
	Economy.reset(float(data.get("points", 0.0)))
	var player: Player = _player()
	if player and data.has("player"):
		var pd: Dictionary = data["player"]
		player.teleport(_to_v(pd["pos"]))
		player.yaw = float(pd.get("yaw", 0.0))
		player.pitch = float(pd.get("pitch", 0.0))
		player.select_tool(int(pd.get("tool", 0)))
	_autosave_time = 0.0
	return true


## Remove todas as peças, soldas e juntas do mundo (o mapa fixo fica).
func clear_world() -> void:
	var player: Player = _player()
	if player:
		player.reset_for_load()
	for j in Build.joints:
		j.destroy()
	Build.joints.clear()
	Build.devices.clear()
	Signals.reset()
	Build.welds.clear()
	Build.active_seat = null
	for c in Build.world_root.get_children():
		if c is Joint3D:
			Build.world_root.remove_child(c)
			c.queue_free()
	for asm in world_assemblies():
		asm.get_parent().remove_child(asm)
		asm.queue_free()


func world_assemblies() -> Array:
	var out: Array = []
	if Build.world_root == null:
		return out
	for c in Build.world_root.get_children():
		if c is Assembly and not c.is_queued_for_deletion() and not (c as Assembly).get_parts().is_empty():
			out.append(c)
	return out


func _player() -> Player:
	if world and is_instance_valid(world) and "player" in world:
		return world.get("player")
	return null


# =============================================================================
# Construções individuais
# =============================================================================

## Tudo o que está ligado à montagem de `part`: soldas (mesma montagem), juntas,
## fios (controles, isoladores e os componentes que eles comandam).
static func machine_of(part: Part) -> Array:
	var found := {part.assembly(): true}
	var changed_any := true
	while changed_any:
		changed_any = false
		var groups_to_add: Array = []
		for j in Build.joints:
			if not j.is_valid():
				continue
			var a := j.part_a.assembly()
			var b := j.part_b.assembly()
			if found.has(a) or found.has(b):
				groups_to_add.append([a, b])
		# Fios: os dois lados e os isoladores do caminho.
		for w in Signals.wires:
			if not w.is_valid():
				continue
			var fa: Assembly = w.from_node.signal_part().assembly()
			var ta: Assembly = w.to_node.signal_part().assembly()
			if found.has(fa) or found.has(ta):
				var add: Array = [fa, ta]
				for ins in w.via:
					if is_instance_valid(ins):
						add.append((ins as Part).assembly())
				groups_to_add.append(add)
		for add: Array in groups_to_add:
			for asm in add:
				if asm and not found.has(asm):
					found[asm] = true
					changed_any = true
	return found.keys()


## Ponto de origem de uma construção: centro da base (alinhado ao mundo).
static func machine_origin(assemblies: Array) -> Transform3D:
	var box := AABB()
	var first := true
	for asm: Assembly in assemblies:
		for p in asm.get_parts():
			var b := p.global_transform * p.bounds
			box = b if first else box.merge(b)
			first = false
	var c := box.get_center()
	return Transform3D(Basis(), Vector3(c.x, box.position.y, c.z))


func save_build(part: Part, save_name: String) -> String:
	var asms := machine_of(part)
	var data := serialize(asms, machine_origin(asms))
	data["type"] = "build"
	data["name"] = save_name
	return _write(DIR_BUILDS, slug(save_name), data)


## Preço de uma construção salva: componentes pelo preço da loja; peças comuns pelo
## peso e metal, como as chapas da loja.
static func build_price(data: Dictionary) -> int:
	var total := 0.0
	for pd: Dictionary in data.get("parts", []):
		if pd.has("g"):
			continue
		total += Economy.recycle_value(pd.get("m", "aco"), float(pd.get("vol", 0.0)) * MetalMaterials.density(pd.get("m", "aco"))) * Catalog.PRICE_FACTOR
	var count := 0
	for gd: Dictionary in data.get("groups", []):
		total += Components.price(gd["kind"], _to_v(gd.get("size", [0, 0, 0])))
		count += 1
	return ceili(total) if total > 0.0 else 0


## Coloca uma construção salva no mundo (origem = centro da base). Cobra os pontos,
## a não ser no modo grátis. Retorna as peças criadas ([] se faltar pontos).
func place_build(data: Dictionary, origin: Transform3D) -> Array:
	var price := build_price(data)
	if not builds_free and not Economy.spend(price):
		return []
	return restore(data, origin)


# =============================================================================
# Serializar
# =============================================================================

## Converte montagens em dados. `origin`: as posições ficam relativas a ele.
static func serialize(assemblies: Array, origin: Transform3D) -> Dictionary:
	var inv := origin.affine_inverse()
	var ids := {}
	var parts: Array[Part] = []
	for asm: Assembly in assemblies:
		for p in asm.get_parts():
			ids[p] = parts.size()
			parts.append(p)

	# Componentes: agrupa as peças que vieram do mesmo spawn.
	var group_index := {}   # comp_group -> índice em groups
	var groups: Array = []
	var group_parts: Array = []
	for p in parts:
		if p.comp_kind == "" or p.comp_group == 0:
			continue
		if not group_index.has(p.comp_group):
			group_index[p.comp_group] = groups.size()
			groups.append({"kind": p.comp_kind, "size": _v(p.comp_size),
				"o": _xf(inv * p.global_transform * p.comp_offset.affine_inverse()), "have": []})
			group_parts.append([])
		var gi: int = group_index[p.comp_group]
		(groups[gi]["have"] as Array).append(p.comp_index)
		(group_parts[gi] as Array).append(p)

	var part_list: Array = []
	for p in parts:
		var pd := {"id": ids[p], "x": _xf(inv * p.global_transform)}
		if not p.marks.is_empty():
			pd["mk"] = p.marks.map(func(m: Array) -> Array: return _v(m[0]) + _v(m[1]))
		if group_index.has(p.comp_group) and p.comp_kind != "":
			pd["g"] = group_index[p.comp_group]
			pd["gi"] = p.comp_index
		else:
			pd["m"] = p.material_id
			pd["vol"] = snappedf(p.volume, 1e-6)
			if not p.planes.is_empty():
				var pl: Array = []
				for plane in p.planes:
					pl.append([_r(plane.normal.x), _r(plane.normal.y), _r(plane.normal.z), _r(plane.d)])
				pd["pl"] = pl
			elif p.shape is CylinderShape3D:
				pd["cyl"] = [(p.shape as CylinderShape3D).radius, (p.shape as CylinderShape3D).height]
			if p.kind != "metal":
				pd["k"] = p.kind
			if p.label != "":
				pd["l"] = p.label
			if not p.cuttable:
				pd["cut"] = false
		part_list.append(pd)

	# Estado das juntas e controles, por componente.
	for gi in groups.size():
		for p: Part in group_parts[gi]:
			if p.comp_index != 0:
				continue
			if p.mech and p.mech.part_a == p and p.mech.is_valid():
				groups[gi]["j"] = _joint_state(p.mech, ids)
			if p.device:
				groups[gi]["d"] = {"v": p.device.value if p.device.kind != "botao" else 0.0,
					"po": p.device.positive_only}
			var sn := Signals.node_of(p)
			if sn and sn.signal_part() == p:
				var st := sn.save_state()
				if sn.node_name != "":
					st["name"] = sn.node_name
				if not st.is_empty():
					groups[gi]["sn"] = st

	var welds: Array = []
	for w in Build.welds:
		if w.internal or not ids.has(w.part_a) or (w.part_b != null and not ids.has(w.part_b)):
			continue
		welds.append({"a": ids[w.part_a], "b": ids[w.part_b] if w.part_b else -1, "p": _v(w.local_pos)})

	var bodies: Array = []
	for asm: Assembly in assemblies:
		var ap := asm.get_parts()
		if ap.is_empty():
			continue
		var bd := {"p": ids[ap[0]]}
		if asm.frozen:
			bd["fz"] = true
		if origin == Transform3D.IDENTITY and not asm.freeze and not asm.sleeping:
			bd["lv"] = _v(asm.linear_velocity)
			bd["av"] = _v(asm.angular_velocity)
		if bd.size() > 1:
			bodies.append(bd)

	var wires: Array = []
	for w in Signals.wires:
		if not w.is_valid():
			continue
		var fp: Part = w.from_node.signal_part()
		var tp: Part = w.to_node.signal_part()
		if not ids.has(fp) or not ids.has(tp) or not group_index.has(fp.comp_group) or not group_index.has(tp.comp_group):
			continue
		var via: Array = []
		for ins in w.via:
			if is_instance_valid(ins) and ids.has(ins):
				via.append(ids[ins])
		wires.append({"f": group_index[fp.comp_group], "fp": w.from_port,
			"t": group_index[tp.comp_group], "tp": w.to_port, "via": via})

	return {
		"format": FORMAT, "version": VERSION,
		"game": str(ProjectSettings.get_setting("application/config/version", "")),
		"time": int(Time.get_unix_time_from_system()),
		"parts": part_list, "groups": groups, "welds": welds, "bodies": bodies, "wires": wires,
	}


static func _joint_state(j: MechJoint, ids: Dictionary) -> Dictionary:
	var s := {
		"rest": _xf(j.rest), "speed": j.speed, "strength": j.strength, "max_angle": j.max_angle,
		"stroke": j.stroke, "invert": j.invert, "toggle": j.toggle, "hold": j.hold,
		"free_idle": j.free_idle, "lock_idle": j.lock_idle, "manual": j.manual, "collide": j.collide,
		"rope_len": j.rope_len, "max_rope": j.max_rope, "latch": j._latched,
		"pos": _binds(j.bind_pos), "neg": _binds(j.bind_neg),
	}
	if j.lock_target and ids.has(j.lock_target):
		s["lock"] = ids[j.lock_target]
	return s


static func _binds(list: Array) -> Array:
	var out: Array = []
	for b: Dictionary in list:
		out.append(b.duplicate())
	return out


# =============================================================================
# Recriar
# =============================================================================

## Cria as peças, componentes, soldas, juntas e fios de `data`, com as posições
## transformadas por `origin`. Retorna todas as peças criadas.
func restore(data: Dictionary, origin: Transform3D) -> Array:
	var by_id := {}
	var created: Array = []
	var groups: Array = data.get("groups", [])
	var group_parts: Array = []   # índice do grupo -> Array de peças (pelo comp_index)
	var to_delete: Array[Part] = []

	# 1) Componentes: nascem inteiros onde nasceram originalmente; peças que já não
	#    existiam são removidas depois.
	for gd: Dictionary in groups:
		var spawned := Components.spawn(gd["kind"], origin * _to_xf(gd["o"]), _to_v(gd.get("size", [0, 0, 0])))
		group_parts.append(spawned)
		var have: Array = gd.get("have", [])
		for i in spawned.size():
			if not have.has(float(i)) and not have.has(i):
				to_delete.append(spawned[i])

	# 2) Peças: comuns são criadas; as de componente vão para a pose salva.
	for pd: Dictionary in data.get("parts", []):
		var xf := origin * _to_xf(pd["x"])
		var p: Part = null
		if pd.has("g"):
			var arr: Array = group_parts[int(pd["g"])]
			var gi := int(pd.get("gi", 0))
			if gi < arr.size():
				p = arr[gi]
				_place(p, xf)
		elif pd.has("pl"):
			var planes: Array[Plane] = []
			for a: Array in pd["pl"]:
				planes.append(Plane(Vector3(a[0], a[1], a[2]), a[3]))
			p = Build.spawn_planes(planes, pd.get("m", "aco"), xf)
		elif pd.has("cyl"):
			p = Part.new()
			p.setup_cylinder(pd["cyl"][0], pd["cyl"][1], pd.get("m", "aco"))
			Build.spawn_part(p, xf)
		if p == null:
			continue
		if not pd.has("g"):
			p.kind = pd.get("k", "metal")
			p.label = pd.get("l", "")
			p.cuttable = pd.get("cut", p.cuttable)
		for m: Array in pd.get("mk", []):
			p.add_mark(Vector3(m[0], m[1], m[2]), Vector3(m[3], m[4], m[5]))
		by_id[int(pd["id"])] = p
		created.append(p)

	for p in to_delete:
		if is_instance_valid(p) and p.is_inside_tree():
			Build.delete_part(p)

	# 3) Soldas (juntam as montagens de novo; solda sem segunda peça = ancorada).
	for wd: Dictionary in data.get("welds", []):
		var a: Part = by_id.get(int(wd["a"]))
		var b: Part = by_id.get(int(wd["b"])) if int(wd["b"]) >= 0 else null
		if a == null or (int(wd["b"]) >= 0 and b == null):
			continue
		Build.make_weld(a, b, a.global_transform * _to_v(wd["p"]), false)

	# 4) Montagens: congeladas e velocidades.
	for bd: Dictionary in data.get("bodies", []):
		var p: Part = by_id.get(int(bd["p"]))
		if p == null:
			continue
		var asm := p.assembly()
		if bd.get("fz", false):
			asm.set_frozen(true)
		elif not asm.anchored and bd.has("lv"):
			asm.linear_velocity = origin.basis * _to_v(bd["lv"])
			asm.angular_velocity = origin.basis * _to_v(bd.get("av", [0, 0, 0]))

	# 5) Juntas e controles: ajustes salvos; a junta física é refeita na pose atual.
	for gi in groups.size():
		var gd: Dictionary = groups[gi]
		var arr: Array = group_parts[gi]
		if arr.is_empty() or not is_instance_valid(arr[0]):
			continue
		var base: Part = arr[0]
		if gd.has("j") and base.mech and base.mech.is_valid():
			_apply_joint_state(base.mech, gd["j"], by_id)
		if gd.has("d") and base.device:
			base.device.positive_only = bool(gd["d"].get("po", false))
			base.device.value = clampf(float(gd["d"].get("v", 0.0)), base.device.min_value(), 1.0)
			base.device.update_visual()

	# 6) Nós de sinal (nome, modo do chip, valor da constante...) e fios.
	for gi in groups.size():
		var gd: Dictionary = groups[gi]
		var arr: Array = group_parts[gi]
		if not gd.has("sn") or arr.is_empty() or not is_instance_valid(arr[0]):
			continue
		var sn := Signals.node_of(arr[0])
		if sn:
			sn.node_name = str(gd["sn"].get("name", ""))
			sn.load_state(gd["sn"])
	for wd: Dictionary in data.get("wires", []):
		var farr: Array = group_parts[int(wd["f"])]
		var tarr: Array = group_parts[int(wd["t"])]
		if farr.is_empty() or tarr.is_empty() or not is_instance_valid(farr[0]) or not is_instance_valid(tarr[0]):
			continue
		var from := Signals.node_of(farr[0])
		var to := Signals.node_of(tarr[0])
		if from == null or to == null:
			continue
		var via: Array = []
		for id in wd.get("via", []):
			if by_id.has(int(id)):
				via.append(by_id[int(id)])
		Signals.connect_ports(from, str(wd["fp"]), to, str(wd["tp"]), via)

	return created


## Leva a peça para `xf` movendo a montagem inteira dela.
static func _place(p: Part, xf: Transform3D) -> void:
	var asm := p.assembly()
	asm.global_transform = xf * p.transform.affine_inverse()
	asm.linear_velocity = Vector3.ZERO
	asm.angular_velocity = Vector3.ZERO
	asm.reset_physics_interpolation()


func _apply_joint_state(j: MechJoint, s: Dictionary, by_id: Dictionary) -> void:
	j.rest = _to_xf(s["rest"])
	j.speed = float(s.get("speed", j.speed))
	j.strength = float(s.get("strength", j.strength))
	j.max_angle = float(s.get("max_angle", j.max_angle))
	j.stroke = float(s.get("stroke", j.stroke))
	j.invert = bool(s.get("invert", false))
	j.toggle = bool(s.get("toggle", false))
	j.hold = bool(s.get("hold", false))
	j.free_idle = bool(s.get("free_idle", false))
	j.collide = bool(s.get("collide", true))
	j.lock_idle = bool(s.get("lock_idle", false))
	j.manual = bool(s.get("manual", false))
	j.rope_len = float(s.get("rope_len", j.rope_len))
	j.max_rope = float(s.get("max_rope", j.max_rope))
	j._latched = float(s.get("latch", 0.0))
	j.bind_pos = _to_binds(s.get("pos", []))
	j.bind_neg = _to_binds(s.get("neg", []))
	j.rebuild(Build.world_root)
	j.apply_strength()
	if s.has("lock") and by_id.has(int(s["lock"])):
		j._make_lock(by_id[int(s["lock"])])
	if j.type in MechJoint.SINGLE:
		j.update(0.0)   # acerta luz/chama


static func _to_binds(list: Array) -> Array:
	var out: Array = []
	for b: Dictionary in list:
		if b.has("key"):
			out.append({"key": int(b["key"])})
		elif b.has("mouse"):
			out.append({"mouse": int(b["mouse"])})
	return out


# =============================================================================
# Conversões (JSON só tem números, textos, listas e dicionários)
# =============================================================================

static func _r(x: float) -> float:
	return snappedf(x, 1e-5)


static func _v(v: Vector3) -> Array:
	return [_r(v.x), _r(v.y), _r(v.z)]


static func _to_v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _xf(t: Transform3D) -> Array:
	var b := t.basis
	return [_r(b.x.x), _r(b.x.y), _r(b.x.z), _r(b.y.x), _r(b.y.y), _r(b.y.z),
		_r(b.z.x), _r(b.z.y), _r(b.z.z), _r(t.origin.x), _r(t.origin.y), _r(t.origin.z)]


static func _to_xf(a: Array) -> Transform3D:
	var b := Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8]))
	return Transform3D(b.orthonormalized(), Vector3(a[9], a[10], a[11]))

extends Node3D
## Monta o mundo: céu, luz, terreno, pátio, estruturas e pilhas de sucata.

const MAP_HALF := 256.0
const GRID_STEP := 2.0
const FLAT_RADIUS := 70.0
const PAD_SIZE := 90.0

## Formatos de sucata espalhados pelo mapa: tamanho, peso no sorteio, quantos por pilha.
const SCRAP := [
	{"size": Vector3(2.0, 0.1, 2.0), "w": 3, "stack": [2, 4]},   # chapa grande
	{"size": Vector3(1.0, 0.1, 1.0), "w": 4, "stack": [3, 6]},   # chapa
	{"size": Vector3(3.0, 0.1, 1.0), "w": 2, "stack": [2, 4]},   # chapa comprida
	{"size": Vector3(0.2, 0.2, 3.0), "w": 3, "stack": [2, 4]},   # viga longa
	{"size": Vector3(0.2, 0.2, 2.0), "w": 3, "stack": [2, 4]},   # viga
	{"size": Vector3(0.1, 0.1, 2.0), "w": 2, "stack": [3, 5]},   # barra
	{"size": Vector3(0.5, 0.5, 0.5), "w": 2, "stack": [1, 3]},   # bloco
	{"size": Vector3(1.0, 1.0, 1.0), "w": 1, "stack": [1, 1]},   # bloco grande
	{"size": Vector3(1.0, 0.5, 0.5), "w": 1, "stack": [1, 2]},   # tarugo
]

var player: Player
var hud: Hud
var recycler: Recycler
var demo_seat: Part
var shop: ShopStation
var environment: Environment
var sun: DirectionalLight3D
var _weld_dark := 0.0
var _base_env := {}
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Build.reset(self)
	Economy.reset()
	_rng.seed = 20141
	_noise.seed = 1337
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.006
	_noise.fractal_octaves = 4

	_build_environment()
	_build_terrain()
	_build_pad()
	_build_props()
	_build_stations()
	_spawn_scrap()

	player = Player.new()
	add_child(player)
	hud = Hud.new()
	add_child(hud)
	hud.setup(player)
	player.interact_requested.connect(_on_interact)
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Modo de desenvolvimento: tour automático com screenshots (-- --tour=pasta).
	var args := OS.get_cmdline_user_args()
	var quick := ""
	for arg in args:
		if arg.begins_with("--quick="):
			quick = arg.trim_prefix("--quick=")
	for arg in args:
		if arg.begins_with("--tour="):
			var script_path := "res://tests/shot_quick.gd" if quick != "" else "res://tests/screenshot_tour.gd"
			var tour: Node = load(script_path).new()
			tour.set("out_dir", arg.trim_prefix("--tour="))
			if quick != "":
				tour.set("scene", quick)
			add_child(tour)


# ---------------------------------------------------------------------------
# Ambiente
# ---------------------------------------------------------------------------

func _on_interact(target: Node) -> void:
	if target.get_meta("interact") == "shop":
		hud.open_shop(shop)


## Centro de reciclagem: reciclador + loja + plataforma de entrega.
func _build_stations() -> void:
	recycler = Recycler.new()
	recycler.name = "Recycler"
	add_child(recycler)
	recycler.position = Vector3(17, 0, -27)
	shop = ShopStation.new()
	shop.name = "Shop"
	add_child(shop)
	shop.position = Vector3(10, 0, -25.5)
	_spawn_component_depot()
	demo_seat = DemoBuilds.build_car(Vector3(-7, 0, 3))
	var wires := WireRenderer.new()
	wires.name = "Wires"
	add_child(wires)


## Ao soldar, o mundo afunda num fog preto forte (como no original):
## só o que está perto do arco continua visível.
func _process(delta: float) -> void:
	if player == null or environment == null:
		return
	var target := 0.0
	var tool := player.current()
	if tool is WeldTool and (tool as WeldTool).is_arc_active():
		target = 1.0
	var prev := _weld_dark
	_weld_dark = move_toward(_weld_dark, target, delta * (12.0 if target > 0.0 else 3.0))
	if is_equal_approx(prev, _weld_dark):
		return
	if _base_env.is_empty():
		_base_env = {
			"fog_color": environment.fog_light_color, "fog_density": environment.fog_density,
			"fog_sky": environment.fog_sky_affect, "ambient": environment.ambient_light_energy,
			"sun": sun.light_energy,
		}
	var t := _weld_dark
	environment.fog_light_color = (_base_env["fog_color"] as Color).lerp(Color.BLACK, t)
	environment.fog_density = lerpf(_base_env["fog_density"], 0.32, t)
	environment.fog_sky_affect = lerpf(_base_env["fog_sky"], 1.0, t)
	environment.ambient_light_energy = lerpf(_base_env["ambient"], 0.08, t)
	sun.light_energy = lerpf(_base_env["sun"], 0.02, t)


func _apply_settings() -> void:
	Settings.apply_graphics(environment, sun, get_viewport())
	player.camera.fov = Settings.fov


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.52, 0.82)
	sky_mat.sky_horizon_color = Color(0.72, 0.78, 0.86)
	sky_mat.ground_horizon_color = Color(0.6, 0.62, 0.62)
	sky_mat.ground_bottom_color = Color(0.25, 0.26, 0.27)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.74, 0.82)
	env.fog_density = 0.0014
	env.fog_sky_affect = 0.3

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	environment = env

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)


# ---------------------------------------------------------------------------
# Terreno com morros (o centro é plano)
# ---------------------------------------------------------------------------

func terrain_height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var hills := smoothstep(FLAT_RADIUS, FLAT_RADIUS + 45.0, r)
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	var h := hills * pow(n, 1.6) * 30.0
	var edge := maxf(absf(x), absf(z))
	h += smoothstep(MAP_HALF - 40.0, MAP_HALF - 4.0, edge) * 35.0
	return h


func _build_terrain() -> void:
	var count := int(MAP_HALF * 2.0 / GRID_STEP) + 1
	var heights := PackedFloat32Array()
	heights.resize(count * count)
	for zi in count:
		for xi in count:
			var x := -MAP_HALF + xi * GRID_STEP
			var z := -MAP_HALF + zi * GRID_STEP
			heights[zi * count + xi] = terrain_height(x, z)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass := Color(0.24, 0.34, 0.15)
	var dry := Color(0.42, 0.40, 0.24)
	var dirt := Color(0.33, 0.26, 0.19)
	for zi in count:
		for xi in count:
			var x := -MAP_HALF + xi * GRID_STEP
			var z := -MAP_HALF + zi * GRID_STEP
			var h := heights[zi * count + xi]
			var hl := heights[zi * count + maxi(xi - 1, 0)]
			var hr := heights[zi * count + mini(xi + 1, count - 1)]
			var hd := heights[maxi(zi - 1, 0) * count + xi]
			var hu := heights[mini(zi + 1, count - 1) * count + xi]
			var n := Vector3(hl - hr, 2.0 * GRID_STEP, hd - hu).normalized()
			var slope := 1.0 - n.y
			var v := _noise.get_noise_2d(x * 6.0, z * 6.0) * 0.5 + 0.5
			var c := grass.lerp(dry, v * 0.7).lerp(dirt, clampf(slope * 5.0, 0.0, 1.0))
			st.set_color(c)
			st.set_normal(n)
			st.add_vertex(Vector3(x, h, z))
	for zi in count - 1:
		for xi in count - 1:
			var i := zi * count + xi
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + count)
			st.add_index(i + 1)
			st.add_index(i + count + 1)
			st.add_index(i + count)
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)

	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.add_to_group("ground")
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)

	# Colisão: HeightMapShape3D com 1 unidade entre pontos, escalada para GRID_STEP.
	var hm := HeightMapShape3D.new()
	hm.map_width = count
	hm.map_depth = count
	var scaled := PackedFloat32Array()
	scaled.resize(heights.size())
	for i in heights.size():
		scaled[i] = heights[i] / GRID_STEP
	hm.map_data = scaled
	var cs := CollisionShape3D.new()
	cs.shape = hm
	cs.scale = Vector3.ONE * GRID_STEP
	body.add_child(cs)


# ---------------------------------------------------------------------------
# Pátio de concreto com grade de 1 m (ajuda a alinhar construções)
# ---------------------------------------------------------------------------

func _build_pad() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform vec3 base_color : source_color = vec3(0.40, 0.40, 0.39);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float grid_line(vec2 p, float width) {
	vec2 g = abs(fract(p - 0.5) - 0.5) / max(fwidth(p), vec2(1e-4));
	return 1.0 - clamp(min(g.x, g.y) - width, 0.0, 1.0);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = vnoise(wpos.xz * 0.8) * 0.6 + vnoise(wpos.xz * 4.0) * 0.4;
	vec3 col = base_color * (0.85 + n * 0.25);
	float minor = grid_line(wpos.xz, 0.2) * 0.10;
	float major = grid_line(wpos.xz / 5.0, 0.6) * 0.22;
	float slab = grid_line(wpos.xz / 10.0, 1.2) * 0.35;
	col *= 1.0 - max(max(minor, major), slab);
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_static_box(Vector3(PAD_SIZE, 0.2, PAD_SIZE), Transform3D(Basis(), Vector3(0, -0.08, 0)), mat, "Pad")


func _static_box(size: Vector3, xform: Transform3D, mat: Material, node_name := "Static") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.add_to_group("ground")
	add_child(body)
	body.global_transform = xform
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	return body


func _simple_mat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


# ---------------------------------------------------------------------------
# Estruturas fixas: rampas, bancadas, muretas e um galpão
# ---------------------------------------------------------------------------

func _build_props() -> void:
	var concrete := _simple_mat(Color(0.5, 0.5, 0.49))
	var yellow := _simple_mat(Color(0.85, 0.65, 0.12), 0.6)
	var steel := _simple_mat(Color(0.35, 0.37, 0.4), 0.5, 0.7)
	var wood := _simple_mat(Color(0.45, 0.32, 0.2), 0.8)

	# Rampas nas bordas do pátio
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ramp_basis := Basis(Vector3.RIGHT, deg_to_rad(-12.0 * side))
		_static_box(Vector3(8, 0.5, 16), Transform3D(ramp_basis, Vector3(side * 30.0, 1.4, -20.0)), yellow, "Ramp")

	# Bancadas de trabalho
	for pos: Vector3 in [Vector3(-8, 0, -6), Vector3(8, 0, -6)]:
		var top := _static_box(Vector3(4, 0.12, 2), Transform3D(Basis(), pos + Vector3(0, 0.94, 0)), wood, "Bench")
		top.name = "Bench"
		for lx: float in [-1.8, 1.8]:
			for lz: float in [-0.85, 0.85]:
				_static_box(Vector3(0.12, 0.88, 0.12), Transform3D(Basis(), pos + Vector3(lx, 0.44, lz)), steel, "Leg")

	# Muretas de concreto (bons pontos de ancoragem)
	for i in 6:
		var x := -25.0 + i * 10.0
		_static_box(Vector3(6, 1.0, 0.6), Transform3D(Basis(), Vector3(x, 0.5, 38.0)), concrete, "Wall")

	# Galpão aberto: pilares e vigas fixas
	var shed_origin := Vector3(-30, 0, 25)
	for px: float in [-6.0, 6.0]:
		for pz: float in [-5.0, 5.0]:
			_static_box(Vector3(0.4, 6, 0.4), Transform3D(Basis(), shed_origin + Vector3(px, 3, pz)), steel, "Pillar")
	for pz: float in [-5.0, 5.0]:
		_static_box(Vector3(12.4, 0.4, 0.4), Transform3D(Basis(), shed_origin + Vector3(0, 6.2, pz)), steel, "Beam")
	_static_box(Vector3(13, 0.15, 11), Transform3D(Basis(), shed_origin + Vector3(0, 6.5, 0)), _simple_mat(Color(0.3, 0.32, 0.34), 0.6, 0.5), "Roof")


# ---------------------------------------------------------------------------
# Sucata espalhada pelo mapa
# ---------------------------------------------------------------------------

func _spawn_scrap() -> void:
	var piles: Array[Vector3] = [
		Vector3(0, 0, -16), Vector3(-18, 0, 6), Vector3(18, 0, 6),
		Vector3(30, 0, 25), Vector3(0, 0, 25),
	]
	# Pilhas mais distantes, nos morros.
	for i in 8:
		var ang := TAU * i / 8.0 + 0.3
		var r := 95.0 + _rng.randf_range(-10.0, 30.0)
		piles.append(Vector3(cos(ang) * r, 0, sin(ang) * r))
	for i in piles.size():
		_spawn_pile(piles[i])
		# Algumas pilhas distantes também têm componentes.
		if i >= 5 and i % 2 == 1:
			var c := piles[i] + Vector3(5.5, 0, 0)
			c.y = terrain_height(c.x, c.z)
			_spawn_component("motor", c + Vector3(0, 0, -0.8))
			_spawn_component("roda", c + Vector3(0, 0, 0.6))
			_spawn_component("roda", c + Vector3(1.0, 0, 0.6))


## Coloca um componente apoiado no chão em `ground_pos`.
func _spawn_component(kind: String, ground_pos: Vector3, size := Vector3.ZERO) -> void:
	var b := Components.bounds(kind, size)
	Components.spawn(kind, Transform3D(Basis(), ground_pos + Vector3(0, -b.position.y + 0.04, 0)), size)


## Depósito de componentes debaixo do galpão.
func _spawn_component_depot() -> void:
	var o := Vector3(-30, 0.02, 25)
	StationBuilder.label_sign(self, "COMPONENTES", o + Vector3(0, 5.2, -5.2))
	var rows := [
		["motor", "motor", "motor", "motor", "servo", "servo"],
		["roda", "roda", "roda", "roda", "roda", "roda"],
		["pistao", "pistao", "dobradica", "dobradica", "assento", "assento"],
		["servo_linear", "servo_linear", "pino", "pino", "esferica", "esferica"],
		["mola", "mola", "mola", "mola", "torcao", "trava"],
		["guincho", "guincho", "propulsor", "propulsor", "ima", "ima"],
		["engate", "engate", "engate", "engate", "torcao", "trava"],
		["botao", "botao", "alavanca", "alavanca", "potenciometro", "potenciometro"],
	]
	for r in rows.size():
		for c in rows[r].size():
			_spawn_component(rows[r][c], o + Vector3(-4.5 + c * 1.8, 0, -4.55 + r * 1.3))


func _spawn_pile(center: Vector3) -> void:
	var total_w := 0
	for s: Dictionary in SCRAP:
		total_w += int(s["w"])
	var cells := 9
	for c in cells:
		var cx := (c % 3 - 1) * 3.4
		var cz := (c / 3 - 1) * 3.4
		var base := center + Vector3(cx, 0, cz)
		base.y = terrain_height(base.x, base.z)
		if Vector2(base.x, base.z).length() < PAD_SIZE * 0.5:
			base.y = maxf(base.y, 0.02)
		var pick := _rng.randi_range(0, total_w - 1)
		var item: Dictionary = SCRAP[0]
		for s: Dictionary in SCRAP:
			pick -= int(s["w"])
			if pick < 0:
				item = s
				break
		var size: Vector3 = item["size"]
		var range_: Array = item["stack"]
		var count := _rng.randi_range(range_[0], range_[1])
		var mat_roll := _rng.randf()
		var material_id := "aco" if mat_roll < 0.55 else ("ferro" if mat_roll < 0.82 else "aluminio")
		var yaw := _rng.randf_range(-0.25, 0.25) + (PI * 0.5 if _rng.randf() < 0.5 else 0.0)
		var y := base.y + 0.05
		for k in count:
			y += size.y * 0.5
			var xf := Transform3D(Basis(Vector3.UP, yaw + _rng.randf_range(-0.08, 0.08)), Vector3(base.x, y, base.z))
			Build.spawn_box(size, material_id, xf)
			y += size.y * 0.5 + 0.03

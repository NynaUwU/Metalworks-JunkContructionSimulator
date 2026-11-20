extends Node
## Autoload "Settings": opções do jogador, salvas em user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"
const GRAPHICS_NAMES: Array[String] = ["Baixo", "Médio", "Alto"]

var graphics := 1                  ## 0 = baixo, 1 = médio, 2 = alto
var mouse_sensitivity := 0.0025
var fov := 75.0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		graphics = clampi(cfg.get_value("video", "graphics", graphics), 0, 2)
		fov = clampf(cfg.get_value("video", "fov", fov), 60.0, 100.0)
		mouse_sensitivity = clampf(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity), 0.0005, 0.006)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "graphics", graphics)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.save(PATH)


func set_graphics(value: int) -> void:
	graphics = clampi(value, 0, 2)
	save()
	changed.emit()


func set_fov(value: float) -> void:
	fov = value
	save()
	changed.emit()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = value
	save()


## Aplica a qualidade gráfica ao ambiente, ao sol e à tela.
func apply_graphics(env: Environment, sun: DirectionalLight3D, viewport: Viewport) -> void:
	match graphics:
		2:  # Alto
			env.ssao_enabled = true
			env.glow_enabled = true
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 140.0
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		1:  # Médio
			env.ssao_enabled = false
			env.glow_enabled = true
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 90.0
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		_:  # Baixo
			env.ssao_enabled = false
			env.glow_enabled = false
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 50.0
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

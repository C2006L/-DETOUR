extends RefCounted
class_name DetourMaterials

# ------------------------------------------------------------
# 程序化材质库：所有石质 / 混凝土 / 金属 / 锈迹 / 发光材质统一管理。
# 通过噪声纹理 + 三平面映射，让程序化体素拥有真实的表面质感，
# 而不是纯色占位方块。所有资源都缓存复用。
# ------------------------------------------------------------

static var _tex_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _hazard_tex: ImageTexture = null
static var _crack_tex: ImageTexture = null
static var _cobble_tex: ImageTexture = null

# 灰度噪声纹理（输出 0..1 的亮度，用于 albedo tint 与 bump）
static func noise_tex(key: String, seed_val: int, freq: float,
		lo: float = 0.58, hi: float = 1.0, size: int = 96) -> NoiseTexture2D:
	var ck := "%s|%d|%.3f|%.2f|%.2f|%d" % [key, seed_val, freq, lo, hi, size]
	if _tex_cache.has(ck):
		return _tex_cache[ck]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = seed_val
	noise.frequency = freq
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = size
	tex.height = size
	tex.seamless = true
	var grad := Gradient.new()
	grad.set_color(0, Color(lo, lo, lo, 1.0))
	grad.set_color(1, Color(hi, hi, hi, 1.0))
	tex.color_ramp = grad
	_tex_cache[ck] = tex
	return tex

# 黄黑警示斜条纹
static func hazard_tex() -> ImageTexture:
	if _hazard_tex:
		return _hazard_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var yellow := Color(0.96, 0.74, 0.12)
	var black := Color(0.10, 0.11, 0.12)
	for y in range(64):
		for x in range(64):
			var band := int(floor(float(x + y) / 11.0)) % 2
			img.set_pixel(x, y, yellow if band == 0 else black)
	_hazard_tex = ImageTexture.create_from_image(img)
	return _hazard_tex

# 石砖纹理：深灰砖面 + 砖缝 + 随机磨损，用于地面
static func cobble_tex() -> ImageTexture:
	if _cobble_tex:
		return _cobble_tex
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var cell := 32
	for y in range(s):
		for x in range(s):
			var cx := x / cell
			var cy := y / cell
			# 交错砖缝
			var offset := (cy % 2) * (cell / 2)
			var lx := (x + offset) % cell
			var ly := y % cell
			var mortar := lx < 3 or ly < 3
			var v := 0.0
			if mortar:
				v = 0.30 + sin(x * 0.7 + y * 0.3) * 0.04
			else:
				var brick_id := cx * 7 + cy * 13
				var shade := 0.52 + fmod(float(brick_id * 37 % 17), 9.0) / 40.0
				var grain := sin(x * 1.7 + brick_id) * cos(y * 1.3 - brick_id) * 0.06
				var wear := sin(float(x) * 0.11 + float(y) * 0.09) * 0.05
				v = shade + grain + wear
				# 砖面边缘暗一点，模拟倒角
				if lx < 6 or ly < 6 or lx > cell - 5 or ly > cell - 5:
					v -= 0.08
			v = clampf(v, 0.18, 0.95)
			img.set_pixel(x, y, Color(v, v * 0.98, v * 0.93, 1.0))
	_cobble_tex = ImageTexture.create_from_image(img)
	return _cobble_tex

# 裂纹细节纹理：深色底 + 不规则亮裂线，用作叠加细节
static func crack_tex() -> ImageTexture:
	if _crack_tex:
		return _crack_tex
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# 先填深底
	for y in range(s):
		for x in range(s):
			img.set_pixel(x, y, Color(0.10, 0.10, 0.10, 1.0))
	# 画若干分叉裂纹
	for c in range(5):
		var x := rng.randi_range(10, s - 10)
		var y := rng.randi_range(10, s - 10)
		var ang := rng.randf_range(0.0, TAU)
		for step in range(26):
			ang += rng.randf_range(-0.5, 0.5)
			x += int(cos(ang) * 2.0)
			y += int(sin(ang) * 2.0)
			if x < 0 or y < 0 or x >= s or y >= s:
				break
			img.set_pixel(x, y, Color(0.75, 0.72, 0.66, 1.0))
			if x + 1 < s:
				img.set_pixel(x + 1, y, Color(0.42, 0.40, 0.36, 1.0))
	_crack_tex = ImageTexture.create_from_image(img)
	return _crack_tex

# 主材质工厂
static func mat(preset: String, tint: Color = Color.WHITE, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%.2f" % [preset, tint.to_html(), emission]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.82
	m.metallic = 0.0
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 0.5

	match preset:
		"cobble":
			m.albedo_texture = cobble_tex()
			m.uv1_triplanar = false
			m.roughness_texture = noise_tex("ground_b", 21, 0.9, 0.3, 1.0)
			m.roughness = 0.96
		"cracked":
			m.albedo_texture = crack_tex()
			m.uv1_triplanar = false
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.98
		"ground":
			m.albedo_texture = noise_tex("ground", 21, 0.42, 0.52, 1.0)
			m.roughness_texture = noise_tex("ground_b", 21, 0.9, 0.3, 1.0)
			m.roughness = 0.97
		"grass":
			m.albedo_texture = noise_tex("grass", 33, 0.7, 0.55, 1.0)
			m.roughness_texture = noise_tex("grass_b", 33, 1.4, 0.3, 1.0)
			m.roughness = 0.98
		"road":
			m.albedo_texture = noise_tex("road", 47, 0.85, 0.72, 1.0, 128)
			m.roughness_texture = noise_tex("road_b", 47, 1.6, 0.4, 1.0)
			m.roughness = 0.88
		"stone":
			m.albedo_texture = noise_tex("stone", 58, 0.55, 0.50, 1.0)
			m.roughness_texture = noise_tex("stone_b", 58, 1.1, 0.25, 1.0)
			m.roughness = 0.95
		"brick":
			m.albedo_texture = noise_tex("brick", 66, 0.75, 0.55, 1.0)
			m.roughness_texture = noise_tex("brick_b", 66, 1.5, 0.3, 1.0)
			m.roughness = 0.94
		"concrete":
			m.albedo_texture = noise_tex("concrete", 72, 0.65, 0.68, 1.0)
			m.roughness_texture = noise_tex("concrete_b", 72, 1.3, 0.4, 1.0)
			m.roughness = 0.90
		"metal":
			m.albedo_texture = noise_tex("metal", 88, 0.45, 0.62, 1.0)
			m.metallic = 0.72
			m.roughness = 0.42
		"darkmetal":
			m.albedo_texture = noise_tex("metal", 88, 0.45, 0.62, 1.0)
			m.metallic = 0.78
			m.roughness = 0.35
		"rust":
			m.albedo_texture = noise_tex("rust", 91, 0.8, 0.45, 1.0)
			m.roughness_texture = noise_tex("rust_b", 91, 1.5, 0.3, 1.0)
			m.metallic = 0.35
			m.roughness = 0.82
		"paint":
			m.albedo_texture = noise_tex("paint", 99, 0.5, 0.82, 1.0)
			m.metallic = 0.30
			m.roughness = 0.52
		"wood":
			m.albedo_texture = noise_tex("wood", 103, 0.6, 0.6, 1.0)
			m.roughness_texture = noise_tex("wood_b", 103, 1.2, 0.35, 1.0)
			m.roughness = 0.90
		"foliage":
			m.albedo_texture = noise_tex("foliage", 112, 0.9, 0.55, 1.0)
			m.roughness_texture = noise_tex("foliage_b", 112, 1.8, 0.35, 1.0)
			m.roughness = 0.96
		"glass":
			m.metallic = 0.15
			m.roughness = 0.16
		"hazard":
			m.albedo_texture = hazard_tex()
			m.uv1_triplanar = false
			m.roughness = 0.7
		"plain":
			pass
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = tint
		m.emission_energy_multiplier = emission
	_mat_cache[key] = m
	return m

# 带顶点色的材质（供 MultiMesh 批量细节使用）
static func batch_mat(preset: String, emission: float = 0.0) -> StandardMaterial3D:
	var key := "BATCH|%s|%.2f" % [preset, emission]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := mat(preset, Color.WHITE, emission).duplicate() as StandardMaterial3D
	m.vertex_color_use_as_albedo = true
	_mat_cache[key] = m
	return m

class_name VisualizerEffects
extends Node

## 3D visual effects - crystals, ribbons, particles, etc.

# Visual elements
var crystal_shapes: Array[MeshInstance3D] = []
var ribbons: Array[MeshInstance3D] = []
var particles: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var bg_shapes: Array[MeshInstance3D] = []
var center_form: MeshInstance3D
var background_sphere: MeshInstance3D
var orbit_rings: Array[MeshInstance3D] = []

# Materials
var bass_material: ShaderMaterial
var mid_material: ShaderMaterial
var high_material: ShaderMaterial
var ribbon_material: ShaderMaterial
var spark_material: ShaderMaterial
var bg_shape_material: ShaderMaterial
var orb_material: ShaderMaterial
var background_material: ShaderMaterial
var post_process_material: ShaderMaterial

# Post processing
var canvas_layer: CanvasLayer
var post_process_rect: ColorRect

func setup(parent: Node) -> void:
	setup_materials()
	setup_background(parent)
	setup_background_shapes(parent)
	setup_abstract_visuals(parent)
	setup_post_processing(parent)

func setup_materials() -> void:
	bass_material = ShaderMaterial.new()
	bass_material.shader = preload("res://Shaders/abstract_bass_shader.gdshader")

	mid_material = ShaderMaterial.new()
	mid_material.shader = preload("res://Shaders/abstract_mid_shader.gdshader")

	high_material = ShaderMaterial.new()
	high_material.shader = preload("res://Shaders/abstract_high_shader.gdshader")

	ribbon_material = ShaderMaterial.new()
	ribbon_material.shader = preload("res://Shaders/ribbon_shader.gdshader")

	spark_material = ShaderMaterial.new()
	spark_material.shader = preload("res://Shaders/spark_shader.gdshader")

	bg_shape_material = ShaderMaterial.new()
	bg_shape_material.shader = preload("res://Shaders/background_shape_shader.gdshader")

	orb_material = ShaderMaterial.new()
	orb_material.shader = preload("res://Shaders/orb_shader.gdshader")

	background_material = ShaderMaterial.new()
	background_material.shader = preload("res://Shaders/background_shader.gdshader")

	post_process_material = ShaderMaterial.new()
	post_process_material.shader = preload("res://Shaders/post_process.gdshader")

func setup_background(parent: Node) -> void:
	background_sphere = MeshInstance3D.new()
	var bg_mesh = SphereMesh.new()
	bg_mesh.radius = 50.0
	bg_mesh.height = 100.0
	bg_mesh.radial_segments = 64
	bg_mesh.rings = 32
	background_sphere.mesh = bg_mesh
	background_sphere.material_override = background_material
	parent.add_child(background_sphere)

func setup_background_shapes(parent: Node) -> void:
	# Distant floating slabs
	for i in range(8):
		var slab = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(randf_range(1.5, 4.0), randf_range(0.1, 0.3), randf_range(1.0, 3.0))
		slab.mesh = box
		var mat = bg_shape_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("shape_id", float(i))
		slab.material_override = mat

		var angle = float(i) / 8.0 * TAU + randf() * 0.5
		var dist = randf_range(12.0, 20.0)
		var height = randf_range(-4.0, 4.0)
		slab.position = Vector3(cos(angle) * dist, height, sin(angle) * dist)
		slab.rotation = Vector3(randf() * 0.3, randf() * TAU, randf() * 0.2)

		parent.add_child(slab)
		bg_shapes.append(slab)

	# Tall pillars/monoliths
	for i in range(6):
		var pillar = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(randf_range(0.3, 0.8), randf_range(3.0, 8.0), randf_range(0.3, 0.8))
		pillar.mesh = box
		var mat = bg_shape_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("shape_id", float(i + 10))
		pillar.material_override = mat

		var angle = float(i) / 6.0 * TAU + 0.3
		var dist = randf_range(10.0, 16.0)
		pillar.position = Vector3(cos(angle) * dist, randf_range(-2.0, 2.0), sin(angle) * dist)
		pillar.rotation = Vector3(randf() * 0.15, randf() * TAU, randf() * 0.15)

		parent.add_child(pillar)
		bg_shapes.append(pillar)

	# Floating debris/fragments
	for i in range(15):
		var debris = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(randf_range(0.2, 0.8), randf_range(0.2, 0.8), randf_range(0.2, 0.8))
		debris.mesh = box
		var mat = bg_shape_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("shape_id", float(i + 20))
		debris.material_override = mat

		var angle = randf() * TAU
		var dist = randf_range(8.0, 18.0)
		var height = randf_range(-5.0, 5.0)
		debris.position = Vector3(cos(angle) * dist, height, sin(angle) * dist)
		debris.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

		parent.add_child(debris)
		bg_shapes.append(debris)

	# Large distant planes
	for i in range(4):
		var plane_shape = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(randf_range(5.0, 10.0), randf_range(0.05, 0.1), randf_range(5.0, 10.0))
		plane_shape.mesh = box
		var mat = bg_shape_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("shape_id", float(i + 40))
		plane_shape.material_override = mat

		var angle = float(i) / 4.0 * TAU + 0.7
		var dist = randf_range(18.0, 28.0)
		plane_shape.position = Vector3(cos(angle) * dist, randf_range(-6.0, 6.0), sin(angle) * dist)
		plane_shape.rotation = Vector3(randf() * 0.4 - 0.2, randf() * TAU, randf() * 0.4 - 0.2)

		parent.add_child(plane_shape)
		bg_shapes.append(plane_shape)

func create_crystal_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	var top = Vector3(0, 1.5, 0)
	var bottom = Vector3(0, -1.5, 0)
	var points: Array[Vector3] = []
	var sides = 6
	for i in range(sides):
		var angle = float(i) / sides * TAU
		points.append(Vector3(cos(angle) * 0.4, 0, sin(angle) * 0.4))

	for i in range(sides):
		var next = (i + 1) % sides
		vertices.append(top)
		vertices.append(points[i])
		vertices.append(points[next])
		vertices.append(bottom)
		vertices.append(points[next])
		vertices.append(points[i])

	for i in range(0, vertices.size(), 3):
		var v0 = vertices[i]
		var v1 = vertices[i + 1]
		var v2 = vertices[i + 2]
		var normal = (v1 - v0).cross(v2 - v0).normalized()
		normals.append(normal)
		normals.append(normal)
		normals.append(normal)
		uvs.append(Vector2(0.5, 0))
		uvs.append(Vector2(0, 1))
		uvs.append(Vector2(1, 1))

	for i in range(vertices.size()):
		indices.append(i)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func create_ribbon_mesh(length: float, width: float, segments: int) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	for i in range(segments + 1):
		var t = float(i) / segments
		var x = (t - 0.5) * length
		vertices.append(Vector3(x, 0, -width / 2))
		vertices.append(Vector3(x, 0, width / 2))
		normals.append(Vector3(0, 1, 0))
		normals.append(Vector3(0, 1, 0))
		uvs.append(Vector2(t, 0))
		uvs.append(Vector2(t, 1))

	for i in range(segments):
		var base = i * 2
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base + 1)
		indices.append(base + 3)
		indices.append(base + 2)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func create_particle_quad() -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array([
		Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0),
		Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)
	])
	var normals = PackedVector3Array([
		Vector3(0, 0, 1), Vector3(0, 0, 1),
		Vector3(0, 0, 1), Vector3(0, 0, 1)
	])
	var uvs = PackedVector2Array([
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)
	])
	var indices = PackedInt32Array([0, 1, 2, 0, 2, 3])

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func setup_abstract_visuals(parent: Node) -> void:
	var crystal_mesh = create_crystal_mesh()
	var ribbon_mesh = create_ribbon_mesh(4.0, 0.3, 32)
	var particle_mesh = create_particle_quad()

	# Floating crystals (bass)
	var crystal_count = 15
	for i in range(crystal_count):
		var crystal = MeshInstance3D.new()
		crystal.mesh = crystal_mesh
		var mat = bass_material.duplicate() as ShaderMaterial
		crystal.material_override = mat

		var golden_angle = PI * (3.0 - sqrt(5.0))
		var theta = golden_angle * i
		var radius = 2.0 + sqrt(float(i)) * 0.5
		var height = sin(float(i) * 0.5) * 1.5

		crystal.position = Vector3(cos(theta) * radius, height, sin(theta) * radius)
		crystal.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

		parent.add_child(crystal)
		crystal_shapes.append(crystal)

	# Flowing ribbons (mid)
	var ribbon_count = 5
	for i in range(ribbon_count):
		var ribbon = MeshInstance3D.new()
		ribbon.mesh = ribbon_mesh
		var mat = ribbon_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("ribbon_id", float(i))
		ribbon.material_override = mat

		var angle = float(i) / ribbon_count * TAU
		ribbon.position = Vector3(cos(angle) * 1.2, 0, sin(angle) * 1.2)
		ribbon.rotation.y = angle + PI / 2

		parent.add_child(ribbon)
		ribbons.append(ribbon)

	# Particle swarm (high)
	var particle_count = 40
	for i in range(particle_count):
		var particle = MeshInstance3D.new()
		particle.mesh = particle_mesh
		var mat = high_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("particle_id", float(i))
		particle.material_override = mat

		var phi = randf() * TAU
		var costheta = randf() * 2.0 - 1.0
		var theta = acos(costheta)
		var r = 1.0 + randf() * 2.0

		particle.position = Vector3(
			r * sin(theta) * cos(phi),
			r * sin(theta) * sin(phi),
			r * cos(theta)
		)
		particle.scale = Vector3.ONE * (0.1 + randf() * 0.15)

		parent.add_child(particle)
		particles.append(particle)

	# Orbit rings
	for i in range(3):
		var ring = MeshInstance3D.new()
		var torus_mesh = TorusMesh.new()
		torus_mesh.inner_radius = 2.5 + i * 0.8
		torus_mesh.outer_radius = 2.55 + i * 0.8
		torus_mesh.rings = 64
		torus_mesh.ring_segments = 6
		ring.mesh = torus_mesh
		ring.material_override = mid_material.duplicate()

		ring.rotation.x = PI / 4 + i * 0.3
		ring.rotation.z = i * 0.5

		parent.add_child(ring)
		orbit_rings.append(ring)

	# Sparking particles
	var spark_count = 20
	for i in range(spark_count):
		var spark = MeshInstance3D.new()
		spark.mesh = particle_mesh
		var mat = spark_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("spark_id", float(i))
		spark.material_override = mat

		spark.position = Vector3(
			(randf() - 0.5) * 6.0,
			(randf() - 0.5) * 4.0,
			(randf() - 0.5) * 6.0
		)
		spark.scale = Vector3.ONE * (0.08 + randf() * 0.1)

		parent.add_child(spark)
		sparks.append(spark)

	# Center form
	center_form = MeshInstance3D.new()
	var center_mesh = SphereMesh.new()
	center_mesh.radius = 0.4
	center_mesh.height = 0.8
	center_mesh.radial_segments = 8
	center_mesh.rings = 4
	center_form.mesh = center_mesh
	center_form.material_override = orb_material
	parent.add_child(center_form)

func setup_post_processing(parent: Node) -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	parent.add_child(canvas_layer)

	post_process_rect = ColorRect.new()
	post_process_rect.anchors_preset = Control.PRESET_FULL_RECT
	post_process_rect.material = post_process_material
	canvas_layer.add_child(post_process_rect)

func update(delta: float, time: float, bass_energy: float, mid_energy: float, high_energy: float, total_energy: float) -> void:
	update_crystals(delta, time, bass_energy)
	update_ribbons(delta, time, mid_energy)
	update_particles(delta, time, high_energy)
	update_orbit_rings(delta, time, mid_energy)
	update_sparks(delta, time, total_energy)
	update_center_form(time, total_energy)
	update_background_shapes(delta, time, total_energy)
	update_background(time)

func update_crystals(delta: float, time: float, bass_energy: float) -> void:
	for i in range(crystal_shapes.size()):
		var crystal = crystal_shapes[i]
		var mat = crystal.material_override as ShaderMaterial

		var id = float(i)
		var phase = id * 0.7 + time

		var wander_x = sin(phase * 0.3 + id * 1.1) * 0.4 + cos(phase * 0.2 + id * 0.7) * 0.3
		var wander_y = sin(phase * 0.25 + id * 0.9) * 0.5 + cos(phase * 0.35 + id * 1.3) * 0.3
		var wander_z = cos(phase * 0.28 + id * 0.8) * 0.4 + sin(phase * 0.22 + id * 1.2) * 0.3

		var golden_angle = PI * (3.0 - sqrt(5.0))
		var base_theta = golden_angle * i
		var orbit_speed = 0.15 + sin(id * 0.5) * 0.05
		var theta = base_theta + time * orbit_speed

		var base_radius = 2.0 + sqrt(id) * 0.5
		var radius_wobble = sin(phase * 0.4) * 0.3
		var radius = base_radius + radius_wobble + bass_energy * 0.5

		var base_height = sin(id * 0.5 + time * 0.2) * 1.2 + cos(id * 0.3 + time * 0.15) * 0.8

		crystal.position = Vector3(
			cos(theta) * radius + wander_x,
			base_height + wander_y + bass_energy * 0.3,
			sin(theta) * radius + wander_z
		)

		crystal.rotation.x += delta * (0.4 + sin(id) * 0.2 + bass_energy * 1.5)
		crystal.rotation.y += delta * (0.3 + cos(id * 0.7) * 0.15 + bass_energy * 1.0)
		crystal.rotation.z += delta * (0.2 + sin(id * 1.3) * 0.1)

		var scale_base = 0.5 + bass_energy * 0.6
		var scale_pulse = sin(time * 3.0 + i * 0.5) * 0.08
		crystal.scale = Vector3.ONE * (scale_base + scale_pulse)

		mat.set_shader_parameter("energy", bass_energy)
		mat.set_shader_parameter("time", time)

func update_ribbons(delta: float, time: float, mid_energy: float) -> void:
	for i in range(ribbons.size()):
		var ribbon = ribbons[i]
		var mat = ribbon.material_override as ShaderMaterial

		var angle = float(i) / ribbons.size() * TAU + time * (0.15 + mid_energy * 0.2)
		var radius = 1.2 + mid_energy * 0.3
		ribbon.position = Vector3(cos(angle) * radius, sin(time * 0.5 + i) * mid_energy * 0.3, sin(angle) * radius)
		ribbon.rotation.y = angle + PI / 2
		ribbon.rotation.x = sin(time * 0.3 + i) * mid_energy * 0.3
		ribbon.rotation.z = cos(time * 0.2 + i) * mid_energy * 0.2

		ribbon.scale = Vector3.ONE * (0.8 + mid_energy * 0.3)

		mat.set_shader_parameter("energy", mid_energy)
		mat.set_shader_parameter("time", time)

func update_particles(delta: float, time: float, high_energy: float) -> void:
	for i in range(particles.size()):
		var particle = particles[i]
		var mat = particle.material_override as ShaderMaterial

		var phase = float(i) * 0.3 + time * (2.0 + high_energy * 3.0)
		var base_r = 1.0 + sin(float(i) * 0.5) * 0.5 + high_energy * 0.5
		var height_var = cos(phase * 0.5 + i * 0.2) * (1.0 + high_energy)

		particle.position = Vector3(cos(phase) * base_r, height_var, sin(phase) * base_r)
		particle.rotation.y = time * 0.5

		var base_scale = 0.1 + sin(float(i) * 0.7) * 0.05
		var energy_scale = high_energy * 0.3
		particle.scale = Vector3.ONE * (base_scale + energy_scale)

		mat.set_shader_parameter("energy", high_energy)
		mat.set_shader_parameter("time", time)

func update_orbit_rings(delta: float, time: float, mid_energy: float) -> void:
	for i in range(orbit_rings.size()):
		var ring = orbit_rings[i]
		ring.rotation.x += delta * (0.3 + mid_energy * 0.5) * (1.0 if i % 2 == 0 else -1.0)
		ring.rotation.y += delta * (0.2 + mid_energy * 0.3)
		ring.rotation.z += delta * 0.1 * (i + 1)

		var mat = ring.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("energy", mid_energy)
			mat.set_shader_parameter("time", time)

func update_sparks(delta: float, time: float, total_energy: float) -> void:
	for i in range(sparks.size()):
		var spark = sparks[i]
		var mat = spark.material_override as ShaderMaterial

		var drift_phase = time * 0.3 + float(i) * 0.5
		var base_x = sin(drift_phase * 0.7 + i) * 3.0
		var base_y = cos(drift_phase * 0.5 + i * 0.3) * 2.0
		var base_z = sin(drift_phase * 0.6 + i * 0.7) * 3.0

		spark.position = Vector3(base_x, base_y, base_z)
		spark.scale = Vector3.ONE * (0.1 + total_energy * 0.15)

		mat.set_shader_parameter("energy", total_energy)
		mat.set_shader_parameter("time", time)

func update_center_form(time: float, total_energy: float) -> void:
	var orb_scale = 0.4 + total_energy * 0.6
	var orb_pulse = sin(time * 6.0) * 0.1 * total_energy
	center_form.scale = Vector3.ONE * (orb_scale + orb_pulse)
	center_form.rotation.y = time * 0.8
	center_form.rotation.x = sin(time * 0.4) * 0.3

func update_background_shapes(delta: float, time: float, total_energy: float) -> void:
	for i in range(bg_shapes.size()):
		var shape = bg_shapes[i]
		var mat = shape.material_override as ShaderMaterial

		shape.rotation.x += delta * 0.02 * (1.0 + sin(float(i)) * 0.5)
		shape.rotation.y += delta * 0.03 * (1.0 + cos(float(i) * 0.7) * 0.5)

		var drift = sin(time * 0.1 + float(i) * 0.3) * 0.1
		shape.position.y += drift * delta

		mat.set_shader_parameter("energy", total_energy)
		mat.set_shader_parameter("time", time)

func update_background(time: float) -> void:
	background_sphere.rotation.y = time * 0.05
	background_sphere.rotation.x = sin(time * 0.03) * 0.05

func update_shader_params(time: float, bass_energy: float, mid_energy: float, high_energy: float) -> void:
	if orb_material:
		orb_material.set_shader_parameter("bass", bass_energy)
		orb_material.set_shader_parameter("mid", mid_energy)
		orb_material.set_shader_parameter("high", high_energy)
		orb_material.set_shader_parameter("time", time)

	if background_material:
		background_material.set_shader_parameter("bass", bass_energy)
		background_material.set_shader_parameter("mid", mid_energy)
		background_material.set_shader_parameter("high", high_energy)
		background_material.set_shader_parameter("time", time)

	if post_process_material:
		post_process_material.set_shader_parameter("bass", bass_energy)
		post_process_material.set_shader_parameter("mid", mid_energy)
		post_process_material.set_shader_parameter("high", high_energy)
		post_process_material.set_shader_parameter("time", time)

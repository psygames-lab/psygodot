extends Node
class_name TempleRunnerObstacleDirector

var rng := RandomNumberGenerator.new()
var stone_mat: StandardMaterial3D
var moss_mat: StandardMaterial3D
var hazard_mat: StandardMaterial3D
var gold_mat: StandardMaterial3D
var vine_mat: StandardMaterial3D
var fire_mat: StandardMaterial3D

func _ready() -> void:
	rng.seed = 812381
	_build_materials()

func decorate_segment(segment: Node3D, segment_index: int, length: float) -> void:
	_add_path(segment, length)
	_add_side_jungle(segment, segment_index, length)
	_add_arches_and_pillars(segment, segment_index, length)
	if segment_index < 2:
		_add_gem_row(segment, 0, -length * 0.36)
		return
	var pattern := segment_index % 6
	if pattern == 0:
		_add_spikes(segment, [-1, 1], -length * 0.25)
		_add_gem(segment, 0, -length * 0.52)
	elif pattern == 1:
		_add_low_gate(segment, rng.randi_range(-1, 1), -length * 0.38)
		_add_gem_row(segment, rng.randi_range(-1, 1), -length * 0.68)
	elif pattern == 2:
		_add_gap(segment, rng.randi_range(-1, 1), -length * 0.34)
		_add_gem(segment, rng.randi_range(-1, 1), -length * 0.62)
	elif pattern == 3:
		_add_block(segment, 0, -length * 0.42)
		_add_gem(segment, -1, -length * 0.66)
		_add_gem(segment, 1, -length * 0.66)
	elif pattern == 4:
		_add_spikes(segment, [rng.randi_range(-1, 1)], -length * 0.34)
		_add_low_gate(segment, 0, -length * 0.68)
	else:
		_add_gap(segment, -1, -length * 0.32)
		_add_block(segment, 1, -length * 0.58)
		_add_gem(segment, 0, -length * 0.78)

func _build_materials() -> void:
	stone_mat = _mat(Color(0.38, 0.37, 0.33), 0.85)
	moss_mat = _mat(Color(0.16, 0.33, 0.18), 0.92)
	hazard_mat = _mat(Color(0.78, 0.12, 0.08), 0.62)
	gold_mat = _mat(Color(1.0, 0.68, 0.12), 0.35, Color(1.0, 0.35, 0.05), 0.8)
	vine_mat = _mat(Color(0.08, 0.37, 0.13), 0.78)
	fire_mat = _mat(Color(1.0, 0.38, 0.08), 0.3, Color(1.0, 0.28, 0.02), 1.8)

func _mat(color: Color, roughness: float, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material

func _add_path(segment: Node3D, length: float) -> void:
	var path := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(9.7, 0.34, length)
	path.mesh = mesh
	path.material_override = stone_mat
	path.position = Vector3(0.0, -0.18, -length * 0.5)
	segment.add_child(path)
	var floor_body := StaticBody3D.new()
	floor_body.name = "PathCollision"
	floor_body.position = path.position
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = mesh.size
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	segment.add_child(floor_body)
	for lane_x in [-1.5, 1.5]:
		var seam := MeshInstance3D.new()
		var seam_mesh := BoxMesh.new()
		seam_mesh.size = Vector3(0.08, 0.04, length)
		seam.mesh = seam_mesh
		seam.material_override = moss_mat
		seam.position = Vector3(lane_x, 0.02, -length * 0.5)
		segment.add_child(seam)

func _add_side_jungle(segment: Node3D, segment_index: int, length: float) -> void:
	for side in [-1, 1]:
		for i in range(3):
			var z := -2.0 - i * 4.0 - fmod(float(segment_index), 2.0)
			var trunk := MeshInstance3D.new()
			var trunk_mesh := CylinderMesh.new()
			trunk_mesh.top_radius = 0.22
			trunk_mesh.bottom_radius = 0.35
			trunk_mesh.height = 3.2
			trunk.mesh = trunk_mesh
			trunk.material_override = _mat(Color(0.26, 0.15, 0.08), 0.8)
			trunk.position = Vector3(side * (5.8 + rng.randf() * 1.5), 1.35, z)
			trunk.rotation.z = side * rng.randf_range(0.05, 0.2)
			segment.add_child(trunk)
			var canopy := MeshInstance3D.new()
			var canopy_mesh := SphereMesh.new()
			canopy_mesh.radius = rng.randf_range(0.75, 1.15)
			canopy_mesh.height = canopy_mesh.radius * 1.6
			canopy.mesh = canopy_mesh
			canopy.material_override = moss_mat
			canopy.position = trunk.position + Vector3(0.0, 2.1, 0.0)
			segment.add_child(canopy)
			var vine := MeshInstance3D.new()
			var vine_mesh := CylinderMesh.new()
			vine_mesh.top_radius = 0.035
			vine_mesh.bottom_radius = 0.035
			vine_mesh.height = 2.2
			vine.mesh = vine_mesh
			vine.material_override = vine_mat
			vine.position = Vector3(side * 4.7, 1.8, z - 0.8)
			vine.rotation.x = PI * 0.5
			segment.add_child(vine)

func _add_arches_and_pillars(segment: Node3D, segment_index: int, length: float) -> void:
	if segment_index % 2 != 0:
		return
	var z := -length * 0.86
	for x in [-4.8, 4.8]:
		var pillar := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.42
		mesh.bottom_radius = 0.55
		mesh.height = 4.4
		pillar.mesh = mesh
		pillar.material_override = stone_mat
		pillar.position = Vector3(x, 2.0, z)
		segment.add_child(pillar)
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(10.8, 0.55, 0.7)
	lintel.mesh = lintel_mesh
	lintel.material_override = stone_mat
	lintel.position = Vector3(0.0, 4.25, z)
	segment.add_child(lintel)
	for x in [-5.2, 5.2]:
		_add_torch(segment, x, z + 0.65)

func _add_torch(segment: Node3D, x: float, z: float) -> void:
	var bowl := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.15
	mesh.height = 0.25
	bowl.mesh = mesh
	bowl.material_override = stone_mat
	bowl.position = Vector3(x, 2.65, z)
	segment.add_child(bowl)
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.22
	flame_mesh.height = 0.45
	flame.mesh = flame_mesh
	flame.material_override = fire_mat
	flame.position = Vector3(x, 2.95, z)
	segment.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.42, 0.1)
	light.light_energy = 0.8
	light.omni_range = 5.0
	light.position = flame.position
	segment.add_child(light)

func _add_area(segment: Node3D, kind: String, lane: int, local_z: float, size: Vector3, y: float, visual: Node3D) -> Area3D:
	var area := Area3D.new()
	area.name = "Area_%s_%d" % [kind, lane]
	area.collision_layer = 2
	area.collision_mask = 1
	area.position = Vector3(float(lane) * 3.0, y, local_z)
	area.set_meta("runner_kind", kind)
	area.set_meta("runner_lane", lane)
	area.set_meta("runner_active", true)
	area.set_meta("runner_near_miss", false)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	if visual:
		area.add_child(visual)
	segment.add_child(area)
	return area

func _add_gem(segment: Node3D, lane: int, local_z: float) -> void:
	var gem := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	gem.mesh = mesh
	gem.material_override = gold_mat
	gem.scale = Vector3(1.0, 1.45, 1.0)
	_add_area(segment, "gem", lane, local_z, Vector3(1.05, 1.05, 1.05), 1.12, gem)

func _add_gem_row(segment: Node3D, lane: int, local_z: float) -> void:
	for i in range(3):
		_add_gem(segment, lane, local_z - i * 1.15)

func _add_spikes(segment: Node3D, lanes: Array, local_z: float) -> void:
	for lane in lanes:
		var root := Node3D.new()
		for i in range(3):
			var spike := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.0
			mesh.bottom_radius = 0.22
			mesh.height = 0.95
			spike.mesh = mesh
			spike.material_override = hazard_mat
			spike.position = Vector3((i - 1) * 0.35, -0.1, 0.0)
			root.add_child(spike)
		_add_area(segment, "spikes", int(lane), local_z, Vector3(1.18, 0.68, 0.9), 0.38, root)

func _add_block(segment: Node3D, lane: int, local_z: float) -> void:
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.65, 1.75, 1.1)
	block.mesh = mesh
	block.material_override = hazard_mat
	block.position.y = 0.3
	_add_area(segment, "block", lane, local_z, Vector3(1.24, 1.5, 0.92), 0.82, block)

func _add_gap(segment: Node3D, lane: int, local_z: float) -> void:
	var pit := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.45, 0.08, 2.4)
	pit.mesh = mesh
	pit.material_override = _mat(Color(0.03, 0.025, 0.02), 0.95)
	pit.position.y = -0.62
	_add_area(segment, "gap", lane, local_z, Vector3(1.3, 0.46, 1.55), 0.08, pit)

func _add_low_gate(segment: Node3D, lane: int, local_z: float) -> void:
	var gate := Node3D.new()
	var bar := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.25, 0.45, 0.6)
	bar.mesh = mesh
	bar.material_override = stone_mat
	bar.position.y = 0.18
	gate.add_child(bar)
	for x in [-0.95, 0.95]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.22, 1.55, 0.35)
		post.mesh = post_mesh
		post.material_override = moss_mat
		post.position = Vector3(x, -0.45, 0.0)
		gate.add_child(post)
	_add_area(segment, "low_gate", lane, local_z, Vector3(1.42, 0.5, 0.62), 1.58, gate)

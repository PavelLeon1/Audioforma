extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	var material := (scene.get_node("Orb") as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
	if material == null or material.shader == null:
		_fail("У сферы отсутствует кодовый пространственный шейдер")
		return
	if material.shader.code.find("void vertex()") < 0 or material.shader.code.find("void fragment()") < 0:
		_fail("Шейдер должен содержать вершинную и фрагментную части")
		return
	if not (scene.get_node("WorldEnvironment") as WorldEnvironment).environment.glow_enabled:
		_fail("Свечение сцены не включено")
		return

	scene._apply_audio_state(Vector3(0.4, 0.6, 0.8), 0.7)
	for parameter in [{"name": "bass", "value": 0.4}, {"name": "mid", "value": 0.6}, {"name": "high", "value": 0.8}, {"name": "level", "value": 0.7}]:
		if not is_equal_approx(material.get_shader_parameter(parameter.name), parameter.value):
			_fail("Параметр %s не передан в шейдер" % parameter.name)
			return

	for index in range(4):
		scene._set_mode(index)
		if material.get_shader_parameter("deformation_mode") != index or not scene.mode_buttons[index].button_pressed:
			_fail("Режим %d не выбран в шейдере и интерфейсе" % index)
			return

	print("PASS: шейдер получает спектр, громкость и четыре режима")
	scene.queue_free()
	await process_frame
	var bus_index := AudioServer.get_bus_index("Audio Analysis")
	if bus_index >= 0:
		AudioServer.remove_bus(bus_index)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

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

	scene.set_process(false)
	var camera := scene.get_node("Camera3D") as Camera3D
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	scene._unhandled_input(wheel)
	if camera.position.z >= 7.0 or scene.zoom_label.text == "100 %":
		_fail("Колесо мыши не приблизило объект")
		return
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.position = Vector2(800.0, 350.0)
	mouse_down.pressed = true
	scene._unhandled_input(mouse_down)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80.0, -50.0)
	scene._unhandled_input(motion)
	if scene.orb.rotation.is_zero_approx():
		_fail("Перетаскивание не повернуло объект")
		return
	motion.relative = Vector2(0.0, 10000.0)
	scene._unhandled_input(motion)
	if scene.orb.rotation.x > 1.15:
		_fail("Наклон объекта выходит за допустимый предел")
		return
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	scene._input(mouse_up)
	if scene.dragging:
		_fail("Отпускание мыши не завершило вращение")
		return
	for index in range(30):
		scene._zoom_camera(-1.0)
	if camera.position.z < 5.599:
		_fail("Камера приблизилась слишком близко")
		return
	for index in range(30):
		scene._zoom_camera(1.0)
	if camera.position.z > 9.001:
		_fail("Камера отдалилась слишком далеко")
		return
	scene.camera_reset_button.pressed.emit()
	if not scene.orb.rotation.is_zero_approx() or not is_equal_approx(camera.position.z, 7.0) or scene.zoom_label.text != "100 %":
		_fail("Сброс не восстановил исходный ракурс")
		return

	var original_stream: AudioStream = scene.audio_controller.player.stream
	scene._on_file_selected("unsupported.txt")
	if scene.playback_label.text.find("MP3") < 0 or scene.audio_controller.player.stream != original_stream:
		_fail("Неподдерживаемый файл не показал понятную ошибку")
		return
	var corrupt_file := FileAccess.open("user://corrupt.wav", FileAccess.WRITE)
	if corrupt_file == null:
		_fail("Не удалось создать повреждённый тестовый файл")
		return
	corrupt_file.store_string("not a wave file")
	corrupt_file.close()
	var corrupt_path := ProjectSettings.globalize_path("user://corrupt.wav")
	scene._on_file_selected(corrupt_path)
	DirAccess.remove_absolute(corrupt_path)
	if scene.playback_label.text.find("Не удалось прочитать") < 0 or scene.audio_controller.player.stream != original_stream:
		_fail("Повреждённый WAV не показал ошибку или заменил текущий звук")
		return
	var valid_path := ProjectSettings.globalize_path("res://tests/fixtures/800.wav")
	scene._on_file_selected(valid_path)
	if scene.playback_label.text != "Звук воспроизводится":
		_fail("Успешная загрузка не очистила ошибку")
		return
	await process_frame
	scene.audio_controller.toggle_playback()
	if scene.playback_label.text != "Воспроизведение приостановлено":
		_fail("Пауза не отражена в интерфейсе")
		return

	print("PASS: шейдер, режимы, ракурс и сообщения о загрузке")
	scene.audio_controller.player.stop()
	scene.queue_free()
	await create_timer(0.3).timeout
	var bus_index := AudioServer.get_bus_index("Audio Analysis")
	if bus_index >= 0:
		AudioServer.remove_bus(bus_index)
	await create_timer(0.1).timeout
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

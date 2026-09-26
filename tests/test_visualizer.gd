extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	scene._loading_appearance = true
	var volume_down := scene.source_panel.find_child("VolumeDownButton", true, false) as Button
	var volume_up := scene.source_panel.find_child("VolumeUpButton", true, false) as Button
	if volume_down == null or volume_up == null:
		_fail("Кнопки управления громкостью отсутствуют")
		return
	var source_bounds: Rect2 = scene.source_panel.get_global_rect()
	if scene.volume_slider.get_global_rect().end.x > source_bounds.end.x - 12.0 or scene.volume_slider.get_global_rect().end.y > source_bounds.end.y - 12.0:
		_fail("Регулятор громкости выходит за границы панели")
		return
	scene.volume_slider.value = 100.0
	volume_down.pressed.emit()
	var master_index := AudioServer.get_bus_index("Master")
	if not is_equal_approx(scene.audio_controller.get_volume_percent(), 90.0) or not is_equal_approx(AudioServer.get_bus_volume_linear(master_index), 0.9) or scene.volume_value_label.text != "90 %":
		_fail("Уменьшение громкости не применилось к звуку и индикатору")
		return
	volume_up.pressed.emit()
	if not is_equal_approx(scene.audio_controller.get_volume_percent(), 100.0):
		_fail("Увеличение громкости не вернуло исходный уровень")
		return
	scene.volume_slider.value = 0.0
	volume_down.pressed.emit()
	if scene.audio_controller.get_volume_percent() != 0.0 or AudioServer.get_bus_volume_linear(master_index) > 0.001:
		_fail("Нулевая громкость не заглушила звук")
		return
	scene.volume_slider.value = 35.0
	if not is_equal_approx(scene.audio_controller.get_volume_percent(), 35.0):
		_fail("Ползунок громкости не установил выбранное значение")
		return
	scene.volume_slider.value = 100.0
	var material := (scene.get_node("Orb") as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
	var halo_material := (scene.get_node("Orb/Halo") as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
	if material == null or material.shader == null:
		_fail("У сферы отсутствует кодовый пространственный шейдер")
		return
	if material.shader.code.find("void vertex()") < 0 or material.shader.code.find("void fragment()") < 0:
		_fail("Шейдер должен содержать вершинную и фрагментную части")
		return
	if halo_material == null or halo_material.shader == null or halo_material.shader.code.find("void fragment()") < 0:
		_fail("Светящийся контур должен использовать кодовый шейдер")
		return
	if not (scene.get_node("WorldEnvironment") as WorldEnvironment).environment.glow_enabled:
		_fail("Свечение сцены не включено")
		return

	scene._apply_audio_state(Vector3(0.4, 0.6, 0.8), 0.7)
	for parameter in [{"name": "bass", "value": 0.4}, {"name": "mid", "value": 0.6}, {"name": "high", "value": 0.8}, {"name": "level", "value": 0.7}]:
		if not is_equal_approx(material.get_shader_parameter(parameter.name), parameter.value) or not is_equal_approx(halo_material.get_shader_parameter(parameter.name), parameter.value):
			_fail("Параметр %s не передан в шейдер" % parameter.name)
			return

	for index in range(4):
		scene._set_mode(index)
		if material.get_shader_parameter("deformation_mode") != index or halo_material.get_shader_parameter("deformation_mode") != index or not scene.mode_buttons[index].button_pressed:
			_fail("Режим %d не выбран в шейдере и интерфейсе" % index)
			return
	scene.motion_time = 1.25
	scene.wave_direction_picker.selected = 2
	scene.orb.rotation.y = PI / 2.0
	scene._register_bass_hit(0.8)
	if not is_equal_approx(material.get_shader_parameter("bass_hit_time_a"), 1.25) or not is_equal_approx(material.get_shader_parameter("bass_hit_strength_a"), 0.8) or not is_equal_approx(halo_material.get_shader_parameter("bass_hit_strength_a"), 0.8):
		_fail("Басовый удар не передан в шейдер")
		return
	var expected_origin: Vector3 = (scene.orb.global_transform.basis.inverse() * Vector3.LEFT).normalized()
	if (material.get_shader_parameter("bass_hit_origin_a") as Vector3).distance_to(expected_origin) > 0.01 or material.get_shader_parameter("bass_hit_paired_a") != 0.0:
		_fail("Направление басовой волны не учитывает поворот сферы")
		return
	scene._update_impact(0.016)
	scene._apply_audio_state(Vector3.ZERO, 0.0)
	if material.get_shader_parameter("beat_pulse") <= 0.0 or Vector2(scene.camera.position.x, scene.camera.position.y).length() <= 0.001:
		_fail("Удар не увеличил сферу или не встряхнул камеру")
		return
	scene._update_impact(1.0)
	if Vector2(scene.camera.position.x, scene.camera.position.y).length() > 0.001 or scene._beat_pulse > 0.001:
		_fail("Пульс и тряска не затухли")
		return
	scene.motion_time = 1.65
	scene.wave_direction_picker.selected = 4
	scene._register_bass_hit(0.5)
	if not is_equal_approx(material.get_shader_parameter("bass_hit_time_b"), 1.65) or material.get_shader_parameter("bass_hit_paired_b") != 1.0:
		_fail("Следующий басовый удар должен запускать отдельную волну")
		return
	scene._reset_bass_waves()
	if material.get_shader_parameter("bass_hit_strength_a") != 0.0 or material.get_shader_parameter("bass_hit_strength_b") != 0.0 or halo_material.get_shader_parameter("bass_hit_strength_a") != 0.0:
		_fail("При смене трека старые волны должны исчезнуть")
		return
	scene.orb.rotation = Vector3.ZERO

	scene._loading_appearance = true
	scene._toggle_appearance_panel()
	if not scene.appearance_panel.visible or scene.source_panel.visible:
		_fail("Панель настроек не открылась")
		return
	var done_button := scene.appearance_panel.find_child("DoneButton", true, false) as Button
	if done_button == null or done_button.get_global_rect().end.y > scene.appearance_panel.get_global_rect().end.y - 12.0:
		_fail("Кнопка закрытия выходит за границы панели настроек")
		return
	scene.accent_picker.color = Color(1.0, 0.6, 0.1)
	scene.background_picker.color = Color(0.08, 0.02, 0.03)
	scene.appearance_sliders["spectrum_mix"].value = 0.0
	scene.appearance_sliders["glow_strength"].value = 1.4
	scene.appearance_sliders["rotation_speed"].value = 0.0
	scene.appearance_sliders["beat_sensitivity"].value = 1.5
	scene.appearance_sliders["beat_pulse_strength"].value = 1.7
	scene.appearance_sliders["shake_strength"].value = 0.0
	scene.wave_direction_picker.selected = 1
	scene._apply_visual_settings()
	for visual_material in [material, halo_material]:
		if visual_material.get_shader_parameter("accent_color") != scene.accent_picker.color or not is_equal_approx(visual_material.get_shader_parameter("glow_strength"), 1.4):
			_fail("Настройки цвета и свечения не переданы обоим слоям")
			return
		if not is_equal_approx(visual_material.get_shader_parameter("beat_pulse_strength"), 1.7):
			_fail("Сила роста сферы не передана обоим слоям")
			return
	if (scene.get_node("WorldEnvironment") as WorldEnvironment).environment.background_color != scene.background_picker.color or scene._auto_rotation_factor != 0.0 or not is_equal_approx(scene.audio_controller.get_bass_sensitivity(), 1.5):
		_fail("Настройки фона, автовращения и чувствительности не применились")
		return
	scene._reset_appearance()
	if not is_equal_approx(material.get_shader_parameter("glow_strength"), 1.0) or scene.wave_direction_picker.selected != 4 or not is_equal_approx(scene.appearance_sliders["shake_strength"].value, 1.0):
		_fail("Сброс настроек не восстановил свечение")
		return
	scene._toggle_appearance_panel()
	if scene.appearance_panel.visible or not scene.source_panel.visible:
		_fail("Панель настроек не закрылась")
		return
	scene._loading_appearance = false

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
	var focus_button := scene.source_panel.find_child("FocusButton", true, false) as Button
	if focus_button == null:
		_fail("Кнопка режима просмотра отсутствует")
		return
	focus_button.pressed.emit()
	if not scene.focus_mode or scene.interface_layer.visible:
		_fail("Режим просмотра должен скрывать весь интерфейс")
		return
	scene.audio_controller.toggle_playback()
	if not scene.audio_controller.is_active():
		_fail("Звук должен запускаться без интерфейса")
		return
	var volume_key := InputEventKey.new()
	volume_key.keycode = KEY_DOWN
	volume_key.pressed = true
	scene._unhandled_input(volume_key)
	if not is_equal_approx(scene.audio_controller.get_volume_percent(), 90.0) or not scene.audio_controller.is_active():
		_fail("Клавиша вниз не меняет громкость в режиме просмотра")
		return
	volume_key.keycode = KEY_UP
	scene._unhandled_input(volume_key)
	if not is_equal_approx(scene.audio_controller.get_volume_percent(), 100.0):
		_fail("Клавиша вверх не возвращает громкость")
		return
	await create_timer(0.5).timeout
	if absf(scene.orb.position.x) > 0.02 or camera.position.z > 5.91:
		_fail("В режиме просмотра сфера должна быть по центру и ближе к камере")
		return
	if not scene.audio_controller.is_active():
		_fail("Скрытие панелей не должно останавливать звук")
		return
	mouse_down.position = Vector2(100.0, 350.0)
	scene._unhandled_input(mouse_down)
	motion.relative = Vector2(90.0, 0.0)
	scene._unhandled_input(motion)
	if scene.orb.rotation.is_zero_approx():
		_fail("Без панелей вращение должно работать в любой части окна")
		return
	scene._input(mouse_up)
	var reset_key := InputEventKey.new()
	reset_key.keycode = KEY_R
	reset_key.pressed = true
	scene._unhandled_input(reset_key)
	if not scene.orb.rotation.is_zero_approx() or not is_equal_approx(camera.position.z, 5.9):
		_fail("Сброс в режиме просмотра должен оставить сферу по центру")
		return
	var escape_key := InputEventKey.new()
	escape_key.keycode = KEY_ESCAPE
	escape_key.pressed = true
	scene._unhandled_input(escape_key)
	await create_timer(0.5).timeout
	if scene.focus_mode or not scene.interface_layer.visible or absf(scene.orb.position.x - 1.55) > 0.02 or not is_equal_approx(camera.position.z, 7.0):
		_fail("Esc должен вернуть панели и прежний ракурс")
		return
	var focus_key := InputEventKey.new()
	focus_key.keycode = KEY_F
	focus_key.pressed = true
	scene._unhandled_input(focus_key)
	if not scene.focus_mode:
		_fail("Клавиша F должна включать режим просмотра")
		return
	scene._unhandled_input(focus_key)
	if scene.focus_mode:
		_fail("Клавиша F должна возвращать интерфейс")
		return

	var original_stream: AudioStream = scene.audio_controller.player.stream
	if not scene.file_dialog.use_native_dialog or scene.file_dialog.filters[0].find("*.wav") < 0:
		_fail("Выбор аудио не использует системный диалог с общим фильтром")
		return
	scene._on_files_dropped(PackedStringArray(["unsupported.txt"]))
	if scene.playback_label.text.find("Перетащите файл") < 0:
		_fail("Неподдерживаемое перетаскивание не показало подсказку")
		return
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
	scene._on_files_dropped(PackedStringArray(["unsupported.txt", valid_path]))
	if scene.playback_label.text != "Звук воспроизводится":
		_fail("Успешная загрузка не очистила ошибку")
		return
	if scene.file_dialog.current_dir != valid_path.get_base_dir():
		_fail("Диалог не запомнил каталог последнего аудиофайла")
		return
	await process_frame
	scene.audio_controller.toggle_playback()
	if scene.playback_label.text != "Воспроизведение приостановлено":
		_fail("Пауза не отражена в интерфейсе")
		return

	print("PASS: шейдер, настройки, режим просмотра, ракурс и загрузка")
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

extends Node3D

const DEFAULT_CAMERA_DISTANCE := 7.0
const FOCUS_CAMERA_DISTANCE := 5.9
const DEFAULT_ORB_POSITION := Vector3(1.55, 0.0, 0.0)
const MIN_CAMERA_DISTANCE := 5.6
const MAX_CAMERA_DISTANCE := 9.0
const CAMERA_STEP := 0.5
const MAX_PITCH := 1.15
const DEFAULT_ACCENT := Color(0.76, 0.16, 0.92)
const DEFAULT_BACKGROUND := Color(0.024, 0.035, 0.069)
const DEFAULT_QUIET_COLOR := Color(0.08, 0.48, 1.0)
const DEFAULT_LOUD_COLOR := Color(1.0, 0.16, 0.22)
const DEFAULT_LOUDNESS_MIX := 0.45
const SETTINGS_FILENAME := "Audioforma.ini"
const DEFAULT_WAVE_DIRECTION := 4

@onready var orb: MeshInstance3D = $Orb
@onready var camera: Camera3D = $Camera3D
@onready var audio_controller: AudioController = $AudioController
@onready var orb_material: ShaderMaterial = orb.get_surface_override_material(0) as ShaderMaterial
@onready var halo_material: ShaderMaterial = $Orb/Halo.get_surface_override_material(0) as ShaderMaterial

var _reactive_materials: Array[ShaderMaterial] = []

var play_button: Button
var volume_slider: HSlider
var volume_value_label: Label
var seek_slider: HSlider
var position_label: Label
var duration_label: Label
var _seeking := false
var playback_label: Label
var status_panel: PanelContainer
var source_name_label: Label
var source_description_label: Label
var zoom_label: Label
var camera_reset_button: Button
var file_dialog: FileDialog
var spectrum_bars: Array[ProgressBar] = []
var mode_buttons: Array[Button] = []
var source_panel: PanelContainer
var appearance_panel: PanelContainer
var accent_picker: ColorPickerButton
var background_picker: ColorPickerButton
var quiet_picker: ColorPickerButton
var loud_picker: ColorPickerButton
var settings_path_override := ""
var appearance_sliders: Dictionary = {}
var wave_direction_picker: OptionButton
var appearance_save_label: Label
var _appearance_save_timer: Timer
var _loading_appearance := false
var _auto_rotation_factor := 1.0
var interface_layer: CanvasLayer
var focus_mode := false
var _camera_distance_before_focus := DEFAULT_CAMERA_DISTANCE
var _focus_tween: Tween
var dragging := false
var orbit_yaw := 0.0
var orbit_pitch := 0.0
var motion_time := 0.0
var deformation_mode := 0
var _bass_wave_slot := 0
var _beat_pulse := 0.0
var _shake_energy := 0.0


func _ready() -> void:
	_reactive_materials = [orb_material, halo_material]
	_appearance_save_timer = Timer.new()
	_appearance_save_timer.one_shot = true
	_appearance_save_timer.wait_time = 0.4
	_appearance_save_timer.timeout.connect(_save_appearance)
	add_child(_appearance_save_timer)
	_create_interface()
	get_window().files_dropped.connect(_on_files_dropped)
	_set_mode(0)
	_load_appearance()
	_apply_visual_settings()
	audio_controller.playback_changed.connect(_update_playback_interface)
	audio_controller.source_changed.connect(_update_source_interface)
	audio_controller.source_changed.connect(_reset_bass_waves)
	audio_controller.playback_seeked.connect(_on_playback_seeked)
	_update_source_interface()
	_update_playback_interface()


func _process(delta: float) -> void:
	if not dragging:
		orbit_yaw += delta * 0.12 * _auto_rotation_factor
		_update_orbit()
	var bands := audio_controller.get_spectrum_analysis(delta)
	var level := audio_controller.get_audio_level(delta)
	motion_time += delta
	var bass_hit := audio_controller.get_bass_hit()
	if bass_hit > 0.0:
		_register_bass_hit(bass_hit)
	_update_impact(delta)
	_apply_audio_state(bands, level)
	for index in range(3):
		spectrum_bars[index].value = bands[index] * 100.0
	_update_timeline()


func _apply_audio_state(bands: Vector3, level: float) -> void:
	for material in _reactive_materials:
		material.set_shader_parameter("bass", bands.x)
		material.set_shader_parameter("mid", bands.y)
		material.set_shader_parameter("high", bands.z)
		material.set_shader_parameter("level", level)
		material.set_shader_parameter("motion_time", motion_time)
		material.set_shader_parameter("beat_pulse", _beat_pulse)


func _register_bass_hit(strength: float) -> void:
	var suffix := "a" if _bass_wave_slot == 0 else "b"
	var direction_index := wave_direction_picker.selected
	if direction_index == 5:
		direction_index = randi_range(0, 4)
	var world_origin := Vector3.UP
	match direction_index:
		1:
			world_origin = Vector3.DOWN
		2:
			world_origin = Vector3.LEFT
		3, 4:
			world_origin = Vector3.RIGHT
	var local_origin := (orb.global_transform.basis.inverse() * world_origin).normalized()
	for material in _reactive_materials:
		material.set_shader_parameter("bass_hit_time_" + suffix, motion_time)
		material.set_shader_parameter("bass_hit_strength_" + suffix, strength)
		material.set_shader_parameter("bass_hit_origin_" + suffix, local_origin)
		material.set_shader_parameter("bass_hit_paired_" + suffix, 1.0 if direction_index == 4 else 0.0)
	_beat_pulse = maxf(_beat_pulse, strength)
	_shake_energy = maxf(_shake_energy, strength)
	_bass_wave_slot = 1 - _bass_wave_slot


func _update_impact(delta: float) -> void:
	_beat_pulse = maxf(0.0, _beat_pulse - delta * 4.5)
	_shake_energy = maxf(0.0, _shake_energy - delta * 6.0)
	var amplitude: float = 0.12 * _shake_energy * appearance_sliders["shake_strength"].value
	camera.position.x = sin(motion_time * 71.0) * amplitude
	camera.position.y = sin(motion_time * 113.0 + 0.8) * amplitude * 0.75


func _reset_bass_waves() -> void:
	_bass_wave_slot = 0
	_beat_pulse = 0.0
	_shake_energy = 0.0
	camera.position.x = 0.0
	camera.position.y = 0.0
	for material in _reactive_materials:
		for suffix in ["a", "b"]:
			material.set_shader_parameter("bass_hit_time_" + suffix, -10.0)
			material.set_shader_parameter("bass_hit_strength_" + suffix, 0.0)
			material.set_shader_parameter("bass_hit_paired_" + suffix, 0.0)
		material.set_shader_parameter("beat_pulse", 0.0)


func _set_mode(index: int) -> void:
	if index < 0 or index > 3:
		return
	deformation_mode = index
	for material in _reactive_materials:
		material.set_shader_parameter("deformation_mode", index)
	for button_index in range(mode_buttons.size()):
		mode_buttons[button_index].button_pressed = button_index == index


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
			dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			dragging = focus_mode or click.position.x > 420.0
		elif click.pressed and click.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-1.0)
		elif click.pressed and click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.0)
	elif event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		orbit_yaw += motion.relative.x * 0.008
		orbit_pitch = clampf(orbit_pitch + motion.relative.y * 0.008, -MAX_PITCH, MAX_PITCH)
		_update_orbit()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_F:
			_toggle_focus_mode()
		elif key.pressed and not key.echo and key.keycode == KEY_ESCAPE and focus_mode:
			_set_focus_mode(false)
		elif key.pressed and not key.echo and key.keycode == KEY_SPACE:
			audio_controller.toggle_playback()
		elif key.pressed and not key.echo and key.keycode == KEY_UP:
			_change_volume(10.0)
		elif key.pressed and not key.echo and key.keycode == KEY_DOWN:
			_change_volume(-10.0)
		elif key.pressed and not key.echo and key.keycode in [KEY_LEFT, KEY_RIGHT]:
			audio_controller.seek_to(audio_controller.get_position() + (-5.0 if key.keycode == KEY_LEFT else 5.0))
		elif key.pressed and not key.echo and key.keycode == KEY_R:
			_reset_view()
		elif key.pressed and not key.echo and key.keycode == KEY_S and not focus_mode:
			_toggle_appearance_panel()
		elif key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_4:
			_set_mode(key.keycode - KEY_1)


func _update_orbit() -> void:
	orb.rotation = Vector3(orbit_pitch, orbit_yaw, 0.0)


func _zoom_camera(direction: float) -> void:
	camera.position.z = clampf(camera.position.z + direction * CAMERA_STEP, MIN_CAMERA_DISTANCE, MAX_CAMERA_DISTANCE)
	zoom_label.text = "%d %%" % roundi(DEFAULT_CAMERA_DISTANCE / camera.position.z * 100.0)


func _reset_view() -> void:
	dragging = false
	orbit_yaw = 0.0
	orbit_pitch = 0.0
	camera.position.z = FOCUS_CAMERA_DISTANCE if focus_mode else DEFAULT_CAMERA_DISTANCE
	_shake_energy = 0.0
	camera.position.x = 0.0
	camera.position.y = 0.0
	_update_orbit()
	zoom_label.text = "%d %%" % roundi(DEFAULT_CAMERA_DISTANCE / camera.position.z * 100.0)


func _toggle_focus_mode() -> void:
	_set_focus_mode(not focus_mode)


func _set_focus_mode(enabled: bool) -> void:
	if focus_mode == enabled:
		return
	if _focus_tween != null and _focus_tween.is_running():
		_focus_tween.kill()
	focus_mode = enabled
	dragging = false
	if enabled:
		_camera_distance_before_focus = camera.position.z
		file_dialog.hide()
		appearance_panel.visible = false
		source_panel.visible = true
		interface_layer.visible = false
		camera.position.z = minf(camera.position.z, FOCUS_CAMERA_DISTANCE)
	else:
		interface_layer.visible = true
		camera.position.z = _camera_distance_before_focus
	zoom_label.text = "%d %%" % roundi(DEFAULT_CAMERA_DISTANCE / camera.position.z * 100.0)
	_focus_tween = create_tween()
	_focus_tween.set_trans(Tween.TRANS_CUBIC)
	_focus_tween.set_ease(Tween.EASE_OUT)
	_focus_tween.tween_property(orb, "position", Vector3.ZERO if enabled else DEFAULT_ORB_POSITION, 0.4)


func _create_interface() -> void:
	var layer := CanvasLayer.new()
	interface_layer = layer
	add_child(layer)

	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)

	var panel := PanelContainer.new()
	source_panel = panel
	screen.add_child(panel)
	panel.anchor_bottom = 1.0
	panel.offset_left = 24.0
	panel.offset_top = 24.0
	panel.offset_right = 390.0
	panel.offset_bottom = -24.0
	panel.add_theme_stylebox_override("panel", _panel_style())

	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 23)
	panel.add_child(padding)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	padding.add_child(column)

	column.add_child(_label("АУДИО\nФОРМА", 40, Color(0.94, 0.98, 1.0)))
	column.add_child(HSeparator.new())

	column.add_child(_label("ИСТОЧНИК ЗВУКА", 12, Color(0.42, 0.78, 0.9)))
	source_name_label = _label("", 21, Color(0.92, 0.97, 1.0))
	source_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	source_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(source_name_label)
	source_description_label = _label("", 13, Color(0.55, 0.65, 0.76))
	column.add_child(source_description_label)

	var source_buttons := HBoxContainer.new()
	source_buttons.add_theme_constant_override("separation", 9)
	column.add_child(source_buttons)
	var open_button := _button("Открыть аудио", false)
	open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_button.pressed.connect(_show_file_dialog)
	source_buttons.add_child(open_button)
	var demo_button := _button("Демо", false)
	demo_button.custom_minimum_size.x = 90.0
	demo_button.pressed.connect(audio_controller.load_demo)
	source_buttons.add_child(demo_button)

	play_button = _button("▶  Воспроизвести", true)
	play_button.custom_minimum_size.y = 50.0
	play_button.pressed.connect(audio_controller.toggle_playback)
	column.add_child(play_button)
	var timeline := HBoxContainer.new()
	timeline.custom_minimum_size.y = 30.0
	timeline.add_theme_constant_override("separation", 7)
	column.add_child(timeline)
	position_label = _label("0:00", 12, Color(0.67, 0.85, 0.9))
	position_label.custom_minimum_size.x = 44.0
	position_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timeline.add_child(position_label)
	seek_slider = HSlider.new()
	seek_slider.name = "SeekSlider"
	seek_slider.step = 0.1
	seek_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seek_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seek_slider.tooltip_text = "Перемотка · ←/→ — на 5 секунд, в том числе в режиме просмотра"
	seek_slider.drag_started.connect(func() -> void: _seeking = true)
	seek_slider.drag_ended.connect(_on_seek_drag_ended)
	seek_slider.value_changed.connect(_on_seek_value_changed)
	timeline.add_child(seek_slider)
	duration_label = _label("0:00", 12, Color(0.55, 0.65, 0.76))
	duration_label.custom_minimum_size.x = 44.0
	duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	duration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timeline.add_child(duration_label)
	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 6)
	column.add_child(volume_row)
	var volume_title := _label("ГРОМКОСТЬ", 11, Color(0.42, 0.78, 0.9))
	volume_title.custom_minimum_size.x = 76.0
	volume_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	volume_row.add_child(volume_title)
	var quieter_button := _button("−", false)
	quieter_button.name = "VolumeDownButton"
	quieter_button.custom_minimum_size = Vector2(30.0, 30.0)
	quieter_button.add_theme_font_size_override("font_size", 14)
	quieter_button.pressed.connect(_change_volume.bind(-10.0))
	volume_row.add_child(quieter_button)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = 100.0
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_slider.tooltip_text = "↑/↓ — изменить громкость, в том числе в режиме просмотра"
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_row.add_child(volume_slider)
	var louder_button := _button("+", false)
	louder_button.name = "VolumeUpButton"
	louder_button.custom_minimum_size = Vector2(30.0, 30.0)
	louder_button.add_theme_font_size_override("font_size", 14)
	louder_button.pressed.connect(_change_volume.bind(10.0))
	volume_row.add_child(louder_button)
	volume_value_label = _label("100 %", 12, Color(0.92, 0.97, 1.0))
	volume_value_label.custom_minimum_size.x = 42.0
	volume_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	volume_row.add_child(volume_value_label)

	status_panel = PanelContainer.new()
	status_panel.custom_minimum_size.y = 44.0
	column.add_child(status_panel)
	var status_padding := MarginContainer.new()
	status_padding.add_theme_constant_override("margin_left", 12)
	status_padding.add_theme_constant_override("margin_right", 12)
	status_padding.add_theme_constant_override("margin_top", 6)
	status_padding.add_theme_constant_override("margin_bottom", 6)
	status_panel.add_child(status_padding)
	playback_label = _label("", 13, Color(0.56, 0.7, 0.77))
	playback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_padding.add_child(playback_label)

	column.add_child(_label("СПЕКТР В РЕАЛЬНОМ ВРЕМЕНИ", 12, Color(0.42, 0.78, 0.9)))
	var spectrum_group := VBoxContainer.new()
	spectrum_group.add_theme_constant_override("separation", 5)
	column.add_child(spectrum_group)
	_add_spectrum_row(spectrum_group, "БАСЫ", Color(0.35, 0.83, 0.91))
	_add_spectrum_row(spectrum_group, "СЕРЕДИНА", Color(0.53, 0.68, 1.0))
	_add_spectrum_row(spectrum_group, "ВЫСОКИЕ", Color(0.77, 0.49, 0.96))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var view_actions := HBoxContainer.new()
	view_actions.add_theme_constant_override("separation", 8)
	column.add_child(view_actions)
	var appearance_button := _button("Настроить вид", false)
	appearance_button.name = "AppearanceButton"
	appearance_button.tooltip_text = "S — открыть настройки внешнего вида"
	appearance_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	appearance_button.pressed.connect(_toggle_appearance_panel)
	view_actions.add_child(appearance_button)
	var focus_button := _button("Просмотр · F", false)
	focus_button.name = "FocusButton"
	focus_button.tooltip_text = "Скрыть панели. F или Esc — вернуть управление."
	focus_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_button.pressed.connect(_toggle_focus_mode)
	view_actions.add_child(focus_button)
	_create_appearance_panel(screen)

	_create_camera_panel(screen)

	var mode_panel := PanelContainer.new()
	screen.add_child(mode_panel)
	mode_panel.anchor_left = 1.0
	mode_panel.anchor_right = 1.0
	mode_panel.anchor_top = 1.0
	mode_panel.anchor_bottom = 1.0
	mode_panel.offset_left = -624.0
	mode_panel.offset_right = -28.0
	mode_panel.offset_top = -120.0
	mode_panel.offset_bottom = -24.0
	mode_panel.add_theme_stylebox_override("panel", _panel_style())
	var mode_padding := MarginContainer.new()
	mode_padding.add_theme_constant_override("margin_left", 18)
	mode_padding.add_theme_constant_override("margin_right", 18)
	mode_padding.add_theme_constant_override("margin_top", 12)
	mode_padding.add_theme_constant_override("margin_bottom", 12)
	mode_panel.add_child(mode_padding)
	var mode_column := VBoxContainer.new()
	mode_column.add_theme_constant_override("separation", 6)
	mode_padding.add_child(mode_column)
	mode_column.add_child(_label("РЕЖИМ ДЕФОРМАЦИИ  ·  КЛАВИШИ 1–4", 11, Color(0.54, 0.77, 0.87)))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 7)
	mode_column.add_child(mode_row)
	var mode_group := ButtonGroup.new()
	for index in range(4):
		var mode_button := _button(["Все", "Пульс", "Волны", "Рябь"][index], false)
		mode_button.toggle_mode = true
		mode_button.button_group = mode_group
		mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_button.custom_minimum_size.y = 35.0
		mode_button.add_theme_stylebox_override("pressed", _button_style(Color(0.35, 0.83, 0.91)))
		mode_button.add_theme_color_override("font_pressed_color", Color(0.04, 0.12, 0.19))
		mode_button.pressed.connect(_set_mode.bind(index))
		mode_row.add_child(mode_button)
		mode_buttons.append(mode_button)

	file_dialog = FileDialog.new()
	file_dialog.title = "Выберите аудиофайл"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.use_native_dialog = true
	file_dialog.filters = PackedStringArray(["*.mp3,*.wav,*.ogg ; Аудиофайлы", "*.mp3 ; MP3", "*.wav ; WAV", "*.ogg ; OGG Vorbis"])
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)


func _create_appearance_panel(screen: Control) -> void:
	appearance_panel = PanelContainer.new()
	appearance_panel.visible = false
	appearance_panel.anchor_bottom = 1.0
	appearance_panel.offset_left = 24.0
	appearance_panel.offset_top = 24.0
	appearance_panel.offset_right = 390.0
	appearance_panel.offset_bottom = -24.0
	appearance_panel.add_theme_stylebox_override("panel", _panel_style())
	screen.add_child(appearance_panel)

	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 18)
	appearance_panel.add_child(padding)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	padding.add_child(column)
	column.add_child(_label("НАСТРОЙКА ВИДА", 12, Color(0.42, 0.78, 0.9)))
	column.add_child(_label("Свет и форма", 27, Color(0.94, 0.98, 1.0)))
	column.add_child(_label("Изменения видны во время воспроизведения.", 12, Color(0.61, 0.72, 0.81)))
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 7)
	scroll.add_child(form)

	var accent_row := HBoxContainer.new()
	form.add_child(accent_row)
	var accent_label := _label("Цвет контура", 13, Color(0.8, 0.9, 0.96))
	accent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accent_row.add_child(accent_label)
	accent_picker = ColorPickerButton.new()
	accent_picker.color = DEFAULT_ACCENT
	accent_picker.custom_minimum_size = Vector2(73.0, 34.0)
	accent_picker.color_changed.connect(_on_appearance_changed)
	accent_row.add_child(accent_picker)

	var background_row := HBoxContainer.new()
	form.add_child(background_row)
	var background_label := _label("Цвет фона", 13, Color(0.8, 0.9, 0.96))
	background_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	background_row.add_child(background_label)
	background_picker = ColorPickerButton.new()
	background_picker.color = DEFAULT_BACKGROUND
	background_picker.custom_minimum_size = Vector2(73.0, 34.0)
	background_picker.color_changed.connect(_on_appearance_changed)
	background_row.add_child(background_picker)

	quiet_picker = _add_color_picker(form, "Тихий звук", DEFAULT_QUIET_COLOR)
	loud_picker = _add_color_picker(form, "Громкий звук", DEFAULT_LOUD_COLOR)
	_add_appearance_slider(form, "loudness_color_mix", "Цвет от громкости", 0.0, 1.0, DEFAULT_LOUDNESS_MIX)
	_add_appearance_slider(form, "spectrum_mix", "Реакция цвета на спектр", 0.0, 1.0, 0.6)
	_add_appearance_slider(form, "glow_strength", "Свечение", 0.0, 2.0, 1.0)
	_add_appearance_slider(form, "outline_width", "Ширина контура", 0.5, 2.0, 1.0)
	_add_appearance_slider(form, "shape_strength", "Деформация", 0.0, 2.0, 1.0)
	_add_appearance_slider(form, "bass_pulse_strength", "Пульс баса", 0.0, 2.0, 1.0)
	_add_appearance_slider(form, "beat_pulse_strength", "Рост на ударе", 0.0, 2.0, 1.0)
	_add_appearance_slider(form, "bass_wave_strength", "Басовая волна", 0.0, 2.0, 1.0)
	var direction_row := HBoxContainer.new()
	direction_row.add_theme_constant_override("separation", 8)
	form.add_child(direction_row)
	var direction_label := _label("Направление волны", 12, Color(0.72, 0.85, 0.91))
	direction_label.custom_minimum_size.x = 153.0
	direction_row.add_child(direction_label)
	wave_direction_picker = OptionButton.new()
	wave_direction_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option in ["Сверху вниз", "Снизу вверх", "Слева направо", "Справа налево", "В стороны", "Случайно"]:
		wave_direction_picker.add_item(option)
	wave_direction_picker.selected = DEFAULT_WAVE_DIRECTION
	wave_direction_picker.item_selected.connect(func(_index: int) -> void: _queue_save_appearance())
	direction_row.add_child(wave_direction_picker)
	_add_appearance_slider(form, "mid_wave_strength", "Средние волны", 0.0, 2.0, 1.0)
	_add_appearance_slider(form, "high_ripple_strength", "Высокая рябь", 0.0, 2.0, 1.0)
	_add_appearance_slider(form, "beat_sensitivity", "Чуткость баса", 0.5, 2.0, 1.0)
	_add_appearance_slider(form, "shake_strength", "Тряска камеры", 0.0, 2.0, 1.0)
	_add_appearance_slider(form, "motion_speed", "Скорость движения", 0.25, 2.0, 1.0)
	_add_appearance_slider(form, "rotation_speed", "Автовращение", 0.0, 2.0, 1.0)
	appearance_save_label = _label("Настройки сохраняются автоматически.", 11, Color(0.61, 0.72, 0.81))
	column.add_child(appearance_save_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	var reset_button := _button("Сбросить", false)
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.pressed.connect(_reset_appearance)
	actions.add_child(reset_button)
	var back_button := _button("Готово", true)
	back_button.name = "DoneButton"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.pressed.connect(_toggle_appearance_panel)
	actions.add_child(back_button)


func _add_color_picker(parent: VBoxContainer, title: String, initial: Color) -> ColorPickerButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var title_label := _label(title, 13, Color(0.8, 0.9, 0.96))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	var picker := ColorPickerButton.new()
	picker.color = initial
	picker.custom_minimum_size = Vector2(73.0, 34.0)
	picker.color_changed.connect(_on_appearance_changed)
	row.add_child(picker)
	return picker


func _add_appearance_slider(parent: VBoxContainer, key: String, title: String, minimum: float, maximum: float, initial: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var title_label := _label(title, 12, Color(0.72, 0.85, 0.91))
	title_label.custom_minimum_size.x = 153.0
	row.add_child(title_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := _label("%.1f" % initial, 12, Color(0.93, 0.98, 1.0))
	value_label.custom_minimum_size.x = 29.0
	row.add_child(value_label)
	appearance_sliders[key] = slider
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%.1f" % value
		_apply_visual_settings()
		_queue_save_appearance()
	)


func _on_appearance_changed(_color: Color) -> void:
	_apply_visual_settings()
	_queue_save_appearance()


func _apply_visual_settings() -> void:
	for material in _reactive_materials:
		material.set_shader_parameter("accent_color", accent_picker.color)
		material.set_shader_parameter("quiet_color", quiet_picker.color)
		material.set_shader_parameter("loud_color", loud_picker.color)
		for key in appearance_sliders:
			if key != "rotation_speed" and key != "beat_sensitivity" and key != "shake_strength":
				material.set_shader_parameter(key, appearance_sliders[key].value)
	_auto_rotation_factor = appearance_sliders["rotation_speed"].value
	audio_controller.set_bass_sensitivity(appearance_sliders["beat_sensitivity"].value)
	var environment := ($WorldEnvironment as WorldEnvironment).environment
	environment.background_color = background_picker.color


func _reset_appearance() -> void:
	accent_picker.color = DEFAULT_ACCENT
	background_picker.color = DEFAULT_BACKGROUND
	quiet_picker.color = DEFAULT_QUIET_COLOR
	loud_picker.color = DEFAULT_LOUD_COLOR
	for key in appearance_sliders:
		var defaults := {"spectrum_mix": 0.6, "loudness_color_mix": DEFAULT_LOUDNESS_MIX}
		appearance_sliders[key].value = defaults.get(key, 1.0)
	wave_direction_picker.selected = DEFAULT_WAVE_DIRECTION
	_apply_visual_settings()
	_queue_save_appearance()


func _toggle_appearance_panel() -> void:
	appearance_panel.visible = not appearance_panel.visible
	source_panel.visible = not appearance_panel.visible
	if not appearance_panel.visible and _appearance_save_timer.time_left > 0.0:
		_appearance_save_timer.stop()
		_save_appearance()


func _queue_save_appearance() -> void:
	if not _loading_appearance:
		_appearance_save_timer.start()


func _appearance_settings_path() -> String:
	if not settings_path_override.is_empty():
		return settings_path_override
	var project_root := ProjectSettings.globalize_path("res://")
	if FileAccess.file_exists(project_root.path_join("project.godot")):
		return project_root.path_join(".local").path_join(SETTINGS_FILENAME)
	return OS.get_executable_path().get_base_dir().path_join(SETTINGS_FILENAME)


func _load_appearance() -> void:
	var settings := ConfigFile.new()
	if settings.load(_appearance_settings_path()) != OK:
		return
	_loading_appearance = true
	var accent: Variant = settings.get_value("appearance", "accent", DEFAULT_ACCENT)
	var background: Variant = settings.get_value("appearance", "background", DEFAULT_BACKGROUND)
	if accent is Color:
		accent_picker.color = accent
	if background is Color:
		background_picker.color = background
	var quiet: Variant = settings.get_value("appearance", "quiet_color", DEFAULT_QUIET_COLOR)
	var loud: Variant = settings.get_value("appearance", "loud_color", DEFAULT_LOUD_COLOR)
	if quiet is Color:
		quiet_picker.color = quiet
	if loud is Color:
		loud_picker.color = loud
	var volume: Variant = settings.get_value("audio", "volume_percent", 100.0)
	if volume is float or volume is int:
		volume_slider.value = clampf(volume, 0.0, 100.0)
	for key in appearance_sliders:
		var value: Variant = settings.get_value("appearance", key, appearance_sliders[key].value)
		if value is float or value is int:
			appearance_sliders[key].value = value
	var direction: Variant = settings.get_value("appearance", "wave_direction", DEFAULT_WAVE_DIRECTION)
	if direction is int and direction >= 0 and direction < wave_direction_picker.item_count:
		wave_direction_picker.selected = direction
	_loading_appearance = false


func _save_appearance() -> void:
	var settings := ConfigFile.new()
	settings.set_value("appearance", "accent", accent_picker.color)
	settings.set_value("appearance", "background", background_picker.color)
	settings.set_value("appearance", "quiet_color", quiet_picker.color)
	settings.set_value("appearance", "loud_color", loud_picker.color)
	for key in appearance_sliders:
		settings.set_value("appearance", key, appearance_sliders[key].value)
	settings.set_value("appearance", "wave_direction", wave_direction_picker.selected)
	settings.set_value("audio", "volume_percent", volume_slider.value)
	var path := _appearance_settings_path()
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error == OK:
		error = settings.save(path)
	if error != OK:
		appearance_save_label.text = "Не удалось сохранить настройки."
		appearance_save_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	else:
		appearance_save_label.text = "Настройки сохранены рядом с приложением."


func _create_camera_panel(screen: Control) -> void:
	var camera_panel := PanelContainer.new()
	screen.add_child(camera_panel)
	camera_panel.anchor_left = 1.0
	camera_panel.anchor_right = 1.0
	camera_panel.offset_left = -278.0
	camera_panel.offset_right = -28.0
	camera_panel.offset_top = 80.0
	camera_panel.offset_bottom = 191.0
	camera_panel.add_theme_stylebox_override("panel", _panel_style())
	var camera_padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		camera_padding.add_theme_constant_override("margin_" + side, 12)
	camera_panel.add_child(camera_padding)
	var camera_column := VBoxContainer.new()
	camera_column.add_theme_constant_override("separation", 5)
	camera_padding.add_child(camera_column)
	camera_column.add_child(_label("РАКУРС", 11, Color(0.54, 0.77, 0.87)))
	var camera_row := HBoxContainer.new()
	camera_row.add_theme_constant_override("separation", 6)
	camera_column.add_child(camera_row)
	var zoom_out_button := _button("−", false)
	zoom_out_button.custom_minimum_size = Vector2(35.0, 33.0)
	zoom_out_button.pressed.connect(_zoom_camera.bind(1.0))
	camera_row.add_child(zoom_out_button)
	zoom_label = _label("100 %", 13, Color(0.91, 0.96, 1.0))
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zoom_label.custom_minimum_size.x = 53.0
	camera_row.add_child(zoom_label)
	var zoom_in_button := _button("+", false)
	zoom_in_button.custom_minimum_size = Vector2(35.0, 33.0)
	zoom_in_button.pressed.connect(_zoom_camera.bind(-1.0))
	camera_row.add_child(zoom_in_button)
	camera_reset_button = _button("Сброс", false)
	camera_reset_button.custom_minimum_size.y = 33.0
	camera_reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camera_reset_button.pressed.connect(_reset_view)
	camera_row.add_child(camera_reset_button)
	camera_column.add_child(_label("Колесо — масштаб  ·  R — сброс", 11, Color(0.63, 0.73, 0.83)))


func _add_spectrum_row(parent: VBoxContainer, title: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	parent.add_child(row)
	var name_label := _label(title, 11, Color(0.63, 0.73, 0.83))
	name_label.custom_minimum_size.x = 78.0
	row.add_child(name_label)
	var meter := ProgressBar.new()
	meter.max_value = 100.0
	meter.show_percentage = false
	meter.custom_minimum_size.y = 12.0
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.add_theme_stylebox_override("background", _button_style(Color(0.11, 0.18, 0.26)))
	meter.add_theme_stylebox_override("fill", _button_style(color))
	row.add_child(meter)
	spectrum_bars.append(meter)


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 43.0
	button.add_theme_font_size_override("font_size", 15)
	var base := Color(0.35, 0.83, 0.91) if primary else Color(0.14, 0.25, 0.34)
	var hover := Color(0.54, 0.92, 0.98) if primary else Color(0.19, 0.33, 0.44)
	var pressed := Color(0.23, 0.66, 0.74) if primary else Color(0.11, 0.2, 0.29)
	button.add_theme_color_override("font_color", Color(0.04, 0.12, 0.19) if primary else Color(0.8, 0.92, 0.97))
	button.add_theme_color_override("font_hover_color", Color(0.04, 0.12, 0.19) if primary else Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(base))
	button.add_theme_stylebox_override("hover", _button_style(hover))
	button.add_theme_stylebox_override("pressed", _button_style(pressed))
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.075, 0.13, 0.96)
	style.border_color = Color(0.17, 0.31, 0.43, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(22)
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(11)
	return style


func _show_file_dialog() -> void:
	file_dialog.popup_centered_ratio(0.72)


func _change_volume(amount: float) -> void:
	volume_slider.value = clampf(volume_slider.value + amount, 0.0, 100.0)


func _on_volume_changed(value: float) -> void:
	audio_controller.set_volume_percent(value)
	volume_value_label.text = "%d %%" % roundi(value)
	_queue_save_appearance()


func _on_file_selected(path: String) -> void:
	if not audio_controller.load_file(path):
		_set_status(audio_controller.last_error, true)
	else:
		file_dialog.current_dir = path.get_base_dir()


func _on_files_dropped(files: PackedStringArray) -> void:
	for path in files:
		if path.get_extension().to_lower() in ["mp3", "wav", "ogg"]:
			_on_file_selected(path)
			return
	_set_status("Перетащите файл MP3, WAV или OGG Vorbis.", true)


func _update_source_interface() -> void:
	source_name_label.text = audio_controller.source_name
	source_name_label.tooltip_text = audio_controller.source_name
	source_description_label.text = audio_controller.source_description
	_seeking = false
	_update_timeline()


func _update_playback_interface() -> void:
	var active := audio_controller.is_active()
	var paused := audio_controller.player.stream_paused
	play_button.text = "Ⅱ  Приостановить" if active else ("▶  Продолжить" if paused else "▶  Воспроизвести")
	_set_status("Звук воспроизводится" if active else ("Воспроизведение приостановлено" if paused else "Готово к воспроизведению"), false)
	_update_timeline()


func _update_timeline() -> void:
	var duration := audio_controller.get_duration()
	# Смена пределов Range может изменить value; это не пользовательская перемотка.
	seek_slider.set_block_signals(true)
	seek_slider.editable = duration > 0.0
	seek_slider.max_value = maxf(duration, 0.1)
	duration_label.text = _format_time(duration)
	if not _seeking:
		var position := audio_controller.get_position()
		seek_slider.set_value_no_signal(position)
		position_label.text = _format_time(position)
	seek_slider.set_block_signals(false)


func _format_time(seconds: float) -> String:
	var total := maxi(0, floori(seconds))
	return "%d:%02d" % [total / 60, total % 60]


func _on_seek_value_changed(value: float) -> void:
	position_label.text = _format_time(value)
	if not _seeking and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		audio_controller.seek_to(value)


func _on_seek_drag_ended(value_changed: bool) -> void:
	_seeking = false
	if value_changed:
		audio_controller.seek_to(seek_slider.value)
	_update_timeline()


func _on_playback_seeked() -> void:
	_reset_bass_waves()
	_apply_audio_state(Vector3.ZERO, 0.0)
	for bar in spectrum_bars:
		bar.value = 0.0
	_update_timeline()


func _set_status(message: String, is_error: bool) -> void:
	playback_label.text = message
	playback_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.68) if is_error else Color(0.67, 0.85, 0.9))
	status_panel.add_theme_stylebox_override("panel", _button_style(Color(0.29, 0.1, 0.17) if is_error else Color(0.07, 0.17, 0.23)))

extends Node3D

@onready var orb: MeshInstance3D = $Orb
@onready var audio_controller: AudioController = $AudioController
@onready var orb_material: ShaderMaterial = orb.get_surface_override_material(0) as ShaderMaterial

var play_button: Button
var playback_label: Label
var source_name_label: Label
var source_description_label: Label
var file_dialog: FileDialog
var spectrum_bars: Array[ProgressBar] = []
var mode_buttons: Array[Button] = []
var dragging := false
var motion_time := 0.0
var deformation_mode := 0


func _ready() -> void:
	_create_interface()
	_set_mode(0)
	audio_controller.playback_changed.connect(_update_playback_interface)
	audio_controller.source_changed.connect(_update_source_interface)
	_update_source_interface()
	_update_playback_interface()


func _process(delta: float) -> void:
	if not dragging:
		orb.rotate_y(delta * 0.12)
	var bands := audio_controller.get_spectrum_analysis(delta)
	var level := audio_controller.get_audio_level(delta)
	motion_time += delta
	_apply_audio_state(bands, level)
	for index in range(3):
		spectrum_bars[index].value = bands[index] * 100.0


func _apply_audio_state(bands: Vector3, level: float) -> void:
	orb_material.set_shader_parameter("bass", bands.x)
	orb_material.set_shader_parameter("mid", bands.y)
	orb_material.set_shader_parameter("high", bands.z)
	orb_material.set_shader_parameter("level", level)
	orb_material.set_shader_parameter("motion_time", motion_time)


func _set_mode(index: int) -> void:
	if index < 0 or index > 3:
		return
	deformation_mode = index
	orb_material.set_shader_parameter("deformation_mode", index)
	for button_index in range(mode_buttons.size()):
		mode_buttons[button_index].button_pressed = button_index == index


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			dragging = click.pressed and click.position.x > 420.0
	elif event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		orb.rotate_y(motion.relative.x * 0.008)
		orb.rotate_x(motion.relative.y * 0.008)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_SPACE:
			audio_controller.toggle_playback()
		elif key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_4:
			_set_mode(key.keycode - KEY_1)


func _create_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)

	var panel := PanelContainer.new()
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
	column.add_theme_constant_override("separation", 11)
	padding.add_child(column)

	column.add_child(_label("ПРОГРАММИРОВАНИЕ ГРАФИКИ И ЗВУКА", 11, Color(0.42, 0.78, 0.9)))
	column.add_child(_label("АУДИО\nФОРМА", 40, Color(0.94, 0.98, 1.0)))
	column.add_child(_label("Музыка обретает форму в трёхмерном пространстве.", 15, Color(0.61, 0.72, 0.81)))
	column.add_child(HSeparator.new())

	column.add_child(_label("ИСТОЧНИК ЗВУКА", 12, Color(0.42, 0.78, 0.9)))
	source_name_label = _label("", 21, Color(0.92, 0.97, 1.0))
	column.add_child(source_name_label)
	source_description_label = _label("", 13, Color(0.55, 0.65, 0.76))
	column.add_child(source_description_label)

	var source_buttons := HBoxContainer.new()
	source_buttons.add_theme_constant_override("separation", 9)
	column.add_child(source_buttons)
	var open_button := _button("Выбрать файл", false)
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

	playback_label = _label("", 13, Color(0.56, 0.7, 0.77))
	column.add_child(playback_label)

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
	column.add_child(_label("Пробел — воспроизведение · Мышь — вращение", 12, Color(0.63, 0.73, 0.83)))

	var corner := _label("3D  /  AUDIO", 12, Color(0.46, 0.68, 0.79))
	corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	screen.add_child(corner)
	corner.anchor_left = 1.0
	corner.anchor_right = 1.0
	corner.offset_left = -200.0
	corner.offset_right = -28.0
	corner.offset_top = 32.0
	corner.offset_bottom = 60.0

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
	file_dialog.filters = PackedStringArray(["*.mp3 ; MP3", "*.wav ; WAV", "*.ogg ; OGG Vorbis"])
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)


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


func _on_file_selected(path: String) -> void:
	if not audio_controller.load_file(path):
		playback_label.text = audio_controller.last_error
		playback_label.add_theme_color_override("font_color", Color(1.0, 0.53, 0.53))


func _update_source_interface() -> void:
	source_name_label.text = audio_controller.source_name
	source_description_label.text = audio_controller.source_description


func _update_playback_interface() -> void:
	var active := audio_controller.is_active()
	play_button.text = "Ⅱ  Приостановить" if active else "▶  Воспроизвести"
	playback_label.text = "Звук воспроизводится" if active else "Готово к воспроизведению"
	playback_label.add_theme_color_override("font_color", Color(0.56, 0.7, 0.77))

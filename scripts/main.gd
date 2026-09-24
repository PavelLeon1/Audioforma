extends Node3D

@onready var orb: MeshInstance3D = $Orb
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

var play_button: Button
var playback_label: Label
var dragging := false


func _ready() -> void:
	audio_player.finished.connect(_on_audio_finished)
	_create_interface()


func _process(delta: float) -> void:
	if not dragging:
		orb.rotate_y(delta * 0.12)


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
			_toggle_playback()


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
		padding.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(padding)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 17)
	padding.add_child(column)

	var eyebrow := _label("ПРОГРАММИРОВАНИЕ ГРАФИКИ И ЗВУКА", 11, Color(0.42, 0.78, 0.9))
	column.add_child(eyebrow)
	column.add_child(_label("АУДИО\nФОРМА", 43, Color(0.94, 0.98, 1.0)))
	column.add_child(_label("Музыка обретает форму в трёхмерном пространстве.", 16, Color(0.61, 0.72, 0.81)))

	var divider := HSeparator.new()
	column.add_child(divider)

	column.add_child(_label("ДЕМОНСТРАЦИЯ", 12, Color(0.42, 0.78, 0.9)))
	column.add_child(_label("Спектральный этюд", 22, Color(0.92, 0.97, 1.0)))
	column.add_child(_label("Авторский аудиофрагмент · 24 секунды", 13, Color(0.55, 0.65, 0.76)))

	play_button = Button.new()
	play_button.text = "▶  Воспроизвести"
	play_button.custom_minimum_size = Vector2(0, 55)
	play_button.add_theme_font_size_override("font_size", 17)
	play_button.add_theme_color_override("font_color", Color(0.04, 0.12, 0.19))
	play_button.add_theme_color_override("font_hover_color", Color(0.04, 0.12, 0.19))
	play_button.add_theme_stylebox_override("normal", _button_style(Color(0.35, 0.83, 0.91)))
	play_button.add_theme_stylebox_override("hover", _button_style(Color(0.54, 0.92, 0.98)))
	play_button.add_theme_stylebox_override("pressed", _button_style(Color(0.23, 0.66, 0.74)))
	play_button.pressed.connect(_toggle_playback)
	column.add_child(play_button)

	playback_label = _label("Готово к воспроизведению", 13, Color(0.56, 0.7, 0.77))
	column.add_child(playback_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	column.add_child(_label("УПРАВЛЕНИЕ", 12, Color(0.42, 0.78, 0.9)))
	column.add_child(_label("Пробел — воспроизвести или приостановить\nМышь — вращать объект", 14, Color(0.63, 0.73, 0.83)))

	var corner := _label("3D  /  AUDIO", 12, Color(0.46, 0.68, 0.79))
	corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	screen.add_child(corner)
	corner.anchor_left = 1.0
	corner.anchor_right = 1.0
	corner.offset_left = -200.0
	corner.offset_right = -28.0
	corner.offset_top = 32.0
	corner.offset_bottom = 60.0


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


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
	style.set_corner_radius_all(13)
	return style


func _toggle_playback() -> void:
	if audio_player.playing:
		audio_player.stream_paused = not audio_player.stream_paused
	else:
		audio_player.play()
	_update_playback_interface()


func _update_playback_interface() -> void:
	var active := audio_player.playing and not audio_player.stream_paused
	play_button.text = "Ⅱ  Приостановить" if active else "▶  Воспроизвести"
	playback_label.text = "Звучит демонстрационный трек" if active else "Готово к воспроизведению"


func _on_audio_finished() -> void:
	_update_playback_interface()

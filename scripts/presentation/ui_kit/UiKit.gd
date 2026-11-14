class_name UiKit
extends RefCounted
## Общий визуальный язык интерфейса: тёмное дерево, золотые акценты, кремовый текст.
## Если текстура ещё не импортирована или отсутствует, используются запасные StyleBoxFlat —
## интерфейс остаётся читаемым и рабочим.


const CREAM: Color = Color(0.98, 0.93, 0.8)
const GOLD: Color = Color(1.0, 0.82, 0.38)
const INK: Color = Color(0.25, 0.16, 0.1)
const WOOD_DARK: Color = Color(0.24, 0.15, 0.1)
const GREEN: Color = Color(0.5, 0.85, 0.4)
const RED: Color = Color(0.95, 0.45, 0.38)

const FONT_PATH: String = "res://assets/fonts/Lora.ttf"

static var _tex_cache: Dictionary = {}


## Безопасная загрузка текстуры: null, если файла нет или он не импортирован.
static func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_tex_cache[path] = texture
	return texture


static func ui_tex(name: String) -> Texture2D:
	return tex("res://assets/ui/%s.png" % name)


## Рамка из 9-patch текстуры (или запасная плоская рамка).
static func box(texture_name: String, margin: int, fallback: Color, content_margin: int = 12) -> StyleBox:
	var texture: Texture2D = ui_tex(texture_name)
	if texture != null:
		var sb := StyleBoxTexture.new()
		sb.texture = texture
		sb.texture_margin_left = margin
		sb.texture_margin_right = margin
		sb.texture_margin_top = margin
		sb.texture_margin_bottom = margin
		sb.content_margin_left = content_margin
		sb.content_margin_right = content_margin
		sb.content_margin_top = content_margin
		sb.content_margin_bottom = content_margin
		return sb
	var flat := StyleBoxFlat.new()
	flat.bg_color = fallback
	flat.border_color = GOLD.darkened(0.2)
	flat.set_border_width_all(3)
	flat.set_corner_radius_all(14)
	flat.content_margin_left = content_margin
	flat.content_margin_right = content_margin
	flat.content_margin_top = content_margin
	flat.content_margin_bottom = content_margin
	return flat


static func wood_panel(content_margin: int = 16) -> StyleBox:
	return box("panel_wood", 28, Color(0.32, 0.2, 0.13), content_margin)


static func dark_panel(content_margin: int = 16) -> StyleBox:
	return box("panel_wood_dark", 28, Color(0.22, 0.14, 0.1), content_margin)


static func parchment_panel(content_margin: int = 16) -> StyleBox:
	return box("panel_parchment", 24, Color(0.93, 0.86, 0.7), content_margin)


## Общая тема для всех экранов.
static func make_theme() -> Theme:
	var theme := Theme.new()
	var font: Font = null
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH) as Font
	if font != null:
		theme.default_font = font
	theme.default_font_size = 20

	theme.set_stylebox("normal", "Button", box("btn_normal", 18, Color(0.45, 0.28, 0.17), 10))
	theme.set_stylebox("hover", "Button", box("btn_hover", 18, Color(0.55, 0.35, 0.2), 10))
	theme.set_stylebox("pressed", "Button", box("btn_pressed", 18, Color(0.3, 0.19, 0.12), 10))
	theme.set_stylebox("disabled", "Button", box("btn_disabled", 18, Color(0.25, 0.22, 0.2), 10))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", Color(1, 1, 0.9))
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color(0.6, 0.55, 0.48))
	theme.set_color("font_outline_color", "Button", Color(0.15, 0.08, 0.04))
	theme.set_constant("outline_size", "Button", 3)
	theme.set_font_size("font_size", "Button", 22)

	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_outline_color", "Label", Color(0.12, 0.07, 0.04, 0.9))
	theme.set_constant("outline_size", "Label", 3)
	theme.set_stylebox("panel", "PanelContainer", wood_panel())

	# Ползунки.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.15, 0.09, 0.06)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD.darkened(0.15)
	fill.set_corner_radius_all(6)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grabber: Texture2D = ui_tex("icon_coin")
	if grabber != null:
		theme.set_icon("grabber", "HSlider", grabber)
		theme.set_icon("grabber_highlight", "HSlider", grabber)
		theme.set_icon("grabber_disabled", "HSlider", grabber)
	return theme


## Золотая «главная» кнопка (Готовить, Дальше, Играть).
static func make_gold(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box("btn_gold", 18, Color(0.8, 0.55, 0.15), 10))
	button.add_theme_stylebox_override("hover", box("btn_gold_hover", 18, Color(0.9, 0.65, 0.2), 10))
	button.add_theme_stylebox_override("pressed", box("btn_gold_pressed", 18, Color(0.6, 0.4, 0.1), 10))
	button.add_theme_color_override("font_color", Color(0.2, 0.1, 0.04))
	button.add_theme_color_override("font_hover_color", Color(0.2, 0.1, 0.04))
	button.add_theme_color_override("font_pressed_color", Color(0.2, 0.1, 0.04))
	button.add_theme_color_override("font_outline_color", Color(1, 0.9, 0.6, 0.6))
	button.add_theme_constant_override("outline_size", 2)


static func icon_rect(texture_name: String, size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = ui_tex(texture_name)
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func label(text: String, font_size: int, color: Color = CREAM, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Небольшая цветная «таблетка» со свойством (Согревает, Сытный…).
static func chip(text: String, color: Color, font_size: int = 13) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.35)
	style.border_color = color.lightened(0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, font_size, Color(1, 0.97, 0.9))
	l.add_theme_constant_override("outline_size", 0)
	panel.add_child(l)
	return panel


## Затемнённый фон для модальных окон.
static func dim_background(alpha: float = 0.72) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.03, 0.02, alpha)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	return bg

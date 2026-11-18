class_name ItemSlot
extends Button
## One square in an inventory grid. Draws its own frame, icon, quantity and
## category strip, so a grid of 40 stays a single node per slot.
##
## Purely visual: it shows an [ItemStack] it is given and reports clicks.
## [InventoryScreen] decides what selecting or activating a slot means.

## Double-click, or Enter while focused: "use" the slot (move it across).
signal activated(slot: ItemSlot)

const SIZE := 84.0
const RADIUS := 4.0
const ICON_SIZE := 56.0
const PRESS_SCALE := 0.94
const PRESS_TIME := 0.07
const RELEASE_TIME := 0.16

const COLOR_BG := Color(1, 1, 1, 0.035)
const COLOR_BG_FILLED := Color(1, 1, 1, 0.06)
const COLOR_BG_HOVER := Color(1, 1, 1, 0.1)
const COLOR_BORDER := Color(0.92, 0.89, 0.82, 0.1)
const COLOR_BORDER_HOVER := Color(0.92, 0.89, 0.82, 0.32)
const COLOR_SELECTED := Color(0.86, 0.58, 0.32)
const COLOR_FOCUS := Color(0.92, 0.89, 0.82, 0.7)
const COLOR_QTY := Color(0.92, 0.89, 0.82)
const COLOR_QTY_FULL := Color(0.86, 0.58, 0.32)

## Which inventory grid this slot belongs to, and its index there.
var source: InventoryComponent
var index: int = -1
## Shown stack, or null for an empty slot.
var stack: ItemStack
## Highlighted as the current selection.
var selected: bool = false:
	set(value):
		if selected != value:
			selected = value
			queue_redraw()
## Dimmed because it doesn't match the category filter.
var filtered_out: bool = false:
	set(value):
		if filtered_out != value:
			filtered_out = value
			_update_interactivity()
			queue_redraw()

var _press_tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	focus_mode = Control.FOCUS_ALL
	flat = true
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# The frame is drawn in _draw(); no theme box, no default focus ring.
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(s, empty)


func _ready() -> void:
	pivot_offset = Vector2(SIZE, SIZE) * 0.5
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(_animate_press.bind(true))
	button_up.connect(_animate_press.bind(false))


## Shows [param new_stack] (null = empty slot).
func set_stack(new_stack: ItemStack) -> void:
	stack = new_stack
	tooltip_text = "" if stack == null else stack.item.display_name
	_update_interactivity()
	queue_redraw()


func is_empty() -> bool:
	return stack == null


func _gui_input(event: InputEvent) -> void:
	if stack == null:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
		activated.emit(self)
		accept_event()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		activated.emit(self)
		accept_event()


func _update_interactivity() -> void:
	# Empty and filtered-out slots can't be selected or focused, so arrow
	# keys skip straight to the next item.
	var usable := stack != null and not filtered_out
	disabled = not usable
	focus_mode = Control.FOCUS_ALL if usable else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if usable else Control.CURSOR_ARROW


func _animate_press(down: bool) -> void:
	if _press_tween:
		_press_tween.kill()
	_press_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(self, "scale", Vector2.ONE * (PRESS_SCALE if down else 1.0),
			PRESS_TIME if down else RELEASE_TIME)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var hovered := is_hovered() and not disabled
	var bg := COLOR_BG if stack == null else (COLOR_BG_HOVER if hovered else COLOR_BG_FILLED)
	var dim := 0.28 if filtered_out else 1.0

	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(bg, bg.a * dim)
	frame.set_corner_radius_all(int(RADIUS))
	frame.set_border_width_all(1)
	frame.border_color = COLOR_BORDER_HOVER if hovered else COLOR_BORDER
	if selected:
		frame.set_border_width_all(2)
		frame.border_color = COLOR_SELECTED
	elif has_focus():
		frame.border_color = COLOR_FOCUS
	frame.anti_aliasing = true
	draw_style_box(frame, rect)

	if stack == null:
		return

	# Category strip on the left edge (same colours as the HUD loot panel).
	var cat_color: Color = HUD.CATEGORY_COLORS.get(stack.item.category, COLOR_BORDER)
	draw_rect(Rect2(5, 10, 3, size.y - 20), Color(cat_color, 0.9 * dim))

	if stack.item.icon:
		var icon_rect := Rect2((size - Vector2(ICON_SIZE, ICON_SIZE)) * 0.5 - Vector2(0, 3), Vector2(ICON_SIZE, ICON_SIZE))
		draw_texture_rect(stack.item.icon, icon_rect, false, Color(1, 1, 1, dim))

	if stack.item.max_stack > 1:
		var font := get_theme_default_font()
		var font_size := 15
		var text := str(stack.quantity)
		var full := stack.quantity >= stack.item.max_stack
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pos := Vector2(size.x - w - 8, size.y - 8)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.6 * dim))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Color(COLOR_QTY_FULL if full else COLOR_QTY, dim))

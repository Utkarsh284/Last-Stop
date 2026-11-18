class_name HUD
extends CanvasLayer
## In-game heads-up display. Purely presentational: it never reads game state
## itself, the game scene pushes text into it. Visual polish in Milestone 11.

const TITLE_FADE_IN := 0.6
const TITLE_HOLD := 2.6
const TITLE_FADE_OUT := 1.0
const MESSAGE_HOLD := 2.5
const PROMPT_IN := 0.12
const PROMPT_OUT := 0.08
const CROSSHAIR_FOCUS_SCALE := 2.0
const CROSSHAIR_TWEEN := 0.1
const COLOR_TEXT := Color(0.92, 0.89, 0.82)
const COLOR_MUTED := Color(0.62, 0.6, 0.56)
const COLOR_ACCENT := Color(0.86, 0.58, 0.32)
const COLOR_CROSSHAIR := Color(0.9, 0.87, 0.8, 0.85)
const LOOT_HOLD := 4.0
const LOOT_IN := 0.22
const LOOT_OUT := 0.4
const LOOT_SLIDE := 16.0
const LOOT_ROW_STAGGER := 0.06
const LOOT_MARGIN := 64.0
const LOOT_MIN_WIDTH := 300.0
## Muted accent per item category, used for the swatch beside each found item.
const CATEGORY_COLORS := {
	ItemData.Category.FOOD: Color(0.6, 0.68, 0.42),
	ItemData.Category.WATER: Color(0.46, 0.63, 0.74),
	ItemData.Category.MEDICAL: Color(0.8, 0.4, 0.38),
	ItemData.Category.MATERIAL: Color(0.64, 0.62, 0.58),
	ItemData.Category.AMMO: Color(0.86, 0.72, 0.4),
	ItemData.Category.WEAPON: Color(0.66, 0.56, 0.72),
}

@onready var _station_label: Label = %StationLabel
@onready var _status_label: Label = %StatusLabel
@onready var _prompt_panel: PanelContainer = %PromptPanel
@onready var _prompt_label: Label = %PromptLabel
@onready var _target_label: Label = %TargetLabel
@onready var _key_chip: Control = %KeyChip
@onready var _hold_track: Control = %HoldTrack
@onready var _hold_fill: Control = %HoldFill
@onready var _crosshair: Control = %Crosshair
@onready var _message_label: Label = %MessageLabel
@onready var _title_card: Control = %TitleCard
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _hint_label: Label = %HintLabel
@onready var _loot_panel: PanelContainer = %LootPanel
@onready var _loot_header: Label = %LootHeader
@onready var _loot_rows: VBoxContainer = %LootRows

var _title_tween: Tween
var _message_tween: Tween
var _prompt_tween: Tween
var _crosshair_tween: Tween
var _loot_tween: Tween
var _prompt_shown: bool = false
var _loot_name_settings: LabelSettings
var _loot_category_settings: LabelSettings
var _loot_no_room_settings: LabelSettings


func _ready() -> void:
	_prompt_panel.hide()
	_prompt_panel.modulate.a = 0.0
	_hold_fill.anchor_right = 0.0
	_message_label.modulate.a = 0.0
	_title_card.modulate.a = 0.0
	_loot_panel.hide()
	_loot_panel.modulate.a = 0.0
	_loot_name_settings = LabelSettings.new()
	_loot_name_settings.font_size = 19
	_loot_name_settings.font_color = COLOR_TEXT
	_loot_category_settings = LabelSettings.new()
	_loot_category_settings.font_size = 14
	_loot_category_settings.font_color = COLOR_MUTED
	_loot_no_room_settings = LabelSettings.new()
	_loot_no_room_settings.font_size = 14
	_loot_no_room_settings.font_color = COLOR_ACCENT


## Top-left location block, e.g. "GREY HOLLOW" / "Parked · doors open".
func set_status(station_line: String, status_line: String) -> void:
	_station_label.text = station_line.to_upper()
	_status_label.text = status_line


## Interaction prompt near the bottom centre, e.g. "FILING CABINET / [E] Search".
## [param status] replaces the key and action when the target can't be used
## ("Searched"). [param is_hold] shows the hold-progress track.
## An empty [param target_name] hides the prompt.
func set_interaction(target_name: String, action: String, status: String = "", is_hold: bool = false) -> void:
	if target_name.is_empty():
		_hide_prompt()
		_set_crosshair_focus(false, false)
		return
	var usable := status.is_empty()
	_target_label.text = target_name.to_upper()
	_prompt_label.text = action if usable else status
	_prompt_label.label_settings.font_color = COLOR_TEXT if usable else COLOR_MUTED
	_key_chip.visible = usable
	_hold_track.visible = usable and is_hold
	set_hold_progress(0.0)
	_show_prompt()
	_set_crosshair_focus(true, usable)


## Fills the hold track under the prompt (0…1).
func set_hold_progress(progress: float) -> void:
	_hold_fill.anchor_right = clampf(progress, 0.0, 1.0)
	_hold_fill.offset_right = 0.0


## True while an interaction prompt is displayed (or fading in).
func is_prompt_visible() -> bool:
	return _prompt_shown


## Short-lived feedback line under the prompt (e.g. why departure failed).
func show_message(text: String) -> void:
	_message_label.text = text
	if _message_tween:
		_message_tween.kill()
	_message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(MESSAGE_HOLD)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.4)


## Panel at the right of the screen listing what a search turned up
## ("FOUND IN SAFE" / "12 × Pistol rounds   Ammunition"). [param stacks] were
## taken; [param left_behind] didn't fit in the backpack and are listed dimmed
## as "No room". Slides in, holds, fades out. A new call replaces it.
func show_loot(source_name: String, stacks: Array[ItemStack], left_behind: Array[ItemStack] = []) -> void:
	for row in _loot_rows.get_children():
		_loot_rows.remove_child(row)
		row.queue_free()
	_loot_header.text = "FOUND IN %s" % source_name.to_upper()
	for stack in stacks:
		_loot_rows.add_child(_make_loot_row(stack))
	for stack in left_behind:
		_loot_rows.add_child(_make_loot_row(stack, true))
	# Right-aligned to the screen edge, as wide as the longest row.
	var size := _loot_panel.get_combined_minimum_size()
	_loot_panel.offset_right = -LOOT_MARGIN
	_loot_panel.offset_left = -LOOT_MARGIN - maxf(size.x, LOOT_MIN_WIDTH)
	_loot_panel.offset_top = -size.y * 0.5
	_loot_panel.offset_bottom = size.y * 0.5

	if _loot_tween:
		_loot_tween.kill()
	var rest_x := _loot_panel.position.x
	_loot_panel.show()
	_loot_panel.modulate.a = 0.0
	_loot_panel.position.x = rest_x + LOOT_SLIDE
	_loot_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_loot_tween.set_parallel()
	_loot_tween.tween_property(_loot_panel, "modulate:a", 1.0, LOOT_IN)
	_loot_tween.tween_property(_loot_panel, "position:x", rest_x, LOOT_IN)
	var i := 0
	for row: Control in _loot_rows.get_children():
		row.modulate.a = 0.0
		_loot_tween.tween_property(row, "modulate:a", 1.0, LOOT_IN).set_delay(0.08 + LOOT_ROW_STAGGER * i)
		i += 1
	_loot_tween.chain().tween_interval(LOOT_HOLD)
	_loot_tween.chain().tween_property(_loot_panel, "modulate:a", 0.0, LOOT_OUT).set_ease(Tween.EASE_IN)
	_loot_tween.chain().tween_callback(_loot_panel.hide)


## True while the found-items panel is on screen.
func is_loot_visible() -> bool:
	return _loot_panel.visible and _loot_panel.modulate.a > 0.0


func _make_loot_row(stack: ItemStack, no_room: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.set_meta(&"no_room", no_room)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(3, 0)
	swatch.color = CATEGORY_COLORS.get(stack.item.category, COLOR_MUTED)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	var name_label := Label.new()
	name_label.text = stack.get_label()
	name_label.label_settings = _loot_name_settings
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var category_label := Label.new()
	category_label.text = "No room" if no_room else stack.item.get_category_name()
	category_label.label_settings = _loot_no_room_settings if no_room else _loot_category_settings
	if no_room:
		name_label.modulate.a = 0.45
		swatch.modulate.a = 0.45
	category_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(category_label)
	return row


## Large centred station name that fades in, holds, then fades out.
func show_title_card(title: String, subtitle: String) -> void:
	_title_label.text = title.to_upper()
	_subtitle_label.text = subtitle
	if _title_tween:
		_title_tween.kill()
	_title_card.modulate.a = 0.0
	_title_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_title_tween.tween_property(_title_card, "modulate:a", 1.0, TITLE_FADE_IN)
	_title_tween.tween_interval(TITLE_HOLD)
	_title_tween.tween_property(_title_card, "modulate:a", 0.0, TITLE_FADE_OUT)


func _show_prompt() -> void:
	if _prompt_shown:
		return
	_prompt_shown = true
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_panel.show()
	_prompt_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_prompt_tween.tween_property(_prompt_panel, "modulate:a", 1.0, PROMPT_IN)


func _hide_prompt() -> void:
	if not _prompt_shown:
		return
	_prompt_shown = false
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_prompt_tween.tween_property(_prompt_panel, "modulate:a", 0.0, PROMPT_OUT)
	_prompt_tween.tween_callback(_prompt_panel.hide)


func _set_crosshair_focus(focused: bool, usable: bool) -> void:
	var target_scale := Vector2.ONE * (CROSSHAIR_FOCUS_SCALE if focused else 1.0)
	var target_color := COLOR_ACCENT if focused and usable else COLOR_CROSSHAIR
	if _crosshair_tween:
		_crosshair_tween.kill()
	_crosshair_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_crosshair_tween.tween_property(_crosshair, "scale", target_scale, CROSSHAIR_TWEEN)
	_crosshair_tween.tween_property(_crosshair, "color", target_color, CROSSHAIR_TWEEN)


## Controls hint in the bottom-left corner.
func set_hint(text: String) -> void:
	_hint_label.text = text

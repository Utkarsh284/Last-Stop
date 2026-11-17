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

var _title_tween: Tween
var _message_tween: Tween
var _prompt_tween: Tween
var _crosshair_tween: Tween
var _prompt_shown: bool = false


func _ready() -> void:
	_prompt_panel.hide()
	_prompt_panel.modulate.a = 0.0
	_hold_fill.anchor_right = 0.0
	_message_label.modulate.a = 0.0
	_title_card.modulate.a = 0.0


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

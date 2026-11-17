class_name HUD
extends CanvasLayer
## In-game heads-up display. Purely presentational: it never reads game state
## itself, the game scene pushes text into it. Visual polish in Milestone 11.

const TITLE_FADE_IN := 0.6
const TITLE_HOLD := 2.6
const TITLE_FADE_OUT := 1.0
const MESSAGE_HOLD := 2.5

@onready var _station_label: Label = %StationLabel
@onready var _status_label: Label = %StatusLabel
@onready var _prompt_panel: PanelContainer = %PromptPanel
@onready var _prompt_label: Label = %PromptLabel
@onready var _message_label: Label = %MessageLabel
@onready var _title_card: Control = %TitleCard
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _hint_label: Label = %HintLabel

var _title_tween: Tween
var _message_tween: Tween


func _ready() -> void:
	_prompt_panel.hide()
	_message_label.modulate.a = 0.0
	_title_card.modulate.a = 0.0


## Top-left location block, e.g. "GREY HOLLOW" / "Parked · doors open".
func set_status(station_line: String, status_line: String) -> void:
	_station_label.text = station_line.to_upper()
	_status_label.text = status_line


## Interaction prompt near the bottom centre. Empty text hides it.
func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_panel.visible = not text.is_empty()


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


## Controls hint in the bottom-left corner.
func set_hint(text: String) -> void:
	_hint_label.text = text

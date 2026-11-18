class_name InventoryScreen
extends CanvasLayer
## Full-screen inventory: the player's backpack, a details pane and, when
## opened at the train's storage locker, the storage grid beside it.
##
## Shows [InventoryComponent]s and calls their public API; it holds no item
## data itself. It redraws whenever an inventory emits [signal
## InventoryComponent.changed], so changes made elsewhere show up live.
##
## Mouse: click selects, double-click moves the stack to the other side.
## Keyboard: arrows move between items, Enter moves, Delete discards
## (press twice), Tab or Esc closes.

signal opened
signal closed

const OPEN_TIME := 0.18
const CLOSE_TIME := 0.12
const SLIDE := 14.0
const FEEDBACK_HOLD := 2.4
const DISCARD_CONFIRM_TIME := 3.0
const PLAYER_COLUMNS := 5
const STORAGE_COLUMNS := 8
const COLOR_TEXT := Color(0.92, 0.89, 0.82)
const COLOR_DANGER := Color(0.88, 0.45, 0.4)

const HINTS_BACKPACK := "Tab / Esc  close     ·     Arrows  browse     ·     Del  discard"
const HINTS_STORAGE := "Tab / Esc  close     ·     Double-click / Enter  move across     ·     Del  discard"

## Category filter chips, in order. -1 = all.
const FILTERS := [
	[-1, "All"],
	[ItemData.Category.FOOD, "Food"],
	[ItemData.Category.WATER, "Water"],
	[ItemData.Category.MEDICAL, "Medical"],
	[ItemData.Category.MATERIAL, "Materials"],
	[ItemData.Category.AMMO, "Ammo"],
	[ItemData.Category.WEAPON, "Weapons"],
]

@onready var _root: Control = %Root
@onready var _backdrop: ColorRect = %Backdrop
@onready var _layout: Control = %Layout
@onready var _filters: HBoxContainer = %Filters
@onready var _player_grid: GridContainer = %PlayerGrid
@onready var _player_capacity: Label = %PlayerCapacity
@onready var _storage_pane: Control = %StoragePane
@onready var _storage_title: Label = %StorageTitle
@onready var _storage_grid: GridContainer = %StorageGrid
@onready var _storage_capacity: Label = %StorageCapacity
@onready var _deposit_all: Button = %DepositAllButton
@onready var _detail_body: Control = %DetailBody
@onready var _empty_state: Label = %EmptyState
@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _detail_name: Label = %DetailName
@onready var _detail_swatch: ColorRect = %DetailSwatch
@onready var _detail_category: Label = %DetailCategory
@onready var _detail_description: Label = %DetailDescription
@onready var _detail_stack: Label = %DetailStack
@onready var _feedback: Label = %Feedback
@onready var _transfer_button: Button = %TransferButton
@onready var _discard_button: Button = %DiscardButton
@onready var _hints: Label = %Hints

var _player_inventory: InventoryComponent
var _storage: InventoryComponent
var _player_slots: Array[ItemSlot] = []
var _storage_slots: Array[ItemSlot] = []
## Current selection: which inventory and slot index (null/-1 = none).
var _selected_source: InventoryComponent
var _selected_index: int = -1
var _filter: int = -1
var _is_open: bool = false
var _discard_armed: bool = false
var _tween: Tween
var _feedback_tween: Tween
var _discard_timer: SceneTreeTimer


func _ready() -> void:
	hide()
	_build_filters()
	_transfer_button.pressed.connect(_transfer_selected)
	_discard_button.pressed.connect(_on_discard_pressed)
	_deposit_all.pressed.connect(_deposit_everything)
	_feedback.modulate.a = 0.0


## Opens the screen on [param player_inventory]. Passing [param storage]
## shows that inventory alongside for moving items in and out.
func open(player_inventory: InventoryComponent, storage: InventoryComponent = null,
		storage_title: String = "Train storage") -> void:
	_bind(player_inventory, storage)
	_storage_title.text = storage_title.to_upper()
	_storage_pane.visible = storage != null
	_hints.text = HINTS_STORAGE if storage else HINTS_BACKPACK
	_set_filter(-1)
	_clear_selection()
	_refresh()
	_is_open = true
	show()
	_animate_open()
	_focus_first_item()
	opened.emit()


## Closes the screen (fades out). Safe to call when already closed.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_disarm_discard()
	_bind(null, null)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_tween.tween_property(_root, "modulate:a", 0.0, CLOSE_TIME)
	_tween.chain().tween_callback(hide)
	var focused := _root.get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	closed.emit()


func is_open() -> bool:
	return _is_open


## The inventory and slot index currently selected (for tests and tooling).
func get_selection() -> Array:
	return [_selected_source, _selected_index]


## Selects a slot programmatically (same as clicking it).
func select_slot(source: InventoryComponent, index: int) -> void:
	_select(source, index)


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event.physical_keycode == KEY_DELETE or event.physical_keycode == KEY_BACKSPACE):
		get_viewport().set_input_as_handled()
		if _selected_stack():
			_on_discard_pressed()


# --- Binding & drawing ---------------------------------------------------------

func _bind(player_inventory: InventoryComponent, storage: InventoryComponent) -> void:
	for inv in [_player_inventory, _storage]:
		if inv and inv.changed.is_connected(_on_inventory_changed):
			inv.changed.disconnect(_on_inventory_changed)
	_player_inventory = player_inventory
	_storage = storage
	for inv in [_player_inventory, _storage]:
		if inv:
			inv.changed.connect(_on_inventory_changed)
	if _player_inventory:
		_player_slots = _ensure_slots(_player_grid, _player_slots, _player_inventory, PLAYER_COLUMNS)
	if _storage:
		_storage_slots = _ensure_slots(_storage_grid, _storage_slots, _storage, STORAGE_COLUMNS)


func _ensure_slots(grid: GridContainer, slots: Array[ItemSlot], inv: InventoryComponent,
		columns: int) -> Array[ItemSlot]:
	grid.columns = columns
	while slots.size() < inv.slot_count:
		var slot := ItemSlot.new()
		slot.pressed.connect(_on_slot_pressed.bind(slot))
		slot.activated.connect(_on_slot_activated)
		slot.focus_entered.connect(_on_slot_pressed.bind(slot))
		grid.add_child(slot)
		slots.append(slot)
	while slots.size() > inv.slot_count:
		var extra: ItemSlot = slots.pop_back()
		extra.queue_free()
	for i in slots.size():
		slots[i].source = inv
		slots[i].index = i
	return slots


func _on_inventory_changed() -> void:
	_refresh()


func _refresh() -> void:
	if _player_inventory == null:
		return
	_fill(_player_slots, _player_inventory)
	_player_capacity.text = "%d / %d" % [_player_inventory.get_used_slot_count(), _player_inventory.slot_count]
	if _storage:
		_fill(_storage_slots, _storage)
		_storage_capacity.text = "%d / %d" % [_storage.get_used_slot_count(), _storage.slot_count]
		_deposit_all.disabled = _player_inventory.is_empty()
	# Keep the selection on the same slot; drop it if that slot emptied.
	if _selected_source and _selected_source.get_slot(_selected_index) == null:
		_clear_selection()
	else:
		_update_details()


func _fill(slots: Array[ItemSlot], inv: InventoryComponent) -> void:
	for slot in slots:
		var stack := inv.get_slot(slot.index)
		slot.set_stack(stack)
		slot.filtered_out = stack != null and _filter >= 0 and stack.item.category != _filter
		slot.selected = inv == _selected_source and slot.index == _selected_index


# --- Selection & details -------------------------------------------------------

func _on_slot_pressed(slot: ItemSlot) -> void:
	if slot.stack != null and not slot.filtered_out:
		_select(slot.source, slot.index)


func _on_slot_activated(slot: ItemSlot) -> void:
	_select(slot.source, slot.index)
	if _storage:
		_transfer_selected()


func _select(source: InventoryComponent, index: int) -> void:
	if source == _selected_source and index == _selected_index:
		return
	_selected_source = source
	_selected_index = index
	_disarm_discard()
	_hide_feedback()
	for slot in _player_slots + _storage_slots:
		slot.selected = slot.source == source and slot.index == index
		# Keep the keyboard focus ring on the selection, so only one slot is lit.
		if slot.selected and not slot.has_focus() and slot.is_visible_in_tree():
			slot.grab_focus()
	_update_details()


func _clear_selection() -> void:
	_selected_source = null
	_selected_index = -1
	_disarm_discard()
	for slot in _player_slots + _storage_slots:
		slot.selected = false
	_update_details()


func _selected_stack() -> ItemStack:
	return _selected_source.get_slot(_selected_index) if _selected_source else null


func _update_details() -> void:
	var stack := _selected_stack()
	_detail_body.visible = stack != null
	_empty_state.visible = stack == null
	if stack == null:
		return
	var item := stack.item
	_detail_icon.texture = item.icon
	_detail_name.text = item.display_name
	_detail_swatch.color = HUD.CATEGORY_COLORS.get(item.category, COLOR_TEXT)
	_detail_category.text = item.get_category_name().to_upper()
	_detail_description.text = item.description
	var where := "in backpack" if _selected_source == _player_inventory else "in storage"
	if item.max_stack > 1:
		_detail_stack.text = "Stack %d / %d   ·   %d %s" % [stack.quantity, item.max_stack,
				_selected_source.count_item(item), where]
	else:
		_detail_stack.text = "Does not stack   ·   %d %s" % [_selected_source.count_item(item), where]

	_transfer_button.visible = _storage != null
	if _storage:
		var into_storage := _selected_source == _player_inventory
		var label := "Deposit in storage" if into_storage else "Take to backpack"
		_transfer_button.text = "%s   %s" % [label, "→" if into_storage else "←"] if into_storage \
				else "←   %s" % label
	_update_discard_button()


# --- Actions -------------------------------------------------------------------

func _transfer_selected() -> void:
	var stack := _selected_stack()
	if stack == null or _storage == null:
		return
	var from := _selected_source
	var to := _storage if from == _player_inventory else _player_inventory
	var total := stack.quantity
	var item_name := stack.item.display_name
	var moved := from.transfer_slot(_selected_index, to)
	if moved == 0:
		_show_feedback("No room in %s." % ("storage" if to == _storage else "your backpack"))
	elif moved < total:
		_show_feedback("Only %d of %d %s fit." % [moved, total, item_name])
	_restore_focus()


func _deposit_everything() -> void:
	if _player_inventory == null or _storage == null:
		return
	var before := _player_inventory.get_used_slot_count()
	var moved := _player_inventory.transfer_all(_storage)
	if moved == 0 and before > 0:
		_show_feedback("Storage is full.")
	elif not _player_inventory.is_empty():
		_show_feedback("Storage is full. Some items stayed in your backpack.")
	_restore_focus()


func _on_discard_pressed() -> void:
	var stack := _selected_stack()
	if stack == null:
		return
	if not _discard_armed:
		_discard_armed = true
		_update_discard_button()
		_discard_timer = get_tree().create_timer(DISCARD_CONFIRM_TIME)
		var timer := _discard_timer
		timer.timeout.connect(func() -> void:
			if _discard_timer == timer:
				_disarm_discard())
		return
	var label := stack.get_label()
	_selected_source.remove_from_slot(_selected_index)
	_disarm_discard()
	_show_feedback("Discarded %s." % label)
	_restore_focus()


func _disarm_discard() -> void:
	_discard_armed = false
	_discard_timer = null
	if is_node_ready():
		_update_discard_button()


func _update_discard_button() -> void:
	var stack := _selected_stack()
	if stack == null:
		return
	if _discard_armed:
		_discard_button.text = "Press again to discard %s" % ("all" if stack.quantity > 1 else "it")
		_discard_button.add_theme_color_override("font_color", COLOR_DANGER)
		_discard_button.add_theme_color_override("font_hover_color", COLOR_DANGER)
		_discard_button.add_theme_color_override("font_focus_color", COLOR_DANGER)
	else:
		_discard_button.text = "Discard" if stack.quantity == 1 else "Discard stack (%d)" % stack.quantity
		for c in ["font_color", "font_hover_color", "font_focus_color"]:
			_discard_button.remove_theme_color_override(c)


# --- Filters -------------------------------------------------------------------

func _build_filters() -> void:
	var group := ButtonGroup.new()
	for f in FILTERS:
		var chip := Button.new()
		chip.text = f[1]
		chip.toggle_mode = true
		chip.button_group = group
		chip.theme_type_variation = &"ChipButton"
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		chip.focus_mode = Control.FOCUS_CLICK
		chip.set_meta(&"category", f[0])
		chip.pressed.connect(_set_filter.bind(f[0]))
		_filters.add_child(chip)


func _set_filter(category: int) -> void:
	_filter = category
	for chip: Button in _filters.get_children():
		chip.set_pressed_no_signal(chip.get_meta(&"category") == category)
	_refresh()
	var stack := _selected_stack()
	if stack and _filter >= 0 and stack.item.category != _filter:
		_clear_selection()


# --- Feedback & focus ------------------------------------------------------------

func _show_feedback(text: String) -> void:
	_feedback.text = text
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback.modulate.a = 1.0
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(FEEDBACK_HOLD)
	_feedback_tween.tween_property(_feedback, "modulate:a", 0.0, 0.4)


func _hide_feedback() -> void:
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback.modulate.a = 0.0


## After an action, keep keyboard focus on the selected slot, or the nearest
## item if that slot is now empty, so arrow keys keep working.
func _restore_focus() -> void:
	var slots := _player_slots if _selected_source == _player_inventory or _selected_source == null else _storage_slots
	if _selected_stack() != null:
		slots[_selected_index].grab_focus()
		return
	_focus_first_item()


func _focus_first_item() -> void:
	for slot in _player_slots + (_storage_slots if _storage else []):
		if slot.focus_mode != Control.FOCUS_NONE and slot.is_visible_in_tree():
			slot.grab_focus()
			return


func _animate_open() -> void:
	if _tween:
		_tween.kill()
	_root.modulate.a = 0.0
	_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_root, "modulate:a", 1.0, OPEN_TIME)
	# The CenterContainer positions Layout on its next sort; slide up from
	# just below that resting place once it's known.
	await get_tree().process_frame
	if not _is_open:
		return
	var rest_y := _layout.position.y
	_layout.position.y = rest_y + SLIDE
	var slide := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	slide.tween_property(_layout, "position:y", rest_y, OPEN_TIME + 0.06)

extends Control
class_name Slot
## Mayo 台槽位：占位轮廓 + 序号 + 期望用途提示。
## 槽位本身是"被动"的——落点判定由 main.gd 统一处理。

@onready var _outline: Panel = $Outline
@onready var _index_label: Label = $IndexLabel
@onready var _hint_label: Label = $HintLabel

const SLOT_SIZE := Vector2(110, 150)

## 由 main.gd 在 add_child 前注入。
var index: int = -1
var hint: String = ""

var occupied: bool = false
var occupant = null


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	size = SLOT_SIZE
	_index_label.text = ("%d" % (index + 1)) if index >= 0 else ""
	_hint_label.text = hint


func is_empty() -> bool:
	return not occupied


func occupy(card) -> void:
	occupied = true
	occupant = card


func vacate() -> void:
	occupied = false
	occupant = null


func flash_correct() -> void:
	_flash(Color(0.45, 1.0, 0.5, 1.0))


func flash_wrong() -> void:
	_flash(Color(1.0, 0.4, 0.4, 1.0))


func _flash(color: Color) -> void:
	var orig: Color = _outline.modulate
	_outline.modulate = color
	var tw := create_tween()
	tw.tween_property(_outline, "modulate", orig, 0.45)

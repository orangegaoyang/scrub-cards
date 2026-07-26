extends Control
class_name Card
## Stacklands 风格的器械卡牌：卡面 + 阴影 + 图标 + 名称/用途。
## 拖拽通过 _gui_input 手动实现（不用 _get_drag_data，避免 Control 强制拖拽预览）。
## 阴影偏移 + z_index 变化传达"被拎起"的手感。

signal drag_started(card: Control)
signal drag_ended(card: Control)

const CARD_SIZE := Vector2(110, 150)
const REST_SHADOW := Vector2(4, 6)
const HOVER_SHADOW := Vector2(6, 9)
const DRAG_SHADOW := Vector2(9, 14)

@onready var _shadow: Panel = $Shadow
@onready var _body: Panel = $Body
@onready var _icon_rect: ColorRect = $Body/IconRect
@onready var _name_label: Label = $Body/NameLabel
@onready var _purpose_label: Label = $Body/PurposeLabel

## 由生成方在 add_child 前注入。
var def: ProcedureData.InstrumentDef = null
## 锁定后不再响应输入（已正确归位 / 正被医生使用）。
var locked: bool = false
## 医生使用过、吐回的卡牌为 true（视觉灰化）。
var used: bool = false

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	# 子节点忽略鼠标，保证整卡接收 _gui_input
	for c: Control in [_shadow, _body, _icon_rect, _name_label, _purpose_label]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if def != null:
		_apply_visual()


func _apply_visual() -> void:
	_icon_rect.color = def.color
	_name_label.text = def.name_cn
	_purpose_label.text = def.purpose


# 按下在 _gui_input 触发（确保只在卡牌上点击才开始拖拽）；
# 移动与释放在 _input 全局处理，避免快速拖动出卡牌矩形时丢事件。
func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging = true
		_drag_offset = get_global_mouse_position() - global_position
		_lift()
		drag_started.emit(self)
		accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - _drag_offset
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		_rest()
		drag_ended.emit(self)
		get_viewport().set_input_as_handled()


func _lift() -> void:
	_shadow.position = DRAG_SHADOW
	_shadow.modulate.a = 0.55
	z_index = 100


func _rest() -> void:
	_shadow.position = REST_SHADOW
	_shadow.modulate.a = 1.0
	z_index = 0


func _on_mouse_entered() -> void:
	if _dragging or locked:
		return
	_shadow.position = HOVER_SHADOW
	z_index = 1


func _on_mouse_exited() -> void:
	if _dragging or locked:
		return
	_shadow.position = REST_SHADOW
	z_index = 0


## 正确归位后调用：锁定、变绿、阴影收紧。
func lock_in_place() -> void:
	locked = true
	_dragging = false
	_shadow.position = Vector2(2, 3)
	_shadow.modulate.a = 1.0
	_body.modulate = Color(0.82, 1.0, 0.82, 1.0)
	z_index = 0


## 术中开始时调用：解锁卡牌、移除准备阶段的绿色提示，恢复为可拖拽状态。
func unlock_for_surgery() -> void:
	locked = false
	_dragging = false
	_body.modulate = Color.WHITE
	_shadow.position = REST_SHADOW
	_shadow.modulate.a = 1.0
	z_index = 0


## 医生用完后调用：灰化表示"已使用"。仍可拖（玩家可选放回原位）。
func mark_used() -> void:
	used = true
	_body.modulate = Color(0.6, 0.6, 0.64, 1.0)
	_icon_rect.modulate = Color(0.7, 0.7, 0.72, 1.0)
	_shadow.position = REST_SHADOW
	_shadow.modulate.a = 1.0


## 错误反馈：短暂闪红后恢复。
func flash_wrong() -> void:
	var orig: Color = _body.modulate
	_body.modulate = Color(1.0, 0.55, 0.55, 1.0)
	var tw := create_tween()
	tw.tween_property(_body, "modulate", orig, 0.25)

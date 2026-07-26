extends Control
class_name Card
## Stacklands 风格的器械卡牌：卡面 + 阴影 + 图标 + 名称/用途。
## 手感：拖拽时按速度倾斜、抬起放大、落地回弹、归位 squash；每个动作配音。

signal drag_started(card: Control)
signal drag_ended(card: Control)

const CARD_SIZE := Vector2(110, 150)
const REST_SHADOW := Vector2(4, 6)
const HOVER_SHADOW := Vector2(6, 9)
const DRAG_SHADOW := Vector2(9, 14)
const LIFT_SCALE := 1.06
const MAX_TILT: float = 0.22        # 最大倾斜弧度
const TILT_GAIN: float = 0.02       # 鼠标横向速度 → 倾斜

@onready var _shadow: Panel = $Shadow
@onready var _body: Panel = $Body
@onready var _icon_rect: ColorRect = $Body/IconRect
@onready var _name_label: Label = $Body/NameLabel
@onready var _purpose_label: Label = $Body/PurposeLabel
@onready var _op_bg: ColorRect = $Body/OpProgressBg
@onready var _op_fill: ColorRect = $Body/OpProgressFill

## 由生成方在 add_child 前注入。
var def: ProcedureData.InstrumentDef = null
## 锁定后不再响应输入（已正确归位 / 正被医生使用）。
var locked: bool = false
## 医生使用过、吐回的卡牌为 true（视觉灰化）。
var used: bool = false

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _last_mouse: Vector2 = Vector2.ZERO
var _anim: Tween = null


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	for c: Control in [_shadow, _body, _icon_rect, _name_label, _purpose_label, _op_bg, _op_fill]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_op_fill.pivot_offset = Vector2.ZERO  # 从左端填充
	_op_fill.scale = Vector2.ZERO
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
		_last_mouse = get_global_mouse_position()
		_drag_offset = _last_mouse - global_position
		_lift()
		drag_started.emit(self)
		accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		var mp := get_global_mouse_position()
		global_position = mp - _drag_offset
		var vx: float = mp.x - _last_mouse.x
		_last_mouse = mp
		var target_rot: float = clampf(vx * TILT_GAIN, -MAX_TILT, MAX_TILT)
		rotation = lerpf(rotation, target_rot, 0.35)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		_rest()
		drag_ended.emit(self)
		get_viewport().set_input_as_handled()


func _lift() -> void:
	_kill_anim()
	_shadow.position = DRAG_SHADOW
	_shadow.modulate.a = 0.55
	scale = Vector2(LIFT_SCALE, LIFT_SCALE)
	z_index = 100
	AudioManager.play("pick", -8.0)


func _rest() -> void:
	_kill_anim()
	_shadow.position = REST_SHADOW
	_shadow.modulate.a = 1.0
	z_index = 0
	_anim = create_tween()
	_anim.set_parallel(true)
	_anim.tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim.tween_property(self, "rotation", 0.0, 0.18)
	AudioManager.play("drop", -10.0)


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


## 正确归位后调用：锁定、变绿、阴影收紧、squash 回弹。
func lock_in_place() -> void:
	locked = true
	_dragging = false
	rotation = 0.0
	_shadow.position = Vector2(2, 3)
	_shadow.modulate.a = 1.0
	_body.modulate = Color(0.82, 1.0, 0.82, 1.0)
	z_index = 0
	_kill_anim()
	_anim = create_tween()
	_anim.tween_property(self, "scale", Vector2(1.14, 0.86), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim.tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 术中开始时调用：解锁、移除准备阶段的绿色提示，恢复为可拖拽状态。
func unlock_for_surgery() -> void:
	locked = false
	_dragging = false
	rotation = 0.0
	_kill_anim()
	scale = Vector2.ONE
	_body.modulate = Color.WHITE
	_shadow.position = REST_SHADOW
	_shadow.modulate.a = 1.0
	z_index = 0


## 医生用完后调用：灰化表示"已使用"。仍可拖（玩家可选放回原位）。
func mark_used() -> void:
	used = true
	_kill_anim()
	scale = Vector2.ONE
	rotation = 0.0
	_body.modulate = Color(0.6, 0.6, 0.64, 1.0)
	_icon_rect.modulate = Color(0.7, 0.7, 0.72, 1.0)
	_shadow.position = REST_SHADOW
	_shadow.modulate.a = 1.0


## 操作进度条：医生使用该器械时显示，0→1 填满后弹出。
func show_operation_progress(vis: bool) -> void:
	_op_bg.visible = vis
	_op_fill.visible = vis
	if vis:
		_op_fill.scale = Vector2.ZERO


func set_operation_progress(p: float) -> void:
	_op_fill.scale.x = clampf(p, 0.0, 1.0)


## 错误反馈：短暂闪红后恢复。
func flash_wrong() -> void:
	var orig: Color = _body.modulate
	_body.modulate = Color(1.0, 0.55, 0.55, 1.0)
	var tw := create_tween()
	tw.tween_property(_body, "modulate", orig, 0.25)


func _kill_anim() -> void:
	if _anim != null:
		_anim.kill()
		_anim = null

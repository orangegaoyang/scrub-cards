extends Control
class_name Report
## 手术报告（RESULT）：分拍揭晓，营造仪式感。
## 流程：暗场→纸面缩入+sting→标题砸入→星星逐颗点亮→逐行 tick→
##       flavor→解锁 shimmer→按钮淡入。

const REVEAL_OFFSET: float = 14.0

@onready var _dim: ColorRect = $DimBg
@onready var _paper: Panel = $Paper
@onready var _title: Label = $Paper/TitleLabel
@onready var _stars: Array = [$Paper/Star1, $Paper/Star2, $Paper/Star3]
@onready var _patient: Label = $Paper/PatientLabel
@onready var _accuracy: Label = $Paper/AccuracyLine
@onready var _prep: Label = $Paper/PrepLine
@onready var _delay: Label = $Paper/DelayLine
@onready var _flavor: Label = $Paper/FlavorLabel
@onready var _unlock: Label = $Paper/UnlockLabel
@onready var _restart: Button = $Paper/RestartButton

var _revealed: bool = false


func _ready() -> void:
	visible = false
	_dim.modulate.a = 0.0
	_paper.pivot_offset = _paper.size * 0.5
	_paper.scale = Vector2(0.88, 0.88)
	_paper.modulate.a = 0.0
	_restart.disabled = true
	_restart.modulate.a = 0.0
	_restart.pressed.connect(_on_restart_pressed)
	# 所有可揭晓元素先藏起
	for n: Control in [_title, _patient, _accuracy, _prep, _delay, _flavor, _unlock]:
		n.modulate.a = 0.0
		n.position.y += REVEAL_OFFSET
	for s in _stars:
		s.pivot_offset = s.size * 0.5
		s.modulate.a = 0.0
		(s as Label).text = "★"  # 占位；show_report 里再决定点亮与否


func show_report() -> void:
	if _revealed:
		return
	_revealed = true
	_fill_report()
	visible = true
	AudioManager.play("sting", -2.0)
	# 暗场 + 纸面缩入
	var tw_dim := create_tween()
	tw_dim.tween_property(_dim, "modulate:a", 1.0, 0.35)
	var tw_paper := create_tween()
	tw_paper.tween_property(_paper, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_paper.parallel().tween_property(_paper, "modulate:a", 1.0, 0.35)
	await get_tree().create_timer(0.4).timeout
	# 标题砸入
	_reveal_slam(_title)
	await get_tree().create_timer(0.35).timeout
	# 星星逐颗点亮
	var earned: int = GameState.get_stars()
	for i in range(3):
		_reveal_star(_stars[i], i < earned, 1.0 + i * 0.10)
		await get_tree().create_timer(0.16).timeout
	await get_tree().create_timer(0.18).timeout
	# 数据行逐行 tick（升调）
	_reveal_line(_patient, "tick", 0.9)
	await get_tree().create_timer(0.12).timeout
	_reveal_line(_accuracy, "tick", 1.0)
	await get_tree().create_timer(0.12).timeout
	_reveal_line(_prep, "tick", 1.1)
	await get_tree().create_timer(0.12).timeout
	_reveal_line(_delay, "tick", 1.2)
	await get_tree().create_timer(0.28).timeout
	# flavor
	_reveal_line(_flavor, "", 1.0)
	await get_tree().create_timer(0.35).timeout
	# 解锁（shimmer）
	_reveal_unlock()
	await get_tree().create_timer(0.45).timeout
	# 按钮淡入 + 启用
	_restart.disabled = false
	var tw_r := create_tween()
	tw_r.tween_property(_restart, "modulate:a", 1.0, 0.3)


func _fill_report() -> void:
	var acc: float = GameState.get_accuracy()
	_patient.text = "Patient status: %s" % GameState.get_patient_status()
	_accuracy.text = "✓  Instrument accuracy   %d%%" % int(round(acc * 100.0))
	_prep.text = "✓  Preparation time   %s" % GameState.get_prep_rating()
	if GameState.surgery_timeouts == 0:
		_delay.text = "✓  No instrument delays"
	else:
		_delay.text = "✗  %d instrument delay(s)" % GameState.surgery_timeouts


func _reveal_line(node: Control, sound: String, pitch: float) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position:y", node.position.y - REVEAL_OFFSET, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if sound != "":
		AudioManager.play(sound, -6.0, pitch)


func _reveal_slam(node: Label) -> void:
	node.scale = Vector2(1.35, 1.35)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, 0.25)
	tw.tween_property(node, "position:y", node.position.y - REVEAL_OFFSET, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var sc := create_tween()
	sc.tween_property(node, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play("sting", -8.0, 1.0)


func _reveal_star(node: Label, filled: bool, pitch: float) -> void:
	if filled:
		node.text = "★"
		node.scale = Vector2(1.7, 1.7)
		var tw := create_tween()
		tw.tween_property(node, "modulate:a", 1.0, 0.25)
		var sc := create_tween()
		sc.tween_property(node, "scale", Vector2.ONE, 0.32) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		AudioManager.play("star", -3.0, pitch)
	else:
		node.text = "☆"
		var tw := create_tween()
		tw.tween_property(node, "modulate:a", 0.28, 0.3)


func _reveal_unlock() -> void:
	_unlock.scale = Vector2(0.85, 0.85)
	AudioManager.play("unlock", -2.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_unlock, "modulate:a", 1.0, 0.3)
	tw.tween_property(_unlock, "position:y", _unlock.position.y - REVEAL_OFFSET, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var sc := create_tween()
	sc.tween_property(_unlock, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

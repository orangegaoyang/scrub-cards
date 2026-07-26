extends Control
class_name Report
## 手术报告（RESULT）：全中文 + 分拍揭晓 + 实习生成长反馈。
## 流程：暗场→纸面缩入+sting→标题砸入→星星→表现行→导师评语→
##       值班进度（天数/职级/进度条）→新解锁（shimmer）→按钮。

const REVEAL_OFFSET: float = 14.0

@onready var _dim: ColorRect = $DimBg
@onready var _paper: Panel = $Paper
@onready var _title: Label = $Paper/TitleLabel
@onready var _stars: Array = [$Paper/Star1, $Paper/Star2, $Paper/Star3]
@onready var _patient: Label = $Paper/PatientLabel
@onready var _accuracy: Label = $Paper/AccuracyLine
@onready var _prep: Label = $Paper/PrepLine
@onready var _delay: Label = $Paper/DelayLine
@onready var _verdict: Label = $Paper/VerdictLabel
@onready var _rank: Label = $Paper/RankLabel
@onready var _bar_bg: ColorRect = $Paper/RankBarBg
@onready var _bar_fill: ColorRect = $Paper/RankBarFill
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
	for n: Control in [_title, _patient, _accuracy, _prep, _delay, _verdict, _rank, _unlock, _bar_bg]:
		n.modulate.a = 0.0
		n.position.y += REVEAL_OFFSET
	for s in _stars:
		s.pivot_offset = s.size * 0.5
		s.modulate.a = 0.0
		(s as Label).text = "★"
	# 进度条 fill：从左端生长
	_bar_fill.pivot_offset = Vector2.ZERO
	_bar_fill.scale = Vector2.ZERO


func show_report() -> void:
	if _revealed:
		return
	_revealed = true
	_fill_report()
	visible = true
	AudioManager.play("sting", -2.0)
	var tw_dim := create_tween()
	tw_dim.tween_property(_dim, "modulate:a", 1.0, 0.35)
	var tw_paper := create_tween()
	tw_paper.tween_property(_paper, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_paper.parallel().tween_property(_paper, "modulate:a", 1.0, 0.35)
	await get_tree().create_timer(0.4).timeout

	_reveal_slam(_title)
	await get_tree().create_timer(0.35).timeout

	# 星星
	var earned: int = GameState.get_stars()
	for i in range(3):
		_reveal_star(_stars[i], i < earned, 1.0 + i * 0.10)
		await get_tree().create_timer(0.16).timeout
	await get_tree().create_timer(0.18).timeout

	# 患者状态 + 表现行
	_reveal_line(_patient, "tick", 0.9)
	await get_tree().create_timer(0.12).timeout
	_reveal_line(_accuracy, "tick", 1.0)
	await get_tree().create_timer(0.12).timeout
	_reveal_line(_prep, "tick", 1.1)
	await get_tree().create_timer(0.12).timeout
	_reveal_line(_delay, "tick", 1.2)
	await get_tree().create_timer(0.25).timeout

	# 导师评语
	_reveal_line(_verdict, "tick", 0.8)
	await get_tree().create_timer(0.3).timeout

	# 值班进度：职级 + 进度条
	_reveal_line(_rank, "tick", 1.0)
	await get_tree().create_timer(0.15).timeout
	_reveal_line(_bar_bg, "", 1.0)
	await get_tree().create_timer(0.18).timeout
	_grow_rank_bar()
	await get_tree().create_timer(0.45).timeout

	# 新解锁（shimmer）
	_reveal_unlock()
	await get_tree().create_timer(0.45).timeout

	# 按钮
	_restart.disabled = false
	var tw_r := create_tween()
	tw_r.tween_property(_restart, "modulate:a", 1.0, 0.3)


func _fill_report() -> void:
	var acc: float = GameState.get_accuracy()
	_patient.text = "患者状态：%s" % GameState.get_patient_status()
	_accuracy.text = "✓  器械准确率   %d%%" % int(round(acc * 100.0))
	_prep.text = "✓  准备时间   %s" % GameState.get_prep_rating()
	_delay.text = ("✓  无器械延误" if GameState.surgery_timeouts == 0
			else "✗  %d 次器械延误" % GameState.surgery_timeouts)
	_verdict.text = "Reyes：%s" % GameState.get_verdict()
	var rank: Dictionary = GameState.get_rank()
	var t: String = "值班第 %d 天 · %s" % [GameState.meta_day, rank.title]
	if rank.is_max:
		t += "（满级）"
	_rank.text = t


func _grow_rank_bar() -> void:
	var rank: Dictionary = GameState.get_rank()
	var tw := create_tween()
	tw.tween_property(_bar_fill, "scale:x", float(rank.progress), 0.5) \
		.set_ease(Tween.EASE_OUT)
	if not rank.is_max:
		AudioManager.play("tick", -6.0, 1.3)


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

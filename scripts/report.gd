extends Control
class_name Report
## 手术报告：RESULT 阶段弹出。从 GameState 读取指标 + 静态 meta 解锁 teaser。

@onready var _patient: Label = $Paper/PatientLabel
@onready var _accuracy: Label = $Paper/AccuracyLine
@onready var _prep: Label = $Paper/PrepLine
@onready var _delay: Label = $Paper/DelayLine
@onready var _restart: Button = $Paper/RestartButton


func _ready() -> void:
	visible = false
	_restart.pressed.connect(_on_restart_pressed)


func show_report() -> void:
	var acc: float = GameState.get_accuracy()
	_patient.text = "Patient status: %s" % GameState.get_patient_status()
	_accuracy.text = "✓  Instrument accuracy   %d%%" % int(round(acc * 100.0))
	_prep.text = "✓  Preparation time   %s" % GameState.get_prep_rating()
	if GameState.surgery_timeouts == 0:
		_delay.text = "✓  No instrument delays"
	else:
		_delay.text = "✗  %d instrument delay(s)" % GameState.surgery_timeouts
	visible = true


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

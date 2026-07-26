extends Node
## GameState autoload: phase state machine + scoring + combo + signals.
## PREP → READY → SURGERY → RESULT

signal phase_changed(new_phase: int)
signal prep_completed()
signal prep_item_secured(slot_index: int)
signal surgery_step_completed(step_index: int)
signal score_updated()
signal combo_changed(combo: int)

enum Phase { PREP, READY, SURGERY, RESULT }

var current_phase: int = Phase.PREP:
	set(v):
		current_phase = v
		phase_changed.emit(v)

# Prep scoring
var prep_correct: int = 0
var prep_start_time: float = 0.0
var prep_elapsed: float = 0.0

# Surgery scoring
var surgery_correct: int = 0
var surgery_wrong: int = 0           # 错误递送 + 超时（准确率分母）
var surgery_timeouts: int = 0        # 超时次数（"延误"指标）
var surgery_start_time: float = 0.0
var surgery_elapsed: float = 0.0
var current_demand_index: int = 0

# Combo
var combo: int = 0
var max_combo: int = 0

const TOTAL_STEPS: int = 6

# 准备阶段评级阈值（秒）
const PREP_EXCELLENT: float = 25.0
const PREP_GOOD: float = 45.0


func reset() -> void:
	current_phase = Phase.PREP
	prep_correct = 0
	prep_start_time = Time.get_ticks_msec() / 1000.0
	prep_elapsed = 0.0
	surgery_correct = 0
	surgery_wrong = 0
	surgery_timeouts = 0
	surgery_start_time = 0.0
	surgery_elapsed = 0.0
	current_demand_index = 0
	combo = 0
	max_combo = 0
	combo_changed.emit(0)
	score_updated.emit()


func secure_prep_item(slot_index: int) -> void:
	prep_correct += 1
	prep_item_secured.emit(slot_index)
	score_updated.emit()
	if prep_correct >= TOTAL_STEPS:
		enter_ready()


func enter_ready() -> void:
	prep_elapsed = (Time.get_ticks_msec() / 1000.0) - prep_start_time
	prep_completed.emit()
	current_phase = Phase.READY


func start_surgery() -> void:
	current_phase = Phase.SURGERY
	surgery_start_time = Time.get_ticks_msec() / 1000.0
	current_demand_index = 0
	combo = 0
	combo_changed.emit(0)


func record_correct() -> void:
	surgery_correct += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	combo_changed.emit(combo)
	score_updated.emit()


func record_wrong(is_timeout: bool = false) -> void:
	surgery_wrong += 1
	combo = 0
	if is_timeout:
		surgery_timeouts += 1
	combo_changed.emit(0)
	score_updated.emit()


func finish_surgery() -> void:
	surgery_elapsed = (Time.get_ticks_msec() / 1000.0) - surgery_start_time
	current_phase = Phase.RESULT


# ───────── 报告所需指标 ─────────

func get_accuracy() -> float:
	var total: int = surgery_correct + surgery_wrong
	if total == 0:
		return 1.0
	return float(surgery_correct) / float(total)


func get_stars() -> int:
	var r: float = get_accuracy()
	if r >= 0.95:
		return 3
	elif r >= 0.8:
		return 2
	else:
		return 1


func get_prep_rating() -> String:
	if prep_elapsed <= PREP_EXCELLENT:
		return "Excellent"
	elif prep_elapsed <= PREP_GOOD:
		return "Good"
	else:
		return "Fair"


func get_patient_status() -> String:
	return "Stable" if get_accuracy() >= 0.8 else "Critical"

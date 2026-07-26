extends Node
## GameState autoload: phase state machine + scoring + signals.
## 卡牌版沿用 organizer 3D 版的状态机，PREP → READY → SURGERY → RESULT。

signal phase_changed(new_phase: int)
signal prep_completed()
signal prep_item_secured(slot_index: int)
signal surgery_step_completed(step_index: int)
signal score_updated()

enum Phase { PREP, READY, SURGERY, RESULT }

var current_phase: int = Phase.PREP:
	set(v):
		current_phase = v
		phase_changed.emit(v)

# Prep scoring
var prep_correct: int = 0  # number of cards placed in correct slot

# Surgery scoring
var surgery_correct: int = 0
var surgery_wrong: int = 0
var surgery_start_time: float = 0.0
var surgery_elapsed: float = 0.0
var current_demand_index: int = 0

const TOTAL_STEPS: int = 6


func reset() -> void:
	current_phase = Phase.PREP
	prep_correct = 0
	surgery_correct = 0
	surgery_wrong = 0
	surgery_start_time = 0.0
	surgery_elapsed = 0.0
	current_demand_index = 0
	score_updated.emit()


func secure_prep_item(slot_index: int) -> void:
	prep_correct += 1
	prep_item_secured.emit(slot_index)
	score_updated.emit()
	if prep_correct >= TOTAL_STEPS:
		enter_ready()


func enter_ready() -> void:
	prep_completed.emit()
	current_phase = Phase.READY


func start_surgery() -> void:
	current_phase = Phase.SURGERY
	surgery_start_time = Time.get_ticks_msec() / 1000.0
	current_demand_index = 0


func record_correct() -> void:
	surgery_correct += 1
	score_updated.emit()


func record_wrong() -> void:
	surgery_wrong += 1
	score_updated.emit()


func finish_surgery() -> void:
	surgery_elapsed = (Time.get_ticks_msec() / 1000.0) - surgery_start_time
	current_phase = Phase.RESULT


func get_stars() -> int:
	var total_attempts: int = surgery_correct + surgery_wrong
	if total_attempts == 0:
		return 0
	var ratio: float = float(surgery_correct) / float(total_attempts)
	if ratio >= 0.95:
		return 3
	elif ratio >= 0.8:
		return 2
	else:
		return 1

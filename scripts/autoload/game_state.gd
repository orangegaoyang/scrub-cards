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

# 跨次存档：实习生成长进度
var meta_day: int = 1   # 当前值班第几天（每完成一台手术 +1）

const TOTAL_STEPS: int = 6

# 准备阶段评级阈值（秒）
const PREP_EXCELLENT: float = 25.0
const PREP_GOOD: float = 45.0

# 职级：按值班天数晋升
const RANKS: Array = [
	{title = "实习生", min_day = 1, span = 1},
	{title = "见习器械护士", min_day = 2, span = 2},
	{title = "器械护士", min_day = 4, span = 3},
	{title = "资深器械护士", min_day = 7, span = 999},
]
const SAVE_PATH := "user://intern_progress.json"


func _ready() -> void:
	_load_meta()


func _load_meta() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("day"):
		meta_day = int(parsed["day"])


func _save_meta() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"day": meta_day}))
	f.close()


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
	meta_day += 1
	_save_meta()
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
		return "优秀"
	elif prep_elapsed <= PREP_GOOD:
		return "良好"
	else:
		return "一般"


func get_patient_status() -> String:
	return "稳定" if get_accuracy() >= 0.8 else "危急"


## 护士长 Reyes 按准确率给的评语（成长反馈）。
func get_verdict() -> String:
	var acc: float = get_accuracy()
	if acc < 0.6:
		return "……回去把器械图谱再翻两遍吧。"
	elif acc < 0.8:
		return "勉强能用。明天手别抖。"
	elif acc < 0.95:
		return "不错，有点样子了。"
	else:
		return "今天漂亮。Halberg 都没骂人——头一回。"


## 当前职级信息：title / index / days_into / days_for / progress / is_max
func get_rank() -> Dictionary:
	var d: int = meta_day
	for i in range(RANKS.size() - 1, -1, -1):
		var r: Dictionary = RANKS[i]
		if d >= int(r.min_day):
			var into: int = d - int(r.min_day)
			var span: int = int(r.span)
			var is_max: bool = i >= RANKS.size() - 1
			var pct: float = 1.0 if is_max else clampf(float(into) / float(span), 0.0, 1.0)
			return {
				"title": r.title,
				"index": i,
				"days_into": into,
				"days_for": span,
				"progress": pct,
				"is_max": is_max,
			}
	return {"title": RANKS[0].title, "index": 0, "days_into": 0, "days_for": 1, "progress": 0.0, "is_max": false}

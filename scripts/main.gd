extends Control
## 主场景编排：
## 准备：点击手术包 → 卡牌飞出 → 拖入顶部 6 槽位
## 术中：开始按钮 → 医生面板滑入 → 需求(倒计时环) → 拖对应卡到递送区
##       → 操作(环变绿填充) → 啵吐出灰卡(可选放回) → 下一件
## 节奏：取回后 80% 概率 0.2–0.8s 要下一件，20% 概率 3–6s 停顿

const CARD_SCENE := preload("res://scenes/card.tscn")
const SLOT_SCENE := preload("res://scenes/slot.tscn")
const PACK_SCENE := preload("res://scenes/surgery_pack.tscn")
const NUM_INSTRUMENTS: int = 6

# 布局
const SLOT_W: float = 110.0
const SLOT_GAP: float = 20.0
const SLOT_Y: float = 50.0

# 术中节奏
const FIRST_DEMAND_DELAY: float = 1.0
const COUNTDOWN_DURATION: float = 6.0  # 与 doctor_panel 一致，仅用于提示

signal demand_resolved(result: String)

@onready var _slots_layer: Control = $SlotsLayer
@onready var _cards_layer: Control = $CardsLayer
@onready var _fx_layer: Control = $FxLayer
@onready var _pack_layer: Control = $PackLayer
@onready var _hud_label: Label = $HUDLabel
@onready var _combo_label: Label = $ComboLabel
@onready var _phase_label: Label = $PhaseLabel
@onready var _doctor_panel: DoctorPanel = $DoctorPanel
@onready var _start_button: Button = $StartButton
@onready var _report: Report = $Report

var _slots: Array = []
var _cards: Array = []
var _card_home: Dictionary = {}  # card -> Vector2（原槽位/牌堆位置）
var _demand_index: int = 0
var _demand_active: bool = false
var _pack: SurgeryPack = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	GameState.reset()
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.score_updated.connect(_update_hud)
	GameState.combo_changed.connect(_on_combo_changed)
	_rng.randomize()
	_build_slots()
	_spawn_pack()
	_start_button.visible = false
	_start_button.pressed.connect(_on_start_pressed)
	_combo_label.visible = false
	_combo_label.pivot_offset = Vector2(80, 16)
	_doctor_panel.countdown_expired.connect(_on_countdown_expired)
	_doctor_panel.operate_complete.connect(_on_operate_complete)
	_update_hud()
	_on_phase_changed(GameState.current_phase)


# ───────── 准备阶段：槽位 + 手术包 ─────────

func _build_slots() -> void:
	var total_w: float = NUM_INSTRUMENTS * SLOT_W + (NUM_INSTRUMENTS - 1) * SLOT_GAP
	var start_x: float = (size.x - total_w) * 0.5
	for i in NUM_INSTRUMENTS:
		var slot = SLOT_SCENE.instantiate()
		slot.index = i
		var inst_id: String = ProcedureData.demand_sequence[i]
		slot.hint = ProcedureData.get_instrument(inst_id).purpose
		slot.position = Vector2(start_x + i * (SLOT_W + SLOT_GAP), SLOT_Y)
		_slots_layer.add_child(slot)
		_slots.append(slot)


func _spawn_pack() -> void:
	_pack = PACK_SCENE.instantiate()
	_pack.position = Vector2(size.x * 0.5 - 70.0, size.y * 0.66)
	_pack_layer.add_child(_pack)
	_pack.opened.connect(_on_pack_opened)


func _on_pack_opened(pack: SurgeryPack) -> void:
	var origin: Vector2 = pack.global_position + pack.size * 0.5
	_burst(origin, Color(0.95, 0.95, 0.8), 18, 1.3)
	_spawn_shuffled_cards_from(origin)


func _spawn_shuffled_cards_from(origin: Vector2) -> void:
	var ids: Array = ProcedureData.demand_sequence.duplicate()
	ids.shuffle()
	var positions := _compute_scatter_positions(ids.size())
	for i in range(ids.size()):
		var def = ProcedureData.get_instrument(ids[i])
		var card = CARD_SCENE.instantiate()
		card.def = def
		card.position = origin
		card.rotation = _rng.randf_range(-0.15, 0.15)
		_cards_layer.add_child(card)
		card.drag_ended.connect(_on_card_drag_ended)
		_cards.append(card)
		var tw: Tween = card.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(card, "position", positions[i], 0.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _compute_scatter_positions(n: int) -> Array:
	var out: Array = []
	const COLS: int = 3
	const CW: float = 125.0
	const CH: float = 165.0
	var start_x: float = size.x * 0.5 - (COLS * CW) * 0.5 + 8.0
	var start_y: float = 290.0
	for i in range(n):
		var col: int = i % COLS
		var row: int = i / COLS
		var jitter := Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-6.0, 6.0))
		out.append(Vector2(start_x + col * CW, start_y + row * CH) + jitter)
	return out


# ───────── 拖拽落点分发 ─────────

func _on_card_drag_ended(card: Card) -> void:
	match GameState.current_phase:
		GameState.Phase.PREP:
			_handle_prep_drop(card)
		GameState.Phase.SURGERY:
			_handle_surgery_drop(card)
		_:
			pass  # 自由放置


func _handle_prep_drop(card: Card) -> void:
	for slot in _slots:
		if not slot.is_empty():
			continue
		if _rects_overlap_global(card, slot):
			if slot.index == card.def.slot_index:
				_place_correct(card, slot)
			else:
				_reject(card, slot)
			return


func _handle_surgery_drop(card: Card) -> void:
	if not _doctor_panel.deliverable:
		return
	if not _doctor_panel.get_drop_rect().intersects(Rect2(card.global_position, card.size)):
		return
	if _doctor_panel.receive_card(card):
		card.global_position = _doctor_panel.get_drop_anchor_global_pos()
		card.locked = true
		_doctor_panel.start_operating(card)
	else:
		# 错误器械：闪红 + 计误 + 弹回原位
		card.flash_wrong()
		GameState.record_wrong(false)
		AudioManager.play("wrong", -4.0)
		var home: Vector2 = _card_home.get(card, card.global_position)
		var tw: Tween = card.create_tween()
		tw.tween_property(card, "global_position", home, 0.25)


func _rects_overlap_global(a: Control, b: Control) -> bool:
	var ra := Rect2(a.global_position, a.size)
	var rb := Rect2(b.global_position, b.size)
	return ra.intersects(rb)


func _place_correct(card: Card, slot: Slot) -> void:
	card.global_position = slot.global_position
	_card_home[card] = slot.global_position
	card.lock_in_place()
	slot.occupy(card)
	slot.flash_correct()
	_burst(card.global_position + card.size * 0.5, Color(0.6, 1.0, 0.55), 10)
	AudioManager.play("correct", -4.0)
	GameState.secure_prep_item(slot.index)


func _reject(card: Card, slot: Slot) -> void:
	slot.flash_wrong()
	card.flash_wrong()
	AudioManager.play("wrong", -4.0)
	var home: Vector2 = _card_home.get(card, card.global_position)
	var tw: Tween = card.create_tween()
	tw.tween_property(card, "global_position", home, 0.25)


# ───────── 术中循环 ─────────

func _on_start_pressed() -> void:
	_start_button.visible = false
	for c: Card in _cards:
		c.unlock_for_surgery()
	GameState.start_surgery()
	_doctor_panel.slide_in()
	_demand_index = 0
	_run_surgery_loop()


func _run_surgery_loop() -> void:
	await get_tree().create_timer(FIRST_DEMAND_DELAY).timeout
	while _demand_index < NUM_INSTRUMENTS and GameState.current_phase == GameState.Phase.SURGERY:
		var inst_id: String = ProcedureData.demand_sequence[_demand_index]
		var def = ProcedureData.get_instrument(inst_id)
		_demand_active = true
		_doctor_panel.show_demand(def)
		await demand_resolved   # 计分在 _on_operate_complete / _on_countdown_expired 内完成
		_demand_index += 1
		_doctor_panel.clear_demand()
		if _demand_index < NUM_INSTRUMENTS:
			await get_tree().create_timer(_rhythm_delay()).timeout
	_finish_surgery()


func _rhythm_delay() -> float:
	if _rng.randf() < 0.8:
		return _rng.randf_range(0.2, 0.8)
	return _rng.randf_range(3.0, 6.0)


func _on_countdown_expired() -> void:
	if not _demand_active:
		return
	_demand_active = false
	GameState.record_wrong(true)
	demand_resolved.emit("timeout")


func _on_operate_complete(card: Card) -> void:
	if not _demand_active:
		return
	_demand_active = false
	GameState.record_correct()
	# 爽点：PERFECT 弹字 + 升调音效（combo 越高音越高）
	var center: Vector2 = _doctor_panel.get_drop_rect().get_center()
	_float_text(center, "PERFECT", Color(1.0, 0.85, 0.3))
	var pitch: float = clampf(1.0 + (GameState.combo - 1) * 0.06, 1.0, 2.0)
	AudioManager.play("correct", -3.0, pitch)
	_spit_out(card)
	demand_resolved.emit("correct")


func _spit_out(card: Card) -> void:
	card.show_operation_progress(false)
	card.mark_used()
	card.locked = false
	var target := _get_spit_target()
	var tw_pos: Tween = card.create_tween()
	tw_pos.tween_property(card, "global_position", target, 0.45) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	var tw_sc: Tween = card.create_tween()
	tw_sc.tween_property(card, "scale", Vector2(1.18, 1.18), 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_sc.tween_property(card, "scale", Vector2.ONE, 0.20)
	_burst(card.global_position + card.size * 0.5, Color(0.7, 0.85, 1.0), 8)
	AudioManager.play("spit", -4.0)


func _get_spit_target() -> Vector2:
	return Vector2(
		_rng.randf_range(120.0, 520.0),
		_rng.randf_range(540.0, 620.0)
	)


## 简易粒子：在 pos 撒出 count 个小色块，向外飞散并淡出。
func _burst(pos: Vector2, color: Color, count: int = 12, spread: float = 1.0) -> void:
	for i in count:
		var s := ColorRect.new()
		s.color = color
		s.size = Vector2(5, 5)
		s.position = pos - s.size * 0.5
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx_layer.add_child(s)
		var ang: float = _rng.randf_range(0.0, TAU)
		var dist: float = _rng.randf_range(30.0, 110.0) * spread
		var dur: float = _rng.randf_range(0.3, 0.5)
		var dest := pos + Vector2(cos(ang), sin(ang)) * dist - s.size * 0.5
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(s, "position", dest, dur).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 0.0, dur)
		tw.chain().tween_callback(s.queue_free)


## 浮空文字（PERFECT 等）：弹一下、上浮、淡出。
func _float_text(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", color)
	l.position = pos - Vector2(60, 18)
	l.pivot_offset = Vector2(60, 18)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(l)
	var sc := create_tween()
	sc.tween_property(l, "scale", Vector2(1.25, 1.25), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sc.tween_property(l, "scale", Vector2.ONE, 0.10)
	var mv := create_tween()
	mv.set_parallel(true)
	mv.tween_property(l, "position:y", l.position.y - 70.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	mv.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.25)
	mv.chain().tween_callback(l.queue_free)


func _finish_surgery() -> void:
	GameState.finish_surgery()
	_doctor_panel.slide_out()
	await get_tree().create_timer(0.5).timeout
	_report.show_report()


# ───────── UI ─────────

func _update_hud() -> void:
	match GameState.current_phase:
		GameState.Phase.PREP, GameState.Phase.READY:
			_hud_label.text = "已摆放 %d / %d" % [GameState.prep_correct, NUM_INSTRUMENTS]
		GameState.Phase.SURGERY:
			_hud_label.text = "递送 %d · 错误 %d" % [GameState.surgery_correct, GameState.surgery_wrong]
		GameState.Phase.RESULT:
			_hud_label.text = "★ %d" % GameState.get_stars()


func _on_combo_changed(combo: int) -> void:
	if combo >= 2:
		_combo_label.text = "COMBO  x%d" % combo
		_combo_label.visible = true
		_combo_label.scale = Vector2(1.35, 1.35)
		var tw := create_tween()
		tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_combo_label.visible = false


func _on_phase_changed(new_phase: int) -> void:
	match new_phase:
		GameState.Phase.PREP:
			_phase_label.text = "准备阶段：点击手术包打开"
		GameState.Phase.READY:
			_phase_label.text = "摆放完成"
			_start_button.visible = true
		GameState.Phase.SURGERY:
			_phase_label.text = "术中"
		GameState.Phase.RESULT:
			_phase_label.text = "手术完成！正确 %d · 错误 %d · 用时 %.1fs" % [
				GameState.surgery_correct, GameState.surgery_wrong, GameState.surgery_elapsed]
	_update_hud()

extends Control
## 入口页：图片化布局。点"开始准备"进入 preparation 页（main.tscn）。

const MAIN_SCENE := "res://scenes/main.tscn"

@onready var _start: TextureButton = $StartBtn


func _ready() -> void:
	_start.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	_start.disabled = true
	AudioManager.play("pick", -2.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(MAIN_SCENE))

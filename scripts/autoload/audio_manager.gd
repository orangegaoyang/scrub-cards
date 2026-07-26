extends Node
## AudioManager autoload：按名字播放预加载的 wav，对象池复用 AudioStreamPlayer。
## 用法：AudioManager.play("pick")；未加载的 name 静默忽略。

const SFX_DIR := "res://assets/audio"
const POOL_SIZE: int = 8
const DEFAULT_VOL: float = -6.0

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0


func _ready() -> void:
	_load_all()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = DEFAULT_VOL
		add_child(p)
		_pool.append(p)


func _load_all() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		push_warning("AudioManager: audio dir not found at %s" % SFX_DIR)
		return
	dir.list_dir_begin()
	var fn: String = dir.get_next()
	while fn != "":
		if fn.ends_with(".wav"):
			var key := fn.get_basename()
			var res := load("%s/%s" % [SFX_DIR, fn])
			if res != null:
				_streams[key] = res
		fn = dir.get_next()
	dir.list_dir_end()


func play(name: String, vol_db: float = DEFAULT_VOL) -> void:
	var s = _streams.get(name)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	p.stream = s
	p.volume_db = vol_db
	p.play()


func has(name: String) -> bool:
	return _streams.has(name)

# Scrub Cards — 技术规范 (spec.md)

## 引擎与语言
- **引擎**：Godot 4.7.x（CLI: `godot`，已安装 4.7.1）
- **语言**：GDScript
- **渲染**：**GL Compatibility**（OpenGL3），为 Web 导出铺路
- **分辨率**：1280×720，`canvas_items` 拉伸，`expand` 宽高比

## 输入映射
| 动作 | 默认键 | 说明 |
|------|--------|------|
| (鼠标拖拽) | 左键按下/移动/释放 | 卡牌操作，无需 input action |
| ui_cancel | Esc | 释放/暂停（预留）|

## Autoload（全局单例）
1. **GameState** (`scripts/autoload/game_state.gd`)：阶段状态机、分数、信号
2. **ProcedureData** (`scripts/autoload/procedure_data.gd`)：器械定义、需求序列、槽位顺序

## 项目结构
```
scrub-cards/
├── project.godot
├── icon.svg
├── design.md
├── spec.md
├── todo.md
├── scenes/
│   ├── main.tscn              # 入口：桌面 + 推车 + Mayo 台 + HUD
│   ├── card.tscn              # Stacklands 风格器械卡（Control + 阴影 + 卡面 + 图标 + 文本）
│   └── slot.tscn              # Mayo 台槽位卡（序号 + 期望用途 + 占位轮廓）
├── scripts/
│   ├── main.gd                # 流程：准备 → (术中) → 结算；洗牌发牌、拖拽验证
│   ├── card.gd                # 卡牌视觉/状态：setup(def)、阴影/缩放/拖拽反馈、locked
│   ├── slot.gd                # 槽位：index、occupied、occupant、empty()
│   └── autoload/
│       ├── game_state.gd
│       └── procedure_data.gd
├── data/
│   └── procedure.json         # 6 件器械定义（与 organizer 共用同 schema）
└── assets/
    ├── textures/              # 后期卡面美术
    ├── fonts/
    └── audio/
```

## 数据模型

### InstrumentDef（沿用 3D 版，schema 不变）
```gdscript
{
  "id": "scalpel",
  "name_cn": "手术刀",
  "name_en": "Scalpel",
  "category": "cutting",
  "purpose": "切皮",
  "color_r": 0.90, "color_g": 0.20, "color_b": 0.20,
  "slot_index": 0
}
```
类别：`cutting` / `clamping` / `grasping` / `suturing` / `dressing`

### 需求序列 = 槽位顺序
`[scalpel, hemostat, forceps, scissors, needle_holder, gauze]`

## 卡牌视觉规范（Stacklands 风格）
- **尺寸**：110 × 150 px
- **结构**（Control 根节点）：
  - `Shadow` (Panel, 偏移 +4,+6, StyleBoxFlat 黑 25% 透明, 圆角 10)
  - `Body` (Panel, StyleBoxFlat 米白 #f7f1df + 深灰边框, 圆角 10)
    - `IconRect` (ColorRect, 60×60, 器械类别色)
    - `NameLabel` (Label, 粗体居中)
    - `PurposeLabel` (Label, 小字灰色)
- **状态机**：`REST` / `HOVER` / `DRAG` / `LOCKED`，各自有阴影偏移/缩放/z_index
- **鼠标过滤**：根 `STOP`，子节点全 `IGNORE`（保证整卡接收 `_gui_input`）

## 拖拽实现（card.gd）
- `_gui_input`：左键按下 → 进入 DRAG，记录 `_drag_offset = mouse - global_pos`
- `InputEventMouseMotion` + DRAG → `global_position = mouse - _drag_offset`
- 左键释放 → 退出 DRAG，发 `drag_ended` 信号；由 main.gd 判定落点
- 信号：`drag_started(card)`、`drag_ended(card)`、`clicked(card)`

## 槽位（slot.gd）
- 字段：`index: int`、`occupied: bool`、`occupant: Card`
- 方法：`is_empty() -> bool`、`occupy(card)`、`vacate()`
- 视觉：透明填充 + 虚线/实线轮廓 + 序号 Label + 期望用途 Label

## 阶段状态机（GameState）
```
PREP → READY → SURGERY → RESULT
```
- `PREP`：整理器械台（拖卡入槽）
- `READY`：6 张全归位，显示"开始手术"按钮（替代倒计时）
- `SURGERY`：术中递送循环（MVP 暂不实现，里程碑 2）
- `RESULT`：结算

**信号**：`phase_changed(new_phase)`、`prep_completed()`、`prep_item_secured(slot_index)`、`score_updated()`

## 拖拽落点判定（main.gd）
```
_on_card_drag_ended(card):
    for slot in _slots:
        if slot.is_empty() and Rect2(card.pos, card.size).intersects(Rect2(slot.pos, slot.size)):
            if slot.index == card.def.slot_index:
                _place_correct(card, slot)   # 吸附 + 锁定 + 计数
            else:
                _reject(card)                 # 弹回原位 + 槽位闪红
            return
    # 未命中任何槽位：留在拖放处（玩家可继续拖）
```

## 计分
- 准备阶段：正确归位数 / 6
- 术中（里程碑 2）：递送正确数、错误数、总用时
- 结算：星级（正确率 + 用时综合）

## 验证节点
- **里程碑 1（本 scaffold 目标）**：能拖拽 6 张器械卡到 6 个槽位，对错判定正确，全部归位后进入 READY 态
- **里程碑 2**：术中递送/取回/放回全流程跑通
- **里程碑 3**：结算 + 重玩 + Web 导出

## 运行与验证命令
```bash
# 生成导入缓存并校验项目（无 GUI）
godot --headless --import

# 启动游戏（GUI）
godot

# 运行指定场景
godot res://scenes/main.tscn

# Web 导出（里程碑 3）
godot --headless --export-release "Web" scrub-cards.html
```

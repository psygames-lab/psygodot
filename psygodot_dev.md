# Godot 心理学可解释游戏框架开发计划

> 项目暂定名：**PsyGodot**  
> 中文名：**面向自然主义心理学研究的 Godot 游戏行为标注与数据采集框架**  
> 版本：v0.1 开发计划  
> 日期：2026-05-12

---

## 0. 项目一句话定位

本项目不是为 Godot 做一个传统的“心理学实验运行器”，而是为 Godot 游戏增加一个 **心理学可解释层 / 实验可读层**，让游戏过程中的关键行为、事件、状态、条件和同步信号可以被严谨记录、标注、还原和分析。

传统心理学实验任务通常是：

```text
Trial → Stimulus → Response → Feedback → Data
```

本项目要实现的是：

```text
Gameplay → Hidden Psychological Structure → Event Tagging
→ Continuous Behavioral Logging → Interpretable Behavioral Metrics
→ Optional EEG/fNIRS/Eye-tracking Synchronization
```

核心原则：

```text
Do not force games into trials.
Instead, make gameplay events psychologically interpretable.
```

中文表述：

```text
不要强行把游戏切成 trial，而是让游戏过程中的关键事件具有心理学可解释性。
```

---

## 1. 项目目标

### 1.1 产品目标

开发一个 Godot 框架，使研究者能够：

1. 在 Godot 游戏中嵌入隐藏心理学结构。
2. 将游戏事件标注为心理学事件。
3. 连续记录玩家行为流。
4. 从原始行为事件中提取可解释行为指标。
5. 可选地向 EEG、fNIRS、眼动或其他外部设备发送 marker / trigger。
6. 保留原始事件流，支持后续重新分析、回放和验证。

### 1.2 学术目标

本项目的理论贡献不是“Godot 可以做心理学任务”，而是：

> 为交互式自然主义范式提供一个可复现、可标注、可同步、可分析的开发层。

游戏可以被视为 **active naturalistic paradigm**。与电影观看、故事聆听等被动自然主义范式不同，游戏范式允许参与者持续主动决策、探索、适应反馈、学习规则，并表现出个体化策略。

### 1.3 MVP 目标

第一版最小可行产品应完成：

```text
Hidden Reversal-Learning Game
+
PsychRuntime
+
Session / Episode / Probe system
+
EventTag system
+
JSONL raw event stream
+
Mock trigger
+
Python derived metrics extractor
```

---

## 2. 非目标

MVP 阶段不做以下内容：

```text
1. 不做完整 Godot Editor Plugin UI
2. 不做复杂后端 dashboard
3. 不做真实 EEG/fNIRS 硬件接入
4. 不做复杂美术和大型游戏内容
5. 不做多人联网
6. 不做移动端部署
7. 不做完整跨平台 timing validation
8. 不把框架设计成 trial-first experiment runner
```

这些内容可以在 MVP 闭环跑通后再逐步扩展。
注意：你有godot mcp可以用于godot设计和开发
---

## 3. 与 PsychoPy / jsPsych / Unity UXF 的区别

### 3.1 传统实验工具

PsychoPy、jsPsych 等工具主要围绕传统离散试次结构：

```text
trial
stimulus onset
response
feedback
trial result
```

它们非常适合标准化实验任务，例如 Stroop、Go/No-Go、Flanker、MID、PRL 等。

### 3.2 Unity UXF 类工具

Unity UXF 的核心仍然接近：

```text
Session → Block → Trial → Result
```

它适合在 Unity 中组织 VR、桌面或远程实验，但其范式更接近“在游戏引擎中管理实验”。

### 3.3 本项目的区别

本项目不是把传统实验搬进 Godot，而是让游戏本身成为可分析范式。

推荐对象模型不是：

```text
Session → Block → Trial
```

而是：

```text
Session → Episode → Probe → EventTag → BehaviorEvent → BehaviorMetric
```

其中：

- **Episode**：一段可分析游戏片段。
- **Probe**：嵌入游戏中的心理学测量点。
- **EventTag**：事件的心理学语义标签。
- **BehaviorEvent**：底层连续行为记录。
- **BehaviorMetric**：从原始事件流中提取的行为指标。
- **Marker / Trigger**：用于外部设备同步的硬件或软件信号。

---

## 4. 总体技术架构

项目整体分为五层：

```text
Godot Game Layer
    ↓
Psych Instrumentation Layer
    ↓
Local Data Layer
    ↓
Optional Backend / Sync Layer
    ↓
Analysis / Validation Layer
```

具体结构：

```text
[Game Scenes]
  player, objects, NPCs, rewards, hazards, UI, world rules
        ↓ signals / groups / direct API
[Psych Instrumentation Layer]
  PsychRuntime
  SessionManager
  EpisodeManager
  ProbeManager
  EventTagger
  BehaviorLogger
  ConditionScheduler
  MetricExtractor Bridge
  TriggerManager
  ReplayRecorder
        ↓ JSONL / CSV / LSL / HTTP
[Data Layer]
  raw_events.jsonl
  session_manifest.json
  derived_metrics.csv
  trigger_log.jsonl
  replay_index.json
        ↓ optional upload
[Backend]
  API
  database
  object storage
  researcher dashboard
  export service
        ↓
[Analysis]
  Python/R notebooks
  metric validation
  timing validation
  paper-ready figures
```

核心原则：

```text
Raw event stream first. Derived metrics second.
```

不要只保存最终反应时、正确率或得分。必须保存完整事件流，以便后续重新计算、回放、验证和排错。

---

## 5. 推荐技术基线

### 5.1 Godot 版本

建议使用：

```text
Godot 4.6.x stable
```

MVP 阶段优先使用 GDScript，不急于引入 GDExtension。

### 5.2 Godot 端技术选择

```text
Autoload singleton:
  PsychRuntime
  SessionManager
  BehaviorLogger

Signals:
  游戏对象向心理学层发送事件

Groups:
  标记 psych_probe、loggable_actor、trigger_source、condition_zone 等节点

Resources:
  study config、probe config、marker map、condition table

JSONL:
  保存 raw event stream

CSV:
  保存 derived metrics
```

### 5.3 后期技术扩展

```text
EditorPlugin:
  probe editor
  marker map editor
  condition table editor
  researcher debug panel

GDExtension:
  LSL bridge
  serial port trigger
  parallel port trigger
  vendor SDK bridge
```

---

## 6. Godot 端核心模块

## 6.1 PsychRuntime

全局入口，作为 Autoload singleton 存在。

职责：

```text
1. 初始化研究配置
2. 创建和结束 session
3. 连接 logger / trigger / metric components
4. 提供统一 log_event() API
5. 管理 episode 和 probe 生命周期
6. 提供 debug overlay 数据
7. 统一 flush 和 shutdown
```

核心 API：

```gdscript
PsychRuntime.start_session(config)
PsychRuntime.end_session(reason)
PsychRuntime.start_episode(episode_type, metadata)
PsychRuntime.end_episode(episode_id, metadata)
PsychRuntime.register_probe(probe_config)
PsychRuntime.start_probe(probe_id, metadata)
PsychRuntime.end_probe(probe_id, metadata)
PsychRuntime.log_event(event_type, event_tag, payload)
PsychRuntime.emit_marker(marker_code, marker_label, payload)
PsychRuntime.flush()
```

游戏脚本调用示例：

```gdscript
PsychRuntime.log_event(
    "choice_made",
    "response_made",
    {
        "probe_id": current_probe_id,
        "choice": "tree_a",
        "x": player.global_position.x,
        "y": player.global_position.y
    }
)
```

PsychRuntime 应负责自动补齐：

```text
session_id
participant_id_hash
episode_id
probe_id
timestamp_usec
frame
physics_frame
condition
marker info
schema_version
```

---

## 6.2 SessionManager

管理一次被试运行。

字段：

```text
session_id
study_id
participant_id_hash
build_version
godot_version
platform
start_time_wall
start_time_monotonic_usec
condition_assignment
random_seed
consent_flags
device_info
```

职责：

```text
1. 创建 session_id
2. 记录 study 和 participant 信息
3. 保存 session_manifest.json
4. 管理 session start / end
5. 记录异常退出和恢复状态
6. 为所有事件提供 session context
```

---

## 6.3 EpisodeManager

Episode 是游戏中的一段可分析片段，不等于传统 trial。

Episode 可以是：

```text
一次探索
一场战斗
一段对话
一次奖励机会
一次规则学习窗口
一段社会互动
一次风险选择过程
```

核心 API：

```gdscript
var episode_id = PsychRuntime.start_episode("rule_learning_round", {
    "rule_state": "A_rewarded",
    "episode_index": 12
})

PsychRuntime.end_episode(episode_id, {
    "outcome": "rewarded",
    "score_delta": 10
})
```

Episode 应记录：

```text
episode_id
episode_type
start_time
end_time
duration_ms
condition
outcome
summary_metadata
```

---

## 6.4 ProbeManager

Probe 是嵌入游戏世界中的心理学测量点，是本项目最重要的抽象之一。

Probe 类型示例：

```text
decision_probe
reward_cue_probe
conflict_probe
inhibition_probe
memory_load_probe
social_feedback_probe
rule_shift_probe
risk_choice_probe
reversal_choice_probe
```

Probe 配置示例：

```json
{
  "probe_id": "P_00042",
  "probe_type": "reversal_choice",
  "episode_id": "E_00012",
  "condition": {
    "rule_state": "A_rewarded",
    "reward_probability_A": 0.8,
    "reward_probability_B": 0.2,
    "reversal_index": 2
  },
  "expected_events": [
    "choice_options_onset",
    "decision_onset",
    "response_made",
    "feedback_onset"
  ],
  "marker_policy": {
    "choice_options_onset": 101,
    "response_made": 102,
    "feedback_positive": 103,
    "feedback_negative": 104
  }
}
```

Probe 的作用：

```text
玩家看到的是游戏对象、奖励和反馈。
研究者看到的是心理学结构、条件和事件序列。
```

---

## 6.5 EventTagger

EventTag 是事件语义层。

MVP 阶段建议固定以下标签：

```text
session_start
session_end

episode_start
episode_end

probe_start
probe_end

cue_onset
decision_onset
response_made
feedback_onset
feedback_positive
feedback_negative

reward_cue
punishment_cue
neutral_cue

rule_shift
conflict_high
conflict_low
memory_load_high
memory_load_low

approach_start
avoidance_start
collision
object_collected
object_ignored

error_commission
error_omission
perseverative_error

marker_sent
upload_success
upload_failure
```

注意：

```text
EventTag ≠ MarkerCode
```

EventTag 是心理学语义，MarkerCode 是外部设备同步信号。二者应有关联，但不能混为一谈。

---

## 6.6 BehaviorLogger

BehaviorLogger 是底层数据记录器。

必须满足：

```text
append-only
crash-safe
JSONL output
periodic flush
offline first
event buffer
schema_version
session context auto-fill
```

Raw event 示例：

```json
{
  "schema_version": "0.1.0",
  "study_id": "godot_psych_pilot",
  "session_id": "S_20260512_abc123",
  "participant_id_hash": "p_9f31a",
  "build_version": "0.1.0-dev",
  "platform": "windows",
  "event_id": "EV_00000042",
  "event_type": "gameplay",
  "event_tag": "response_made",
  "timestamp_usec": 482913772,
  "wall_time_iso": "2026-05-12T14:32:10.123-04:00",
  "frame": 18342,
  "physics_frame": 11004,
  "episode_id": "E_00012",
  "probe_id": "P_00042",
  "condition": {
    "rule_state": "A_rewarded",
    "reversal_index": 2
  },
  "object_id": "tree_a",
  "actor_id": "player",
  "position": {
    "x": 144.2,
    "y": 392.8
  },
  "input": {
    "action": "interact",
    "device": "keyboard"
  },
  "response": {
    "choice": "A",
    "rt_ms": 713
  },
  "marker": {
    "requested": true,
    "code": 102,
    "label": "response_made",
    "driver": "mock"
  },
  "metadata": {}
}
```

---

## 6.7 MetricExtractor

MetricExtractor 不应该在 MVP 中硬写进游戏逻辑。推荐独立放在 `analysis/` 目录中，用 Python 实现。

输入：

```text
raw_events.jsonl
session_manifest.json
probe_config.json
```

输出：

```text
derived_metrics.csv
episode_metrics.csv
probe_metrics.csv
participant_summary.csv
```

MVP 指标：

```text
rt_ms
choice
accuracy
rewarded
switch_after_loss
stay_after_win
perseverative_error
learning_slope
approach_latency_ms
hesitation_duration_ms
path_length
exploration_entropy
post_error_slowing
feedback_sensitivity
```

原则：

```text
所有 derived metrics 必须能从 raw event stream 重新计算。
```

---

## 6.8 TriggerManager

MVP 阶段只做 mock trigger。

后续 driver 结构：

```text
TriggerManager
  ├── MockTriggerDriver
  ├── LSLTriggerDriver
  ├── SerialTriggerDriver
  ├── ParallelPortTriggerDriver
  └── UDPTriggerDriver
```

Trigger 事件必须同时写入 raw event stream：

```json
{
  "event_tag": "marker_sent",
  "marker": {
    "code": 102,
    "label": "response_made",
    "driver": "mock",
    "linked_event_id": "EV_00000042"
  }
}
```

---

## 7. 推荐项目目录结构

```text
godot-psych-instrumented-games/
  README.md
  prd.md
  architecture.md
  progress.md
  tasks.json
  acceptance_tests.md
  agent_loop.md

  godot_project/
    project.godot

    addons/
      psych_instrumentation/
        plugin.cfg
        psych_runtime.gd
        session_manager.gd
        episode_manager.gd
        probe_manager.gd
        event_tagger.gd
        behavior_logger.gd
        condition_scheduler.gd
        metric_bridge.gd
        trigger_manager.gd

        drivers/
          mock_trigger_driver.gd
          lsl_trigger_driver.gd
          udp_trigger_driver.gd
          serial_trigger_driver.gd

        resources/
          psych_config.gd
          probe_config.gd
          marker_map.gd
          condition_table.gd

        ui/
          researcher_debug_overlay.tscn
          researcher_debug_overlay.gd

        tests/
          test_event_schema.gd
          test_session_lifecycle.gd
          test_episode_probe_flow.gd

    scenes/
      prototype_reversal_game/
        main.tscn
        player.tscn
        world.tscn
        choice_zone.tscn
        feedback_ui.tscn

    scripts/
      game/
        player_controller.gd
        reward_tree.gd
        rule_controller.gd
        choice_zone.gd
        feedback_controller.gd

    configs/
      study_config.json
      marker_map.json
      condition_table.json
      probe_templates.json

  analysis/
    README.md
    requirements.txt
    parse_jsonl.py
    compute_metrics.py
    validate_schema.py
    notebooks/
      prototype_metrics.ipynb
      timing_validation.ipynb

  backend/
    README.md
    api/
    db/
    dashboard/

  docs/
    conceptual_framework.md
    event_schema.md
    metric_definitions.md
    timing_validation_protocol.md
    paper_outline.md

  data_examples/
    raw_events_example.jsonl
    derived_metrics_example.csv
```

---

## 8. MVP 游戏：隐藏 Reversal-Learning Game

### 8.1 游戏表层

玩家在一个小型 2D 花园或森林中探索。地图上有两类资源点：

```text
Tree A
Tree B
```

玩家每轮可以选择靠近并采集其中一个。玩家以为自己在玩资源收集游戏，但背后 reward contingency 会变化：

```text
阶段 1：A 高奖励概率，B 低奖励概率
阶段 2：规则反转，B 高奖励概率，A 低奖励概率
阶段 3：再次反转
```

### 8.2 隐藏心理学结构

```text
reward learning
feedback sensitivity
reversal learning
cognitive flexibility
perseveration
approach / avoidance
decision latency
```

### 8.3 每轮 Episode 事件流

```text
episode_start
choice_options_onset
decision_onset
approach_start
response_made
feedback_onset
feedback_positive / feedback_negative
episode_end
```

规则反转时记录：

```text
rule_shift
```

### 8.4 指标

```text
choice_rt_ms
approach_latency_ms
stay_after_win
switch_after_loss
perseverative_error_count
trials_to_criterion
learning_slope
post_error_slowing
path_hesitation
feedback_sensitivity
```

### 8.5 MVP 游戏验收标准

```text
1. 玩家可以完成至少 30 个 episode。
2. 规则会按配置自动反转。
3. 每轮选择和反馈都被记录。
4. rule_shift 事件被记录。
5. raw_events.jsonl 中包含完整 session / episode / probe 信息。
6. derived_metrics.csv 可以从 raw_events.jsonl 生成。
7. mock marker 与关键事件关联。
8. 游戏无心理学层也能作为小游戏运行。
```

---

## 9. 数据采集架构

### 9.1 第一阶段：Local-first

```text
Godot client
  ↓
local event buffer
  ↓
JSONL write-ahead log
  ↓
periodic flush
  ↓
local export
  ↓
Python metric extraction
```

### 9.2 第二阶段：Backend Sync

```text
Godot client
  ↓
local event buffer
  ↓
periodic upload
  ↓
backend API
  ↓
database / object storage
  ↓
researcher dashboard
  ↓
CSV / JSONL / Parquet export
```

### 9.3 后端 API 草案

```text
POST /api/sessions/start
POST /api/sessions/end
POST /api/events/batch
POST /api/metrics/batch
GET  /api/studies/{study_id}/exports
GET  /api/sessions/{session_id}/raw-events
```

### 9.4 数据库表草案

```text
studies
participants
sessions
episodes
probes
events
metrics
marker_events
uploads
builds
```

MVP 阶段不建议先开发 dashboard。先保证：

```text
raw_events.jsonl 稳定写出
derived_metrics.csv 可以重算
prototype 可以完整跑完
```

---

## 10. Timing / Trigger Validation 方案

如果只做行为研究，本地日志和事件时间戳可以支持 MVP。若要进入 EEG、fNIRS、眼动同步场景，必须单独做 timing validation。

### 10.1 需要区分四种时间

```text
1. game logic time
   游戏逻辑中事件发生的时间

2. log timestamp
   BehaviorLogger 写入事件时的时间

3. marker timestamp
   TriggerManager 发出 marker 时的时间

4. physical display onset
   屏幕上 cue / feedback 真正出现的时间
```

不能把 1、2、3 直接当作 4。

### 10.2 Validation Protocol

每个关键事件都应记录：

```text
cue_onset
feedback_onset
marker_sent
photodiode_detected
external_trigger_detected
```

计算：

```text
software_to_marker_latency_ms
marker_to_photodiode_latency_ms
software_to_photodiode_latency_ms
mean_latency
sd_latency
jitter
95_percent_range
dropped_marker_rate
```

设备方案：

```text
photodiode：检测屏幕亮度变化
microcontroller / logic analyzer：检测 trigger 输出
LSL recorder：记录 LSL marker
Godot JSONL：记录软件事件
```

论文表述应谨慎：

```text
本框架支持 marker 发送与事件日志，但具体实验部署中的视觉 onset 精度需要使用外部设备验证。
```

---

## 11. 插件化路线

不要一开始就做完整 Godot plugin。推荐顺序：

```text
Phase 1: prototype game
Phase 2: reusable instrumentation scripts
Phase 3: addon-style package
Phase 4: editor plugin
Phase 5: GDExtension / external trigger drivers
```

后期 EditorPlugin 可做：

```text
Probe editor
EventTag registry editor
Marker map editor
Condition table editor
Session debug panel
Data export panel
Timing validation panel
```

后期 GDExtension 可做：

```text
LSL native bridge
serial port trigger
parallel port trigger
low-latency device SDK bridge
```

---

## 12. Raphael / Ralph Loop 开发方案

### 12.1 开发理念

使用 agent 开发时，不应该让 agent 自由发挥，而应使用严格的 PRD、任务清单、验收标准和进度文件约束。

每轮 loop 应完成：

```text
1. 读取 prd.md / architecture.md / tasks.json / progress.md / acceptance_tests.md
2. 选择最高优先级未完成任务
3. 做最小可交付改动
4. 运行测试或创建测试
5. 更新 progress.md
6. 更新 tasks.json
7. git commit
8. 进入下一轮
```

### 12.2 必备文件

```text
prd.md
architecture.md
tasks.json
progress.md
acceptance_tests.md
agent_loop.md
```

### 12.3 Agent Loop Prompt 模板

```text
You are the coding agent for the Godot Psych Instrumentation Layer.

Read these files first:
- prd.md
- architecture.md
- tasks.json
- progress.md
- acceptance_tests.md

Your job in this iteration:
1. Select the highest-priority unfinished task that can be completed in one iteration.
2. Implement the smallest working change.
3. Run available tests or create tests if missing.
4. Update progress.md with:
   - task completed
   - files changed
   - tests run
   - remaining risks
   - next recommended task
5. Update tasks.json status.
6. Commit changes with a clear message.

Hard constraints:
- Do not change the project positioning.
- Do not make this a trial-first experiment runner.
- Do not implement full plugin UI before the MVP works.
- Do not remove raw event logging.
- Do not store only derived metrics.
- Do not add external hardware dependencies in Phase 1.
- Prefer simple GDScript implementation before GDExtension.
```

### 12.4 progress.md 模板

```md
# Progress

## Last iteration
Date:
Task:
Commit:
Files changed:
Tests run:
Result:

## Current working state
- Godot project opens:
- Prototype playable:
- JSONL logging:
- Metrics extraction:
- Trigger mock:
- Known issues:

## Next recommended task
```

---

## 13. Agent 角色分工

如果使用多个 agent，建议拆成以下角色，避免多个 agent 同时修改同一批文件。

### 13.1 Architect Agent

负责：

```text
architecture.md
event_schema.md
metric_definitions.md
API boundaries
```

### 13.2 Godot Agent

负责：

```text
Godot scenes
GDScript
Autoload
signals
logger integration
prototype gameplay
```

### 13.3 Data Agent

负责：

```text
JSONL schema validation
Python parser
metric extraction
CSV output
example data
```

### 13.4 QA Agent

负责：

```text
test cases
schema tests
event coverage tests
regression tests
timing validation protocol
```

### 13.5 Paper / Docs Agent

负责：

```text
conceptual_framework.md
paper_outline.md
method section draft
figure explanations
developer documentation
```

如果只有一个 agent，则按顺序串行执行：

```text
Architect → Godot → Data → QA → Docs
```

---

## 14. Phase-by-Phase 开发计划

## Phase 0：项目冻结与 PRD

目标：把项目哲学写死，防止 agent 走偏。

交付物：

```text
prd.md
architecture.md
event_schema.md
metric_definitions.md
tasks.json
progress.md
```

验收标准：

```text
项目定位明确：psych-instrumented game framework
核心对象明确：Session / Episode / Probe / EventTag / BehaviorEvent / BehaviorMetric / Marker
MVP 明确：hidden reversal-learning game
非目标明确：不做完整插件、不做复杂后端、不接真实硬件
```

---

## Phase 1：Godot MVP 游戏

目标：做一个能玩的隐藏 reversal-learning 游戏。

交付物：

```text
2D prototype scene
player movement
two choice objects
reward feedback
rule reversal controller
basic UI
```

验收标准：

```text
玩家可以完成至少 30 个 episode
规则会按配置反转
游戏不崩溃
没有心理学层也能作为小游戏运行
```

---

## Phase 2：Instrumentation Layer

目标：让游戏事件变成心理学事件流。

交付物：

```text
PsychRuntime
SessionManager
EpisodeManager
ProbeManager
EventTagger
BehaviorLogger
MockTriggerManager
```

验收标准：

```text
session_start / session_end 被记录
episode_start / episode_end 被记录
probe_start / probe_end 被记录
choice / feedback / rule_shift 被记录
raw_events.jsonl 有完整 schema
```

---

## Phase 3：Metrics Extraction

目标：从 raw event stream 生成 analysis-ready metrics。

交付物：

```text
parse_jsonl.py
compute_metrics.py
derived_metrics.csv
metric_definitions.md
example notebook
```

验收标准：

```text
能计算 rt_ms
能计算 stay_after_win
能计算 switch_after_loss
能计算 perseverative_error
能计算 learning_slope
所有 metric 都能追溯到 raw event
```

---

## Phase 4：Data QA / Replay / Debug

目标：证明数据不是“能写出来”，而是“可信”。

交付物：

```text
schema validator
event coverage report
session integrity checker
debug overlay
replay index
```

验收标准：

```text
每个 probe 的 expected_events 都能检查
缺失 event 会报警
重复 event 会报警
session 可以完整关闭
异常退出后数据仍可恢复
```

---

## Phase 5：Trigger / LSL / Timing Validation

目标：进入 EEG/fNIRS/眼动可扩展阶段。

交付物：

```text
LSLTriggerDriver
marker_map.json
trigger_log.jsonl
timing_validation_protocol.md
photodiode test scene
```

验收标准：

```text
marker_sent 事件被记录
LSL marker 可被外部 recorder 看到
Godot event 与 marker event 有关联 id
完成至少一轮 photodiode / external trigger validation
报告 mean latency / SD / jitter / 95% range
```

---

## Phase 6：Addon / Plugin 化

目标：把框架从 prototype 抽象成 Godot addon。

交付物：

```text
addons/psych_instrumentation
plugin.cfg
researcher debug panel
probe editor
marker map editor
condition table editor
```

验收标准：

```text
新 Godot 项目可以安装 addon
研究者可以配置 EventTag / Probe / MarkerMap
不用修改核心代码也能记录基本事件
```

---

## Phase 7：论文与开源发布

目标：形成 conceptual + framework + prototype validation 文章。

可能论文题目：

```text
Making Gameplay Experimentally Legible:
A Godot Layer for Event Tagging, Behavioral Logging,
and Neurophysiological Synchronization
```

或：

```text
Psych-Instrumented Games:
A Godot-Based Framework for Naturalistic Behavioral Experiments
```

论文结构建议：

```text
1. 传统任务生态效度局限
2. 被动自然主义范式与主动游戏范式的区别
3. 游戏作为 active naturalistic paradigm 的价值
4. 框架设计：Session / Episode / Probe / EventTag / BehaviorEvent / Metric / Marker
5. MVP prototype：hidden reversal-learning game
6. 数据结构与指标提取
7. timing / trigger validation
8. 局限与未来工作
```

---

## 15. 第一批任务清单

建议直接放入 `tasks.json`：

```text
T001 Create repository scaffold
T002 Write PRD and architecture docs
T003 Create Godot 4.6.x project
T004 Implement PsychRuntime autoload
T005 Implement SessionManager
T006 Implement BehaviorLogger JSONL writer
T007 Implement Event schema validator
T008 Build simple 2D reversal-learning scene
T009 Implement EpisodeManager
T010 Implement ProbeManager
T011 Log choice and feedback events
T012 Implement mock TriggerManager
T013 Generate raw_events_example.jsonl
T014 Build Python metric extractor
T015 Generate derived_metrics_example.csv
T016 Add researcher debug overlay
T017 Add event coverage tests
T018 Write timing validation protocol
T019 Write paper outline
T020 Package v0.1 MVP
```

优先级：

```text
P0: T001–T015
P1: T016–T018
P2: T019–T020
```

---

## 16. tasks.json 初始模板

```json
{
  "project": "godot-psych-instrumented-games",
  "current_phase": "phase_1_mvp",
  "tasks": [
    {
      "id": "T001",
      "title": "Create repository scaffold",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "Repository contains README.md, prd.md, architecture.md, tasks.json, progress.md",
        "Godot project directory exists",
        "analysis directory exists"
      ]
    },
    {
      "id": "T002",
      "title": "Write PRD and architecture docs",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "PRD states that the project is a psych-instrumented game framework",
        "PRD explicitly rejects trial-first framing for MVP",
        "Architecture defines Session, Episode, Probe, EventTag, BehaviorEvent, BehaviorMetric, Marker"
      ]
    },
    {
      "id": "T003",
      "title": "Create Godot project scaffold",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "Godot project opens without errors",
        "addons/psych_instrumentation exists",
        "scenes/prototype_reversal_game exists"
      ]
    },
    {
      "id": "T004",
      "title": "Implement PsychRuntime autoload",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "PsychRuntime can start and end session",
        "PsychRuntime exposes log_event API",
        "No scene-specific dependency exists in PsychRuntime"
      ]
    },
    {
      "id": "T005",
      "title": "Implement SessionManager",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "SessionManager creates unique session_id",
        "session_manifest.json is written",
        "session_start and session_end events are emitted"
      ]
    },
    {
      "id": "T006",
      "title": "Implement BehaviorLogger JSONL writer",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "Each event is written as one JSON object per line",
        "schema_version is included",
        "flush works",
        "append-only mode is used"
      ]
    },
    {
      "id": "T007",
      "title": "Implement event schema validator",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "Validator checks required fields",
        "Validator reports missing session_id, event_id, timestamp, event_tag",
        "Example invalid events fail validation"
      ]
    },
    {
      "id": "T008",
      "title": "Build simple 2D reversal-learning scene",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "Player can move",
        "Player can choose Tree A or Tree B",
        "Reward feedback appears",
        "Rule reverses according to config"
      ]
    },
    {
      "id": "T009",
      "title": "Implement EpisodeManager",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "episode_start and episode_end events are logged",
        "episode_id is attached to gameplay events",
        "Episode metadata includes rule_state and episode_index"
      ]
    },
    {
      "id": "T010",
      "title": "Implement ProbeManager",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "probe_start and probe_end events are logged",
        "probe_id is attached to choice and feedback events",
        "Expected events can be defined per probe"
      ]
    },
    {
      "id": "T011",
      "title": "Log choice and feedback events",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "response_made event is logged on choice",
        "feedback_positive or feedback_negative event is logged",
        "rt_ms is computed or recoverable from event timestamps"
      ]
    },
    {
      "id": "T012",
      "title": "Implement mock TriggerManager",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "Mock marker is emitted for key events",
        "marker_sent event is logged",
        "marker event links back to source event_id"
      ]
    },
    {
      "id": "T013",
      "title": "Generate raw_events_example.jsonl",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "Example includes session, episode, probe, choice, feedback, marker events",
        "Example validates against schema",
        "Example is documented"
      ]
    },
    {
      "id": "T014",
      "title": "Build Python metric extractor",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "compute_metrics.py reads raw_events.jsonl",
        "derived_metrics.csv is generated",
        "Metrics include rt_ms, stay_after_win, switch_after_loss, perseverative_error"
      ]
    },
    {
      "id": "T015",
      "title": "Generate derived_metrics_example.csv",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "CSV contains one row per episode or probe",
        "CSV links back to session_id and episode_id",
        "CSV metrics are reproducible from raw events"
      ]
    }
  ]
}
```

---

## 17. acceptance_tests.md 初始模板

```md
# Acceptance Tests

## A. Project Scaffold
- [ ] Repository contains required root files.
- [ ] Godot project opens without errors.
- [ ] analysis directory contains Python scripts.

## B. Runtime Lifecycle
- [ ] Session can start.
- [ ] Session can end.
- [ ] session_manifest.json is written.
- [ ] session_start and session_end events are logged.

## C. Event Logging
- [ ] Every event contains schema_version.
- [ ] Every event contains session_id.
- [ ] Every event contains event_id.
- [ ] Every event contains timestamp_usec.
- [ ] Every event contains event_tag.
- [ ] JSONL contains one valid JSON object per line.

## D. Episode / Probe Flow
- [ ] episode_start precedes episode_end.
- [ ] probe_start precedes probe_end.
- [ ] choice events include episode_id and probe_id.
- [ ] feedback events include episode_id and probe_id.

## E. Reversal Game
- [ ] Player can choose A or B.
- [ ] Feedback is generated.
- [ ] Rule reversal occurs.
- [ ] rule_shift event is logged.

## F. Metrics
- [ ] Metric extractor runs without error.
- [ ] derived_metrics.csv is generated.
- [ ] rt_ms is computed.
- [ ] stay_after_win is computed.
- [ ] switch_after_loss is computed.
- [ ] perseverative_error is computed.

## G. Trigger Mock
- [ ] marker_sent event is logged.
- [ ] marker links to source event.
- [ ] mock driver works without hardware.
```

---

## 18. 最小闭环验收标准

第一版只要完成下面 10 件事，就已经是强 MVP：

```text
1. Godot 游戏可运行
2. 有隐藏 reversal-learning 结构
3. 有 Session
4. 有 Episode
5. 有 Probe
6. 有 EventTag
7. 有 raw_events.jsonl
8. 有 derived_metrics.csv
9. 有 mock marker
10. 有 Python/R 分析模板
```

完成后可以明确表述：

```text
我们实现了一个 Godot psychological instrumentation layer，
使自然主义游戏过程中的关键事件可以被标注、记录、导出和分析。
```

这比“做了一个游戏化心理学任务”更有学术与工具价值。

---

## 19. 开发风险与控制策略

### 风险 1：Agent 把项目做成 trial-first experiment runner

控制：

```text
在 prd.md 中写死核心原则。
所有任务验收必须检查 Episode / Probe / EventTag，而不是只检查 trial。
```

### 风险 2：过早做插件 UI

控制：

```text
MVP 前禁止完整 editor plugin。
先实现运行时、数据和原型。
```

### 风险 3：只保存 derived metrics

控制：

```text
Raw event stream 必须是 P0。
所有 metric 必须能从 raw event 重新计算。
```

### 风险 4：timing 声称过强

控制：

```text
MVP 只声称支持日志和 mock marker。
EEG/fNIRS 相关同步精度必须经外部设备验证后再写入论文。
```

### 风险 5：游戏内容复杂度过高

控制：

```text
第一版只做 2D reversal-learning prototype。
美术、剧情、复杂交互全部后置。
```

---

## 20. 推荐下一步

建议立刻执行：

```text
Step 1: 创建 repository scaffold
Step 2: 写入 prd.md / architecture.md / tasks.json / progress.md
Step 3: 创建 Godot 4.6.x 项目
Step 4: 实现 PsychRuntime + SessionManager + BehaviorLogger
Step 5: 做最小 reversal-learning 场景
Step 6: 接入 Episode / Probe / EventTag
Step 7: 生成 raw_events.jsonl
Step 8: 写 Python metric extractor
```

第一轮 agent 开发不要超过这个范围。

最终目标不是先做大框架，而是先证明这个闭环：

```text
游戏行为 → 心理学事件标注 → 原始事件流 → 可解释指标 → 可验证同步扩展
```

只要这个闭环跑通，项目就可以继续扩展为论文、Godot addon、后端系统和神经生理同步工具。

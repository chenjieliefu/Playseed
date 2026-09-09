# Playseed

[English](README.md) | **简体中文**

当前仓库版本：**0.8.53**

<p align="center">
  <img src="docs/images/playseed-product.png" alt="Playseed产品界面截图" width="960">
</p>

实际创作主页截图（0.8.38）。当前源码已支持网页2D与实验性Three.js 3D在本机浏览器制作和试玩，公开分享链接尚未接通。

让制作游戏变得简单，让每个人都有自己的游戏。

Playseed 是一个 macOS 本机 AI 游戏创作原型。用户用中文说出想法，先说明想让朋友怎么玩到——**下载到电脑玩**，还是**发链接在网页直接玩**；Playseed 帮助他整理方案、准备素材、生成可以试玩、修改和恢复版本的游戏。当前本机2D和实验性3D房间寻物可用；网页2D与实验性Three.js 3D已接通本机浏览器制作/试玩，公开分享链接尚未接通，真实状态见[当前能力与边界](docs/04-当前能力与边界.md)与[路线图](docs/05-路线图.md)。

## 直接使用

### 从 GitHub 获取源码

仓库保存源码、测试、品牌素材和文档。`Playseed.app`、`.playseed/`、个人游戏工程、导出文件及临时文件由本机生成，不随源码上传；仓库中的验收截图和说明用于记录已有验证，试玩入口依赖原本机的验收工程，克隆后不能直接打开这些历史样本。

开发环境需要 macOS、Python 3.11、已登录的 Codex CLI，以及 Godot 运行程序。安装 Xcode Command Line Tools 后，在仓库目录指定本机 Godot 的实际路径构建：

```sh
python3 scripts/build_macos_app.py --runtime "/实际安装位置/Godot.app/Contents/MacOS/Godot"
```

网页制作与检查另需 Node.js、Google Chrome，并在仓库目录运行 `npm ci` 安装锁定的依赖。

基础道具制作另需本机安装 Blender；本机去背景需要 macOS 14 或更新版本。当前是本机开发原型，换机器后仍需核对本机依赖和运行路径，不是可直接分发的安装包。

### 在已构建的本机应用中创作

1. 双击本机构建的 `Playseed.app`。
2. 在创作主页说出游戏想法，可用圆形“＋”提供参考图或提前选择空文件夹；输入框下方可选择“玩的方式”（还没想好 / 下载到电脑玩 / 发链接在网页玩）。
3. 选择 GPT 模型和对应的思考强度（可选范围见[当前能力](docs/04-当前能力与边界.md)），点击“开始创作”。
4. 选择或新建一个空文件夹，作为这个游戏的独立项目目录。
5. 在对话里理清并确认第一版方案，准备素材和制作清单，然后开始制作。
6. 按交付方式通过Godot或浏览器检查后，打开独立窗口试玩；回到同一个聊天框继续描述修改。

Playseed 使用这台 Mac 上 Codex CLI 登录的 GPT 账号，不保存用户密码。游戏、素材和版本放在用户选择的项目文件夹；对话、方案和任务日志保存在本项目的 `.playseed/`。

## 它怎样制作游戏

Playseed 按两种交付方式组织制作：想“下载到电脑玩”的，用 GPT 写玩法、Godot 负责运行（2D 已稳定；3D 房间寻物为实验范围，需要精细模型时由本机 Blender 制作）；网页方向已支持GPT生成画板2D和Three.js 3D，先在本机浏览器试玩，公开分享仍待接入；Blender 继续只做素材。两种方向共用同一套对话、方案、素材和版本体系，素材保存在同一项目库；网页当前可用PNG和程序造型，声音和GLB入场仍待接入。

已接通实验性3D房间寻物：确认方案并准备清单后，在制作按钮下选择3D；当前支持几何体房间、行走碰撞、拾取和出口目标。可通过`验收游戏/3D 验证 · 温室寻物.command`试玩，静态基础色GLB可作为障碍外观，贴图、骨骼、战斗、跳跃与3D声音尚未接通。

确认方案后可发送“生成模型：”加道具描述，用本机Blender制作静态道具草稿，查看两个角度后采用。可双击[Blender道具试玩](验收游戏/Blender%20道具%20·%20温室种植箱.command)查看已采用的种植箱。也可从“素材 → 模型素材与来源”导入、补齐资料、重新预览，再添加到对话制作新版本。双击[模型入场试玩](验收游戏/模型入场%20·%20温室寻物.command)查看已验证的花盆场景。

新手比较试玩可双击`验收游戏/新手试玩 · 从这里开始.command`，按三段任务体验并保存反馈。操作与验收边界见[新手试玩与体验验收](docs/11-新手试玩与体验验收.md)。

已生成的五类开发验收样本在 [验收游戏](验收游戏/) 文件夹中，双击中文 `.command` 入口可打开独立试玩窗口。每款已完成三轮修改，默认打开最新版，也可打开最初版本比较。运行、专项玩法和自动输入通关检查已通过，文件夹内有结算画面；尚未进行普通用户体验评估，准确范围见当前能力文档。

Playseed 当前的主要分工：

- GPT 理解想法、整理方案并编写或修改GDScript或网页JavaScript。
- Godot 4.7.2运行Playseed界面与本机游戏；独立Chromium负责网页游戏，Three.js负责网页3D。
- Python 调用模型、校验结果、隔离运行并保存版本。

新生成版本必须经过对应运行环境的真实核心操作与重开检查。本机游戏使用实际 `playseed_action`；网页游戏使用隔离浏览器中的真实输入。新版网页宿主还检查暂停、继续及连续两次重开后仍能操作；手势专用模式使用模拟摄像头和合成关键点，不代表真人手感验收。

本机2D的声音从右侧“素材 → 声音素材与音量”导入、试听，再添加到对话用于下一版游戏。声音样本可双击[试玩入口](验收游戏/声音验证%20·%20灯塔守卫.command)。

详细调用链见 [系统架构](docs/03-系统架构.md)。当前稳定范围是本机小型 2D 游戏与实验性 3D 房间寻物；网页2D和实验性Three.js 3D已接通本机浏览器流程，联网和公开发布尚未接通。准确范围见 [当前能力与边界](docs/04-当前能力与边界.md)。

## 项目文档

从 [文档中心](docs/README.md) 开始阅读：

- [产品定义](docs/01-产品定义.md)
- [用户创作流程](docs/02-用户创作流程.md)
- [系统架构](docs/03-系统架构.md)
- [当前能力与边界](docs/04-当前能力与边界.md)
- [路线图](docs/05-路线图.md)
- [AI 协作指南](docs/06-AI协作指南.md)
- [关键决策记录](docs/07-决策记录.md)

竞品实测、截图和旧版本落地过程保存在 `research/`，只作为研究证据，不代表当前产品方案。其他 AI 参与开发前先读 [AGENTS.md](AGENTS.md)。

## 主要代码

| 文件 | 作用 |
|---|---|
| `app/creator.gd` | Playseed 主界面和交互状态 |
| `backend.py` | 本地任务入口、GPT 调用和请求分发 |
| `creator.py` | 对话、方案、确认和制作清单 |
| `producer.py` | 本机生成、Godot 检查及交付分流 |
| `web_games.py` | 网页生成、修复上下文、浏览器检查与版本 |
| `runtime/web/` 与 `scripts/web_runner.mjs` | 可信网页宿主、组件、手势输入和隔离检查 |
| `resources.py` | 图片素材、可信动画/特效辅助和导出 |
| `audio_assets.py` | 声音素材校验、来源、音量与版本快照 |
| `project_ops.py` | 项目置顶、重命名和删除 |
| `scripts/build_macos_app.py` | 重新生成 macOS 应用 |

## 验证

当前共149项Python检查；包含独立2D/3D网页制作、多轮修改与恢复、暂停/继续、连续重玩、失败修复和历史宿主兼容。检查通过不代表任意生成质量、全部玩法机制或真人体验已验收。

```sh
python3 -m unittest discover -s tests -v
"./Playseed.app/Contents/MacOS/PlayseedRuntime" --headless --path app --script game_tests.gd
"./Playseed.app/Contents/MacOS/PlayseedRuntime" --headless --path app --script input_tests.gd
"./Playseed.app/Contents/MacOS/PlayseedRuntime" --headless --path app --script creator_tests.gd
```

重新打包：

```sh
python3 scripts/build_macos_app.py
```

当前 `Playseed.app` 内含 Godot 运行组件，并依赖 Python 3.11 与 Codex CLI。应用标识为 `local.playseed.studio`。本机开发应用尚未进行对外发行和公证。

### 网页小游戏（0.8.40）

本机需要Node.js和Google Chrome；在仓库运行 `npm ci --ignore-scripts` 安装网页检查依赖。新项目选择网页交付，再选2D或3D，可在独立浏览器试玩、修改、恢复并导出静态网页ZIP。网页公开托管尚未接通，本机临时地址不是公开分享链接。新网页版本支持可选实验手势与程序合成音效；手势需要用户点开启并允许摄像头。真人稳定性、音频文件和GLB入场尚待完善。

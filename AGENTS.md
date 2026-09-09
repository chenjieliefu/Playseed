# Playseed AI 协作入口

开始任何产品或代码任务前，先读 [docs/README.md](docs/README.md)。它是文档总入口，并说明每类任务还要读哪一份资料。

## 项目目标

Playseed 帮助没有编程和游戏制作经验的人，通过对话把游戏想法逐步变成可以试玩、继续修改和恢复版本的游戏。产品能力是重点，仓库中的示例游戏只用于验证能力。

## 必须保持的产品边界

- 面向中国用户的界面和用户文案使用简体中文。
- 先理解想法、确认方案和准备素材，再制作游戏；每个状态必须反映真实完成情况。
- 两种交付方式共用同一产品：本机（下载到电脑玩）游戏当前可制作，其中 2D 稳定、实验性 3D 房间寻物可用；网页2D与实验性Three.js 3D可在本机浏览器制作和试玩；网页可选手势与合成音效为实验能力，真人手势稳定性待验收；公开分享链接、网页音频文件/导入模型及超出已验证范围的内容完成前，要明确显示为尚未接通。
- 生成代码必须先经过静态限制、隔离运行、真实输入和重开检查：本机使用Godot解析与运行；网页使用JavaScript解析与独立Chromium浏览器检查。通过后才能成为新版本。
- 用户选择的项目文件夹包含游戏工程、素材和版本；重命名和删除必须同步处理文件夹，并保留现有安全校验。

## 修改流程

1. 阅读与任务相关的当前文档和代码，不使用历史研究文档推断当前实现。
2. 将用户要求落实到真实流程；按钮和状态不能只做展示。
3. 修改对应测试，运行与改动范围匹配的检查。
4. 更新唯一的权威文档。版本考察和竞品截图放在 `research/`，不复制成第二份当前规划。
5. 交接时写明：改了什么、为什么、验证结果、仍未完成什么、下一步从哪里开始。

## 常用验证

```sh
python3 -m unittest discover -s tests -v
"./Playseed.app/Contents/MacOS/PlayseedRuntime" --headless --path app --script game_tests.gd
"./Playseed.app/Contents/MacOS/PlayseedRuntime" --headless --path app --script input_tests.gd
"./Playseed.app/Contents/MacOS/PlayseedRuntime" --headless --path app --script creator_tests.gd
```

重新生成 macOS 应用：

```sh
python3 scripts/build_macos_app.py
```

`.playseed/jobs/`、`.playseed/qa/`、`exports/`、`Playseed.app/` 和各游戏项目的 `revisions/` 是运行或验证产物，不是产品计划的来源。

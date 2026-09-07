from pathlib import Path
import json,html,base64
ROOT=Path(__file__).resolve().parent
rows=[
('01 首页','开始一个游戏','输入想法；可添加参考图；选择 Smart / Quality；点 START','首页同时显示项目卡和剩余作品位','想法必填；参考图、模式属于可选设置','测试账号已有 1 个项目、剩余 0 个作品位','创建名额和生成任务是两个限制','E001','S001-home.png'),
('02 创建受限','启动本次测试','输入小猫收集星星的测试想法，点击 START','提示当前已有 1 个运行任务，上限 1 个','等待当前任务结束','未创建第二个项目','不是点击成功就代表任务已经开始','E007','S007-create-limit.png'),
('03 澄清主题','把模糊想法变成可做的主题','历史原文：帮我生成一个愤怒的小鸟；已选暴躁团雀大战偷蛋浣熊','ASKED · ANSWERED；问题与选择结果留在对话里','选择主题或自由补充','后续出现完整方案','这是进入前的历史，未亲手操作原始提问','E004','S004-original-question.png'),
('04 查看方案','知道将做什么','点击“查看完整方案”','GAME PLAN 弹窗；分玩法、控制、关卡、美术、音频等章节','可关闭，回到制作页','仍保留同一项目与制作状态','首次锁定前是否需单独确认，待补充','E005','S005-full-plan.png'),
('05 制作中','知道 AI 正在做什么','等待；可查看任务卡与素材','左边对话事件；底部当前步骤、计数、计时和 STOP；右边占位','等待或停止，无需手动点每个工具','任务清单从 0/7 到 7/7；角色图、背景、音频出现','工具术语多，普通人未必看得懂','E002','S002-building.png'),
('06 自动修复','生成失败时继续前进','本阶段未额外点击','素材有失败标记；加载检查 2/3 待修复，后面继续写入和测试','这一轮由系统继续，无需人点重试','出现后续测试截图与 READY','工具卡勾选与内部结果偶有冲突，不能只看绿色勾','E011','S009-first-ready.png'),
('07 试玩','确认真的能玩','在右侧直接拖拽鸟，按空格；随后点画面并按 R','鸟数量从 2 变 1，出现鼓气提示；重开恢复开局；最终 LIVE 60fps','满意则继续；不满意写修改要求','右侧从占位变为可交互游戏','已验证发射与重开，不等于所有关卡和物理机制通过','E010','S010-play-shot.png'),
('08 设备预览','检查不同屏幕','点“桌面”选择“手机 · 竖屏”','右侧改为窄长预览；桌面、手机横屏、平板同列','选一种预览尺寸，可切回桌面','同一游戏在另一尺寸显示','该样本竖屏文字很小；没有看到方案承诺的旋转提示','E013','S013-phone-portrait.png'),
('09 继续修改','给当前游戏加操作提示','同一个输入框输入具体要求，点 SEND','输入被清空；按钮变 STOP；开始新一轮；旧游戏保留在右侧','只需说要改什么，无“聊方案 / 改游戏”选择','记录新要求，继续读写和测试','底部仍沿用上轮 COMPLETE 清单，容易误读','E014','S014-modification-sent.png'),
('10 查看任务','展开具体制作步骤','点击底部任务摘要','展开 7 条任务，再点可收起','是否查看详细过程属于可选动作','对话与游戏位置不变','本次修改未及时更新任务清单','E015','S015-progress-toggle.png'),
('11 手动停止','中断这一轮修改','点击 STOP','本轮已停止；已完成内容保留，可以继续或重新生成；SEND 恢复','继续描述或先试玩','旧预览仍可用；停止记录出现','主动停止被放在“出错”样式里','E016','S016-stopped.png'),
('12 停止后继续','完成刚才的小改动','输入“继续完成上一条操作提示”，点击 SEND','新一轮计时、读写、自动试玩检查','等待结果，再实际验收','继续同一项目，没有再填初始方案','有写入失败后继续修复的过程','E017','S017-resume.png'),
]
evidence=[dict(stage=r[0],goal=r[1],action=r[2],feedback=r[3],decision=r[4],change=r[5],friction=r[6],id=r[7],screenshot=r[8]) for r in rows]
(ROOT/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2))
header='''# MakePlay 实测与 Playseed 交互改造依据

本次查看范围：2026-09-05（北京时间），ego lite 已登录的 MakePlay 创作首页和项目“这蛋不能忍”。进入时项目正在生成；本次亲自测试了新建入口、方案弹窗、实时试玩、设备尺寸、一次小修改、停止和继续。原始需求及主题选择通过该项目可见历史还原，不能冒充本次从零生成。

尚未确认：账号没有空余作品位；首次方案确认环节的按钮需用户补充；未公开发布或保存副本；未证明所有关卡、碰撞及材质机制完成。页面显示的模型工具卡只证明展示过该事件，不证明内部架构或工具成功结果。

## 用户旅程证据表

| 阶段 | 用户目标 | 用户动作 | 页面反馈 | 用户需要做的决定 | 页面/资产状态变化 | 问题或阻力 | 证据 |
|---|---|---|---|---|---|---|---|
'''
for r in rows:
    vals=[r[0],r[1],'【页面事实】'+r[2],'【页面事实】'+r[3],r[4],'【页面事实】'+r[5],'【合理推断】'+r[6],f'{r[7]} · [{r[8].split("-")[0]}](screenshots/{r[8]})']
    header+='| '+' | '.join(x.replace('|','／') for x in vals)+' |\n'
header+='''
## 前端与 UI：具体学什么

- 【页面事实，E001】首页集中一个输入框与 START，模式选择和参考图是附加项；下面是已有项目卡片。首页不是把整个编辑器同时展示出来。
- 【页面事实，E002/E009】桌面工作区主要是左对话、右预览两栏，项目入口在顶部。Playseed 保留用户明确要求的左侧项目栏，构成“项目 / 对话 / 预览”三栏，属于我们的适配，不声称竞品也是三栏。
- 【页面事实，E005/E015】完整方案用弹窗，任务步骤可折叠。对话一直是进展和决策的中心，不需要右侧长期占满方案文字。
- 【页面事实，E009/E010/E014】游戏在右侧页面内实际运行；修改期间旧画面仍保留。预览有重载、静音、全屏和设备尺寸入口。
- 【页面事实，E002】深紫底、粉色主按钮、青绿状态、像素字与硬边框形成统一游戏风格。Playseed 使用自己的奶油绿和吉祥物，不需要复制它的配色或品牌资产。
- 【页面事实，DOM 观察】右侧游戏使用带 allow-scripts / allow-pointer-lock 的 iframe；对话区域独立滚动，观察窗口宽 1454px 时对话约 454px。不能据此推断它后台使用什么模型或有多少代理。

## 三个最值得讨论的体验问题

1. 【合理推断，E009/E011/E014】“任务完成”“生成停止”“真正符合玩法要求”混在一起：7/7 COMPLETE 后还继续工作，并承认多个验收项未达成。Playseed 要分别标明正在制作、检查通过可试玩、已知未实现项。
2. 【合理推断，E002/E005/E015】它减少了需要用户点的按钮，但大量英文工具记录会增加阅读负担。Playseed 默认显示中文阶段摘要，技术细节折叠。
3. 【合理推断，E010/E013】有画面不代表好玩或适配完成。实际发射、重开、手机尺寸需要验证；Playseed 不能把静态截图叫成实时试玩。

## 用户感受与待补充

【页面事实】本轮没有用户在 MakePlay 内明确表达情绪的记录。
【合理推断，E007/E011/E016】创建受限、完成状态矛盾、主动停止被标成错误，可能让新手犹豫或担心内容丢失。
待用户补充：你在哪一步最不清楚该点什么？你的实际感受是否与上述推断一致？

## 应用到 Playseed：按证据分批做

| 改动 | 依据 | 实施边界 |
|---|---|---|
| 方案作为对话中的摘要卡，详细内容点开看 | E004/E005 | 保留完整方案和已有确认记录 |
| 确认方案与开始制作合并成一个明确动作 | E005 + 我们现有两次点击 | 属于 Playseed 简化建议；竞品首次确认细节待补充 |
| 生成时显示真实阶段与可展开的过程记录 | E002/E015 | 只标已经发生的步骤，不伪造资产或进度百分比 |
| 已有游戏默认输入修改要求，讨论方案放次级入口 | E014/E017 | 保留单独讨论的功能，用户无需每次选工作模式 |
| 成功、主动停止、错误使用不同文案；旧游戏保留 | E011/E016 | 已有版本必须安全保留 |
| 工作台内实时试玩、设备尺寸 | E010/E013 | 后续独立工程项；目前是 Godot 隔离窗口，不能把 PNG 包装成实时试玩 |
| 图片、音效素材过程卡 | E002 | 需真正接通素材链路，当前程序绘图阶段不做假卡片 |
| 发布与分享 | 仅顶部入口可见 | 没有公开发布，本轮不照猜流程 |
'''
(ROOT/'用户旅程证据与改造依据.md').write_text(header)
extra=[
('13 修改验收','确认改动真的出现','查看更新后的右侧游戏','底部出现拖拽发射、空格鼓气、R 重开提示；状态 LIVE','继续试玩或再提要求','本次小改动可见，之前的角色和场景仍在','只验证这一处变化，不宣称所有缺失机制补齐','E018','S018-modification-result.png'),
('14 项目信息','找到名称、简介和封面入口','点顶部游戏名，查看后取消','编辑游戏信息对话框，含名称、简介、封面、随机起名、保存','保存或取消','本次取消，未改元信息','未观察到可浏览的版本历史入口','E021','S021-project-info.png'),
('15 再试新建','验证零作品位的真实阻断','任务结束后再次在首页点 START','弹窗“作品位用完了”；邀请好友、获得方式、以后再说','以后再说或自行处理额度','没有新增项目','与运行并发限制不同，应在产品里明确区分','E023','S023-slot-limit.png')]
for r in extra:
    evidence.append(dict(stage=r[0],goal=r[1],action=r[2],feedback=r[3],decision=r[4],change=r[5],friction=r[6],id=r[7],screenshot=r[8]))
evidence[5]['screenshot']='S019-check-failure.png'
(ROOT/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2))
report=ROOT/'用户旅程证据与改造依据.md'
text=report.read_text().replace('E011 · [S009](screenshots/S009-first-ready.png)','E011 · [S019](screenshots/S019-check-failure.png)')
insert=''
for r in extra:
    insert+='| '+' | '.join([r[0],r[1],'【页面事实】'+r[2],'【页面事实】'+r[3],r[4],'【页面事实】'+r[5],'【合理推断】'+r[6],f'{r[7]} · [{r[8].split("-")[0]}](screenshots/{r[8]})'])+' |\n'
text=text.replace('\n## 前端与 UI', '\n'+insert+'\n## 前端与 UI')
text+='\n\n补充索引：E009 = 首次 READY 与游戏画面（S009）；E012 = 重开后的开局（S012）；E020 = 素材卡片（S020）；E022 = Smart / Quality 菜单（S022）。E008 为站内引导弹窗，只代表产品说明，不作为实际完成发布的证据。\n'
report.write_text(text)

template=Path('/Users/chenjieliefu/.codex/skills/map-product-user-journey/assets/user-journey-template.html').read_text()
css=template.split('<style>')[1].split('</style>')[0]
css+='''
nav{display:flex;gap:8px;flex-wrap:wrap}button{cursor:pointer;font:inherit;border:1px solid #d9dfe8;border-radius:8px;background:#fff;padding:8px 12px}button.active{background:#17202a;color:white}.intro{font-size:17px;max-width:940px}.table-wrap{overflow:auto}td{min-width:130px}td:first-child{min-width:100px}.shot{position:relative;margin:14px 0;background:#17121f;border-radius:10px;overflow:hidden}.shot img{display:block;width:100%;height:auto}.pin{position:absolute;width:28px;height:28px;border-radius:50%;background:#f7df59;color:#17202a;font-weight:800;display:grid;place-items:center;transform:translate(-50%,-50%);box-shadow:0 0 0 3px #1118}.callouts{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:10px}.callouts p{margin:0;padding:12px;background:#f6f7fb;border-radius:8px}.node .badge{margin-bottom:6px}.branch{font-size:12px}.decision-wrap{padding:22px 0}.flow .grid{grid-template-columns:110px repeat(var(--steps),200px);min-width:max-content}.grid .node{min-height:165px}.editable:focus{outline:2px solid #3763d8}.muted{color:var(--muted)}
'''
def h(t):return html.escape(str(t))
def node(title,body,ids,kind='',confidence='页面事实'):
    return f'<article class="node {kind}"><span class="badge {"unconfirmed" if confidence=="尚未确认" else "fact"}">{confidence}</span><h3>{h(title)}</h3><p>{h(body)}</p><span class="evidence">{h(ids)}</span></article>'
def diamond(title,branches,ids):
    return f'<div class="decision-wrap"><div class="decision"><div>{h(title)}<div class="branch">{h(branches)}</div><span class="evidence">{h(ids)}</span></div></div></div>'
stages=['开始','明确方向','制作与检查','试玩','提出修改','停止 / 继续','验收 / 发布']
flow='<div class="grid" style="--steps:7"><div></div>'+''.join(f'<div class="stage">{x}</div>' for x in stages)
flow+='<div class="lane-label lane-user">用户</div>'
flow+=node('写一句想法','必做：输入 + START；选模式、加参考图可选。','E001 · S001')
flow+=node('回答关键问题','历史已回答角色主题；首次确认按钮尚待补充。','E004/E005 · S004/S005')
flow+=diamond('等还是停？','等待 → 制作；STOP → 中断','E002/E016')
flow+=node('右边直接玩','拖拽发射、空格鼓气、R 重开；可切设备尺寸。','E010/E013 · S010/S013')
flow+=node('一句话修改','输入底部操作提示要求 → SEND，无需选择工作模式。','E014 · S014','edit')
flow+=node('停止后再继续','STOP 后重新输入继续要求 → SEND。','E016/E017 · S016/S017','edit')
flow+=node('看结果再决定','操作提示已出现；发布只看到入口，未执行。','E018 · S018')
flow+='<div class="lane-label lane-ui">产品界面</div>'
flow+=node('首页','输入框、模式卡、作品位、已有项目；满额会弹窗。','E001/E023 · S001/S023')
flow+=node('方案卡与弹窗','对话内保留答案；“查看完整方案”打开长文。','E004/E005 · S004/S005')
flow+=node('固定进度区','步骤摘要可展开；计时 + STOP；右边先占位。','E002/E015 · S002/S015')
flow+=node('真实预览','占位变成游戏；工具栏有设备、重载、声音、全屏。','E009/E010 · S009/S010')
flow+=node('保留旧画面','清空已发送文字；SEND 变 STOP；旧预览留在原处。','E014 · S014','edit')
flow+=node('中断反馈','提示本轮已停止，可继续；SEND 恢复。','E016 · S016','fail')
flow+=node('最终结果','LIVE、已保存、下一步建议；底部操作条清楚可见。','E018 · S018')
flow+='<div class="lane-label lane-system">系统结果</div>'
flow+=node('创建阻断','先因并发上限，后来因零作品位；均未新建。','E007/E023 · S007/S023','fail')
flow+=node('初始制作','原项目已锁定方案；进入前的确认行为无法仅凭历史还原。','E004/E005','unknown','尚未确认')
flow+=node('素材 → 代码 → 检查','看到资产、音频、代码和测试事件；失败后继续修复。','E002/E011/E020 · S019/S020')
flow+=node('完成不等于达标','有可玩画面，但记录承认多项方案要求未达成。','E011 · S009')
flow+=node('增量修改','读取现有内容，写入改动，再自动检查。','E014/E017 · S014/S017','edit')
flow+=diamond('是否继续？','继续 → 同项目新一轮；停止 → 留在预览','E016/E017')
flow+=node('发布结果未验证','没有执行公开发布；上线、分享与审核结果不能猜。','入口可见，后续未知','unknown','尚未确认')
flow+='</div>'
shots=[
('首页：先说想法','S001-home.png',[(27,55,'1','主输入：一句话描述玩法与氛围。'),(76,55,'2','START：真正提交任务的主动作。'),(52,75,'3','Smart / Quality：附加模式选择。'),(30,47,'4','作品位：创建之前的资源限制。'),(29,91,'5','已有项目：回到原游戏继续做。')]),
('生成中：过程可见','S002-building.png',[(15,39,'1','左侧事件流：工具结果和检查截图。'),(20,82,'2','固定步骤摘要：可展开详情。'),(16,87,'3','制作计时：等待不遮住页面。'),(27,94,'4','STOP：中断当前轮次。'),(66,56,'5','右侧占位：之后原地变成可玩游戏。')]),
('修改完成：同一输入继续','S018-modification-result.png',[(15,33,'1','完成信息：需与真实画面核对。'),(65,50,'2','右侧可互动游戏，非静态图片。'),(16,95,'3','继续输入修改要求；SEND 提交。'),(8,59,'4','可选修改建议，帮助新手继续。'),(66,91,'5','本次要求已落地：底部中文操作提示。')]),
('停止：保留结果并继续','S016-stopped.png',[(16,57,'1','停止后对话出现明确反馈：本轮已停止，内容保留。'),(66,52,'2','右侧原有预览保留。'),(27,95,'3','恢复 SEND，可发一句话继续。')]),
]
shotdata=[]
for title,file,pins in shots:
    shotdata.append({'title':title,'file':file,'src':'data:image/png;base64,'+base64.b64encode((ROOT/'screenshots'/file).read_bytes()).decode(),'pins':pins})
tablerows=''.join('<tr>'+''.join(f'<td>{h(x)}</td>' for x in [r['stage'],r['goal'],'【页面事实】'+r['action'],'【页面事实】'+r['feedback'],r['decision'],'【页面事实】'+r['change'],'【合理推断】'+r['friction'],r['id']+' · '+r['screenshot'].split('-')[0]])+'</tr>' for r in evidence)
page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MakePlay 实测 · Playseed 的流程依据</title><style>{css}</style><main class="page"><h1>先走一遍，再做 Playseed</h1><p class="subtitle">MakePlay 已登录实测 · 2026-09-05 · 现有项目「这蛋不能忍」</p><p class="intro">亲自跑过：新建受限、方案查看、实时试玩、手机尺寸、修改、停止、继续和改动验收。原始提问来自项目历史；未公开发布。下面把“人点什么”和“系统做什么”分开标明。</p><section class="panel"><h2>先看真实记录</h2><p>【页面事实】修改后的底部操作提示已经出现。【尚未确认】首次方案确认按钮与公开发布后的流程；不是所有玩法都已验收。</p><div class="table-wrap"><table><thead><tr>{''.join('<th>'+x+'</th>' for x in ['阶段','用户目标','用户动作','页面反馈','用户需要做的决定','页面/资产状态变化','问题或阻力','证据'])}</tr></thead><tbody>{tablerows}</tbody></table></div></section><section class="panel"><h2>界面标注：点标签切换截图</h2><nav id="shot-tabs"></nav><div class="shot"><img id="shot-img" alt="MakePlay 实测截图"><div id="pins"></div></div><div id="callouts" class="callouts"></div><p id="shot-source" class="muted"></p></section><section class="panel legend"><span class="badge fact">页面事实</span><span class="badge inference">合理推断</span><span class="badge unconfirmed">尚未确认</span><span>蓝线：主流程</span><span>紫线：修改</span><span>红线：失败 / 停止</span><span>菱形：选择及分支</span><span>E：证据编号；S：截图编号</span></section><section class="panel flow" aria-label="三泳道用户旅程"><h2>用户 → 界面 → 系统结果</h2><p class="muted">横向滚动查看完整路径。虚线节点表示尚未验证。</p>{flow}</section><section class="panel"><h2>迁移到 Playseed</h2><div class="cards"><article class="card"><h3>对话是主入口</h3><p>【合理推断，E004/E005/E014】计划、问题与修改留在对话里。方案卡点开看，不强迫用户反复切工作模式。</p></article><article class="card"><h3>让等待有内容</h3><p>【合理推断，E002/E015】显示真实阶段、耗时和停止；详细过程折叠。不造素材卡，不把进度条当完成证明。</p></article><article class="card"><h3>保留用户的三栏要求</h3><p>【合理推断，E002/E010】MakePlay 桌面是两栏 + 顶部项目入口。Playseed 适配为项目 / 对话 / 效果，保留自己的品牌。</p></article><article class="card"><h3>实时试玩仍有差距</h3><p>【尚未确认】Playseed 现在是开场图 + 隔离试玩窗口。内嵌试玩和素材生成需真实工程支持，不能只做相似外壳。</p></article></div></section><section class="panel"><h2>三个值得讨论的问题</h2><ol><li>【合理推断，E011/E014】完成状态与实际工作不一致：应区分可试玩、检查通过和玩法达标。</li><li>【合理推断，E002/E015】工具记录太多：新手默认看中文步骤，想排查时再展开。</li><li>【合理推断，E010/E013】桌面可玩不等于手机可用：需要验收真实输入与不同屏幕。</li></ol></section><section class="panel"><h2>用户感受与补充</h2><p>【页面事实】未观察到用户在网站内明确表达情绪。【合理推断，E007/E011/E016】限制、矛盾状态与“停止=出错”可能造成疑惑。</p><div class="editable" contenteditable="true">待用户补充：你在哪一步最不清楚该点什么？</div><p></p><div class="editable" contenteditable="true">待用户补充：当时你的期待、感受和主要阻力是什么？（本页输入只用于当前查看，不自动保存）</div></section></main><script>const shots={json.dumps(shotdata,ensure_ascii=False)};const tabs=document.getElementById('shot-tabs');shots.forEach((s,i)=>{{let b=document.createElement('button');b.textContent=s.title;b.onclick=()=>show(i);tabs.append(b)}});function show(i){{const s=shots[i];document.getElementById('shot-img').src=s.src;document.getElementById('pins').replaceChildren();document.getElementById('callouts').replaceChildren();s.pins.forEach(([x,y,n,t])=>{{let p=document.createElement('span');p.className='pin';p.style.left=x+'%';p.style.top=y+'%';p.textContent=n;document.getElementById('pins').append(p);let c=document.createElement('p');c.textContent=n+' · '+t;document.getElementById('callouts').append(c)}});document.getElementById('shot-source').textContent='截图：'+s.file;[...tabs.children].forEach((b,j)=>b.classList.toggle('active',i===j))}}show(0);</script></html>'''
(ROOT/'MakePlay实测流程图.html').write_text(page)

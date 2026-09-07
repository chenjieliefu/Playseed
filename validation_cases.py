"""Canonical P0 game briefs used to measure Playseed generation reliability."""

CASES = [
    {
        "slug": "platformer",
        "genre": "平台跳跃",
        "title": "云端邮差",
        "premise": "一名小邮差穿过漂浮岛屿，把发光信件送到山顶邮箱。",
        "goal": "避开落坑和巡逻风筝，收集三封信并到达终点。",
        "loop": ["左右移动和跳跃", "观察平台节奏并避开危险", "收集信件后抵达终点"],
        "visual": "明亮天空、奶油色云朵和叶绿色邮差；平台边缘、危险和终点清楚可辨。",
        "scope": ["一段可完成的平台路线", "三封信、两个移动平台和一种巡逻敌人", "生命、收集进度、胜负面板和R重开"],
        "revisions": ["加入二段跳，并保留原来的关卡和收集目标。", "在原有两个移动平台之外再增加一段移动平台，不能破坏二段跳，也不要移除原有平台。", "在邮箱前增加一扇清楚可见的终点门：未集齐三封信时关闭，集齐后打开；保留原有收集目标、二段跳和所有移动平台。"],
    },
    {
        "slug": "shooter",
        "genre": "俯视射击",
        "title": "星芽防线",
        "premise": "一艘绿色小飞船守护太空花园。",
        "goal": "击败十二架敌机获胜，生命归零失败。",
        "loop": ["WASD或方向键移动", "瞄准鼠标并点击射击", "躲避敌人和追踪子弹"],
        "visual": "深蓝太空、薄荷绿飞船、珊瑚色敌机；星点背景、明显弹道和命中闪光。",
        "scope": ["可移动飞船和鼠标射击", "十二架敌机分波出现", "三点生命、击杀计数、胜负面板和R重开"],
        "revisions": ["把单发子弹改成并排双发，其他规则不变。", "每击败四架敌机提高一档速度，并保留双发。", "加入一次可冷却的护盾技能，保留难度递进。"],
    },
    {
        "slug": "management",
        "genre": "经营",
        "title": "街角咖啡馆",
        "premise": "经营一间温暖的动物咖啡馆。",
        "goal": "通过制作并出售咖啡赚到一百二十金币。",
        "loop": ["点击制作咖啡消耗原料", "服务等待的顾客赚金币", "花金币进货或升级提高收益"],
        "visual": "奶油白、咖啡棕和叶绿；有吧台、杯子和顾客形象，账目与按钮清楚。",
        "scope": ["订单等待队列与服务按钮", "原料库存、制作耗时、金币收支", "可购买升级，达成目标与R重开"],
        "revisions": ["在已有顾客队列和耐心机制上增加一种急性子顾客，其等待时间为普通顾客的一半，并清楚显示剩余耐心；保留原有收支和升级。", "将已有的一次咖啡机升级扩展为两级，每级购买后进一步缩短制作时间，界面显示当前等级和下次价格；保留急性子顾客和原有收益规则。", "加入连续服务奖励，保留顾客耐心和两级升级；顾客离开时中断连击，连续服务时显示连击数和奖励金币。"],
    },
    {
        "slug": "puzzle",
        "genre": "解谜",
        "title": "森林灯塔",
        "premise": "在森林里修复三盏古老灯塔，帮助迷路的旅人。",
        "goal": "依据线索让三盏灯同时亮起。",
        "loop": ["观察每个开关影响哪些灯", "点击开关切换对应灯的状态", "根据反馈推理正确组合"],
        "visual": "深青森林、暖黄灯光、石质基座；灯亮灭明显，提示清楚。",
        "scope": ["三个互相关联的开关与灯", "可阅读的规则线索和步数记录", "谜题有可达解，完成提示和R重开"],
        "revisions": ["增加可选提示按钮，不能直接给出答案。", "加入最少步数目标，保留提示功能。", "完成后展示本局步数评价，保留原谜题解法。"],
    },
    {
        "slug": "tower_defense",
        "genre": "塔防",
        "title": "花园守夜人",
        "premise": "在夜晚花园里布置植物守卫，阻止小虫走到嫩芽温室。",
        "goal": "守住三波小虫，温室生命归零则失败。",
        "loop": ["消耗阳光在固定位置放置植物", "植物自动攻击沿路线移动的小虫", "根据下一波敌人调整布置"],
        "visual": "月蓝色花园、暖黄灯串、叶绿色植物塔；路线、射程、阳光和波次清楚。",
        "scope": ["一条敌人路线和六个建造位置", "两种植物塔、三波敌人和阳光资源", "温室生命、波次进度、胜负面板和R重开"],
        "revisions": ["加入减速植物，保留原有两种塔。", "第二波加入快速小虫，减速效果要真实生效。", "加入出售植物返还部分阳光，保留三波难度。"],
    },
]


def validate_cases(cases=CASES):
    required = {"slug", "genre", "title", "premise", "goal", "loop", "visual", "scope", "revisions"}
    if len(cases) < 5:
        raise ValueError("P0 至少需要五种玩法样本。")
    if len({case.get("slug") for case in cases}) != len(cases):
        raise ValueError("玩法样本标识不能重复。")
    for case in cases:
        if set(case) != required:
            raise ValueError(f"{case.get('title', '未命名样本')} 的字段不完整。")
        if any(not isinstance(case[key], str) or not case[key].strip()
               for key in ["slug", "genre", "title", "premise", "goal", "visual"]):
            raise ValueError(f"{case['title']} 的文字说明不完整。")
        if len(case["loop"]) < 3 or len(case["scope"]) < 3:
            raise ValueError(f"{case['title']} 缺少完整核心循环或第一版范围。")
        if len(case["revisions"]) != 3:
            raise ValueError(f"{case['title']} 必须有三轮连续修改任务。")
    return cases

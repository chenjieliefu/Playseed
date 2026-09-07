func test_game(game, revision: int):
    game._add_customer()
    var urgent: Dictionary = game.customers[0]
    var normal: Dictionary = game.customers[1]
    expect(urgent.impatient and not normal.impatient, "顾客队列包含普通和急性子两种客人")
    expect(float(urgent.max_patience) * 2 == float(normal.max_patience), "急性子顾客耐心是普通顾客的一半")
    var initial_beans: int = game.beans
    game.playseed_action("make_coffee")
    expect(game.beans == initial_beans - 1 and game.brewing, "制作实际消耗原料")
    for frame in range(140):
        game._process(1.0 / 60.0)
    expect(game.ready_coffee == 1 and not game.brewing, "等待制作时间后产生成品")
    var initial_coins: int = game.coins
    game.playseed_action("serve")
    expect(game.coins > initial_coins and game.ready_coffee == 0, "服务实际消耗成品并获得金币")
    game.reset_game()
    if revision >= 3:
        # Seed funds only to isolate purchase behavior from the time to earn them.
        game.coins = 110
        var duration: float = game.brew_duration
        game.playseed_action("upgrade")
        expect(game.upgrade_level == 1 and game.brew_duration < duration and game.coins < 110, "一级升级扣金币并缩短制作时间")
        game.coins = 110
        duration = game.brew_duration
        game.playseed_action("upgrade")
        expect(game.upgrade_level == 2 and game.brew_duration < duration and game.coins < 110, "二级升级再次扣金币并缩短制作时间")
        var balance: int = game.coins
        game.playseed_action("upgrade")
        expect(game.upgrade_level == 2 and game.coins == balance, "满级不再扣金币")
    game.reset_game()
    if revision >= 4:
        game._add_customer()
        game.ready_coffee = 2
        game.playseed_action("serve")
        var first_balance: int = game.coins
        expect(game.combo_count == 1, "第一次服务开始连击")
        game.playseed_action("serve")
        expect(game.combo_count == 2 and game.last_combo_bonus > 0 and game.coins - first_balance > 15, "连续服务获得额外金币")
        game._add_customer()
        game.customers[0].patience = 0.01
        game._process(0.02)
        expect(game.combo_count == 0 and game.last_combo_bonus == 0, "客人离开会中断连击并清除奖励")
        game.reset_game()
    for frame in range(550):
        game._process(1.0 / 60.0)
    expect(game.missed_count >= 1 and game.reputation < 3, "急性子客人到时离开并扣口碑")
    game.reset_game()
    expect(game.coins == 30 and game.reputation == 3 and game.missed_count == 0, "重开恢复经营状态")

func test_game(game, revision: int):
    expect(game.build_spots.size() == 6 and game.wave_defs.size() == 3, "原有六个建造位置和三波敌人保留")
    for kind in ["leaf", "bloom", "slow"]:
        game.reset_game()
        game.playseed_action("select_" + kind)
        var balance: int = game.sunlight
        game.playseed_action("primary", game.build_spots[0])
        expect(game.towers.size() == 1 and game.towers[0].type == kind and game.sunlight < balance, "植物可建造并消耗阳光：" + kind)
        if revision >= 4:
            var spent_balance: int = game.sunlight
            game.playseed_action("sell", game.build_spots[0])
            expect(game.towers.is_empty() and game.sunlight > spent_balance and game.sunlight < balance, "出售移除植物并返还部分阳光：" + kind)
            var refunded: int = game.sunlight
            game.playseed_action("sell", game.build_spots[0])
            expect(game.sunlight == refunded, "空位置不能重复获得退款")
    game.reset_game()
    game.playseed_action("select_slow")
    game.playseed_action("primary", game.build_spots[0])
    game.playseed_action("start_wave")
    game._spawn_enemy(game.wave_defs[0])
    # Place an actual enemy on the route within tower range, then use normal fire/hit code.
    game.enemies[0].dist = 130.0
    var hp: float = game.enemies[0].hp
    game._update_towers(0.2)
    expect(game.bullets.size() > 0, "减速塔通过自动索敌产生弹丸")
    for frame in range(90):
        game._update_bullets(1.0 / 60.0)
    expect(game.enemies[0].slow > 0 and game.enemies[0].hp < hp, "减速弹命中造成伤害并附加减速")
    var distance: float = game.enemies[0].dist
    game._update_enemies(0.1)
    expect(game.enemies[0].dist - distance < float(game.enemies[0].speed) * 0.1, "减速真实降低敌人沿路线的位移")
    if revision >= 3:
        game.reset_game()
        game.wave = 2
        game._spawn_enemy(game.wave_defs[1])
        game._spawn_enemy(game.wave_defs[1])
        expect(game.enemies[1].kind == "fast" and game.enemies[1].speed > game.enemies[0].speed, "第二波产生更快的敌人")
        game.enemies[1].slow = 1.0
        var start: float = game.enemies[1].dist
        game._update_enemies(0.1)
        expect(game.enemies[1].dist - start < float(game.enemies[1].speed) * 0.1, "快速敌人同样受到减速影响")
    game.reset_game()
    expect(game.towers.is_empty() and game.enemies.is_empty() and game.base_hp == 10 and game.wave == 0, "重开恢复植物、敌人、基地和波次")

func test_game(game, revision: int):
    game.playseed_action("primary", Vector2(480, 200))
    expect(game.shots.size() == 2, "一次射击生成两颗真实子弹")
    expect(game.shots[0].pos != game.shots[1].pos and game.shots[0].vel == game.shots[1].vel, "双弹并排且同向飞行")
    var position: Vector2 = game.shots[0].pos
    game.update_shots(1.0 / 60.0)
    expect(game.shots[0].pos != position, "子弹有实际运动")
    if revision >= 3:
        game.reset_game()
        var speed: float = game.get_player_speed()
        for i in range(3):
            game.register_kill(Vector2.ZERO)
        expect(game.get_player_speed() == speed, "三次击杀尚不升级速度")
        game.register_kill(Vector2.ZERO)
        expect(game.get_player_speed() > speed, "第四次击杀提高速度")
        speed = game.get_player_speed()
        for i in range(4):
            game.register_kill(Vector2.ZERO)
        expect(game.get_player_speed() > speed, "第八次击杀再次提高速度")
    game.reset_game()
    if revision >= 4:
        game.playseed_action("shield")
        expect(game.shield_time > 0 and game.shield_uses == 1, "护盾实际激活")
        game.damage_player()
        expect(game.player_hp == 3, "护盾期间免受伤害")
        game.playseed_action("shield")
        expect(game.shield_uses == 1, "冷却期间不能重复使用护盾")
        game.enemies.clear()
        game.enemy_shots.clear()
        # Isolate cooldown from enemy waves killing the stationary test player.
        game.total_spawned = 12
        var cooldown: float = game.shield_cooldown
        for frame in range(int(ceil(cooldown * 60.0)) + 2):
            game._process(1.0 / 60.0)
        expect(game.shield_cooldown == 0 and game.shield_time == 0, "护盾持续时间和冷却随时间结束")
        expect(not game.won and not game.lost, "冷却测试期间游戏仍处于进行状态")
        game.playseed_action("shield")
        expect(game.shield_uses == 2, "冷却结束后可再次使用护盾")
        game.reset_game()
    game.damage_player()
    expect(game.player_hp == 2, "原有受伤机制保留")
    game.invulnerable = 0.0
    game.damage_player()
    game.invulnerable = 0.0
    game.damage_player()
    expect(game.lost, "生命归零仍触发失败")
    game.reset_game()
    expect(game.player_hp == 3 and not game.lost and game.kills == 0 and game.shots.is_empty(), "重开恢复生命、击杀和双弹状态")

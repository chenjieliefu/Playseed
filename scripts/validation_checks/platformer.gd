func test_game(game, revision: int):
    var origin: float = game.player_pos.x
    game.playseed_action("move_right")
    for frame in range(12):
        game._physics_process(1.0 / 60.0)
    expect(game.player_pos.x > origin, "左右操作真实移动角色")
    game.reset_game()
    game.playseed_action("jump")
    expect(game.player_vel.y < 0 and game.jumps_used == 1, "第一跳产生向上速度")
    for frame in range(6):
        game._physics_process(1.0 / 60.0)
    var first_velocity: float = game.player_vel.y
    game.playseed_action("jump")
    expect(game.jumps_used == 2 and game.player_vel.y < first_velocity, "空中第二跳重新加速向上")
    game._physics_process(1.0 / 60.0)
    var second_velocity: float = game.player_vel.y
    game.playseed_action("jump")
    expect(game.jumps_used == 2 and game.player_vel.y == second_velocity, "不能无限空中跳跃")
    game.reset_game()
    var moving: int = 0
    for platform in game.platforms:
        if float(platform.amp) > 0:
            moving += 1
    expect(moving >= (3 if revision >= 3 else 2), "原有移动平台保留，新增平台数符合本版要求")
    var positions: Array = []
    for platform in game.platforms:
        positions.append(platform.x)
    for frame in range(60):
        game._physics_process(1.0 / 60.0)
    var changed: int = 0
    for i in range(positions.size()):
        if not is_equal_approx(float(positions[i]), float(game.platforms[i].x)):
            changed += 1
    expect(changed == moving, "所有移动平台实际随时间移动")
    game.reset_game()
    if revision >= 4:
        expect(not game.playseed_snapshot().gate_open, "未集齐信件时门关闭")
        game.player_pos = Vector2(843, 180)
        game.playseed_action("move_right")
        for frame in range(12):
            game._physics_process(1.0 / 60.0)
        expect(game.player_pos.x <= 845 and not game.won, "终点门真实阻挡未集齐信件的角色")
        game.reset_game()
    for letter in game.letters:
        game.player_pos = letter
        game._collect_letters()
    expect(game.playseed_snapshot().letters_collected == 3, "三封信仍可通过接触收集")
    if revision >= 4:
        expect(game.playseed_snapshot().gate_open, "集齐信件后门开启")
    game.player_pos = Vector2(900, 180)
    game._physics_process(1.0 / 60.0)
    expect(game.won, "收集后抵达终点仍可获胜")
    game.reset_game()
    expect(not game.won and game.jumps_used == 0 and game.playseed_snapshot().letters_collected == 0, "重开同时恢复二段跳和收集状态")

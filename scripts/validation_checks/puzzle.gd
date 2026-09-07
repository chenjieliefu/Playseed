func test_game(game, revision: int):
    var initial: int = game.lights_mask
    game.playseed_action("hint")
    expect(game.hint_level > 0, "点击提示产生提示状态")
    expect(game.lights_mask == initial and game.steps == 0 and not game.won, "提示不会替用户操作或直接通关")
    game.playseed_action("toggle_left")
    expect(game.lights_mask != initial and game.steps == 1, "原有联动开关仍然工作并计步")
    game.playseed_action("toggle_left")
    expect(game.lights_mask == initial and game.steps == 2, "相同开关两次操作会抵消")
    game.reset_game()
    var actions: Array[String] = ["toggle_left", "toggle_middle", "toggle_right"]
    var minimum: int = 99
    # Exhaust all 3-bit combinations through the public game actions.
    for combination in range(8):
        game.reset_game()
        for i in range(3):
            if combination & (1 << i):
                game.playseed_action(actions[i])
        if game.won:
            minimum = mini(minimum, game.steps)
    expect(minimum == 2, "原谜题仍然存在两步可达解")
    game.reset_game()
    game.playseed_action("toggle_left")
    game.playseed_action("toggle_middle")
    expect(game.won and game.steps == 2, "原来的最短操作顺序保持有效")
    if revision >= 3:
        expect(game.playseed_snapshot().min_steps == minimum, "显示的最少步数与穷举结果一致")
    if revision >= 4:
        var best_grade: String = game.result_grade
        expect(not best_grade.is_empty(), "通关后产生步数评价")
        game.reset_game()
        game.playseed_action("toggle_right")
        game.playseed_action("toggle_right")
        game.playseed_action("toggle_left")
        game.playseed_action("toggle_middle")
        expect(game.won and game.steps == 4 and game.result_grade != best_grade, "多用两步得到不同评价，原解法保留")
    game.reset_game()
    expect(not game.won and game.steps == 0 and game.hint_level == 0 and game.lights_mask == initial, "重开恢复谜题、步数和提示")
    if revision >= 4:
        expect(game.result_grade.is_empty(), "重开清除上局评价")

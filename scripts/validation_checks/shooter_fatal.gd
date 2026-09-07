func test_game(game, _revision: int):
    # Minimal fatal-hit fixture: two bullets and one life exercise list invalidation.
    game.reset_game()
    game.player_hp = 1
    game.enemy_shots.clear()
    for n in range(2):
        game.enemy_shots.append({"pos": game.player_pos, "vel": Vector2.ZERO})
    game.update_enemy_shots(0.0)
    expect(game.lost and game.player_hp == 0 and game.enemy_shots.is_empty(), "致命伤清空弹幕后安全结束遍历")
    game.reset_game()
    expect(not game.lost and game.player_hp == 3, "致命伤后仍可重开")

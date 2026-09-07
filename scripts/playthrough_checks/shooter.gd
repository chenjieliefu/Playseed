func exercise():
    for n in range(18000):
        if game.won or game.lost:
            break
        if EXPECTED == "won":
            var target_x: float = 480.0 + sin(float(n) / 130.0) * 390.0
            key(KEY_A, game.player_pos.x > target_x + 8)
            key(KEY_D, game.player_pos.x < target_x - 8)
            if n % 11 == 0 and not game.enemies.is_empty():
                click(game.enemies[0].pos)
            if game.shield_cooldown <= 0:
                tap(KEY_SPACE)
        await tick()

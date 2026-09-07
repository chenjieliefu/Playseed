func exercise():
    var stage: int = 0
    var targets: Array[Vector2] = [Vector2(178,412),Vector2(350,330),Vector2(535,275),Vector2(720,237),Vector2(835,170),Vector2(910,187)]
    var last_jump: int = -100
    var previous_lives: int = game.lives
    for n in range(18000):
        if game.won or game.lost:
            break
        if game.lives != previous_lives:
            release_all()
            stage = 0
            previous_lives = game.lives
        if EXPECTED == "lost":
            steer(1 if game.player_pos.x < 225 else (-1 if game.player_pos.x > 235 else 0))
        else:
            var target: Vector2 = targets[stage]
            steer(1 if game.player_pos.x < target.x - 8 else (-1 if game.player_pos.x > target.x + 8 else 0))
            if game.grounded and n - last_jump > 15 and (abs(game.player_pos.x - target.x) > 15 or game.player_pos.y > target.y + 25):
                tap(KEY_SPACE)
                last_jump = n
            elif not game.grounded and game.jumps_used == 1 and game.player_vel.y >= -30 and game.player_pos.y > target.y - 15:
                tap(KEY_SPACE)
                last_jump = n
            var reached = abs(game.player_pos.x - target.x) < 35 and game.player_pos.y < target.y + 30
            if stage == 1: reached = game.letter_taken[0]
            if stage == 2: reached = game.letter_taken[1]
            if stage == 4: reached = game.letter_taken[2]
            if reached and stage < targets.size() - 1:
                checkpoints.append({"stage":stage,"frame":n,"position":str(game.player_pos)})
                stage += 1
        await tick()

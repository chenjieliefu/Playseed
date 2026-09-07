func exercise():
    var slots: Array[int] = [0,1,3,4,5,2]
    var built: int = 0
    for n in range(18000):
        if game.won or game.lost:
            break
        if EXPECTED == "won" and n % 30 == 0 and built < slots.size() and game.sunlight >= 75:
            tap(KEY_1)
            click(game.build_spots[slots[built]])
            built += 1
        if n == 60:
            tap(KEY_SPACE)
        await tick()

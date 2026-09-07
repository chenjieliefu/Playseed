func exercise():
    for n in range(18000):
        if game.won or game.lost:
            break
        if EXPECTED == "won" and n % 15 == 0:
            if game.ready_coffee > 0 and not game.customers.is_empty():
                tap(KEY_2)
            elif game.beans == 0 and game.coins >= 12:
                tap(KEY_3)
            elif not game.brewing and game.ready_coffee < 2:
                tap(KEY_1)
            if game.upgrade_level < 2 and game.coins >= game.UPGRADE_PRICES[game.upgrade_level] + 12:
                tap(KEY_4)
        await tick()

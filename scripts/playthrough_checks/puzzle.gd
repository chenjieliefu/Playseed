func exercise():
    tap(KEY_H)
    await tick()
    tap(KEY_1)
    await tick()
    tap(KEY_2)
    await tick()
    for n in range(180):
        await tick()

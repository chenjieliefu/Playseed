extends SceneTree
var game
var failures: Array = []
var waves_seen: Array = []
var choices: Array = []
var kinds: Dictionary = {}
var frames: int = 0
var spawn_records: Dictionary = {}
var battle_captured: Dictionary = {}
func _initialize():
    call_deferred("run_test")
func require(ok: bool, message: String):
    if not ok and not failures.has(message):
        failures.append(message)
func tap(code: int):
    for down in [true, false]:
        var e = InputEventKey.new()
        e.keycode = code
        e.physical_keycode = code
        e.pressed = down
        Input.parse_input_event(e)
func click(at: Vector2):
    for down in [true, false]:
        var e = InputEventMouseButton.new()
        e.position = at
        e.global_position = at
        e.button_index = MOUSE_BUTTON_LEFT
        e.pressed = down
        root.push_input(e, true)
func tick():
    await process_frame
    frames += 1
func snap() -> Dictionary:
    return game.playseed_snapshot().duplicate(true)
func capture(label: String):
    if CAPTURE_DIR != "":
        RenderingServer.force_draw(false)
        root.get_texture().get_image().save_png(CAPTURE_DIR + "/" + label + ".png")
func run_test():
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await tick()
    var initial = snap()
    require(initial.total_waves == TOTAL, "总波数不符合方案")
    await capture("start")
    click(Vector2(600, 300))
    await tick()
    require(snap().shots > 0, "战斗射击没有发生")
    tap(KEY_R)
    await tick()
    require(snap().shots == initial.shots and game.projectiles.is_empty(), "战斗重开残留炮弹")
    var last_phase = ""
    for i in range(18000):
        var s = snap()
        if not waves_seen.has(s.wave): waves_seen.append(s.wave)
        require(not (s.won and s.lost), "胜负同时成立")
        require(s.health <= 10, "生命超过上限")
        var spawn_key = str(s.wave) + ":" + str(s.spawned)
        if s.spawned > 0 and not spawn_records.has(spawn_key) and not game.enemies.is_empty():
            var raw = game.enemies[-1]
            spawn_records[spawn_key] = {"wave":s.wave,"kind":raw.kind,"speed":raw.speed,"max_hp":raw.max_hp}
        if s.phase == "combat" and s.spawned == s.wave_total and not battle_captured.has(s.wave):
            await capture("battle-" + str(s.wave))
            battle_captured[s.wave] = true
        require(s.wave_total == [4, 6, 8, 10][int(s.wave)-1], "本波数量不符合方案")
        for enemy in s.enemies:
            var key = str(s.wave) + ":" + str(enemy.kind)
            kinds[key] = true
        if s.phase == "intermission":
            require(s.spawned == s.wave_total and s.enemies.is_empty(), "本波未清空就进入休整")
            require(s.wave < TOTAL, "最后一波仍进入休整")
            if s.phase != last_phase:
                await capture("rest-" + str(s.wave))
                var before = snap()
                require(not before.upgrade_chosen, "新休整未清理上次选择")
                tap(KEY_SPACE)
                click(Vector2(500, 300))
                for n in range(30): await tick()
                var locked = snap()
                require(locked.wave == before.wave and locked.phase == "intermission", "未选升级即可跳波")
                require(locked.shots == before.shots and locked.spawned == before.spawned and locked.health == before.health, "休整仍在战斗")
                var choice = KEY_1 if CHOICE == "damage" else KEY_2
                tap(choice)
                await tick()
                var selected = snap()
                require(selected.upgrade_chosen, "升级选择未记录")
                if CHOICE == "damage":
                    require(selected.damage == before.damage + 1, "火力升级未增加1点")
                else:
                    require(selected.health == mini(10, int(before.health) + 3), "修复未恢复3点或未限制上限")
                tap(KEY_1)
                tap(KEY_2)
                await tick()
                var duplicate = snap()
                require(duplicate.damage == selected.damage and duplicate.health == selected.health, "同次休整重复领取升级")
                choices.append({"wave":s.wave,"before":before.health,"after":selected.health,"damage":selected.damage})
                tap(KEY_SPACE)
                await tick()
                var next = snap()
                require(next.wave == s.wave + 1 and next.phase == "combat", "无法开启下一波")
                tap(KEY_SPACE)
                await tick()
                require(snap().wave == next.wave, "重复开始跳过波次")
        elif s.phase == "combat" and OUTCOME == "won":
            # Recovery route intentionally takes initial damage, through normal play.
            var wait_for_hit = CHOICE == "heal" and s.wave == 1 and s.health > 9
            if not wait_for_hit and not s.enemies.is_empty() and i % 6 == 0:
                var target = s.enemies[0]
                for enemy in s.enemies:
                    if enemy.x < target.x: target = enemy
                click(Vector2(float(target.x), float(target.y)))
        if s.won or s.lost: break
        last_phase = str(s.phase)
        await tick()
    var end = snap()
    require(bool(end.get(OUTCOME, false)), "未达到预期结局：" + OUTCOME)
    if OUTCOME == "won":
        require(waves_seen.size() == TOTAL and choices.size() == TOTAL - 1, "波次或休整次数不完整")
        require(end.spawned == end.wave_total and end.enemies.is_empty(), "提前胜利")
        if REVISION >= 2 and REVISION <= 4:
            require(kinds.has("2:fast"), "第二波没有观察到快速船")
        if REVISION == 4:
            require(kinds.has("3:armored") and kinds.has("4:armored"), "后两波没有观察到装甲船")
        var previous_speed = 0.0
        for w in range(1, TOTAL + 1):
            var normal_speed = 0.0
            var normal_hp = 0
            var fast_count = 0
            var armored_count = 0
            for record in spawn_records.values():
                if record.wave != w: continue
                if record.kind == "fast": fast_count += 1
                elif record.kind == "armored": armored_count += 1
                else:
                    normal_speed = float(record.speed)
                    normal_hp = int(record.max_hp)
            require(normal_speed > previous_speed, "普通船波次速度没有递进")
            previous_speed = normal_speed
            if REVISION >= 2 and REVISION <= 4 and w >= 2: require(fast_count >= 2, "快速船数量不足")
            if REVISION == 4 and w >= 3: require(armored_count >= 2, "装甲船数量不足")
            for record in spawn_records.values():
                if record.wave != w: continue
                if record.kind == "fast": require(is_equal_approx(float(record.speed), normal_speed * 1.5), "快速船速度比例不正确")
                if record.kind == "armored":
                    require(is_equal_approx(float(record.speed), normal_speed * 0.75), "装甲船速度比例不正确")
                    require(int(record.max_hp) == normal_hp * 2, "装甲船生命不是两倍")
        if CHOICE == "heal": require(choices.size() > 0 and choices[0].after > choices[0].before, "没有验证受伤后的真实修复")
    await capture("end")
    tap(KEY_SPACE)
    tap(KEY_1)
    click(Vector2(500, 300))
    for i in range(120): await tick()
    var frozen = snap()
    for field in ["wave", "health", "damage", "shots", "kills", "phase"]:
        require(frozen[field] == end[field], "结局后状态仍变化：" + field)
    for attempt in range(20):
        tap(KEY_R)
        await tick()
        var reset = snap()
        for field in ["wave", "health", "damage", "shots", "kills", "phase", "upgrade_chosen"]:
            require(reset[field] == initial[field], "重开未恢复：" + field)
    # Reach intermission again through input, then restart there too.
    for i in range(4000):
        var current = snap()
        if current.phase != "combat": break
        if not current.enemies.is_empty() and i % 6 == 0:
            var target = current.enemies[0]
            for enemy in current.enemies:
                if enemy.x < target.x: target = enemy
            click(Vector2(float(target.x), float(target.y)))
        await tick()
    require(snap().phase == "intermission", "休整重开前未到达休整")
    tap(KEY_R)
    await tick()
    for field in ["wave", "health", "damage", "shots", "kills", "phase", "upgrade_chosen"]:
        require(snap()[field] == initial[field], "休整重开未恢复：" + field)
    require(game.projectiles.is_empty(), "休整重开残留炮弹")
    await capture("reset")
    print("PROGRESSION_REPORT:" + JSON.stringify({"passed":failures.is_empty(),"failures":failures,"end":end,"waves":waves_seen,"choices":choices,"kinds":kinds,"frames":frames,"reset_count":20,"spawn_records":spawn_records}))
    quit(0 if failures.is_empty() else 1)

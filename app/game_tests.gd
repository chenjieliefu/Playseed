extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func require(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(condition, message)

func run_tests() -> void:
	var game = load("res://game_preview.gd").new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.reset_game(true)
	var before: Vector2 = game.player
	game.move_player(Vector2.RIGHT, 0.2)
	require(game.player.x > before.x + 45, "movement uses configured speed")
	game.move_player(Vector2(1, 1), 100.0)
	require(game.player.x <= 906 and game.player.y <= 546, "arena boundaries")
	game.config.shield_count = 0
	game.reset_game(true)
	game.enemies.assign([game.player])
	game.step(0.01, Vector2.ZERO)
	require(game.ended and not game.won, "collision loses")
	game.config.shield_count = 1
	game.reset_game(true)
	game.enemies.assign([game.player])
	game.step(0.01, Vector2.ZERO)
	require(game.playing and game.shields == 0 and game.invincible > 0, "shield absorbs contact")
	game.config.duration = 0.02
	game.config.collectible_count = 0
	game.reset_game(true)
	game.enemies.clear()
	game.step(0.03, Vector2.ZERO)
	require(game.ended and game.won, "survival timer wins")
	game.config.duration = 60
	game.config.collectible_count = 2
	game.reset_game(true)
	game.enemies.clear()
	game.seeds.assign([game.player, game.player + Vector2(5, 0)])
	game.step(0.01, Vector2.ZERO)
	require(game.won and game.collected == 2, "collect all wins")
	game.config.duration = 0.02
	game.reset_game(true)
	game.enemies.clear()
	game.seeds.assign([Vector2(80, 140)])
	game.step(0.03, Vector2.ZERO)
	require(game.ended and not game.won, "collection deadline loses")
	game.reset_game(true)
	require(game.playing and not game.ended and game.collected == 0, "restart clears game state")
	game.configure({"initial_lives": 3, "max_lives": 5, "heart_count": 5, "shield_count": 0, "duration": 60})
	game.reset_game(true)
	require(game.lives == 3 and game.hearts.size() == 5, "initial lives and map hearts")
	game.hearts.clear()
	game.enemies.assign([game.player, game.player])
	game.step(0.01, Vector2.ZERO)
	require(game.lives == 2 and game.playing, "contact costs one life even with overlapping enemies")
	game.enemies.assign([game.player])
	game.step(0.01, Vector2.ZERO)
	require(game.lives == 2, "invulnerability prevents repeated contact damage")
	game.invincible = 0
	game.dash_time = 0.15
	game.step(0.01, Vector2.ZERO)
	require(game.lives == 2, "dash protects lives")
	game.dash_time = 0
	game.shields = 1
	game.step(0.01, Vector2.ZERO)
	require(game.lives == 2 and game.shields == 0, "shield is consumed before life")
	game.enemies.clear()
	game.lives = 4
	game.hearts.assign([game.player, game.player])
	game.step(0.01, Vector2.ZERO)
	require(game.lives == 5 and game.hearts.size() == 1, "healing caps at max and keeps unneeded hearts")
	game.step(0.01, Vector2.ZERO)
	require(game.lives == 5 and game.hearts.size() == 1, "full health does not consume heart")
	game.lives = 4
	game.step(0.01, Vector2.ZERO)
	require(game.lives == 5 and game.hearts.is_empty() and game.playing and game.collected == 0, "remaining heart heals later without counting as win collectible")
	game.lives = 1
	game.invincible = 0
	game.enemies.assign([game.player])
	game.step(0.01, Vector2.ZERO)
	require(game.lives == 0 and game.ended and not game.won, "zero lives loses")
	game.reset_game(true)
	require(game.lives == 3 and game.hearts.size() == 5, "restart restores health and hearts")
	game.config.heart_count = 20
	game.reset_game(true)
	require(game.hearts.size() == 20, "maximum heart count spawns exactly")
	game.configure({"enemy_count": 2})
	game.reset_game(true)
	require(game.lives == 1 and game.hearts.is_empty(), "legacy game keeps one life and no hearts")
	print("HEALTH TESTS PASSED: damage, protection, shield, dash, capped healing, reusable full-health hearts, death, restart, legacy compatibility")
	print("GAME TESTS PASSED: movement, bounds, collision, shield, survival win, collection win/loss, restart")
	quit(0)

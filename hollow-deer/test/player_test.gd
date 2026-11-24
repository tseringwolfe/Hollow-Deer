extends GdUnitTestSuite

func test_player_scene_loads() -> void:
	var runner := scene_runner("res://scenes/player.tscn")
	assert_object(runner.scene()).is_not_null()

# Wait for completed physics updates before checking movement.
func _wait_physics_frames(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


func test_move_right() -> void:
	var runner := scene_runner("res://scenes/test_level.tscn")
	var player := runner.scene().get_node("Player") as CharacterBody2D
	await _wait_physics_frames(3)

	var starting_x := player.position.x

	runner.simulate_action_press("move_right")
	await _wait_physics_frames(10)
	runner.simulate_action_release("move_right")

	assert_float(player.position.x).is_greater(starting_x)


func test_move_left() -> void:
	var runner := scene_runner("res://scenes/test_level.tscn")
	var player := runner.scene().get_node("Player") as CharacterBody2D
	await _wait_physics_frames(3)

	var starting_x := player.position.x

	runner.simulate_action_press("move_left")
	await _wait_physics_frames(10)
	runner.simulate_action_release("move_left")

	assert_float(player.position.x).is_less(starting_x)


func test_releasing_movement_stops_player() -> void:
	var runner := scene_runner("res://scenes/test_level.tscn")
	var player := runner.scene().get_node("Player") as CharacterBody2D
	await _wait_physics_frames(3)

	runner.simulate_action_press("move_right")
	await _wait_physics_frames(10)
	runner.simulate_action_release("move_right")
	await _wait_physics_frames(3)

	var stopped_x := player.position.x
	await _wait_physics_frames(5)

	assert_float(player.velocity.x).is_equal_approx(0.0, 0.001)
	assert_float(player.position.x).is_equal_approx(stopped_x, 0.01)


func test_jump_from_floor() -> void:
	var runner := scene_runner("res://scenes/test_level.tscn")
	var player := runner.scene().get_node("Player") as CharacterBody2D
	await _wait_physics_frames(3)

	assert_bool(player.is_on_floor()).is_true()
	var starting_y := player.position.y

	runner.simulate_action_press("jump")
	await _wait_physics_frames(3)
	runner.simulate_action_release("jump")

	assert_float(player.velocity.y).is_less(0.0)
	assert_float(player.position.y).is_less(starting_y)
	assert_bool(player.is_on_floor()).is_false()


func test_cannot_jump_again_in_midair() -> void:
	var runner := scene_runner("res://scenes/test_level.tscn")
	var player := runner.scene().get_node("Player") as CharacterBody2D
	await _wait_physics_frames(3)

	runner.simulate_action_press("jump")
	await _wait_physics_frames(3)
	runner.simulate_action_release("jump")
	await _wait_physics_frames(3)

	assert_bool(player.is_on_floor()).is_false()
	assert_bool(player.is_on_wall()).is_false()
	var velocity_before_second_press := player.velocity.y

	runner.simulate_action_press("jump")
	await _wait_physics_frames(2)
	runner.simulate_action_release("jump")

	# Gravity should keep increasing Y velocity instead of resetting the jump.
	assert_float(player.velocity.y).is_greater(
		velocity_before_second_press
	)


func test_player_lands_after_jumping() -> void:
	var runner := scene_runner("res://scenes/test_level.tscn")
	var player := runner.scene().get_node("Player") as CharacterBody2D
	await _wait_physics_frames(3)

	var starting_y := player.position.y

	runner.simulate_action_press("jump")
	await _wait_physics_frames(3)
	runner.simulate_action_release("jump")
	await _wait_physics_frames(90)

	assert_bool(player.is_on_floor()).is_true()
	assert_float(player.position.y).is_equal_approx(starting_y, 0.1)
	
func _place_player_against_wall(runner: GdUnitSceneRunner) -> CharacterBody2D:
	var player := runner.scene().get_node("Player") as CharacterBody2D

	var wall := runner.scene().get_node("Wall") as StaticBody2D
	player.global_position = wall.global_position + Vector2(-15, -50)
	player.velocity = Vector2.ZERO

	runner.simulate_action_press("move_right")
	await _wait_physics_frames(6)

	return player


func test_wall_cling_briefly_stops_falling() -> void:
	var runner := scene_runner("res://scenes/test_level.tscn")
	var player := await _place_player_against_wall(runner)

	assert_bool(player.is_on_wall_only()).is_true()

	await _wait_physics_frames(2)
	var vertical_velocity := player.velocity.y
	runner.simulate_action_release("move_right")

	assert_float(vertical_velocity).is_equal_approx(0.0, 0.001)


func test_wall_cling_transitions_to_slide() -> void:
	var runner := scene_runner("res://scenes/test_level.tscn")
	var player := await _place_player_against_wall(runner)

	assert_bool(player.is_on_wall_only()).is_true()

	var slide_frames := int(ceil(
		0.5 * Engine.physics_ticks_per_second
	))
	await _wait_physics_frames(slide_frames)

	var still_on_wall := player.is_on_wall_only()
	var first_slide_velocity := player.velocity.y

	var observation_frames := 6
	await _wait_physics_frames(observation_frames)

	var second_slide_velocity := player.velocity.y
	var remained_on_wall := player.is_on_wall_only()
	runner.simulate_action_release("move_right")

	var elapsed_time := (
		float(observation_frames) / Engine.physics_ticks_per_second
	)
	var expected_velocity: float = (
		first_slide_velocity + player.WALL_SLIDE_ACCELERATION * elapsed_time
	)
	var tolerance: float = (
		2.0 * player.WALL_SLIDE_ACCELERATION / Engine.physics_ticks_per_second
	)

	assert_bool(still_on_wall).is_true()
	assert_bool(remained_on_wall).is_true()
	assert_float(first_slide_velocity).is_greater(0.0)
	assert_float(second_slide_velocity).is_equal_approx(
		expected_velocity, tolerance
	)


func test_wall_jump_pushes_up_and_away() -> void:
	var runner := scene_runner("res://scenes/test_level.tscn")
	var player := await _place_player_against_wall(runner)

	assert_bool(player.is_on_wall_only()).is_true()
	var starting_position := player.position

	# Continue holding toward the wall while jumping.
	runner.simulate_action_press("jump")
	await _wait_physics_frames(2)

	runner.simulate_action_release("jump")
	runner.simulate_action_release("move_right")

	# The wall is on the right, so jumping away means moving left.
	assert_float(player.velocity.x).is_less(0.0)
	assert_float(player.velocity.y).is_less(0.0)
	assert_float(player.position.x).is_less(starting_position.x)
	assert_float(player.position.y).is_less(starting_position.y)

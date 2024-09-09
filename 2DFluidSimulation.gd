extends Node2D

@export_group("Particle  Settings")
@export_range(100, 1000) var num_particles: int = 500
@export_range(1, 100) var particle_radius: float = 50

@export_group("Container Settings")
@export var container_dimensions: Vector2 = Vector2(1600, 1000)
@export var container_center: Vector2 = Vector2(0, 0)

@export_group("Grid Settings")
@export_range(1, 25) var group_size: int = 6
@export_range(0.1, 500) var cell_size: float = 1

@export_group("Simulation Settings")
@export var gravity: Vector2 = Vector2(0, -9.8)

@export_group("Debug Settings")
@export var is_draw_container: bool
@export var is_draw_grid: bool
@export var is_log_cursor_grid_position: bool

var positions: Array[Vector2]

var grid: Grid

var rng = RandomNumberGenerator.new()

var half_dimensions: Vector2

##################### Godot Event Functions #####################
func _ready():
	half_dimensions = container_dimensions * 0.5
	
	initialize_particles()
	grid = Grid.new(group_size, cell_size)


func _process(delta):
	for group in grid.groups.values():
		for i in range(group_size * group_size):
			group[i].v += delta * gravity.y
			group[i].u += delta * gravity.x

	log_cursor_grid_position()
	queue_redraw()


func _physics_process(delta):
	var used_groups = {}

	for i in range(num_particles):
		var grid_position = grid.convert_world_to_grid(positions[i])
		var group_position = grid_position[0]

		used_groups[group_position] = true

		if not group_position in grid.groups:
			grid.initialize_group(group_position)

		positions[i] += grid.interpolate_velocity_at_point(positions[i]) * delta
		positions[i] = handle_collisions(positions[i])

	if Engine.get_frames_drawn() % 10 == 0:
		for group in grid.groups.keys():
			if not group in used_groups:
				grid.groups.erase(group)


func _draw():
	# Draw particles
	for i in range(num_particles):
		draw_circle(positions[i], particle_radius, Color.AQUA)
		
	if is_draw_container:
		draw_container()

	if is_draw_grid:
		for key in grid.groups.keys():
			draw_group(key * group_size * cell_size)

######################## Debug Functions ########################
func draw_container():
	var top_left = container_center - half_dimensions

	draw_rect(Rect2(top_left, container_dimensions), Color.GREEN, false)


func draw_group(origin: Vector2):
	var offset = Vector2(group_size * cell_size / 2, group_size * cell_size / 2)

	for i in range(group_size + 1):
		var start = origin + Vector2(i * cell_size, 0) - offset
		var end = start + Vector2(0, group_size * cell_size)

		draw_line(start, end, Color.GREEN)

	for i in range(group_size + 1):
		var start = origin + Vector2(0, i * cell_size) - offset
		var end = start + Vector2(group_size * cell_size, 0)

		draw_line(start, end, Color.GREEN)


func log_cursor_grid_position():
	if is_log_cursor_grid_position:
		var label = $Control/DebugInfo
		var cursor_positions = grid.cursor_position_to_grid()
		label.text = "Group: {0}\nCell: {1}\nWorld: {2}".format(cursor_positions)
	else:
		$Control/DebugInfo.text = ""

########################### Particles ###########################
func handle_collisions(particle_position: Vector2) -> Vector2:
	var new_position = particle_position

	if particle_position.x - particle_radius < container_center.x - half_dimensions.x:
		new_position.x = container_center.x - half_dimensions.x + particle_radius
	elif particle_position.x + particle_radius > container_center.x + half_dimensions.x:
		new_position.x = container_center.x + half_dimensions.x - particle_radius

	if particle_position.y - particle_radius < container_center.y - half_dimensions.y:
		new_position.y = container_center.y - half_dimensions.y + particle_radius
	elif particle_position.y + particle_radius > container_center.y + half_dimensions.y:
		new_position.y = container_center.y + half_dimensions.y - particle_radius

	return new_position


func initialize_particles():
	positions = []
	
	for i in range(num_particles):
		positions.append(
			Vector2(
				rng.randf_range(container_center.x - half_dimensions.x, container_center.x + half_dimensions.x),
				rng.randf_range(container_center.y - half_dimensions.y, container_center.y + half_dimensions.y)
			)
		)

extends Node2D

@export_group("Container Settings")
@export var container_size: Vector2i = Vector2i(10, 6) # In number of cells

@export_group("Grid Settings")
@export_range(1, 25) var group_size: int = 6
@export_range(0.1, 500) var cell_size: float = 1
@export_range(0, 25) var grid_size: int = 3

@export_group("Simulation Settings")
@export var gravity: Vector2 = Vector2(0, -9.8)

@export_group("Debug Settings")
@export var is_draw_container: bool
@export var is_draw_grid: bool
@export var is_log_cursor_grid_position: bool
@export var is_draw_velocity_vector: bool

var grid: Grid

var half_dimensions: Vector2

var container_center: Vector2

enum {LEFT, TOP, CENTER}

##################### Godot Event Functions #####################
func _ready():
	half_dimensions = container_size * 0.5
	grid = Grid.new(grid_size, group_size, cell_size)
	var grid_position = grid.get_central_position()
	container_center = grid_position
	$Camera2D.position = grid_position


func _process(_delta):

	log_cursor_grid_position()
	queue_redraw()


func _physics_process(delta):
	if grid.groups.is_empty():
			return
	
	for group_position in grid.groups:
		var group = grid.groups[group_position]
		for i in range(group_size):
			for j in range(group_size):
				var cell_position = Vector2i(i, j)
				
				var cell_world_position = grid.convert_cell_to_world(group_position, cell_position)

				var x_velocity = advect_component(group_position, cell_position, LEFT, delta)
				var y_velocity = advect_component(group_position, cell_position, TOP, delta)

				group[i * group_size + j].x_velocity = x_velocity + delta * gravity.x
				group[i * group_size + j].y_velocity = y_velocity + delta * gravity.y

	
func _draw():
	if is_draw_grid:
		for key in grid.groups.keys():
			draw_group(key * group_size * cell_size)

	if is_draw_container:
		draw_container()
		
	if is_draw_velocity_vector:
		draw_velocities()

######################## Debug Functions ########################
func draw_container():
	var top_left = container_center - (half_dimensions * cell_size)

	draw_rect(Rect2(top_left, container_size * cell_size), Color.RED, false)


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


func draw_velocities():
	for group_position in grid.groups.keys():
		for i in range(group_size):
			for j in range(group_size):
				var cell_position = Vector2i(i, j)
				var velocity = grid.interpolate_velocity_at_center(group_position, cell_position)

				draw_arrow(grid.convert_cell_to_world(group_position, cell_position), velocity)


func draw_arrow(origin: Vector2, vector: Vector2):
	var arrow_length = 0.4 * cell_size
	
	var direction = vector.normalized() * arrow_length
	
	var end_point = origin + direction
	
	var velocity_magnitude = vector.length()
	var color = get_velocity_color(velocity_magnitude)

	draw_line(origin, end_point, color, 2)


func get_velocity_color(velocity_magnitude: float) -> Color:
	var slow_velocity = 0
	var fast_velocity = 400
	
	var t = clamp((velocity_magnitude - slow_velocity) / (fast_velocity - slow_velocity), 0, 1)
	return Color(1, 0, 0).lerp(Color(0, 1, 0), 1 - t)


func log_cursor_grid_position():
	if is_log_cursor_grid_position:
		var label = $Control/DebugInfo
		var cursor_positions = convert_cursor_position_to_grid()
		label.text = "Group: {0}\nCell: {1}\nWorld: {2}".format(cursor_positions)
	else:
		$Control/DebugInfo.text = ""


func convert_cursor_position_to_grid() -> Array:
	var cursor_pos = get_global_mouse_position()
	var grid_pos = grid.convert_world_to_grid(cursor_pos)
	var world_pos = grid.convert_cell_to_world(grid_pos[0], grid_pos[1])
	
	return grid_pos + [world_pos]

######################### Main Functions #########################

func advect_component(group_position: Vector2i, cell_position: Vector2i, corner: int, time_step: float) -> float:
	var center_position = grid.convert_cell_to_world(group_position, cell_position)
	var current_position: Vector2

	if corner == TOP:
		current_position = center_position + Vector2(0, -0.5 * cell_size)
	elif corner == LEFT:
		current_position = center_position + Vector2(-0.5 * cell_size, 0)
	else:
		return -1

	var current_velocity = grid.interpolate_velocity_at_center(group_position, cell_position)

	var mid_position = current_position - 0.5 * time_step * current_velocity
	var mid_grid_position = grid.convert_world_to_grid(mid_position)
	var mid_velocity = grid.interpolate_velocity_at_top(mid_grid_position[0], mid_grid_position[1])

	var previous_position = current_position - time_step * mid_velocity
	var previous_velocity = grid.interpolate_velocity_at_point(previous_position)

	if corner == TOP:
		return previous_position.y
	elif corner == LEFT:
		return previous_velocity.x
	else:
		return -1

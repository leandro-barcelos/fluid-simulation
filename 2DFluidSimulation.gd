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

var positions: Array[Vector2]

var grid: Grid

var rng = RandomNumberGenerator.new()

var half_dimensions: Vector2

var container_center: Vector2

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
		for i in range(group_size):
			for j in range(group_size):
				var cell_center_position = grid.convert_cell_to_world(group_position, Vector2i(i, j))

				var u_position = cell_center_position
				u_position.x -= 0.5 * cell_size

				var v_position = cell_center_position
				v_position.y -= 0.5 * cell_size

				var group = grid.groups[group_position]

				var u_a = advect_velocity(delta, u_position).x
				var v_a = advect_velocity(delta, v_position).y

				group[i * group_size + j].u = u_a + delta * gravity.x
				group[i * group_size + j].v = v_a + delta * gravity.y

	
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


func draw_arrow(center: Vector2, vector: Vector2):
	var half_size = vector * 0.5
	var start_point = center - half_size
	var end_point = center + half_size

	draw_line(start_point, end_point, Color(1, 1, 1), 2) # White arrow body with thickness 2

	# Calculate the arrowhead's size and direction
	var arrowhead_length = vector.length() * 0.2 # The length of the arrowhead (20% of the vector size)
	var arrow_angle = 30 # The angle for the arrowhead in degrees
	var angle_radians = deg_to_rad(arrow_angle)

	# Calculate two points for the arrowhead, offset by arrow_angle from the line
	var direction = (end_point - start_point).normalized() # Get the direction of the vector
	var arrowhead_left = end_point - (direction.rotated(angle_radians) * arrowhead_length)
	var arrowhead_right = end_point - (direction.rotated(-angle_radians) * arrowhead_length)

	# Draw the arrowhead using a polygon (triangle)
	draw_polygon([end_point, arrowhead_left, arrowhead_right], [Color(1, 1, 1)]) # White arrowhead


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

func advect_velocity(time_step: float, particle_position: Vector2) -> Vector2:
	var current_velocity = grid.interpolate_cell_velocity_at_point(particle_position)

	var mid_position = particle_position - 0.5 * time_step * current_velocity

	var mid_velocity = grid.interpolate_cell_velocity_at_point(mid_position)
	
	if mid_velocity == Vector2():
		mid_velocity = grid.interpolate_velocity_at_point(mid_position, current_velocity)

	var previous_position = particle_position - time_step * mid_velocity

	return grid.interpolate_velocity_at_point(current_velocity, previous_position)

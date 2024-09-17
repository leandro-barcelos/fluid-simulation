extends Node2D

# Dynamic Sparse Grid
class_name Grid

const RIGHT = Vector2i(1, 0)
const LEFT = Vector2i(-1, 0)
const BOTTOM = Vector2i(0, 1)
const TOP = Vector2i(0, -1)

class Cell:
	var pressure: float = 0
	var x_velocity: float = 0
	var y_velocity: float = 0

# Grids are divided in groups of dimentions group_size x group_size
var groups: Dictionary = {}
var group_size: int # Size in number of cells
var cell_size: float
var grid_size: int

func _init(grid_size_: int, group_size_: int, cell_size_: float):
	self.cell_size = cell_size_
	self.group_size = group_size_
	self.grid_size = grid_size_
	
	for i in range(grid_size):
		for j in range(grid_size):
			initialize_group(Vector2i(i, j))


# Returns a cell given its group and position in that group
func get_cell_in_group(group_position: Vector2i, cell_position: Vector2i) -> Cell:
	if group_position in groups:
		return groups[group_position][(cell_position.x * group_size) + cell_position.y]
		
	return null


func get_central_position() -> Vector2:
	var half_group_size = (group_size * cell_size) / 2
	var upper_rigth_corner = Vector2(-half_group_size, -half_group_size)
	
	var half_grid_size = (grid_size * group_size * cell_size) / 2
	return upper_rigth_corner + Vector2(half_grid_size, half_grid_size)


func initialize_group(group_position: Vector2i):
	if group_position in groups:
		return

	var cells = []
	for i in range(group_size * group_size):
		cells.append(Cell.new())
		
	groups[group_position] = cells


# Gets the group and cell given a world position 
func convert_world_to_grid(world_position: Vector2) -> Array[Vector2i]:
	var half_group_size = group_size * cell_size / 2
	var adjusted_world_position = world_position + Vector2(half_group_size, half_group_size)

	var cell_position = Vector2i(
		floor(adjusted_world_position.x / cell_size),
		floor(adjusted_world_position.y / cell_size)
	)

	var group_position = Vector2i(
		floor(adjusted_world_position.x / (group_size * cell_size)),
		floor(adjusted_world_position.y / (group_size * cell_size))
	)

	cell_position.x = (cell_position.x + group_size) % group_size if cell_position.x < 0 else cell_position.x % group_size
	cell_position.y = (cell_position.y + group_size) % group_size if cell_position.y < 0 else cell_position.y % group_size

	return [group_position, cell_position]


# Gets the world position of the center of the cell
func convert_cell_to_world(group_position: Vector2i, cell_position: Vector2i) -> Vector2:
	var offset = -((group_size / 2.0 - 0.5) * cell_size) # offset of the world origin to the grid origin
	return Vector2(offset, offset) + (Vector2(group_position) * group_size + Vector2(cell_position)) * cell_size

func get_neighboring_cell(group_position: Vector2i, cell_position: Vector2i, direction: Vector2i) -> Cell:
	var new_group_position = group_position
	var new_cell_position = cell_position

	new_cell_position += direction

	if new_cell_position.x >= group_size:
		new_cell_position.x = 0
		new_group_position.x += 1
	elif new_cell_position.x < 0:
		new_cell_position.x = group_size - 1
		new_group_position.x -= 1

	if new_cell_position.y >= group_size:
		new_cell_position.y = 0
		new_group_position.y += 1
	elif new_cell_position.y < 0:
		new_cell_position.y = group_size - 1
		new_group_position.y -= 1
		
	var neighboring_cell = get_cell_in_group(new_group_position, new_cell_position)

	return neighboring_cell if neighboring_cell != null else get_cell_in_group(group_position, cell_position)

func interpolate_velocity_at_top(group_position: Vector2i, cell_position: Vector2i) -> Vector2:
	var current_cell = get_cell_in_group(group_position, cell_position)
	
	var right_cell = get_neighboring_cell(group_position, cell_position, RIGHT)
	
	var upper_cell = get_neighboring_cell(group_position, cell_position, TOP)
	
	var upper_right_cell = get_neighboring_cell(group_position, cell_position, TOP + RIGHT)

	return Vector2(
		(current_cell.x_velocity + right_cell.x_velocity + upper_cell.x_velocity + upper_right_cell.x_velocity) / 4,
		current_cell.y_velocity
	)

func interpolate_velocity_at_left(group_position: Vector2i, cell_position: Vector2i) -> Vector2:
	var current_cell = get_cell_in_group(group_position, cell_position)
	
	var left_cell = get_neighboring_cell(group_position, cell_position, LEFT)
	
	var bottom_cell = get_neighboring_cell(group_position, cell_position, BOTTOM)
	
	var bottom_left_cell = get_neighboring_cell(group_position, cell_position, BOTTOM + LEFT)

	return Vector2(
		current_cell.x_velocity,
		(current_cell.y_velocity + bottom_cell.y_velocity + left_cell.y_velocity + bottom_left_cell.y_velocity) / 4
	)

func interpolate_velocity_at_center(group_position: Vector2i, cell_position: Vector2i) -> Vector2:
	var current_cell = get_cell_in_group(group_position, cell_position)
	
	var bottom_cell = get_neighboring_cell(group_position, cell_position, BOTTOM)

	var right_cell = get_neighboring_cell(group_position, cell_position, RIGHT)

	return Vector2(
		(current_cell.x_velocity + bottom_cell.x_velocity) / 2,
		(current_cell.y_velocity + right_cell.y_velocity) / 2
	)

func interpolate_velocity_at_point(world_point: Vector2) -> Vector2:
	var grid_position = convert_world_to_grid(world_point)
	var group_position = grid_position[0]
	var cell_position = grid_position[1]

	var x_velocities = []
	var y_velocities = []

	# Get point's position relative to the cell
	var cell_origin = convert_cell_to_world(group_position, cell_position)
	var half_cell_size = cell_size / 2

	var relative_position = (world_point - cell_origin) / cell_size

	# Getting current, right and bottom cells (always needed)
	var current_cell = get_cell_in_group(group_position, cell_position)

	var right_cell = get_neighboring_cell(group_position, cell_position, RIGHT)

	var bottom_cell = get_neighboring_cell(group_position, cell_position, BOTTOM)

	# Get 4 closest x-velocity points

	x_velocities.append(current_cell.x_velocity)
	x_velocities.append(right_cell.x_velocity)

	if relative_position.y < 0:
		var upper_cell = get_neighboring_cell(group_position, cell_position, TOP)
		var upper_right_cell = get_neighboring_cell(group_position, cell_position, TOP + RIGHT)

		x_velocities.append(upper_cell.x_velocity)
		x_velocities.append(upper_right_cell.x_velocity)
	else:
		var bottom_right_cell = get_neighboring_cell(group_position, cell_position, BOTTOM + RIGHT)

		x_velocities.append(bottom_cell.x_velocity)
		x_velocities.append(bottom_right_cell.x_velocity)

	# Get 4 closest y-velocity points

	y_velocities.append(current_cell.y_velocity)
	y_velocities.append(bottom_cell.y_velocity)

	if relative_position.x < 0:
		var left_cell = get_neighboring_cell(group_position, cell_position, LEFT)
		var bottom_left_cell = get_neighboring_cell(group_position, cell_position, BOTTOM + LEFT)

		y_velocities.append(left_cell.y_velocity)
		y_velocities.append(bottom_left_cell.y_velocity)
	else:
		var bottom_right_cell = get_neighboring_cell(group_position, cell_position, BOTTOM + RIGHT)

		y_velocities.append(right_cell.y_velocity)
		y_velocities.append(bottom_right_cell.y_velocity)

	# Perform bilinear interpolation on both x and y velocities
	var interpolated_u = bilinear_interpolate(x_velocities, relative_position)
	var interpolated_v = bilinear_interpolate(y_velocities, relative_position)

	return Vector2(interpolated_u, interpolated_v)

func bilinear_interpolate(velocities: Array, relative_position: Vector2) -> float:
	var v00 = velocities[0]
	var v10 = velocities[1] 
	var v01 = velocities[2]
	var v11 = velocities[3]

	var u_x = relative_position.x
	var u_y = relative_position.y

	var interpolated_value = v00 * (1 - u_x) * (1 - u_y) + v10 * u_x * (1 - u_y) + v01 * (1 - u_x) * u_y + v11 * u_x * u_y

	return interpolated_value

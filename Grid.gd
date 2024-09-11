extends Node2D

# Dynamic Sparse Grid
class_name Grid

class Cell:
	var pressure: float = 0
	var u: float = 0
	var v: float = 0

# Grids are divided in groups of dimentions group_size x group_size
var groups: Dictionary = {}
var group_size: int # Size in number of cells
var cell_size: float

func _init(group_size_: int, cell_size_: float):
	self.cell_size = cell_size_
	self.group_size = group_size_


# Returns a cell given its group and position in that group
func get_cell_in_group(group_position: Vector2i, cell_position: Vector2i) -> Cell:
	if group_position in groups:
		return groups[group_position][(cell_position.x * group_size) + cell_position.y]
		
	return null


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


func interpolate_cell_velocity_at_point(world_point: Vector2) -> Vector2:
	var grid_position = convert_world_to_grid(world_point)
	var group_position = grid_position[0]
	var cell_position = grid_position[1]

	var current_cell = get_cell_in_group(group_position, cell_position)
	
	if current_cell == null:
		return Vector2()

	# Getting the right cell's u
	var right_cell: Cell
	var right_group_position = group_position
	var right_cell_position = cell_position

	if cell_position.x + 1 < group_size:
		right_cell_position.x += 1
	else:
		right_group_position += Vector2i(1, 0)
		right_cell_position = Vector2i(0, cell_position.y)

	right_cell = get_cell_in_group(right_group_position, right_cell_position)

	if right_cell == null:
		right_cell = current_cell

	# Getting the bottom cell's v
	var bottom_cell: Cell
	var bottom_group_position = group_position
	var bottom_cell_position = cell_position

	if cell_position.y + 1 < group_size:
		bottom_cell_position.y += 1
	else:
		bottom_group_position += Vector2i(0, 1)
		bottom_cell_position = Vector2i(cell_position.x, 0)

	bottom_cell = get_cell_in_group(bottom_group_position, bottom_cell_position)

	if bottom_cell == null:
		bottom_cell = current_cell

	# Get point's position relative to the cell
	var cell_origin = convert_cell_to_world(group_position, cell_position)
	var half_cell_size = cell_size / 2
	var velocity_origin = cell_origin - Vector2(half_cell_size, half_cell_size) # upper-left corner

	var relative_position = (world_point - velocity_origin) / cell_size

	# Get interpolated components
	var u_interpolated = lerp(current_cell.u, right_cell.u, relative_position.x)
	var v_interpolated = lerp(current_cell.v, bottom_cell.v, relative_position.y)

	return Vector2(u_interpolated, v_interpolated)


func interpolate_velocity_at_point(velocity: Vector2, world_point: Vector2) -> Vector2:
	var grid_position = convert_world_to_grid(world_point)
	var group_position = grid_position[0]
	var cell_position = grid_position[1]

	# Get point's position relative to the cell
	var cell_origin = convert_cell_to_world(group_position, cell_position)
	var half_cell_size = cell_size / 2
	var velocity_origin = cell_origin - Vector2(half_cell_size, half_cell_size) # upper-left corner

	var relative_position = (world_point - velocity_origin) / cell_size

	return velocity * relative_position

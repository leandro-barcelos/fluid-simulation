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

func interpolate_velocity_at_top(group_position: Vector2i, cell_position: Vector2i) -> Vector2:
	var current_cell = get_cell_in_group(group_position, cell_position)
	
	# right cell
	var right_cell: Cell
	var right_group_position = group_position
	var right_cell_position = cell_position

	if cell_position.x + 1 < group_size:
		right_cell_position.x += 1
	else:
		right_group_position += Vector2i(1, 0)
		right_cell_position = Vector2i(0, cell_position.y)

	right_cell = get_cell_in_group(right_group_position, right_cell_position)
	
	# Upper cell
	var upper_cell: Cell
	var upper_group_position = group_position
	var upper_cell_position = cell_position

	if cell_position.y - 1 > 0:
		upper_cell_position.y -= 1
	else:
		upper_group_position -= Vector2i(0, 1)
		upper_cell_position = Vector2i(cell_position.x, group_size - 1)

	upper_cell = get_cell_in_group(upper_group_position, upper_cell_position)
	
	# Upper-rigth cell
	var upper_right_cell: Cell
	var upper_right_group_position = upper_group_position
	var upper_right_cell_position = upper_cell_position

	if upper_cell_position.x + 1 < group_size:
		upper_right_cell_position.x += 1
	else:
		upper_right_group_position += Vector2i(1, 0)
		upper_right_cell_position = Vector2i(0, upper_cell_position.y)

	upper_right_cell = get_cell_in_group(upper_right_group_position, upper_right_cell_position)

	return Vector2(
		(current_cell.u + right_cell.u + upper_cell.u + upper_right_cell.u) / 4,
		current_cell.v
		)

func interpolate_velocity_at_left(group_position: Vector2i, cell_position: Vector2i) -> Vector2:
	var current_cell = get_cell_in_group(group_position, cell_position)
	
	# left cell
	var left_cell: Cell
	var left_group_position = group_position
	var left_cell_position = cell_position

	if cell_position.x - 1 > 0:
		left_cell_position.x -= 1
	else:
		left_group_position -= Vector2i(1, 0)
		left_cell_position = Vector2i(group_size - 1, cell_position.y)

	left_cell = get_cell_in_group(left_group_position, left_cell_position)
	
	# bottom cell
	var bottom_cell: Cell
	var bottom_group_position = group_position
	var bottom_cell_position = cell_position

	if cell_position.y + 1 < group_size:
		bottom_cell_position.y += 1
	else:
		bottom_group_position += Vector2i(0, 1)
		bottom_cell_position = Vector2i(cell_position.x, 0)

	bottom_cell = get_cell_in_group(bottom_group_position, bottom_cell_position)
	
	# bottom-left cell
	var bottom_left_cell: Cell
	var bottom_left_group_position = bottom_group_position
	var bottom_left_cell_position = bottom_cell_position

	if bottom_cell_position.x - 1 > 0:
		bottom_left_cell_position.x -= 1
	else:
		bottom_left_group_position -= Vector2i(1, 0)
		bottom_left_cell_position = Vector2i(group_size - 1, bottom_cell_position.y)

	bottom_left_cell = get_cell_in_group(bottom_left_group_position, bottom_left_cell_position)

	return Vector2(
		current_cell.u,
		(current_cell.v + bottom_cell.v + left_cell.v + bottom_left_cell.v) / 4
		)

func interpolate_velocity_at_center(group_position: Vector2i, cell_position: Vector2i) -> Vector2:
	var current_cell = get_cell_in_group(group_position, cell_position)
	
	# bottom cell
	var bottom_cell: Cell
	var bottom_group_position = group_position
	var bottom_cell_position = cell_position

	if cell_position.y + 1 < group_size:
		bottom_cell_position.y += 1
	else:
		bottom_group_position += Vector2i(0, 1)
		bottom_cell_position = Vector2i(cell_position.x, 0)

	bottom_cell = get_cell_in_group(bottom_group_position, bottom_cell_position)

	# right cell
	var right_cell: Cell
	var right_group_position = group_position
	var right_cell_position = cell_position

	if cell_position.x + 1 < group_size:
		right_cell_position.x += 1
	else:
		right_group_position += Vector2i(1, 0)
		right_cell_position = Vector2i(0, cell_position.y)

	right_cell = get_cell_in_group(right_group_position, right_cell_position)

	return Vector2(
		(current_cell.u + bottom_cell.u) / 2,
		(current_cell.v + right_cell.v) / 2
		)
-- // H - uint16, h - int16, I - uint32, i - int32, c - char

local types = {}
types.__index = types

local function constructor(slots)
	return function()
		local tbl = {}
		tbl.num_slots = #(slots)

		for _, v in pairs(slots) do
			tbl[v] = 0
		end

		return tbl
	end
end

types.TextureMap = constructor(
	{
		'name',
		'flags',
		'width',
		'height',
		'column_dir', -- // unused
		'patch_count',
		'patch_maps'
	}
)

types.PatchMap = constructor(
	{
		'x_offset',
		'y_offset',
		'p_name_index',
		'step_dir', -- // unused
		'color_map' -- // unused
	}
)

types.TextureHeader = constructor(
	{
		'texture_count',
		'texture_offset',
		'texture_data_offset'
	}
)

types.PatchColumn = constructor(
	{
		'top_delta', -- // B
		'length', -- // B
		'padding_pre', -- // B - unused
		'data', -- // length x B
		'padding_post' -- // B - unused
	}
)

types.PatchHeader = constructor(
	{
		'width', -- // H
		'height', -- // H
		'left_offset', -- // h
		'top_offset', -- // h
		'column_offset' -- // width x I
	}
)

-- // 26 bytes = 2h + 2h + 8c + 8c + 2H x 3

types.Sector = constructor(
	{
		'floor_height',
		'ceil_height',
		'floor_texture',
		'ceil_texture',
		'light_level',
		'type',
		'tag'
	}
)

-- // 30 bytes = 2h + 2h + 8c + 8c + 8c + 2H

types.Sidedef = constructor(
	{
		'x_offset',
		'y_offset',
		'upper_texture',
		'lower_texture',
		'middle_texture',
		'sector_id',

		'sector'
	}
)

-- // 10 bytes

types.Thing = constructor(
	{
		'pos', -- // pos.x, pos.y - 4h
		'angle', -- // 2H
		'type', -- // 2H
		'flags' -- // 2H
	}
)

-- // 12 bytes = 2h x 6

types.Seg = constructor(
	{
		'start_vertex_id',
		'end_vertex_id',
		'angle',
		'linedef_id',
		'direction',
		'offset',

		'start_vertex',
		'end_vertex',
		'linedef',
		'front_sector',
		'back_sector'
	}
)

-- // 4 bytes = 2h + 2h

types.SubSector = constructor(
	{
		'seg_count',
		'first_seg_id'
	}
)

-- // 28 bytes = 2x x 12 + 2H x 2

local BBox = constructor(
	{
		'top',
		'bottom',
		'left',
		'right'
	}
)

types.Node = function()
	local tbl = {}

	local slots = {
		'x_partition',
		'y_partition',
		'dx_partition',
		'dy_partition',
		'bbox', -- // 8h
		'front_child_id',
		'back_child_id'
	}

	for _, v in pairs(slots) do
		tbl[v] = 0
	end

	tbl.bbox = {
		["front"] = BBox(),
		["back"] = BBox()
	}

	return tbl
end

-- // 14 bytes = 2H x 7

types.Linedef = constructor(
	{
		'start_vertex_id',
		'end_vertex_id',
		'flags',
		'line_type',
		'sector_tag',
		'front_sidedef_id',
		'back_sidedef_id',

		'front_sidedef',
		'back_sidedef'
	}
)

return types
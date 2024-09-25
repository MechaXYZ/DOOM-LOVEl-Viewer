local vec2 = require("libs/vec2")
local data_types = require("libs/data_types")

local WadReader = {}
WadReader.__index = WadReader

function WadReader.__init(self, wad_path)
	local data, err = love.filesystem.newFile(wad_path, "r")
	assert(data, err)

	self.wad_file = data

	self.header = self:read_header()
	self.directory = self:read_directory()

	return self
end

function WadReader.read_texture_map(offset)
	local self = WadReader
	local r2b = self.read_2_bytes
	local r4b = self.read_4_bytes
	local rs = self.read_string

	local tex_map = data_types.TextureMap()
	tex_map.name = rs(self, offset, 8)
	tex_map.flags = r4b(self, offset + 8, 'I')
	tex_map.width = r2b(self, offset + 12, 'H')
	tex_map.height = r2b(self, offset + 14, 'H')
	tex_map.column_dir = r4b(self, offset + 16, 'I') -- // unused
	tex_map.patch_count = r2b(self, offset + 20, 'H')
	tex_map.patch_maps = {}

	for i = 0, tex_map.patch_count - 1 do
		-- // 10 bytes each
		tex_map.patch_maps[i] = self.read_patch_map(offset + 22 + i * 10)
	end

	return tex_map
end

function WadReader.read_patch_map(offset)
	-- // defining how the patch should be drawn inside the texture

	local self = WadReader
	local r2b = self.read_2_bytes

	local patch_map = data_types.PatchMap()
	patch_map.x_offset = r2b(self, offset + 0, 'h')
	patch_map.y_offset = r2b(self, offset + 2, 'h')
	patch_map.p_name_index = r2b(self, offset + 4, 'H')
	patch_map.step_dir = r2b(self, offset + 6, 'H') -- // unused
	patch_map.color_map = r2b(self, offset + 8, 'H') -- // unused

	return patch_map
end

function WadReader.read_texture_header(offset)
	local self = WadReader
	local r4b = self.read_4_bytes

	local tex_header = data_types.TextureHeader()
	tex_header.texture_count = r4b(self, offset + 0, 'I')
	tex_header.texture_offset = r4b(self, offset + 4, 'I')

	tex_header.texture_data_offset = {}

	for i = 0, tex_header.texture_count - 1 do
		tex_header.texture_data_offset[i] = r4b(self, offset + 4 + i * 4, 'I')
	end

	return tex_header
end

function WadReader.read_patch_column(offset)
	local self = WadReader
	local r1b = self.read_1_byte

	local patch_column = data_types.PatchColumn()
	patch_column.top_delta = r1b(self, offset + 0)

	if patch_column.top_delta ~= 0xFF then
		patch_column.length = r1b(self, offset + 1)
		patch_column.padding_pre = r1b(self, offset + 2) -- // unused

		patch_column.data = {}

		for i = 0, patch_column.length - 1 do
			patch_column.data[i] = r1b(self, offset + 3 + i)
		end

		patch_column.padding_post = r1b(self, offset + 3 + patch_column.length) -- // unused

		return patch_column, offset + 4 + patch_column.length
	end

	return patch_column, offset + 1
end

function WadReader.read_patch_header(offset)
	local self = WadReader
	local r2b = self.read_2_bytes
	local r4b = self.read_4_bytes

	local patch_header = data_types.PatchHeader()
	patch_header.width = r2b(self, offset + 0, 'H')
	patch_header.height = r2b(self, offset + 2, 'H')
	patch_header.left_offset = r2b(self, offset + 4, 'h')
	patch_header.top_offset = r2b(self, offset + 6, 'h')
	patch_header.column_offset = {}

	for i = 0, patch_header.width - 1 do
		patch_header.column_offset[i] = r4b(self, offset + 8 + 4 * i, 'I')
	end

	return patch_header
end

function WadReader.read_palette(offset)
	-- // 3 bytes = B + B + B

	local self = WadReader
	local r1b = self.read_1_byte

	local palette = {}

	for i = 0, 255 do
		palette[i] = {
			r1b(self, offset + i * 3 + 0),
			r1b(self, offset + i * 3 + 1),
			r1b(self, offset + i * 3 + 2),
		}
	end

	return palette
end

function WadReader.read_sector(offset)
	-- // 26 bytes = 2h + 2h + 8c + 8c + 2H x 3

	local self = WadReader
	local r2b = self.read_2_bytes
	local rs = self.read_string

	local sector = data_types.Sector()
	sector.floor_height = r2b(self, offset, 'h')
	sector.ceil_height = r2b(self, offset + 2, 'h')
	sector.floor_texture = rs(self, offset + 4, 8)
	sector.ceil_texture = rs(self, offset + 12, 8)
	sector.light_level = r2b(self, offset + 20, 'H')
	sector.type = r2b(self, offset + 22, 'H')
	sector.tag = r2b(self, offset + 24, 'H')

	return sector
end

function WadReader.read_sidedef(offset)
	-- // 30 bytes = 2h + 2h + 8c + 8c + 8c + 2H

	local self = WadReader
	local r2b = self.read_2_bytes
	local rs = self.read_string

	local sidedef = data_types.Sidedef()
	sidedef.x_offset = r2b(self, offset, 'h')
	sidedef.y_offset = r2b(self, offset + 2, 'h')
	sidedef.upper_texture = rs(self, offset + 4, 8)
	sidedef.lower_texture = rs(self, offset + 12, 8)
	sidedef.middle_texture = rs(self, offset + 20, 8)
	sidedef.sector_id = r2b(self, offset + 28, 'H')

	return sidedef
end

function WadReader.read_thing(offset)
	-- // 10 bytes = 2h + 2h + 2H x 3

	local self = WadReader
	local r2b = self.read_2_bytes

	local thing = data_types.Thing()
	local x = r2b(self, offset, 'h')
	local y = r2b(self, offset + 2, 'h')

	thing.angle = r2b(self, offset + 4, 'H')
	thing.type = r2b(self, offset + 6, 'H')
	thing.flags = r2b(self, offset + 8, 'H')

	thing.pos = vec2(x, y)

	return thing
end

function WadReader.read_segment(offset)
	-- // 12 bytes = 2h x 6

	local self = WadReader
	local r2b = self.read_2_bytes

	local seg = data_types.Seg()
	seg.start_vertex_id = r2b(self, offset, 'h')
	seg.end_vertex_id = r2b(self, offset + 2, 'h')
	seg.angle = r2b(self, offset + 4, 'h')
	seg.linedef_id = r2b(self, offset + 6, 'h')
	seg.direction = r2b(self, offset + 8, 'h')
	seg.offset = r2b(self, offset + 10, 'h')

	return seg
end

function WadReader.read_sub_sector(offset)
	-- // 4 bytes = 2h + 2h

	local sub_sector = data_types.SubSector()
	sub_sector.seg_count = WadReader:read_2_bytes(offset, 'h')
	sub_sector.first_seg_id = WadReader:read_2_bytes(offset + 2, 'h')

	return sub_sector
end

function WadReader.read_node(offset)
	-- // 28 bytes = 2h x 12 + 2H x 2

	local self = WadReader
	local r2b = self.read_2_bytes

	local node = data_types.Node()
	local bbox = node.bbox
	local front = bbox.front
	local back = bbox.back

	node.x_partition = r2b(self, offset, 'h')
	node.y_partition = r2b(self, offset + 2, 'h')
	node.dx_partition = r2b(self, offset + 4, 'h')
	node.dy_partition = r2b(self, offset + 6, 'h')

	front.top = r2b(self, offset + 8, 'h')
	front.bottom = r2b(self, offset + 10, 'h')
	front.left = r2b(self, offset + 12, 'h')
	front.right = r2b(self, offset + 14, 'h')

	back.top = r2b(self, offset + 16, 'h')
	back.bottom = r2b(self, offset + 18, 'h')
	back.left = r2b(self, offset + 20, 'h')
	back.right = r2b(self, offset + 22, 'h')

	node.front_child_id = r2b(self, offset + 24, 'H')
	node.back_child_id = r2b(self, offset + 26, 'H')

	return node
end

function WadReader.read_linedef(offset)
	-- // 14 bytes = 2H x 7

	local self = WadReader
	local r2b = self.read_2_bytes

	local linedef = data_types.Linedef()
	linedef.start_vertex_id = r2b(self, offset, 'H')
	linedef.end_vertex_id = r2b(self, offset + 2, 'H')
	linedef.flags = r2b(self, offset + 4, 'H')
	linedef.line_type = r2b(self, offset + 6, 'H')
	linedef.sector_tag = r2b(self, offset + 8, 'H')
	linedef.front_sidedef_id = r2b(self, offset + 10, 'H')
	linedef.back_sidedef_id = r2b(self, offset + 12, 'H')

	return linedef
end

function WadReader.read_vertex(offset)
	-- // 4 bytes = 2h + 2h

	local x = WadReader:read_2_bytes(offset, 'h')
	local y = WadReader:read_2_bytes(offset + 2, 'h')

	return vec2(x, y)
end

function WadReader.read_directory(self)
	local directory = {}

	for i = 0, tonumber(self.header.lump_count) - 1 do
		local offset = self.header.init_offset + i * 16

		local lump_info = {
			['lump_offset'] = self:read_4_bytes(offset),
			['lump_size'] = self:read_4_bytes(offset + 4),
			['lump_name'] = self:read_string(offset + 8, 8)
		}

		directory[i] = lump_info
	end

	return directory
end

function WadReader.read_header(self)
	return {
		['wad_type'] = self:read_string(0, 4),
		['lump_count'] = self:read_4_bytes(4),
		['init_offset'] = self:read_4_bytes(8)
	}
end

function WadReader.read_1_byte(self, offset, byte_format)
	-- // B - unsigned char, b - signed char
	byte_format = byte_format or 'B'
	return self:read_bytes(offset, 1, byte_format)
end

function WadReader.read_2_bytes(self, offset, byte_format)
	-- // H - uint16, h - int16
	return self:read_bytes(offset, 2, byte_format)
end

function WadReader.read_4_bytes(self, offset, byte_format)
	-- // I - uint32, i32 - int32
	byte_format = byte_format or 'i'
	return self:read_bytes(offset, 4, byte_format)
end

function WadReader.read_string(self, offset, num_bytes)
	-- // c - char
	return string.upper(string.gsub(self:read_bytes(offset, num_bytes, 'c'), '%z', ''))
end

function WadReader.read_string_alt(offset, num_bytes)
	return string.upper(string.gsub(WadReader:read_bytes(offset, num_bytes, 'c'), '%z', ''))
end

function WadReader.read_bytes(self, offset, num_bytes, byte_format)
	self.wad_file:seek(offset)

	if byte_format ~= "c" then
		return love.data.unpack(byte_format, self.wad_file:read(num_bytes), 1)
	else
		return self.wad_file:read(num_bytes)
	end
end

function WadReader.close(self)
	self.wad_file:close()
end

return function(...)
	return WadReader:__init(...)
end
local AssetData = require("libs/asset_data")
local WadReader = require("libs/wad_reader")

local WadData = {}
WadData.__index = WadData

local lump_indices = {
	["THINGS"] = 1,
	["LINEDEFS"] = 2,
	["SIDEDEFS"] = 3,
	["VERTEXES"] = 4,
	["SEGS"] = 5,
	["SSECTORS"] = 6,
	["NODES"] = 7,
	["SECTORS"] = 8,
	["REJECT"] = 9,
	["BLOCKMAP"] = 10
}

local LINEDEF_FLAGS = {
	["BLOCKING"] = 1,
	["BLOCK_MONSTERS"] = 2,
	["TWO_SIDED"] = 4,
	["DONT_PEG_TOP"] = 8,
	["DONT_PEG_BOTTOM"] = 16,
	["SECRET"] = 32,
	["SOUND_BLOCK"] = 64,
	["DONT_DRAW"] = 128,
	["MAPPED"] = 256
}

function WadData.__init(self, engine)
	self.LINEDEF_FLAGS = LINEDEF_FLAGS
	self.reader = WadReader(engine.wad_path)
	self.map_index = self:get_lump_index(engine.map)

	self.vertexes = self:get_lump_data(
		self.reader.read_vertex,
		self.map_index + lump_indices.VERTEXES,
		4 -- // num bytes per vertex
	)

	self.linedefs = self:get_lump_data(
		self.reader.read_linedef,
		self.map_index + lump_indices.LINEDEFS,
		14
	)

	self.nodes = self:get_lump_data(
		self.reader.read_node,
		self.map_index + lump_indices.NODES,
		28
	)

	self.sub_sectors = self:get_lump_data(
		self.reader.read_sub_sector,
		self.map_index + lump_indices.SSECTORS,
		4
	)

	self.segments = self:get_lump_data(
		self.reader.read_segment,
		self.map_index + lump_indices.SEGS,
		12
	)

	self.things = self:get_lump_data(
		self.reader.read_thing,
		self.map_index + lump_indices.THINGS,
		10
	)

	self.sidedefs = self:get_lump_data(
		self.reader.read_sidedef,
		self.map_index + lump_indices.SIDEDEFS,
		30
	)

	self.sectors = self:get_lump_data(
		self.reader.read_sector,
		self.map_index + lump_indices.SECTORS,
		26
	)

	-- // for _, v in pairs(self.linedefs) do
	-- // 	WadData.__print_attrs(v)
	-- // end

	self:update_data()
	self.asset_data = AssetData(self)
	-- // self.reader:close()

	return self
end

function WadData.update_data(self)
	self:update_linedefs()
	self:update_sidedefs()
	self:update_segs()
end

function WadData.update_sidedefs(self)
	for _, sidedef in pairs(self.sidedefs) do
		sidedef.sector = self.sectors[sidedef.sector_id]
	end
end

function WadData.update_linedefs(self)
	for _, linedef in pairs(self.linedefs) do
		linedef.front_sidedef = self.sidedefs[linedef.front_sidedef_id]

		if linedef.back_sidedef_id == 0xFFFF then -- // undefined sidedef
			linedef.back_sidedef = nil
		else
			linedef.back_sidedef = self.sidedefs[linedef.back_sidedef_id]
		end
	end
end

function WadData.update_segs(self)
	for _, seg in pairs(self.segments) do
		seg.start_vertex = self.vertexes[seg.start_vertex_id]
		seg.end_vertex = self.vertexes[seg.end_vertex_id]
		seg.linedef = self.linedefs[seg.linedef_id]

		local front_sidedef, back_sidedef

		if seg.direction == 1 then
			front_sidedef = seg.linedef.back_sidedef
			back_sidedef = seg.linedef.front_sidedef
		else
			front_sidedef = seg.linedef.front_sidedef
			back_sidedef = seg.linedef.back_sidedef
		end

		seg.front_sector = front_sidedef.sector

		if bit.band(self.LINEDEF_FLAGS.TWO_SIDED, seg.linedef.flags) > 0 then
			seg.back_sector = back_sidedef.sector
		else
			seg.back_sector = nil
		end

		-- // convert angles from BAMs to degrees
		seg.angle = bit.lshift(seg.angle, 16) * 8.38190317e-8
		seg.angle = (seg.angle < 0 and seg.angle + 360 or seg.angle)

		-- // texture special case
		if seg.front_sector and seg.back_sector then
			if front_sidedef.upper_texture == '-' then
				seg.linedef.front_sidedef.upper_texture = back_sidedef.upper_texture
			end

			if front_sidedef.lower_texture == '-' then
				seg.linedef.front_sidedef.lower_texture = back_sidedef.lower_texture
			end
		end
	end
end

function WadData.__print_attrs(obj)
	local j = 0
	local str = "{"

	for i, v in pairs(obj) do
		if i ~= "num_slots" then
			j = j + 1
			str = str .. '"' .. i .. '": '

			if tonumber(v) then
				str = str .. v
			else
				str = str .. '"' .. v .. '"'
			end

			if j ~= obj.num_slots then
				str = str .. ", "
			end
		end
	end

	print(str .. "}")
end

function WadData.get_lump_data(self, reader_func, lump_index, num_bytes, header_length)
	header_length = header_length or 0

	local data = {}
	local lump_info = self.reader.directory[lump_index]
	local count = math.floor(lump_info.lump_size / num_bytes)

	for i = 0, count - 1 do
		local offset = lump_info.lump_offset + i * num_bytes + header_length
		data[i] = reader_func(offset, num_bytes)
	end

	return data
end

function WadData.get_lump_index(self, lump_name)
	for index, lump_info in pairs(self.reader.directory) do
		if lump_info.lump_name == lump_name then
			return index
		end
	end
end

return function(...)
	return WadData:__init(...)
end
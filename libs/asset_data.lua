local utils = require("libs/utils")
local cfg = require("libs/settings")

local function round(num)
    return math.floor(num + 0.5)
end

local function resize(data, nw, nh)
	local n_data = {}
	local w, h = #(data[0]) + 1, #(data) + 1

	for y = 0, nh - 1 do
		n_data[y] = {}

		for x = 0, nw - 1 do
			local sx = math.min(math.floor(round(x / nw * w)), w - 1)
			local sy = math.min(math.floor(round(y / nh * h)), h - 1)

			n_data[y][x] = data[sy][sx]
		end
	end

	return n_data
end

local function blit(dest, src, ox, oy)
	for y = 0, #(src) do
		if not dest[oy + y] then
			dest[oy + y] = {}
		end

		for x = 0, #(src[0]) do
			dest[oy + y][ox + x] = src[y][x]
		end
	end
end

local Patch = {}
Patch.__index = Patch

function Patch.__init(self, asset_data, name, is_sprite)
	is_sprite = is_sprite or true

	local patch = setmetatable({}, self)
	patch.asset_data = asset_data
	patch.name = name

	patch.palette = asset_data.palette
	patch.header, patch.patch_columns = patch:load_patch_columns(name)
	patch.width = patch.header.width
	patch.height = patch.header.height

	patch.image = patch:get_image()

	if is_sprite then
		patch.image = resize(patch.image, patch.width * cfg.SCALE, patch.height * cfg.SCALE)
	end

	return patch
end

function Patch.load_patch_columns(self, patch_name)
	local reader = self.asset_data.reader
	local patch_index = self.asset_data:get_lump_index(patch_name)
	local patch_offset = reader.directory[patch_index].lump_offset

	local patch_header = self.asset_data.reader.read_patch_header(patch_offset)

	local patch_columns = {}

	for i = 0, patch_header.width - 1 do
		local offs = patch_offset + patch_header.column_offset[i]

		while true do
			local patch_column, off = reader.read_patch_column(offs)
			offs = off

			if not patch_columns[0] then
				patch_columns[0] = patch_column
			else
				patch_columns[#(patch_columns) + 1] = patch_column
			end

			if patch_column.top_delta == 0xFF then
				break
			end
		end
	end

	return patch_header, patch_columns
end

function Patch.get_image(self)
	local image = utils.create2d(self.width, self.height)

	local ix = 0

	for _, column in pairs(self.patch_columns) do
		repeat
			if column.top_delta == 0xFF then
				ix = ix + 1
				break -- // continue
			end

			for iy = 0, column.length - 1 do
				local color_idx = column.data[iy]
				local color = self.palette[color_idx]
				image[iy + column.top_delta][ix] = color
			end
		until true
	end

	return image
end

local Texture = {}
Texture.__index = Texture

function Texture.__init(self, asset_data, tex_map)
	local texture = setmetatable({}, self)
	texture.asset_data = asset_data
	texture.tex_map = tex_map
	texture.image = texture:get_image()

	return texture
end

function Texture.get_image(self)
	local image = utils.create2d(self.tex_map.width, self.tex_map.height)

	for _, patch_map in pairs(self.tex_map.patch_maps) do
		local patch = self.asset_data.texture_patches[patch_map.p_name_index]
		blit(image, patch.image, patch_map.x_offset * cfg.SCALE, patch_map.y_offset * cfg.SCALE)
	end

	return image
end


local Flat = {}
Flat.__index = Flat

function Flat.__init(self, asset_data, flat_data)
	local flat = setmetatable({}, self)
	flat.flat_data = flat_data
	flat.palette = asset_data.palette
	flat.image = flat:get_image()

	return flat
end

function Flat.get_image(self)
	local image = utils.create2d(64, 64)

	for i, color_idx in pairs(self.flat_data) do
		local ix = i % 64
		local iy = math.floor(i / 64)
		local color = self.palette[color_idx]
		image[iy][ix] = color
	end

	return image
end

local AssetData = {}
AssetData.__index = AssetData

function AssetData.__init(self, wad_data)
	self.wad_data = wad_data
	self.reader = wad_data.reader
	self.get_lump_index = wad_data.get_lump_index

	-- // palettes
	self.palettes = wad_data:get_lump_data(
		self.reader.read_palette,
		wad_data:get_lump_index('PLAYPAL'),
		256 * 3
	)

	-- // current palette
	self.palette_idx = 0
	self.palette = self.palettes[self.palette_idx]

	-- // sprites
	print("init sprites")
	self.sprites = self:get_sprites('S_START', 'S_END')

	-- // texture patch names
	self.p_names = wad_data:get_lump_data(
		self.reader.read_string_alt,
		wad_data:get_lump_index('PNAMES'),
		8,
		4
	)

	print("init p names")
	self.texture_patches = {}

	for _, p_name in pairs(self.p_names) do
		print("init", p_name)

		local value = Patch:__init(self, p_name, false)

		if not self.texture_patches[0] then
			self.texture_patches[0] = value
		else
			self.texture_patches[#(self.texture_patches) + 1] = value
		end
	end

	-- // wall textures
	local texture_maps = self:load_texture_maps('TEXTURE1')

	if self:get_lump_index('TEXTURE2') then
		for _, v in pairs(self:load_texture_maps('TEXTURE2')) do
			table.insert(texture_maps, v)
		end
	end

	self.textures = {}
	print("init wall textures")

	for _, tex_map in pairs(texture_maps) do
		print("init", tex_map.name)
		self.textures[tex_map.name] = Texture:__init(self, tex_map).image
	end

	-- // flat textures
	print("init flat textures")

	for i, flat in pairs(self:get_flats()) do
		print("init", i)
		self.textures[i] = flat
	end

	-- // sky
	self.sky_id = 'F_SKY1'
	self.sky_tex_name = 'SKY1'
	self.sky_tex = self.textures[self.sky_tex_name]

	return self
end

function AssetData.get_flats(self, start_marker, end_marker)
	start_marker = start_marker or 'F_START'
	end_marker = end_marker or 'F_END'

	local idx1 = self:get_lump_index(start_marker) + 1
	local idx2 = self:get_lump_index(end_marker)
	local flat_lumps = utils.slice(self.reader.directory, idx1, idx2)
	local flats = {}

	for _, flat_lump in pairs(flat_lumps) do
		local offset = flat_lump.lump_offset
		local size = flat_lump.lump_size -- // 64 x 64
		local flat_data = {}

		for i = 0, size - 1 do
			flat_data[i] = self.reader.read_1_byte(self.reader, offset + i, 'B')
		end

		local flat_name = flat_lump.lump_name
		flats[flat_name] = Flat:__init(self, flat_data).image
	end

	return flats
end

function AssetData.load_texture_maps(self, texture_lump_name)
	local tex_idx = self:get_lump_index(texture_lump_name)
	local offset = self.reader.directory[tex_idx].lump_offset
	local texture_header = self.reader.read_texture_header(offset)

	local texture_maps = {}

	for i = 0, texture_header.texture_count - 1 do
		texture_maps[i] = self.reader.read_texture_map(
			offset + texture_header.texture_data_offset[i]
		)
	end

	return texture_maps
end

function AssetData.get_sprites(self, start_marker, end_marker)
	start_marker = start_marker or 'S_START'
	end_marker = end_marker or 'S_END'

	local idx1 = self:get_lump_index(start_marker) + 1
	local idx2 = self:get_lump_index(end_marker)
	local lumps_info = utils.slice(self.reader.directory, idx1, idx2)

	local sprites = {}

	for _, lump in pairs(lumps_info) do
		print("init", lump.lump_name)
		sprites[lump.lump_name] = Patch:__init(self, lump.lump_name)
		break
	end

	return sprites
end

return function(...)
	return AssetData:__init(...)
end
local utils = require("libs/utils")
local cfg = require("libs/settings")

local SegHandler = {}
SegHandler.__index = SegHandler

function SegHandler.__init(self, engine)
	self.MAX_SCALE = 64
	self.MIN_SCALE = 0.00390625

	self.engine = engine
	self.player = engine.player
	self.wad_data = engine.wad_data
	self.sky_id = self.wad_data.asset_data.sky_id
	self.textures = self.wad_data.asset_data.textures

	self.seg = nil
	self.rw_angle1 = nil
	self.screen_range = nil
	self.upper_clip, self.lower_clip = {}, {}
	self.x_to_angle = self.get_x_to_angle_table()

	return self
end

function SegHandler.update(self)
	self:init_floor_ceil_clip_height()
	self:init_screen_range()
end

function SegHandler.init_floor_ceil_clip_height(self)
	local width = cfg.WIDTH
	local height = cfg.HEIGHT
	local upper_clip, lower_clip = {}, {}

	for i = 0, width - 1 do
		upper_clip[i] = -1
	end

	for i = 0, width - 1 do
		lower_clip[i] = height
	end

	self.upper_clip = upper_clip
	self.lower_clip = lower_clip
end

function SegHandler.init_screen_range(self)
	self.screen_range = {}

	for i = 0, cfg.WIDTH - 1 do
		self.screen_range[i] = i
	end
end

function SegHandler.get_x_to_angle_table()
	local x_to_angle = {}

	for i = 0, cfg.WIDTH do
		local angle = math.deg(math.atan((cfg.H_WIDTH - i) / cfg.SCREEN_DIST))
		x_to_angle[i] = angle
	end

	return x_to_angle
end

function SegHandler.scale_from_global_angle(self, x, rw_normal_angle, rw_distance)
	local x_angle = self.x_to_angle[x]
	local num = cfg.SCREEN_DIST * math.cos(math.rad(rw_normal_angle - x_angle - self.player.angle))
	local den = rw_distance * math.cos(math.rad(x_angle))

	local scale = num / den
	scale = math.min(self.MAX_SCALE, math.max(self.MIN_SCALE, scale))

	return scale
end

function SegHandler.draw_solid_wall_range(self, x1, x2)
	-- // some aliases to shorten the following code
	local seg = self.seg
	local line = seg.linedef
	local side = line.front_sidedef
	local upper_clip = self.upper_clip
	local lower_clip = self.lower_clip
	local front_sector = seg.front_sector
	local renderer = self.engine.view_renderer

	-- // textures
	local wall_texture_id = side.middle_texture
	local ceil_texture_id = front_sector.ceil_texture
	local floor_texture_id = front_sector.floor_texture
	local light_level = front_sector.light_level

	-- // calculate the relative plane heights of front sector
	local world_front_z1 = front_sector.ceil_height - self.player.height
	local world_front_z2 = front_sector.floor_height - self.player.height

	-- // check which parts must be rendered
	local b_draw_wall = side.middle_texture ~= '-'
	local b_draw_ceil = world_front_z1 > 0 or front_sector.ceil_texture == self.sky_id
	local b_draw_floor = world_front_z2 < 0

	if not b_draw_wall and not b_draw_ceil and not b_draw_floor then
		return
	end

	-- // calculate the scaling factors of the left and right edges of the wall range
	local rw_normal_angle = seg.angle + 90
	local offset_angle = rw_normal_angle - self.rw_angle1

	local hypotenuse = utils.dist({self.player.pos.x, self.player.pos.y}, {seg.start_vertex.x, seg.start_vertex.y})
	local rw_distance = hypotenuse * math.cos(math.rad(offset_angle))
	local rw_scale1 = self:scale_from_global_angle(x1, rw_normal_angle, rw_distance)

	-- // lol try to fix the stretched line bug
	if utils.isclose(offset_angle % 360, 90, nil, 1) then
		rw_scale1 = rw_scale1 * 0.01
	end

	local scale2
	local rw_scale_step

	if x1 < x2 then
		scale2 = self:scale_from_global_angle(x2, rw_normal_angle, rw_distance)
		rw_scale_step = (scale2 - rw_scale1) / (x2 - x1)
	else
		rw_scale_step = 0
	end

	-- // determine how the wall textures are vertically aligned
	local v_top, middle_tex_alt
	local wall_texture = self.textures[wall_texture_id]

	if bit.band(line.flags, self.wad_data.LINEDEF_FLAGS.DONT_PEG_BOTTOM) > 0 then
		v_top = front_sector.floor_height + #(wall_texture) + 1
		middle_tex_alt = v_top - self.player.height
	else
		middle_tex_alt = world_front_z1
	end

	middle_tex_alt = middle_tex_alt + side.y_offset

	-- // determine how the wall textures are horizontally aligned
	local rw_offset = hypotenuse * math.sin(math.rad(offset_angle))
	rw_offset = rw_offset + seg.offset + side.x_offset

	local rw_center_angle = rw_normal_angle - self.player.angle

	-- // determine where on the screen the wall is drawn
	local wall_y1 = cfg.H_HEIGHT - world_front_z1 * rw_scale1
	local wall_y1_step = -(rw_scale_step) * world_front_z1

	local wall_y2 = cfg.H_HEIGHT - world_front_z2 * rw_scale1
	local wall_y2_step = -(rw_scale_step) * world_front_z2

	-- // now the rendering is carried out
	for x = x1, x2 do
		local draw_wall_y1 = wall_y1 - 1
		local draw_wall_y2 = wall_y2

		if b_draw_ceil then
			local cy1 = upper_clip[x] + 1
			local cy2 = utils.int(math.min(draw_wall_y1 - 1, lower_clip[x] - 1))

			renderer:draw_flat(ceil_texture_id, light_level, x, cy1, cy2, world_front_z1)
		end

		if b_draw_wall then
			local wy1 = utils.int(math.max(draw_wall_y1, upper_clip[x] + 1))
			local wy2 = utils.int(math.min(draw_wall_y2, lower_clip[x] - 1))

			if wy1 < wy2 then
				local angle = rw_center_angle - self.x_to_angle[x]
				local texture_column = rw_distance * math.tan(math.rad(angle)) - rw_offset
				local inv_scale = (1 / rw_scale1)

				renderer:draw_wall_col(wall_texture, texture_column, x, wy1, wy2, middle_tex_alt, inv_scale, light_level)
			end
		end

		if b_draw_floor then
			local fy1 = utils.int(math.max(draw_wall_y2 + 1, upper_clip[x] + 1))
			local fy2 = lower_clip[x] - 1

			renderer:draw_flat(floor_texture_id, light_level, x, fy1, fy2, world_front_z2)
		end

		wall_y1 = wall_y1 + wall_y1_step
		wall_y2 = wall_y2 + wall_y2_step
		rw_scale1 = rw_scale1 + rw_scale_step
	end
end

function SegHandler.draw_portal_wall_range(self, x1, x2)
	-- // some aliases to shorten the following code
	local seg = self.seg
	local front_sector = seg.front_sector
	local back_sector = seg.back_sector
	local line = seg.linedef
	local side = line.front_sidedef
	local renderer = self.engine.view_renderer

	local upper_clip = self.upper_clip
	local lower_clip = self.lower_clip

	-- // textures
	local upper_wall_texture = side.upper_texture
	local lower_wall_texture = side.lower_texture
	local tex_ceil_id = front_sector.ceil_texture
	local tex_floor_id = front_sector.floor_texture
	local light_level = front_sector.light_level

	-- // calculate the relative plane heights of front and back sector
	local world_front_z1 = front_sector.ceil_height - self.player.height
	local world_back_z1 = back_sector.ceil_height - self.player.height
	local world_front_z2 = front_sector.floor_height - self.player.height
	local world_back_z2 = back_sector.floor_height - self.player.height

	-- // sky hack
	if front_sector.ceil_texture == back_sector.ceil_texture == self.sky_id then
		world_back_z1 = world_front_z1 -- // world_front_z1 = world_back_z1
	end

	-- // check which parts must be rendered
	local b_draw_ceil = false
	local b_draw_floor = false
	local b_draw_upper_wall = false
	local b_draw_lower_wall = false

	if (world_front_z1 ~= world_back_z1 or
	front_sector.light_level ~= back_sector.light_level or
	front_sector.ceil_texture ~= back_sector.ceil_texture) then
		b_draw_upper_wall = side.upper_texture ~= '-' and world_back_z1 < world_front_z1
		b_draw_ceil = world_front_z1 >= 0 or front_sector.ceil_texture == self.sky_id
	else
		b_draw_upper_wall = false
		b_draw_ceil = false
	end

	if (world_front_z2 ~= world_back_z2 or
	front_sector.floor_texture ~= back_sector.floor_texture or
	front_sector.light_level ~= back_sector.light_level) then
		b_draw_lower_wall = side.lower_texture ~= '-' and world_back_z2 > world_front_z2
		b_draw_floor = world_front_z2 <= 0
	else
		b_draw_lower_wall = false
		b_draw_floor = false
	end

	-- // if nothing must be rendered, we can skip this seg
	if not b_draw_upper_wall and not b_draw_ceil and not b_draw_lower_wall and not b_draw_floor then
		return
	end

	-- // calculate the scaling factors of the left and right edges of the wall range
	local rw_normal_angle = seg.angle + 90
	local offset_angle = rw_normal_angle - self.rw_angle1

	local hypotenuse = utils.dist({self.player.pos.x, self.player.pos.y}, {seg.start_vertex.x, seg.start_vertex.y})
	local rw_distance = hypotenuse * math.cos(math.rad(offset_angle))

	local rw_scale1 = self:scale_from_global_angle(x1, rw_normal_angle, rw_distance)

	local scale2
	local rw_scale_step

	if x2 > x1 then
		scale2 = self:scale_from_global_angle(x2, rw_normal_angle, rw_distance)
		rw_scale_step = (scale2 - rw_scale1) / (x2 - x1)
	else
		rw_scale_step = 0
	end

	-- // determine how the wall textures are vertically aligned
	local v_top, upper_tex_alt, lower_tex_alt

	if b_draw_upper_wall then
		upper_wall_texture = self.textures[side.upper_texture]

		if bit.band(line.flags, self.wad_data.LINEDEF_FLAGS.DONT_PEG_TOP) > 0 then
			upper_tex_alt = world_front_z1
		else
			v_top = back_sector.ceil_height + #(upper_wall_texture) + 1
			upper_tex_alt = v_top - self.player.height
		end

		upper_tex_alt = upper_tex_alt + side.y_offset
	end

	if b_draw_lower_wall then
		lower_wall_texture = self.textures[side.lower_texture]

		if bit.band(line.flags, self.wad_data.LINEDEF_FLAGS.DONT_PEG_BOTTOM) > 0 then
			lower_tex_alt = world_front_z1
		else
			lower_tex_alt = world_back_z2
		end

		lower_tex_alt = lower_tex_alt + side.y_offset
	end

	-- // determine how the wall textures are horizontally aligned
	local rw_offset, rw_center_angle
	local seg_textured = (b_draw_upper_wall or b_draw_lower_wall)

	if seg_textured then
		rw_offset = hypotenuse * math.sin(math.rad(offset_angle))
		rw_offset = rw_offset + seg.offset + side.x_offset
		rw_center_angle = rw_normal_angle - self.player.angle
	end

	-- // the y positions of the top / bottom edges of the wall on the screen
	local portal_y1
	local portal_y2
	local portal_y1_step
	local portal_y2_step

	local draw_wall_y1
	local draw_wall_y2

	local wall_y1 = cfg.H_HEIGHT - world_front_z1 * rw_scale1
	local wall_y1_step = -(rw_scale_step) * world_front_z1
	local wall_y2 = cfg.H_HEIGHT - world_front_z2 * rw_scale1
	local wall_y2_step = -(rw_scale_step) * world_front_z2

	-- // the y positon of the top edge of the portal
	if b_draw_upper_wall then
		if world_back_z1 > world_front_z2 then
			portal_y1 = cfg.H_HEIGHT - world_back_z1 * rw_scale1
			portal_y1_step = -(rw_scale_step) * world_back_z1
		else
			portal_y1 = wall_y2
			portal_y1_step = wall_y2_step
		end
	end

	if b_draw_lower_wall then
		if world_back_z2 < world_front_z1 then
			portal_y2 = cfg.H_HEIGHT - world_back_z2 * rw_scale1
			portal_y2_step = -(rw_scale_step) * world_back_z2
		else
			portal_y2 = wall_y1
			portal_y2_step = wall_y1_step
		end
	end

	-- // now the rendering is carried out
	for x = x1, x2 do
		draw_wall_y1 = wall_y1 - 1
		draw_wall_y2 = wall_y2

		local angle, texture_column, inv_scale

		if seg_textured then
			angle = rw_center_angle - self.x_to_angle[x]
			texture_column = rw_distance * math.tan(math.rad(angle)) - rw_offset
			inv_scale = 1 / rw_scale1
		end

		if b_draw_upper_wall then
			local draw_upper_wall_y1 = wall_y1 - 1
			local draw_upper_wall_y2 = portal_y1

			if b_draw_ceil then
				local cy1 = upper_clip[x] + 1
				local cy2 = utils.int(math.min(draw_wall_y1 - 1, lower_clip[x] - 1))

				renderer:draw_flat(tex_ceil_id, light_level, x, cy1, cy2, world_front_z1)
			end

			local wy1 = utils.int(math.max(draw_upper_wall_y1, upper_clip[x] + 1))
			local wy2 = utils.int(math.min(draw_upper_wall_y2, lower_clip[x] - 1))

			renderer:draw_wall_col(upper_wall_texture, texture_column, x, wy1, wy2, upper_tex_alt, inv_scale, light_level)

			if upper_clip[x] < wy2 then
				upper_clip[x] = wy2
			end

			portal_y1 = portal_y1 + portal_y1_step
		end

		if b_draw_ceil then
			local cy1 = upper_clip[x] + 1
			local cy2 = utils.int(math.min(draw_wall_y1 - 1, lower_clip[x] - 1))

			renderer:draw_flat(tex_ceil_id, light_level, x, cy1, cy2, world_front_z1)

			if upper_clip[x] < cy2 then
				upper_clip[x] = cy2
			end
		end

		if b_draw_lower_wall then
			if b_draw_floor then
				local fy1 = utils.int(math.max(draw_wall_y2 + 1, upper_clip[x] + 1))
				local fy2 = lower_clip[x] - 1

				renderer:draw_flat(tex_floor_id, light_level, x, fy1, fy2, world_front_z2)
			end

			local draw_lower_wall_y1 = portal_y2 - 1
			local draw_lower_wall_y2 = wall_y2

			local wy1 = utils.int(math.max(draw_lower_wall_y1, upper_clip[x] + 1))
			local wy2 = utils.int(math.min(draw_lower_wall_y2, lower_clip[x] - 1))

			renderer:draw_wall_col(lower_wall_texture, texture_column, x, wy1, wy2, lower_tex_alt, inv_scale, light_level)

			if lower_clip[x] > wy1 then
				lower_clip[x] = wy1
			end

			portal_y2 = portal_y2 + portal_y2_step
		end

		if b_draw_floor then
			local fy1 = utils.int(math.max(draw_wall_y2 + 1, upper_clip[x] + 1))
			local fy2 = lower_clip[x] - 1

			renderer:draw_flat(tex_floor_id, light_level, x, fy1, fy2, world_front_z2)

			if lower_clip[x] > draw_wall_y2 + 1 then
				lower_clip[x] = fy1
			end
		end

		wall_y1 = wall_y1 + wall_y1_step
		wall_y2 = wall_y2 + wall_y2_step
		rw_scale1 = rw_scale1 + rw_scale_step
	end
end

function SegHandler.clip_portal_walls(self, x_start, x_end)
	local curr_wall = {}

	for i = x_start, x_end - 1 do
		curr_wall[i] = i
	end

	local intersection = {}

	for _, k in pairs(curr_wall) do
		if utils.find(self.screen_range, k) then
			table.insert(intersection, k)
		end
	end

	table.sort(intersection)

	if #(intersection) > 0 then
		if #(intersection) == utils.len(curr_wall) then
			self:draw_portal_wall_range(x_start, x_end - 1)
		else
			local arr = intersection
			local x = arr[1]

			for _, v in utils.zip(arr, utils.slice(arr, 1)) do
				local x1, x2 = unpack(v)
				if x2 - x1 > 1 then
					self:draw_portal_wall_range(x, x1)
					x = x2
				end
			end

			self:draw_portal_wall_range(x, arr[#(arr)])
		end
	end
end

function SegHandler.clip_solid_walls(self, x_start, x_end)
	if self.screen_range and utils.len(self.screen_range) > 0 then
		local curr_wall = {}

		for i = x_start, x_end - 1 do
			curr_wall[i] = i
		end

		local intersection = {}

		for _, k in pairs(curr_wall) do
			if utils.find(self.screen_range, k) then
				table.insert(intersection, k)
			end
		end

		table.sort(intersection)

		if #(intersection) > 0 then
			if #(intersection) == utils.len(curr_wall) then
				self:draw_solid_wall_range(x_start, x_end - 1)
			else
				local arr = intersection
				local x, x2 = arr[1], arr[#(arr)]

				for _, v in utils.zip(arr, utils.slice(arr, 1)) do
					local x1 = v[1]
					x2 = v[2]

					if x2 - x1 > 1 then
						self:draw_solid_wall_range(x, x1)
						x = x2
					end
				end

				self:draw_solid_wall_range(x, x2)
			end

			local new = {}

			for _, v in pairs(self.screen_range) do
				if not utils.find(intersection, v) then
					if not new[0] then
						new[0] = v
					else
						new[#(new) + 1] = v
					end
				end
			end

			self.screen_range = new
		end
	else
		self.engine.is_traverse_bsp = false
	end
end

function SegHandler.classify_segment(self, segment, x1, x2, rw_angle1)
	-- // add seg data
	self.seg = segment
	self.rw_angle1 = rw_angle1

	-- // does not cross a pixel?
	if x1 == x2 then
		return
	end

	local back_sector = segment.back_sector
	local front_sector = segment.front_sector

	-- // handle solid walls
	if not back_sector then
		self:clip_solid_walls(x1, x2)
		return
	end

	-- // wall with window
	if (front_sector.ceil_height ~=
	back_sector.ceil_height or
	front_sector.floor_height ~=
	back_sector.floor_height) then
		self:clip_portal_walls(x1, x2)
		return
	end

	-- // reject empty lines used for triggers and special events.
	-- // identical floor and ceiling on both sides, identical
	-- // light levels on both sides, and no middle texture.
	if (back_sector.ceil_texture == front_sector.ceil_texture and
	back_sector.floor_texture == front_sector.floor_texture and
	back_sector.light_level == front_sector.light_level and
	self.seg.linedef.front_sidedef.middle_texture == '-') then
		return
	end

	-- // borders with different light levels and textures
	self:clip_portal_walls(x1, x2)
end

return function(...)
	return SegHandler:__init(...)
end
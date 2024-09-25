local utils = require("libs/utils")
local vec2 = require("libs/vec2")
local cfg = require("libs/settings")

local BSP = {}
BSP.__index = BSP

local SUB_SECTOR_IDENTIFIER = 0x8000 -- // 2^15 = 32768

function BSP.__init(self, engine)
	self.engine = engine
	self.player = engine.player
	self.nodes = engine.wad_data.nodes
	self.segs = engine.wad_data.segments
	self.sub_sectors = engine.wad_data.sub_sectors
	self.root_note_id = #(self.nodes) -- // no need to subtract 1 as # returns the highest index
	self.is_traverse_bsp = true

	return self
end

function BSP.update(self)
	self.is_traverse_bsp = true
	self:render_bsp_node(self.root_note_id)
end

function BSP.angle_to_x(angle)
	local x

	if angle > 0 then
		x = cfg.SCREEN_DIST - math.tan(math.rad(angle)) * cfg.H_WIDTH
	else
		x = -math.tan(math.rad(angle)) * cfg.H_WIDTH + cfg.SCREEN_DIST
	end

	return utils.int(x)
end

function BSP.add_segment_to_fov(self, vertex1, vertex2)
	local angle1 = self:point_to_angle(vertex1)
	local angle2 = self:point_to_angle(vertex2)

	local span = self.norm(angle1 - angle2)

	-- // backface culling
	if span >= 180.0 then
		return
	end

	-- // needed for further calculations
	local rw_angle1 = angle1

	angle1 = angle1 - self.player.angle
	angle2 = angle2 - self.player.angle

	local span1 = self.norm(angle1 + cfg.H_FOV)

	if span1 > cfg.FOV then
		if span1 >= span + cfg.FOV then
			return
		end

		-- // clipping
		angle1 = cfg.H_FOV
	end

	local span2 = self.norm(cfg.H_FOV - angle2)

	if span2 > cfg.FOV then
		if span2 >= span + cfg.FOV then
			return
		end

		-- // clipping
		angle2 = -(cfg.H_FOV)
	end

	local x1 = self.angle_to_x(angle1)
	local x2 = self.angle_to_x(angle2)

	return {x1, x2, rw_angle1}
end

function BSP.render_sub_sector(self, sub_sector_id)
	local sub_sector = self.sub_sectors[sub_sector_id]

	for i = 0, sub_sector.seg_count - 1 do
		local seg = self.segs[sub_sector.first_seg_id + i]
		local result = self:add_segment_to_fov(seg.start_vertex, seg.end_vertex)

		if result then
			self.engine.seg_handler:classify_segment(seg, unpack(result))
		end
	end
end

function BSP.norm(angle)
	return angle % 360
end

function BSP.get_sub_sector_height(self)
	local sub_sector_id = self.root_note_id

	while not (sub_sector_id >= SUB_SECTOR_IDENTIFIER) do
		local node = self.nodes[sub_sector_id]
		local is_on_back = self:is_on_back_side(node)

		if is_on_back then
			sub_sector_id = self.nodes[sub_sector_id].back_child_id
		else
			sub_sector_id = self.nodes[sub_sector_id].front_child_id
		end
	end

	local sub_sector = self.sub_sectors[sub_sector_id - SUB_SECTOR_IDENTIFIER]
	local seg = self.segs[sub_sector.first_seg_id]

	return seg.front_sector.floor_height
end

function BSP.check_bbox(self, bbox)
	local a, b = vec2(bbox.left, bbox.bottom), vec2(bbox.left, bbox.top)
	local c, d = vec2(bbox.right, bbox.top), vec2(bbox.right, bbox.bottom)

	local bbox_sides
	local ppos = self.player.pos
	local px, py = ppos.x, ppos.y

	if px < bbox.left then
		if py > bbox.top then
			bbox_sides = {{b, a}, {c, b}}
		elseif py < bbox.bottom then
			bbox_sides = {{b, a}, {a, d}}
		else
			bbox_sides = {{b, a}}
		end
	elseif px > bbox.right then
		if py > bbox.top then
			bbox_sides = {{c, b}, {d, c}}
		elseif py < bbox.bottom then
			bbox_sides = {{a, d}, {d, c}}
		else
			bbox_sides = {{d, c}}
		end
	else
		if py > bbox.top then
			bbox_sides = {{c, b}}
		elseif py < bbox.bottom then
			bbox_sides = {{a, d}}
		else
			return true
		end
	end

	for _, side in pairs(bbox_sides) do
		repeat
			local angle1 = self:point_to_angle(side[1])
			local angle2 = self:point_to_angle(side[2])
			local span = self.norm(angle1 - angle2)
			angle1 = angle1 - self.player.angle

			local span1 = self.norm(angle1 + cfg.H_FOV)
			if span1 > cfg.FOV then
				if span1 >= span + cfg.FOV then
					break
				end
			end

			return true
		until true
	end

	return false
end

function BSP.point_to_angle(self, vertex)
	local delta = vertex - self.player.pos
	return math.deg(math.atan2(delta.y, delta.x))
end

function BSP.render_bsp_node(self, node_id)
	if self.is_traverse_bsp then
		if node_id >= SUB_SECTOR_IDENTIFIER then
			local sub_sector_id = node_id - SUB_SECTOR_IDENTIFIER
			self:render_sub_sector(sub_sector_id)
			return
		end

		local node = self.nodes[node_id]
		local is_on_back = self:is_on_back_side(node)

		if is_on_back then
			self:render_bsp_node(node.back_child_id)

			if self:check_bbox(node.bbox.front) then
				self:render_bsp_node(node.front_child_id)
			end
		else
			self:render_bsp_node(node.front_child_id)

			if self:check_bbox(node.bbox.back) then
				self:render_bsp_node(node.back_child_id)
			end
		end
	end
end

function BSP.is_on_back_side(self, node)
	local dx = self.player.pos.x - node.x_partition
	local dy = self.player.pos.y - node.y_partition
	return dx * node.dy_partition - dy * node.dx_partition <= 0
end

return function(...)
	return BSP:__init(...)
end
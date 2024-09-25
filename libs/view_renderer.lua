local utils = require("libs/utils")
local cfg = require("libs/settings")

local ViewRenderer = {}
ViewRenderer.__index = ViewRenderer

function ViewRenderer.__init(self, engine)
	self.count = 0
	self.colors = {}
	self.engine = engine
	self.player = engine.player
	self.framebuffer = engine.framebuffer
	self.asset_data = engine.wad_data.asset_data
	self.x_to_angle = self.engine.seg_handler.x_to_angle

	self.palette = self.asset_data.palette
	self.sprites = self.asset_data.sprites
	self.textures = self.asset_data.textures

	-- // sky settings
	self.sky_id = self.asset_data.sky_id
	self.sky_tex = self.asset_data.sky_tex
	self.sky_inv_scale = 160 / cfg.HEIGHT
	self.sky_tex_alt = 100

	return self
end

function ViewRenderer.draw_framebuffer(self)
	for y = 0, #(self.framebuffer) do
		for x = 0, #(self.framebuffer[0]) do
			love.graphics.setColor(unpack(self.framebuffer[y][x]))
			love.graphics.points(x, y)
		end
	end
end

function ViewRenderer.draw_flat(self, tex_id, light_level, x, y1, y2, world_z)
	if y1 < y2 then
		if tex_id == self.sky_id then
			local tex_column = 2.2 * (self.player.angle + self.x_to_angle[x])
			self:draw_wall_col(self.sky_tex, tex_column, x, y1, y2, self.sky_tex_alt, self.sky_inv_scale, 255)
		else
			local flat_tex = self.textures[tex_id]
			self:draw_flat_col(flat_tex, x, y1, y2, light_level, world_z, self.player.angle, self.player.pos.x, self.player.pos.y)
		end
	end
end

function ViewRenderer.draw_flat_col(self, flat_tex, x, y1, y2, light_level, world_z, player_angle, player_x, player_y)
	light_level = light_level / 255

	local player_dir_x = math.cos(math.rad(player_angle))
	local player_dir_y = math.sin(math.rad(player_angle))

	for iy = y1, y2 do
		local z = cfg.H_WIDTH * world_z / (cfg.H_HEIGHT - iy)

		local px = player_dir_x * z + player_x
		local py = player_dir_y * z + player_y

		local left_x = -(player_dir_y) * z + px
		local left_y = player_dir_x * z + py
		local right_x = player_dir_y * z + px
		local right_y = -(player_dir_x) * z + py

		local dx = (right_x - left_x) / cfg.WIDTH
		local dy = (right_y - left_y) / cfg.WIDTH
		local tx = bit.band(utils.int(left_x + dx * x), 63)
		local ty = bit.band(utils.int(left_y + dy * x), 63)

		local col = flat_tex[ty][tx]
		col = {col[1] / 255 * light_level, col[2] / 255 * light_level, col[3] / 255 * light_level}
		self.count = self.count + 1
		self.framebuffer[iy][x] = col
	end
end

function ViewRenderer.draw_wall_col(self, tex, tex_col, x, y1, y2, tex_alt, inv_scale, light_level)
	light_level = light_level / 255

	if y1 < y2 then
		local tex_h, tex_w = #(tex) + 1, #(tex[0]) + 1
		local tex_col = math.floor(tex_col) % tex_w
		local tex_y = tex_alt + (y1 - cfg.H_HEIGHT) * inv_scale

		for iy = y1, y2 do
			local col = tex[math.floor((math.floor(tex_y) % tex_h) * cfg.SCALE)][math.floor(tex_col * cfg.SCALE)] or {0xFF, 0xFF, 0xFF}
			col = {col[1] / 255 * light_level, col[2] / 255 * light_level, col[3] / 255 * light_level}

			self.count = self.count + 1
			self.framebuffer[iy][x] = col

			tex_y = tex_y + inv_scale
		end
	end
end

return function(...)
	return ViewRenderer:__init(...)
end
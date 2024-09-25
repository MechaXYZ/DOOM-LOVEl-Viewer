local vec2 = require("libs/vec2")
local cfg = require("libs/settings")

local keydown = love.keyboard.isDown

local Player = {}
Player.__index = Player

local DIAG_MOVE_CORR = 1 / math.sqrt(2)


local function rotate(v, delta)
	delta = math.rad(delta)

	return vec2(
		v.x * math.cos(delta) - v.y * math.sin(delta),
		v.x * math.sin(delta) + v.y * math.cos(delta)
	)
end

function Player.__init(self, engine)
	self.engine = engine
	self.thing = engine.wad_data.things[0]

	self.pos = self.thing.pos
	self.angle = self.thing.angle
	self.height = cfg.PLAYER_HEIGHT

	return self
end

function Player.update(self)
	self:get_height()

	coroutine.wrap(function()
		self:control()
	end)()
end

function Player.get_height(self)
	self.height = self.engine.bsp:get_sub_sector_height() + cfg.PLAYER_HEIGHT
end

function Player.control(self)
	local speed = cfg.PLAYER_SPEED * self.engine.dt
	local rot_speed = cfg.PLAYER_ROT_SPEED * self.engine.dt

	if keydown("f") then
		self.angle = self.angle + rot_speed
	elseif keydown("g") then
		self.angle = self.angle - rot_speed
	end

	local inc = vec2.ZERO

	if keydown("w") then
		inc = inc + rotate(vec2(speed, 0), self.angle)
	end

	if keydown("s") then
		inc = inc + rotate(vec2(-(speed), 0), self.angle)
	end

	if keydown("a") then
		inc = inc + rotate(vec2(0, speed), self.angle)
	end

	if keydown("d") then
		inc = inc + rotate(vec2(0, -(speed)), self.angle)
	end

	if math.abs(inc.x) > 10 and math.abs(inc.y) > 10 then
		inc = inc * DIAG_MOVE_CORR
	end

	self.pos = self.pos + inc
end

return function(...)
	return Player:__init(...)
end
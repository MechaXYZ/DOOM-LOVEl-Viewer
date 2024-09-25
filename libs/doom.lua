local BSP = require("libs/bsp")
local utils = require("libs/utils")
local Player = require("libs/player")
local WadData = require("libs/wad_data")
local SegHandler = require("libs/seg_handler")
local ViewRenderer = require("libs/view_renderer")

local DoomEngine = {}
DoomEngine.__index = DoomEngine

function DoomEngine.__init(self, wad_path, map)
	self.wad_path = wad_path
	self.map = map

	self.framebuffer = utils.create2d(love.graphics.getWidth(), love.graphics.getHeight())
	self.running = true
	self.dt = (1 / 60)
	self:__on_init()

	return self
end

function DoomEngine.__on_init(self)
	self.wad_data = WadData(self)
	self.player = Player(self)
	self.bsp = BSP(self)
	self.seg_handler = SegHandler(self)
	self.view_renderer = ViewRenderer(self)
end

function DoomEngine.update(self, dt)
	self.player:update()
	self.seg_handler:update()
	self.bsp:update()

	self.dt = dt
end

function DoomEngine.draw(self)
	self.view_renderer:draw_framebuffer()

	love.graphics.setColor(0, 1, 0)
	love.graphics.print(tostring(love.timer.getFPS()), 10, 10)
end

function DoomEngine.run(self)
	function love.draw()
		self:update(love.timer.getDelta())
		self:draw()
	end
end

return function(...)
	return DoomEngine:__init(...)
end
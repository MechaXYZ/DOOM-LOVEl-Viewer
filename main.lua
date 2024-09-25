local cfg = require("libs/settings")
love.window.setMode(cfg.WIDTH, cfg.HEIGHT)

local doom = require("libs/doom")("assets/DOOM.WAD", "E1M1")
doom:run()
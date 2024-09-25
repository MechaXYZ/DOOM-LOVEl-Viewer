local scl = 2
local dw = 320
local dh = 240

local w = math.floor(dw * scl)
local h = math.floor(dh * scl)
local hw = math.floor(w / 2)
local hh = math.floor(h / 2)

local fov = 90
local hfov = fov / 2

local ps = 320
local prs = 120
local sd = hw / math.tan(math.rad(hfov))

local ph = 41

return {
	FOV = fov,
	WIDTH = w,
	HEIGHT = h,
	DOOM_W = dw,
	DOOM_H = dh,
	SCALE = scl,
	H_FOV = hfov,
	H_WIDTH = hw,
	H_HEIGHT = hh,
	SCREEN_DIST = sd,
	PLAYER_SPEED = ps,
	PLAYER_HEIGHT = ph,
	PLAYER_ROT_SPEED = prs
}
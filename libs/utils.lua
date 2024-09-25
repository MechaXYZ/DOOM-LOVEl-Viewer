local utils = {}
utils.__index = utils

function deepcopy(orig)
	local orig_type = type(orig)
	local copy

	if orig_type == 'table' then
		copy = {}

		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end

		-- // setmetatable(copy, deepcopy(getmetatable(orig)))
	else
		copy = orig
	end

	return copy
end

function utils.zip(...)
	assert(select("#", ...) > 0, "Must supply at least 1 table")

	local function ZipIteratorArray(all, k)
		k = k + 1

		local values = {}

		for i, t in pairs(all) do
			local v = t[k]
			if v ~= nil then
				values[i] = v
			else
				return nil, nil
			end
		end

		return k, values
	end

	local function ZipIteratorMap(all, k)
		local values = {}

		for i, t in pairs(all) do
			local v = next(t, k)

			if v ~= nil then
				values[i] = v
			else
				return nil, nil
			end
		end

		return k, values
	end

	local all = {...}

	if #(all[1]) > 0 then
		return ZipIteratorArray, all, 0
	else
		return ZipIteratorMap, all, nil
	end
end

function utils.slice(tbl, first, last, step)
	if last then
		last = last - 1
	end

	local sliced = {}

	for i = first or 1, last or #(tbl), step or 1 do
		sliced[i] = tbl[i]
	end

	return sliced
end

function utils.dist(p, q)
	if tonumber(p) and tonumber(q) then
		return math.abs(q - p)
	end

	local sum = 0

	for _, c in utils.zip(p, q) do
		sum = sum + (c[1] - c[2]) ^ 2
	end

	return math.sqrt(sum)
end

function utils.find(haystack, needle)
	for i, v in pairs(haystack) do
		if v == needle then
			return i
		end
	end
end

function utils.int(x)
	if x >= 0 then
		return math.floor(x)
	else
		return -(math.floor(math.abs(x)))
	end
end

function utils.create2d(w, h)
	local arr = {}

	for y = 0, h - 1 do
		arr[y] = {}

		for x = 0, w - 1 do
			arr[y][x] = {0xFF, 0xFF, 0xFF}
		end
	end

	return arr
end

function utils.isclose(a, b, rel_tol, abs_tol)
	abs_tol = abs_tol or 0
	rel_tol = rel_tol or 1e-9
	assert(abs_tol >= 0, "abs_tol must be at least zero")
	assert(rel_tol > 0, "rel_tol must be greater than zero")

	return math.abs(a - b) <= math.max(rel_tol * math.max(math.abs(a), math.abs(b)), abs_tol)
end

function utils.len(tbl)
	local i = 0

	for _ in pairs(tbl) do
		i = i + 1
	end

	return i
end

utils.copy = deepcopy

return utils
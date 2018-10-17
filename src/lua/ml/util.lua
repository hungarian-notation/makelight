
local function lerp(x, a, b)
	return a * (1-x) + b * (x)
end

local function clamp(_1, _2, _3, _4)
	if type(_3) == 'number' then
		local result = _1

		if _1 <= _2 then
			result = _2
		elseif _1 >= _3 then
			result = _3
		end

		if type(_4) == 'function' then
			return assert(_4(result))
		else
			return assert(result)
		end
	else
		if type(_3) == 'function' then
			return function(_x)
				return clamp(_x, _1, _2, _3)
			end
		else
			return function(_x, _y)
				return clamp(_x, _1, _2, _y or nil)
			end
		end
	end
end

return {
	clamp 	= clamp;
	lerp	= lerp;
}

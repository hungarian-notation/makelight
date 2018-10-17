local pl_class 	= require "pl.class"
local ml 		= require "ml"
local 	lerp	= ml.util.lerp
local 	clamp	= ml.util.clamp

local Color = pl_class()
do
	local clamp_byte 	= clamp( 0x00, 0xff, math.floor )
	local clamp_channel	= clamp( 0.0, 1.0 )

	function Color:_init(...)
		local args = {...}

		if #args == 1 and Color:class_of(args[1]) then
			local 	other = args[1]
			self._r, self._g, self._b = other._r, other._g, other._b
		elseif #args == 3 then
			self._r = clamp_channel(args[1])
			self._g = clamp_channel(args[2])
			self._b = clamp_channel(args[3])
		else
			error(string.format("expected 3 arguments. (got %d)", #args))
		end
	end

	function Color:clone()
		return Color(self)
	end

	function Color:bytes()
		return 	clamp_byte(self._r * 0xFF),
				clamp_byte(self._g * 0xFF),
				clamp_byte(self._b * 0xFF)
	end

	function Color:r() return self._r end
	function Color:g() return self._g end
	function Color:b() return self._b end

	function Color.__add(lh, rh)
		assert(type(lh) == 'table', "expected Color as left hand argument")
		assert(type(rh) == 'table', "expected Color as right hand argument")
		return Color(lh._r + rh._r, lh._g + rh._g, lh._b + rh._b)
	end

	function Color.__sub(lh, rh)
		assert(type(lh) == 'table', "expected Color as left hand argument")
		assert(type(rh) == 'table', "expected Color as right hand argument")
		return Color(lh._r - rh._r, lh._g - rh._g, lh._b - rh._b)
	end

	function Color.__mul(lh, rh)
		assert(type(lh) == 'table', "expected Color as left hand argument")
		assert(type(rh) == 'number', "expected number as right hand argument")
		return Color(lh._r * rh, lh._g * rh, lh._b * rh)
	end

	function Color.__div(lh, rh)
		assert(type(lh) == 'table', "expected Color as left hand argument")
		assert(type(rh) == 'number', "expected number as right hand argument")
		return Color(lh._r / rh, lh._g / rh, lh._b / rh)
	end

	function Color:__tostring()
		return string.format("Color[%.3f, %.3f, %.3f]", self._r, self._g, self._b)
	end

	function Color.__eq(lh, rh)
		if Color:class_of(lh) and Color:class_of(rh) then
			return lh:r() == rh:r() and lh:g() == rh:g() and lh:b() == rh:b()
		else
			return false
		end
	end
end

local function hsv_to_rgb(h, s, v)
	local HUE_DOMAIN = 360
	local HUE_BUCKET = HUE_DOMAIN / 6

	local c, x, m

	while h < 0 do
		h = h + HUE_DOMAIN
	end

	while h > HUE_DOMAIN do
		h = h - HUE_DOMAIN
	end

	c = v * s
	x = c * (1 - math.abs(((h / HUE_BUCKET) % 2) - 1))
	m = v - c

	local r, g, b

	if 		h < 1 * HUE_BUCKET then
		r, g, b = c, x, 0;
	elseif 	h < 2 * HUE_BUCKET then
		r, g, b = x, c, 0;
	elseif 	h < 3 * HUE_BUCKET then
		r, g, b = 0, c, x;
	elseif 	h < 4 * HUE_BUCKET then
		r, g, b = 0, x, c;
	elseif 	h < 5 * HUE_BUCKET then
		r, g, b = x, 0, c;
	elseif 	h < 6 * HUE_BUCKET then
		r, g, b = c, 0, x;
	end

	return r + m, g + m, b + m;
end

local function HSV(h, s, v)
	return Color(hsv_to_rgb(h, s, v))
end

local function RGB(_1, _2, _3)
	return Color(_1 / 255.0, _2 / 255.0, _3 / 255.0)
end

local Curve = pl_class()
do
	function Curve:_init(...)
		self._points = {
			{
				x 		= 0;
				color 	= nil;
			}
		}

		local args = {...}

		if #args == 1 and type(args[1]) == 'table' then
			args = args[1]
		end

		for i = 1, #args, 2 do
			self:add(args[i], args[i+1])
		end
	end

	function Curve:search(x)
		local pts = self._points

		local lower, upper

		for i = 1, #pts do
			local p = pts[i]

			if p.x <= x then
				lower = i
			end

			if (not upper) and (p.x >= x) then
				upper = i
				break
			end
		end

		return lower, upper
	end

	function Curve:add(x, color)
		local pts 	= self._points

		local point = {
			x 		= x;
			color	= color;
		}

		local lower, upper = self:search(x)

		if lower == nil and upper == nil then
			assert(#pts == 0, 				"lower == nil and upper == nil implies #pts == 0")
			pts[1] = point
		elseif lower == upper then
			assert(pts[lower].x == x, 		"lower == upper implies pts[lower].x == x")
			pts[lower] = point
		elseif lower == nil then
			assert(upper == 1, 				"lower == nil implies upper == 1")
			table.insert(pts, 1, point)
		elseif upper == nil then
			assert(lower == #pts, 			"upper == nil implies lower == #pts")
			table.insert(pts, point)
		else
			assert(lower == upper - 1, 		"(upper ~= lower and upper ~= nil and lower ~= nil) implies (lower == upper - 1)")
			table.insert(pts, upper, point)
		end

		return self
	end

	function Curve:color(i, _lead)
		local pts 	= self._points

		if #pts <= 0 then
			return _lead or Color(0,0,0)
		elseif i <= 1 then
			return pts[1].color or _lead or Color(0,0,0)
		else
			return pts[i].color
		end
	end

	function Curve:size()
		return #self._points
	end

	function Curve:sample(x, _lead)
		local p = self._points

		if #p <= 1 then
			return self:color(1, _lead)
		else
			local lower, upper = self:search(x)

			if not lower then
				return self:color(upper, _lead)
			elseif not upper then
				return self:color(lower, _lead)
			elseif lower == upper then
				return self:color(lower, _lead)
			else
				local a, b 		= p[lower], p[upper]
				local a_c, b_c 	= self:color(lower, _lead), self:color(upper, _lead)
				local range 	= b.x - a.x
				local progress 	= x - a.x
				local factor 	= clamp( progress / range, 0.0, 1.0 )
				return (a_c * (1 - factor) + b_c * (factor))
			end
		end
	end
end

return {
	Color	= Color;
	Curve 	= Curve;
	RGB		= RGB;
	HSV		= HSV;
}

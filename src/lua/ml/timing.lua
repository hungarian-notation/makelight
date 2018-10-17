local pl_class = require "pl.class"

local ml = require "ml"

local 	TICKS_PER_BEAT		= ml.common.TICKS_PER_BEAT
local 	TICKS_PER_MEASURE	= ml.common.TICKS_PER_MEASURE

local 	Color 				= ml.color.Color
local 	Curve 				= ml.color.Curve
local 	RGB 				= ml.color.RGB
local 	HSV 				= ml.color.HSV

local 	Channel				= ml.channels.Channel
local 	Automation			= ml.channels.Automation
local	Event				= ml.channels.Event

local	Sequence			= ml.sequence.Sequence
local 	Section				= ml.sequence.Section

local 	Duration

do 	Duration = pl_class()
	function Duration:_init(_1, _2)
		if _2 then
			self._ticks = (_1 / _2) * TICKS_PER_MEASURE
		else
			self._ticks = _1 * TICKS_PER_MEASURE
		end
	end

	function Duration:ticks()
		return self._ticks
	end
end


return {
	Cursor = Cursor;
	Duration = Duration;
}

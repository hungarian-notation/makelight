local pl_class = require "pl.class"

local ml 					= require "ml"

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
local	Duration			= ml.timing.Duration
local 	query_channel		= ml.sequence.query_channel

local 	Cursor, Selection, Overlay

do 	Cursor = pl_class()

	local STATIC_FUNCTIONS = {}

	local PROXY_FUNCTIONS = {
		tick_period 	= 'tick_period';
		beat_period		= 'beat_period';
		section_name 	= 'name';
		section_time	= 'time';
		section_index	= "section_index";
		section_count	= "section_count";
		sequence		= "sequence";
		channels		= "channels";
		select_channels	= "channels";
	}

	for name, proxied in pairs(PROXY_FUNCTIONS) do
		assert(type(Section[proxied]) == 'function')

		Cursor[name] = function (cursor, ...)
			return Section[proxied](cursor:section(), ...)
		end
	end

	function Cursor:_init(_1, _2)
		if Cursor:class_of(_1) then
			self._section 	= _1._section
			self._frame		= _1._frame
		elseif Section:class_of(_1) then
			assert(type(_2) == 'number',
				"expect numeric frame index as second argument")
			self._section 	= _1
			self._frame		= assert(_2)
		else
			error("expect Cursor(Cursor) or Cursor(Section, number)")
		end
	end

	function Cursor:clone()
		return Cursor(self)
	end

	function Cursor:section()
		return self._section
	end

	function Cursor:frame()
		return self._frame
	end

	Cursor.local_frame = Cursor.frame

	function Cursor:local_time()
		return self:tick_period() * self:frame()
	end

	function Cursor:global_time()
		return self:section():time() + self:local_time()
	end

	function Cursor:set_frame(new_frame)
		self._frame = new_frame
	end

	function Cursor:animate(selection, curve, ...)
		local ticks = self:resolve_ticks(...)

		local start		= self:global_time()
		self:step(ticks)
		local stop		= self:global_time()

		for i, channel in ipairs(self:sequence():channels()) do
			local modifiers = selection:modifiers(channel)

			if not modifiers.exclude then

				local duration			= (stop - start)
				local modified_duration = duration * (modifiers.scale or 1);
				local freedom			= duration - modified_duration;
				local modified_start 	= start + freedom * (modifiers.offset or 0);

				local event 	= Automation {
					start 		= modified_start;
					duration	= modified_duration;
					curve		= curve;
				}

				channel:add_event(event)
			end
		end
	end

	function Cursor:resolve_ticks(_1, _2)
		if _2 then
			return self:resolve_ticks(Duration(_1, _2))
		end

		if type(_1) == 'number' then
			return _1
		elseif type(_1) == 'table' then
			if type(_1.ticks) then
				local ticks = type(_1.ticks) == 'number' and _1.ticks or _1:ticks()

				if ticks then
					return ticks
				end
			end

			if type(_1.time) then
				local time = type(_1.time) == 'number' and _1.time or _1:time()
				if time then
					return time / self:tick_period()
				end
			end
		end

		error("could not resolve ticks for arguments")
	end

	function Cursor:step(...)
		self:set_frame(self:frame() + self:resolve_ticks(...))
	end

	function Cursor:setfenv(f)
		local cursor = self

		local function env_index(env, key)
			if type(cursor[key]) == 'function' and not STATIC_FUNCTIONS[key] then
				return function(...)
					cursor[key](cursor, ...)
				end
			else
				return _G[key]
			end
		end

		local env 	= setmetatable({

			cursor		= cursor;
			section		= cursor:section();
			sequence	= cursor:section():sequence();
			duration	= function(...) return Duration(...) end;

		},{ __index = env_index })

		for k, v in pairs(Cursor) do
			if type(v) == 'function' then
				if STATIC_FUNCTIONS[k] then
					env[k] = v
				else
					env[k] = function(...)
						return cursor[k](cursor, ...)
					end
				end
			end
		end

		setfenv(f, env)
	end

	function Cursor:fork(_1)
		local forked = self:clone()
		forked:invoke(_1)
	end

	function Cursor:invoke(_1)
		if type(_1) == 'table' then
			for i, arg in ipairs(_1) do
				self:invoke(arg)
			end
		elseif type(_1) == 'function' then
			self:setfenv(_1)
			_1()
		else
			error("expect function or table of functions")
		end
	end

	function Cursor:env()
		return {
			cursor = self;
			section = self:section();
			sequence = self:sequence();
		}
	end
end

local MODIFIERS = {

	-- Excludes any matching channels from the effect.
	['exclude'] 	= 'boolean';

	-- Modifies the window over which the animation will be applied to
	-- matching channels.
	--
	-- Scale is applied so that the starting time remains fixed. The start time
	-- can be moved with the `offset' modifier.
	['scale'] 		= 'number';

	-- Moves the start time of the effect. The offset is not affected by scale.
	['offset'] 		= 'number';

	['match']		= 'table';

}

local function valid_modifier(v, vt)
	for m, t in pairs(MODIFIERS) do
		if v == m then
			if vt then
				return t == vt
			else
				return true
			end
		end
	end
end

do Selection = pl_class()

	function Selection:_init(query)
		self._sequence 	= sequence
		self._query 	= query
	end

	function Selection:modifiers(channel)
		return query_channel(self._query, channel) and {} or { exclude = true }
	end

	function Selection:__call(overlay)
		return Overlay(self, overlay)
	end

end

do Overlay = pl_class()

	function Overlay:_init(base, modifier)
		self._base 		= base

		local actual = {}

		for k, v in pairs(modifier) do

			if type(k) == 'number' then
				if valid_modifier(v, 'boolean') then
					actual[v] = true
				else
					error("unknown modifier: " .. tostring(v))
				end
			else
				if valid_modifier(k) then
					if not valid_modifier(k, type(v)) then
						error(string.format("modifier %s must have type %s", k, MODIFIERS[k]))
					end

					actual[k] = v
				else
					error(string.format("invalid modifier: %s", k))
				end
			end

		end

		self._modifier = actual
	end

	function Overlay:base()
		return self._base
	end

	function Overlay:modifiers(channel)
		local mods 			= self:base():modifiers(channel)
		local modifier		= self._modifier

		if (not modifier.match) or query_channel(modifier.match, channel) then
			for k, v in pairs(modifier) do
				if k ~= 'match' then
					mods[k] = v
				end
			end
		end

		return mods
	end

	Overlay.__call = Selection.__call
end

return {
	Cursor 		= Cursor;
	Selection	= Selection;
	Overlay		= Overlay;
}

local pl_class = require "pl.class"

local ml_color				= require "ml.color"
local 	Color 				= ml_color.Color
local 	Curve 				= ml_color.Curve
local 	RGB 				= ml_color.RGB
local 	HSV 				= ml_color.HSV

local ml_common 			= require "ml.common"
local 	TICKS_PER_BEAT		= ml_common.TICKS_PER_BEAT
local 	TICKS_PER_MEASURE	= ml_common.TICKS_PER_MEASURE
local 	UPDATE_RATE			= ml_common.UPDATE_RATE

local ml_channels 			= require "ml.channels"
local 	Channel				= ml_channels.Channel
local 	Automation			= ml_channels.Automation
local	Event				= ml_channels.Event

local 	Sequence,
		Section

local function query_channel(query, channel)
	if type(query) == 'table' then
		local mode = query.mode or 'any'

		for i, criteria in ipairs(query) do
			if query_channel(criteria, channel) then
				if mode == 'any' then
					return true
				elseif mode == 'none' then
					return false
				end
			else
				if mode == 'all' then
					return false
				end
			end
		end

		if mode == 'all' or mode == 'none' then
			return true
		else
			return false
		end
	elseif type(query) == 'string' then
		return channel:name() == query
	elseif type(query) == 'number' then
		return channel:index() == query
	end
end

do	Sequence = pl_class()

	function Sequence:_init(args)
		self._name 			= args.name
		self._media			= args.media
		self._sections 		= {}
		self._section_map	= {}
		self._channels 		= {}

		local ch_arg 		= assert(args.channels, "missing channels field")
		local ch_count 		= 0
		local ch_names 		= {}

		if type(ch_arg) == 'table' then
			ch_count = ch_arg.count or #ch_arg

			for channel, name in pairs(ch_arg) do
				if ch_count < channel then
					ch_count = channel
				end

				if type(name) == 'string' then
					ch_names[channel] = name
				end
			end
		elseif type(ch_arg) == 'number' then
			ch_count = ch_arg
		else
			error("expected channels field to be table or number")
		end

		local ch_array = self._channels

		for i = 1, ch_count do
			local ch = Channel {
				index	= i;
				name 	= ch_names[i];
			}

			ch_array[i] = ch;
		end
	end

	function Sequence:name()
		return self._name
	end

	function Sequence:media()
		return self._media
	end

	function Sequence:section(_1, _2, _3)
		if type(_1) == 'table' and #_1 > 0 then
			_1, _2, _3 = _1[1], _1[2], _1[3]
		end

		local slist = self._sections
		local smap 	= self._section_map

		if _2 then
			local name, time, rate

			if type(_1) == 'string' then
				name, time, rate = _1, _2, _3
			elseif type(_1) == 'number' then
				name, time, rate = nil, _1, _2
			else
				error("unexpected type for first argument")
			end

			if #slist > 0 and time <= slist[#slist]:time() then
				error(string.format("section \"%s\" does not occur after previously defined section \"%s\"", name, slist[#slist]:name()))
			end

			if name and smap[name] then
				error(string.format("section \"%s\" already exists", name))
			end

			local section = Section {
				name 		= name;
				time 		= time;
				rate 		= rate;
				sequence	= self;
			}

			slist[#slist + 1] 		= section;
			smap[section:name()] 	= section;

			return section;
		else
			if type(_1) == 'number' then
				return slist[_1]
			else
				return smap[_1]
			end
		end
	end

	function Sequence:sections()
		return self._sections
	end

	function Sequence:channels(_1)
		local channels = self._channels

		if (type(_1) ~= 'nil') then
			local results = {}

			for i, channel in ipairs(channels) do
				if query_channel(_1, channel) then
					results[#results + 1] = channel
				end
			end

			return results
		else
			return channels
		end
	end

	function Sequence:index_of(section)
		for i, candidate in ipairs(self._sections) do
			if candidate == section then
				return i
			end
		end

		return nil
	end

	function Sequence:run_time()
		local last = 0

		for i, channel in ipairs(self:channels()) do
			local run = channel:run_time()
			if run > last then
				last = run
			end
		end

		return last
	end

	function Sequence:compile(writer)

		local total_ticks	= (self:run_time() + 1) * UPDATE_RATE
		local frames		= {}
		local channels		= self:channels()

		for i = 1, total_ticks do
			local time	= i / UPDATE_RATE
			local frame = {}
			for j = 1, #channels do
				frame[j] = channels[j]:sample(time)
			end
			frames[i] = frame;
		end

		local sections = {}

		for i, section in ipairs(self:sections()) do
			sections[i] = {
				name = section:name();
				time = section:time();
			}
		end

		local compiled = {
			name			= self:name();
			media 			= self:media();
			sections		= sections;

			frame_count		= total_ticks;
			frame_rate		= UPDATE_RATE;

			channel_data	= frames;
			channel_count	= #channels;
		}

		writer:write(compiled)
	end
end

do 	Section = pl_class()

	local lazily_cursor

	function ml_cursor()
		if not lazily_cursor then
			lazily_cursor = require('ml.cursor')
		end

		return lazily_cursor
	end

	local PROXY_FUNCTIONS = {
		section_index	= "index_of";
		section_count	= "sections";
		channels		= "channels";
		select_channels	= "channels";
	}

	for name, proxied in pairs(PROXY_FUNCTIONS) do
		assert(type(Sequence[proxied]) == 'function')

		Section[name] = function (section, ...)
			return Sequence[proxied](section:sequence(), ...)
		end
	end

	function Section:_init(args)
		self._time	= args.time		or error("missing required field: time")
		self._name	= args.name		or self:time_string()
		self._seq	= args.sequence or nil
		self._rate	= args.rate		or nil
	end

	function Section:time()
		return self._time
	end

	function Section:rate()
		return self._rate or assert(self:previous()):rate()
	end

	function Section:name()
		return self._name
	end

	function Section:beat_period()
		return 60 / self:rate()
	end

	function Section:tick_period()
		return self:beat_period() / TICKS_PER_BEAT
	end

	function Section:time_string()
		return string.format("T%.3f", self._time)
	end

	function Section:sequence()
		return assert(self._seq, "section has no sequence")
	end

	function Section:position()
		if not self._seq then
			error("can not retrieve position: section has no sequence")
		else
			local position = self._seq:index_of(self)

			if not position then
				error("section not present in sequence")
			end

			return position
		end
	end

	function Section:previous()
		local position = self:position()
		return self._seq:section(position - 1)
	end

	function Section:next()
		local position = self:position()
		return self._seq:section(position - 1)
	end

	function Section:cursor_at(frame)
		return ml_cursor().Cursor(self, frame)
	end

	function Section:__call(...)
		local cursor = self:cursor_at(0)
		cursor:fork(...)
	end
end

return {
	Sequence 			= Sequence;
	Section 			= Section;
	query_channel		= query_channel;
}

local pl_class 				= require "pl.class"
local ml 					= require "ml"

local 	Color 				= ml.color.Color
local 	Curve 				= ml.color.Curve
local 	RGB 				= ml.color.RGB
local 	HSV 				= ml.color.HSV
local 	TICKS_PER_BEAT		= ml.common.TICKS_PER_BEAT
local 	TICKS_PER_MEASURE	= ml.common.TICKS_PER_MEASURE

local Event, Automation, Channel

do Event = pl_class()
	function Event:_init(args)
		self._start 	= args.start
		self._stop		= args.stop 	or (args.start + args.duration)

		assert(type(self._start) == 'number')
		assert(type(self._stop) == 'number')
		assert(self._stop > self._start)
	end

	function Event:start_time()
		return self._start
	end

	function Event:stop_time()
		return self._stop
	end

	function Event:duration()
		return self:stop_time() - self:start_time()
	end

	function Event:event_type()
		return "generic-event"
	end

	function Event:__tostring()
		return string.format("%s[%.3f to %.3f]", self:event_type(), self:start_time(), self:stop_time())
	end
end

do Automation = pl_class(Event)
	function Automation:_init(args)
		self:super(args)
		self._curve = assert(Curve:class_of(args.curve) and args.curve)
	end

	function Automation:curve()
		return self._curve
	end

	function Automation:event_type()
		return "automation"
	end
end

do Channel = pl_class()

	function Channel:_init(args)
		self._index 		= assert(type(args.index) == 'number' and args.index)
		self._name			= args.name or string.format("channel_%d", self._index)
		self._events		= {}
	end

	function Channel:name()
		return self._name
	end

	function Channel:index()
		return self._index
	end

	function Channel:event_range(from, to)
		local results = {}

		for i, event in ipairs(self._events) do
			if event:stop_time() <= from or event:start_time() >= to then
				-- skip
			else
				results[#results + 1] = event
			end
		end

		return results
	end

	function Channel:add_event(event)
		local conflicts = self:event_range(event:start_time(), event:stop_time())

		if #conflicts > 0 then
			for i, conflict in ipairs(conflicts) do
				print("conflict: ")
				print("\t" .. tostring(event))
				print("\t" .. tostring(conflict))
			end

			error("one or more conflicts on channel " .. self:__tostring())
		else
			self._events[#self._events + 1] = event
			self:sort()
		end
	end

	function Channel:sort()
		table.sort(self._events, function(a, b) return a:start_time() < b:start_time() end)
	end

	function Channel:sample(time)
		local events = self._events

		local prior, active

		for i = 1, #events do
			local e = events[i]

			if e:stop_time() < time then
				prior = e
			elseif e:start_time() < time then
				active = e
				break
			else
				break
			end
		end

		local lead_in = Color(0,0,0)

		if prior then
			if Automation:class_of(prior) then
				lead_in = prior:curve():color(prior:curve():size())
			end
		end

		if active then
			if Automation:class_of(active) then
				local relative_time = time - active:start_time()
				local factor		= relative_time / active:duration()
				return active:curve():sample(factor, lead_in)
			else
				return lead_in
			end
		else
			return lead_in
		end
	end

	function Channel:run_time()
		self:sort()
		local last = self._events[#self._events]
		return last and last:stop_time() or 0
	end

	function Channel:__tostring()
		return self._name
	end
end

return {
	Event 			= Event;
	Automation 		= Automation;
	Channel 		= Channel;
}

local pl_class 	= require "pl.class"
local ml 		= require "ml"

local Writer = pl_class()
do
	function Writer:_init(fd)
		self._out = fd
	end

	function Writer:ls_line(format, ...)
		self._out:write(string.format(format .. "\n", ...))
	end

	function Writer:close()
		self._out:close()
	end

	function Writer:ls_comment(str)
		self:ls_line([[; %s]], str)
	end

	function Writer:ls_metadata(key, value)
		self:ls_line([[? "%s" "%s"]], key, value)
	end

	function Writer:ls_section(name, time)
		self:ls_line([[$ "%s" %f]], name, time)
	end

	function Writer:ls_media_directive(media)
		self:ls_line([[m "%s"]], media)
	end

	function Writer:ls_channels_directive(count)
		self:ls_line([[c %d]], count)
	end

	function Writer:ls_frame_directive(frame)
		self:ls_line([[f %d]], frame)
	end

	function Writer:ls_time_directive(time)
		self:ls_line([[t %f]], time)
	end

	function Writer:ls_rate_directive(rate)
		self:ls_line([[r %f]], rate)
	end

	function Writer:ls_key_directive(channel, color)
		local r, g, b = color:bytes()
		self:ls_line([[k %d %d %d %d]], channel - 1, r, g, b)
	end

	function Writer:write(compiled)
		self:ls_metadata('title', compiled.name)

		for i, section in ipairs(compiled.sections) do
			self:ls_section(section.name, section.time)
		end

		self:ls_media_directive(compiled.media)
		self:ls_channels_directive(compiled.channel_count)
		self:ls_frame_directive(1)
		self:ls_time_directive(0)
		self:ls_rate_directive(compiled.frame_rate)

		local last_data 	= {}
		local last_index 	= 1

		local function emit_key(index, channel, color)
			if index ~= last_index then
				self:ls_frame_directive(index)
				last_index = index
			end
			self:ls_key_directive(channel, color)
		end

		for i = 1, compiled.frame_count do

			for j = 1, compiled.channel_count do
				local color 		= ml.color.RGB(compiled.channel_data[i][j]:bytes())
				local last_color 	= last_data[j]

				if color ~= last_color then
					emit_key(i, j, color)
					last_data[j] = color
				end
			end
		end

		self:close()
	end
end

return function(params)
	local out = params.out

	if type(out) == 'string' then
		out = io.open(out, "w")
	end

	if io.type(out) ~= "file" then
		error("could not write to: ", params.out)
	end

	return Writer(out)
end

local ml = {}

local function ml_loader(_, key)
	local module = require("ml." .. tostring(key))
	ml[key] = module
	return module
end

local function ml_call(_, args)
	local sequence = ml.sequence.Sequence(args)

	local env = setmetatable({},{
		__index = function(env, k)
			--print('global: ', k)

			if sequence[k] then
				--print('sequence-global: ', k)
				if type(sequence[k] == 'function') then
					return function(...)
						return sequence[k](sequence, ...)
					end
				else
					return sequence[k]
				end
			end

			if _G[k] then
				return _G[k]
			end
		end
	})

	ml.install(env)

	function env.select(...)		return ml.cursor.Selection(...) end
	function env.define_curve(...) 	return ml.color.Curve(...) 		end

	function env.define_section(args)
		local name, time, rate = args.name, args.time, args.rate
		return sequence:section(name,time,rate)
	end

	setfenv(2, env)

	return sequence
end

setmetatable( ml, { __index = ml_loader, __call = ml_call } )


local _all = {
	'channels',
	'color',
	'common',
	'cursor',
	'sequence',
	'timing',
	'util'
}

function ml.install(dest)
	dest = dest or _G

	dest['ml'] = ml;

	for i, name in ipairs(_all) do
		local module = ml[name];
		for k, v in pairs(module) do
			if not dest[k] then
				dest[k] = v
				--print("installed: ", k, "from:", name)
			else
				print("conflict: already exists:", k, "from:", name)
			end
		end
	end
end

return ml

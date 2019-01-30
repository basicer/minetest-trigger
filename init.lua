local storage = {}
if minetest then
	storage = minetest.get_mod_storage()
end

local modules = {
	minetest=minetest, io=io, vector=vector, storage=storage,
	VoxelArea=VoxelArea, ItemStack=ItemStack,
	http = minetest.request_http_api()
}
local PATH = minetest and minetest.get_modpath("trigger") or '.'

local function ldump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. tostring(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

--
-- Minetest doesnt let us actually require stuff, so set up
-- a quick and dirty common.js knockoff.
--
local police = {
	__newindex = function(s, idx, v)
		print("Module " .. s.NAME .. " wrote global variable " .. idx .. " is this a mistake?")
		rawset(s, id, v)
	end
}
local function _require(mod)
	if mod == 'worldedit' then return worldedit end
	if not modules[mod] then
		local module = {exports={}}
		modules[mod] = module.exports

		if mod:sub(1,4) == "mod/" then
			local fetched = rawget(_G, mod:sub(5))
			if fetched then modules[mod] = fetched end
			return fetched
		end

		local modulefx, msg = loadfile(PATH .. '/' .. mod .. '.lua')
		if not modulefx then
			error("Couldn't load " .. mod .. ":\n" .. msg)
			modules[mod] = {}
			return
		end

		local env = {
			require = _require,
			dump = dump or ldump,
			dump2 = dump2 or ldump,
			print = print,
			module = module,
			exports = module.exports,
			assert = assert,
			NAME = mod,
			type = type,
			pairs = pairs,
			ipairs = ipairs,
			table = table,
			select = select,
			string = string,
			error = error,
			tonumber = tonumber,
			tostring = tostring,
			setmetatable = setmetatable,
			getmetatable = getmetatable,
			unpack = unpack,
			pcall = pcall,
			next = next,
			loadstring = loadstring,
			setfenv = setfenv,
			getfenv = getfenv,
			coroutine = coroutine,
			math = math,
			_GLOBAL = _G,
			[mod] = module.exports -- Lua 5.3 style, ish?
		}
		env._ENV = env
		setmetatable(env, police)
		setfenv(modulefx, env)
		local success, msg = pcall(modulefx)
		if not success then
			error("Couldn't execute " .. mod .. ":\n" .. msg)
			modules[mod] = {}
			return
		else
			if msg then
				modules[mod] = msg
			else
				modules[mod] = env[mod]
			end
		end
	end

	return modules[mod]

end

math.randomseed(os.time())

trigger = _require('trigger') -- Export to other mods

return _require
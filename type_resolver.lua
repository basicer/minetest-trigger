local triggers_by_id = require('registry').triggers_by_id
local triggers_by_name = require('registry').triggers_by_name
local minetest = require('minetest')
local vector = require('vector')
local util = require('util')



local function parsePosition(str, actor)
	if str == "nil" then return nil end
	local rel, x, y, z = str:match("([~&]?)(-?%d+),(-?%d+),(-?%d+)")
	local vec = {x=0, y=0, z=0}
	if rel ~= nil then
		vec = {x=tonumber(x),y=tonumber(y),z=tonumber(z)}
	end
	if rel == "~" or str == "~" or rel == "&" or str == "&" then
		if actor.getpos then
			vec = vector.add(vector.round(actor:getpos()), vec)
		end
	end
	return vec
end

local function parseTriggerSpec(str, actor)
	local num = tonumber(str)
	local nn = util.normalize(str)
	if str:sub(1,1) == ":" then
		local result = {}
		for k,v in pairs(triggers_by_id) do
			if v:in_group(str:sub(2)) then
				table.insert(result, v)
			end
		end
		return result
	end
	if str:sub(1,1) == "~" or str:sub(1,1) == "`" then
		local result = {}
		for k,v in pairs(triggers_by_name) do
			if k:match(str:sub(2)) then
				table.insert(result, v)
			end
		end
		return result
	end

	local a, b = str:match("^(%d%d-)%-(%d%d-)$")
	if a then
		local result = {}
		for i = tonumber(a),tonumber(b),1 do
			table.insert(result, triggers_by_id[i])
		end
		return result
	end

	if type(num) ~= "nil" then
		return {triggers_by_id[num]}
	end
	if triggers_by_name[nn] then return {triggers_by_name[nn]} end
	error("No triggers found matching '" .. str .. "'.", 0)
end

function type_resolver(value, target, actor, env)
	if target == 'Position' then target = 'Vec3' end
	if target == "Boolean" then return not not value end
	if type(value) == 'string' then
		if target == 'String' then return value end
		if target == 'TriggerSpec' then return parseTriggerSpec(value, actor) end
		if target == 'Vec3' then return parsePosition(value, actor) end
		if target == 'Float' then return tonumber(value) end
		if target == 'Int' then return math.floor(tonumber(value)) end
		if target == 'Table' then return minetest.parse_json(value) end
		if target == 'Player' then return minetest.get_player_by_name(value) end
		if target == "Bounds" then
			if value == 'nil' then return nil end
			local parts = util.split(value)
			return {parsePosition(parts[1]), parsePosition(parts[2])}
		end
	elseif type(value) == 'table' then
        if target == 'Table' then return value end
		if util.is_trigger(value) then
			if ( target == "Bounds" ) then return value:get_bounds() end
			if ( target == "Vec3" ) then return value:get_position() end
			if ( target == "TriggerSpec" ) then return {value} end
			if ( target == "Trigger" ) then return value end
		end
		if util.is_vec3(value) then
			if target == 'Vec3' then return value end
			if target == 'String' then
				return table.concat({value.x,value.y,value.z}, ',')
			end
		end
		if target == "Bounds" and #value == 2 and util.is_vec3(value[1]) and util.is_vec3(value[2]) then
			return value
		end
		if target == 'String' then
			return minetest.write_json(value, true)
		end
	elseif type(value) == 'number' then
		if target == 'Float' then return value end
		if target == 'Int' then return math.floor(value) end
		if target == 'String' then return tostring(value) end
	elseif type(value) == 'userdata' then
		-- Not sure what to do about this.
		if target == "Player" then return value end
		if target == "Vec3" then return value:getpos() end
		if target == "String" then return value:get_player_name() end
	elseif type(value) == 'nil' then
		return nil
	elseif type(value) == 'boolean' then
		if target == "String" then return value and "true" or "false" end
	end

	error('Could not cast ' .. type(value) .. ': ' .. tostring(value) .. ' to ' .. target)
end
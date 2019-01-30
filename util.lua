local triggers_by_name = require('registry').triggers_by_name
local minetest = require('minetest')
local vector = require('vector')

function util.normalize(str)
	return string.gsub(string.lower(str), ' ', '')
end

function util.split(str)
	local out = {}
	for part in string.gmatch(example, "%S+") do
		table.insert(out, part)
	end
	return out
end

-- http://lua-users.org/wiki/CopyTable
function util.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[util.deepcopy(orig_key)] = util.deepcopy(orig_value)
        end
        setmetatable(copy, util.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function util.showSpecThing(s)
	local out = {}
	for k,v in pairs(s) do
		if k == "type" then

		else
			out[#out+1] = k .. "=" .. util.stringify(v)
		end
	end
	return minetest.colorize('green',s.type) .. " " .. table.concat(out," ")
end

function util.eval_param(value, target, actor, env)
	local type_resolver = require('type_resolver')
	if type(value) == 'string' and value:sub(0,1) == '$' then
		value = env[value:sub(2)]
	end
	if type(value) == 'string' and value:sub(0,1) == '@' then
		local trigger = triggers_by_name[util.normalize(value:sub(2))]
		--print("Lookup" .. value:sub(2))
		return type_resolver(trigger, target, actor)
	end
	return type_resolver(value, target, actor)
end

function util.between(t, a, b)
	if a > b then
		return t <= a and t >= b
	else
		return t >= a and t <= b
	end

end

function util.block_between(t, a, b)
	if a > b then
		return t <= (a+0.5) and t >= (b-0.5)
	else
		return t >= (a-0.5) and t <= (b+0.5)
	end

end

function util.inside_bounds(t, b1, b2)
	if not util.between(t.x, b1.x, b2.x) then return false end
	if not util.between(t.y, b1.y, b2.y) then return false end
	if not util.between(t.z, b1.z, b2.z) then return false end
	return true
end

function util.inside_bounds_block(t, b1, b2)
	if not util.block_between(t.x, b1.x, b2.x) then return false end
	if not util.block_between(t.y, b1.y, b2.y) then return false end
	if not util.block_between(t.z, b1.z, b2.z) then return false end
	return true
end

function util.is_vec3(value)
	if type(value) ~= "table" then return false end
	return type(value.x) == 'number' and type(value.y) == 'number' and type(value.z) == 'number'
end

function util.is_trigger(value)
	local mt = getmetatable(value)
	if not mt then return false end
	return mt.type == "Trigger"
end

function util.index_table(table, key)
	local out = table
	for k in string.gmatch(key, "[^.]+") do
		out = out[k]
	end
	return out
end

function util.template_string(str, env, color)
	str = str:gsub('$(%b{})', function(e) return util.stringify(util.index_table(env,e:sub(2,-2)), color) end)
	str = str:gsub('$(%b())', function(e) return util.stringify(util.index_table(env,e:sub(2,-2)), color) end)
	return str
end

function util.stringify(v, color)
	local c = color and minetest.colorize or function(c,v) return v end
	if type(v) == "nil" then return c('red', "nil")
	elseif type(v) == "number" or type(v) == "boolean" then
		return tostring(v)
	elseif type(v) == "string" then return '"' .. v .. '"'
	elseif util.is_vec3(v)  then
		return '(' .. v.x .. ',' .. v.y .. ',' .. v.z .. ')'
	elseif type(v) == "userdata" and v.get_player_name then
		return v:get_player_name()
	elseif #v == 2 and util.is_vec3(v[1]) and util.is_vec3(v[2]) then
		return util.stringify(v[1], color) .. ' - ' .. util.stringify(v[2], color)
	else
		return minetest.write_json(v):gsub("\n", "")
	end

end

function util.values(tab)
    local lst = {}
    for k,v in pairs(tab) do
        table.insert(lst, v)
    end
    return lst
end

function util.get_players_in_bounds(bounds)
	if bound == nil then return minetest.get_connected_players() end
    local center = vector.get_center(unpack(bounds)) 
    local biggestdiff = math.max(unpack(util.values(vector.abs(vector.subtract(bounds[2], bounds[1])))))
    local all_objects = minetest.get_objects_inside_radius(center, biggestdiff)
    local players = {}
    local _,obj
    for _,obj in ipairs(all_objects) do
        if obj:is_player() then
            table.insert(players, obj)
        end
    end
    return players
end

function util.xmatch(str, match)
	for s in string.gmatch(match, "%S+") do
		local escaped = s:gsub("([^%w])", "%%%1"):gsub("%%%*",".-")
		if string.match(str, "^" .. escaped .."$" ) then return true end
	end
	return false
end

function util.uuid4()
    local _y = ({"8", "9", "a", "b"})[math.random(1, 4)]

    return table.concat({
    	string.format("%08x"  ,  math.random(0, 4294967295)),     -- 2**32 - 1
    	string.format("%04x"  ,  math.random(0, 65535)),          -- 2**16 - 1
    	string.format("4%03x" ,  math.random(0, 4095)),           -- 2**12 - 1
    	string.format("%s%03x",  _y, math.random(0, 4095)),       -- 2**12 - 1
    	string.format("%012x" ,  math.random(0, 281474976710656)),-- 2**48 - 1
    }, "-")
end

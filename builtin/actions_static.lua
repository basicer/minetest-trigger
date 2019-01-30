local trigger = require('trigger')
local minetest = require('minetest')
local vector = require('vector')
local util = require('util')
local VoxelArea = require('VoxelArea')

---
-- Immutable Areas
---
local protection_data = {}

local old_is_protected = minetest.is_protected

local function is_protected(pos, kind, named)
	if trigger.is_paused() then return false end
	for k,v in pairs(protection_data) do
		if util.xmatch(kind, v.kind) then
			if v.trigger:is_active() and util.inside_bounds(pos, v.bounds[1], v.bounds[2]) then
				local prevent = true
				if v.match then
					if not util.xmatch(named.name, v.match) then
						prevent = false
					end
				end
				if v.exclude and prevent then
					if util.xmatch(named.name, v.exclude) then
						prevent = false
					end
				end
				if prevent then print(v.name) return true end
			end
		end
	end
	return false
end

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	if not is_protected(pos, "place", newnode) then return false end
	minetest.set_node(pos, oldnode)
	return true
end)

if minetest.register_on_spawnentity then
	minetest.register_on_spawnentity(function(object)
		if is_protected(object:getpos(), "spawn", object:get_luaentity()) then
			print("Prevented spawning of: " .. object:get_luaentity().name .. " because of a protection area ")
			object:remove()
		end
	end)
end

minetest.register_on_punchplayer(function (player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
	if is_protected(player:getpos(), "prot", {name=""}) then
		return true
	else
		return false
	end
end
)



function minetest.is_protected(pos, name, opt)
	local node = minetest.get_node(pos)
	local node_definition = minetest.registered_nodes[node.name]

	if opt ~= nil and is_protected(pos, "place", opt) then return true end

	if node and node_definition then
		-- Actually should check if is airlike
		if node.name == "air" or node_definition.liquidtype ~= "none" then return end
		if is_protected(pos, "prot", node) then return true end
	end

	return old_is_protected(pos, name)
end

trigger.register_action {
	name = "Protect",
	description = "Protectes an area from modification.",
	uses_static = true,
	properties = {
		bounds = {type="Bounds", env="bounds"},
		kind = {type="String", default="prot place"},
		exclude = {type="String"},
		match = {type="String"},
		state = {type="String", env="state", hidden=true},
		trigger = {type="Trigger", env="trigger", hidden=true}
	},
	perform = function(self, props)
		if props.state == "on" then
			protection_data[props._key] = props
		elseif props.state == "off" then
			protection_data[props._key] = nil
		end
	end
}

---
-- Spawn Point
----

local spawn = nil
minetest.register_on_respawnplayer(function(player)
	if spawn then
		player:setpos(spawn)
		return true
	end
	return false
end)

minetest.register_on_newplayer(function(player)
	if spawn then player:setpos(spawn) end
end)

trigger.register_action {
	name = "Spawn Point",
	description = "Mark's servers spawn point.",
	uses_static = true,
	properties = {
		pos = {type="Position", env="pos"},
		state = {type="String", env="state", hidden=true},
		trigger = {type="Trigger", env="trigger", hidden=true}
	},
	perform = function(self, props)
		if props.state == "on" then
			spawn = props.pos
		elseif props.state == "off" then
			spawn = nil
		end
	end
}

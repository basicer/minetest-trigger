local minetest = require('minetest')
--local markers = require('registry') .markers
local triggers_by_name = require('registry').triggers_by_name

function markers.draw(name, pos1, pos2)
	-- entity:remove()
	
	local pos1, pos2 = worldedit.sort_pos(pos1, pos2)


	local thickness = 0.2

	local markers = {}

	--XY plane markers
	for _, z in ipairs({pos1.z - 0.5, pos2.z + 0.5}) do
		local marker = minetest.add_entity({x=pos1.x + sizex - 0.5, y=pos1.y + sizey - 0.5, z=z}, "worldedit:region_cube")
		if marker ~= nil then
			marker:set_properties({
				visual_size={x=sizex * 2, y=sizey * 2},
				collisionbox = {-sizex, -sizey, -thickness, sizex, sizey, thickness},
			})
			marker:get_luaentity().player_name = name
			table.insert(markers, marker)
		end
	end

	--YZ plane markers
	for _, x in ipairs({pos1.x - 0.5, pos2.x + 0.5}) do
		local marker = minetest.add_entity({x=x, y=pos1.y + sizey - 0.5, z=pos1.z + sizez - 0.5}, "worldedit:region_cube")
		if marker ~= nil then
			marker:set_properties({
				visual_size={x=sizez * 2, y=sizey * 2},
				collisionbox = {-thickness, -sizey, -sizez, thickness, sizey, sizez},
			})
			marker:setyaw(math.pi / 2)
			marker:get_luaentity().player_name = name
			table.insert(markers, marker)
		end
	end

	return markers
	
end

local markerList = {}
function markers.hideTrigger(trigger)
	local triggerName = trigger.spec.name
	if markerList[triggerName] ~= nil then
		for k, v in pairs(markerList[triggerName]) do
			v:remove(v)
		end
		markerList[triggerName] = nil
	end
end
function markers.drawTrigger(trigger)
	local triggerName = trigger.spec.name
	if markerList[triggerName] ~= nil then
		return
	end
	markerList[triggerName] = {}
	if trigger.spec == nil then
		print("Trigger doesn't have spec: " .. triggerName)
		return
	end
	if trigger.spec.bounds == nil then
		print("Trigger's spec doesn't have bounds: " .. triggerName)
		return
	end


	local color = 0xFFFFFF00 * math.random() + 0x000000FF
	local pos1 = trigger.spec.bounds[1]
	local pos2 = trigger.spec.bounds[2]
	pos1.x, pos1.y, pos1.z = pos1.x, pos1.y, pos1.z
	pos2.x, pos2.y, pos2.z = pos2.x, pos2.y, pos2.z
	local thickness = 0.1
	local size = 0.501
	if pos1.x > pos2.x then
		pos2.x, pos1.x = pos1.x, pos2.x
	end
	if pos1.y > pos2.y then
		pos2.y, pos1.y = pos1.y, pos2.y
	end
	if pos1.z > pos2.z then
		pos2.z, pos1.z = pos1.z, pos2.z
	end
	local mPos = {x=(pos1.x + pos2.x) / 2,y=(pos1.y + pos2.y) / 2,z=(pos1.z + pos2.z) / 2}

	if minetest.get_node_or_nil(mPos) == nil then
		return
	end

	local sizex, sizey, sizez = (1 + pos2.x - pos1.x) / 2, (1 + pos2.y - pos1.y) / 2, (1 + pos2.z - pos1.z) / 2

	if sizex == 0 or sizey == 0 or sizez == 0 then
		local marker = minetest.add_entity({x=pos1.x + sizex - 0.5, y=pos1.y + sizey - 0.5, z=z}, "trigger:marker_sprite")
		print(triggerName .. " has no width")
		if marker ~= nil then
			marker:set_properties({
				visual_size={x=sizex * 2, y=sizey * 2},
				collisionbox = {-sizex, -sizey, -thickness, sizex, sizey, thickness},
			})
			marker:get_luaentity().trigger = trigger
			table.insert(markerList[triggerName], marker)
			--table.insert(markers, marker)
		end
	else
		--XY plane markers
		for _, z in ipairs({pos1.z - size, pos2.z + size}) do
			local marker = minetest.add_entity({x=pos1.x + sizex - 0.5, y=pos1.y + sizey - 0.5, z=z}, "trigger:marker")
			if marker ~= nil then
				marker:set_properties({
					visual_size={x=sizex * 2, y=sizey * 2},
					collisionbox = {-sizex, -sizey, -thickness, sizex, sizey, thickness},
				})
				marker:get_luaentity().trigger = trigger
				marker:set_properties({colors={color,color}})
				table.insert(markerList[triggerName], marker)
				--table.insert(markers, marker)
			end
		end
		--YZ plane markers
		for _, x in ipairs({pos1.x - size, pos2.x + size}) do
			local marker = minetest.add_entity({x=x, y=pos1.y + sizey - 0.5, z=pos1.z + sizez - 0.5}, "trigger:marker")
			if marker ~= nil then
				marker:set_properties({
					visual_size={x=sizez * 2, y=sizey * 2},
					collisionbox = {-thickness, -sizey, -sizez, thickness, sizey, sizez},
				})
				marker:setyaw(math.pi / 2)
				marker:get_luaentity().trigger = trigger
				marker:set_properties({colors={color,color}})
				table.insert(markerList[triggerName], marker)
				--table.insert(markers, marker)
			end
		end
	end
end
minetest.register_entity("trigger:marker2", {
    collisionbox = {-0.25,-0.25,-0.25, 0.25,0.25,0.25},
    visual = "cube",
    visual_size = {x=0.5, y=0.5, z=0.5},
    textures = {"trigger_t.png","trigger_t.png","trigger_t.png","trigger_t.png","trigger_t.png","trigger_t.png"}, -- number of required textures depends on visual
    colors = {0xFFFFFFFF, 0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF}, -- number of required colors depends on visual
    is_visible = true,
    on_activate = function(self, sd)
    	if markerState ~= true then
    		self.object:remove()
    	end
    end,
    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
    	print(self.triggerName)
    	print(self.c1.x .. " " .. self.c1.y .. " " .. self.c1.z)
    	print(self.c2.x .. " " .. self.c2.y .. " " .. self.c2.z)
  	end,
})
minetest.register_entity("trigger:marker_sprite", {
    collisionbox = {-0.25,-0.25,-0.25, 0.25,0.25,0.25},
	visual = "upright_sprite",
    visual_size = {x=0.5, y=0.5, z=0.5},
    textures = {"trigger_t.png"}, -- number of required textures depends on visual
    colors = {0xFFFFFFFF}, -- number of required colors depends on visual
    spritediv = {x=1, y=1},
    initial_sprite_basepos = {x=0, y=0},
	physical = false,
    is_visible = true,
	on_step = function(self)
		
		if self.trigger == nil then
			self.object:remove()
		else
			local triggerName = self.trigger.spec.name
			if markerList[triggerName] == nil then
				self.object:remove()
			end
		end
		
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		print("TRIGGER PUNCHED: " .. self.trigger.spec.name)
	end,
})


minetest.register_entity("trigger:marker", {
	initial_properties = {
		visual = "upright_sprite",
		visual_size = {x=1.1, y=1.1},
		textures = {"trigger_box.png"},
		visual_size = {x=10, y=10},
		physical = false,
		glow=-1,
		backface_culling = true,
		colors={0xFF0000FF}
	},
	on_step = function(self)
		if self.trigger == nil then
			self.object:remove()
		else
			local triggerName = self.trigger.spec.name
			if markerList[triggerName] == nil then
				self.object:remove()
			end
		end
		
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		print("TRIGGER PUNCHED: " .. self.trigger.spec.name)
		require('ui').show_editor(puncher:get_player_name(), self.trigger)
	end,
})

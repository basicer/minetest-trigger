local trigger = require('trigger')
local minetest = require('minetest')
local vector = require('vector')
local util = require('util')
local VoxelArea = require('VoxelArea')
local ItemStack = require('ItemStack')

-- helper functions
local function sort_pos(pos1, pos2)
	pos1 = {x=pos1.x, y=pos1.y, z=pos1.z}
	pos2 = {x=pos2.x, y=pos2.y, z=pos2.z}
	if pos1.x > pos2.x then
		pos2.x, pos1.x = pos1.x, pos2.x
	end
	if pos1.y > pos2.y then
		pos2.y, pos1.y = pos1.y, pos2.y
	end
	if pos1.z > pos2.z then
		pos2.z, pos1.z = pos1.z, pos2.z
	end
	return pos1, pos2
end

local function keep_loaded(pos1, pos2)
	local manip = minetest.get_voxel_manip()
	manip:read_from_map(pos1, pos2)
end
------------------------------------------

trigger.register_action {
	name = "Activate Trigger",
	properties = {
		trigger = {type="Trigger", env="trigger"}
	},
	preform = function(self, props)
		props.trigger:set_state('active', true)
	end
}

trigger.register_action {
	name = "Activate Random Trigger",
	properties = {
		trigger1 = {type="Trigger", env="trigger"},
		trigger2 = {type="Trigger", env="trigger"},
		trigger3 = {type="Trigger", env="trigger"},
		trigger4 = {type="Trigger", env="trigger"},
		avoid = {type="Float"}
	},
	preform = function(self, props)
		--minetest.log("activating a random trigger")
		local ind = math.random(4)
		if props.avoid ~= nil and ind >= props.avoid then ind = (ind + 1)%4 end
		if ind == 1 then 
			props.trigger1:set_state('active', true)
			--table.foreach(props.trigger1.spec,print)
		end
		if ind == 2 then 
			props.trigger2:set_state('active', true) 
			--table.foreach(props.trigger2.spec,print)
		end
		if ind == 3 then 
			props.trigger3:set_state('active', true) 
			--table.foreach(props.trigger3.spec,print)
		end
		if ind == 4 then
			props.trigger4:set_state('active', true)
		end
	end
}

trigger.register_action {
	name = "Run Random Trigger",
	properties = {
		trigger1 = {type="Trigger", env="trigger"},
		trigger2 = {type="Trigger", env="trigger"},
		trigger3 = {type="Trigger", env="trigger"},
		trigger4 = {type="Trigger", env="trigger"},
		avoid = {type="Float"}
	},
	preform = function(self, props)
		--minetest.log("activating a random trigger")
		local ind = math.random(4)
		if props.avoid ~= nil and ind >= props.avoid then ind = ind + 1 end
		local env = {}
		if ind == 1 then 
	        props.trigger1:write_env(props)
	        props.trigger1:run(env)
			--table.foreach(props.trigger1.spec,print)
		end
		if ind == 2 then 
			props.trigger2:write_env(props)
	        props.trigger2:run(env)
			--table.foreach(props.trigger2.spec,print)
		end
		if ind == 3 then 
			props.trigger3:write_env(props)
	        props.trigger3:run(env)
			--table.foreach(props.trigger3.spec,print)
		end
		if ind == 4 then
			props.trigger4:write_env(props)
	        props.trigger4:run(env)
		end
	end
}

trigger.register_action {
	name = "Deactivate Trigger",
	properties = {
		trigger = {type="Trigger", env="trigger"}
	},
	preform = function(self, props)
		props.trigger:set_state('active', false)
	end
}

trigger.register_action {
	name = "Log",
	properties = {
		text = {type="String", env="text", default="Logging something..."}
	},
	preform = function(self, props, env)
		minetest.chat_send_all(util.template_string(props.text, props._env, true))
	end
}


trigger.register_action {
	name = "Lua",
	description = "Run lua code",
	properties = {
		player = {type="Player", env="player"},
		code = {type="String", multiline=true}
	},
	preform = function(self, props)
		if not props.code then return end
		local fn = loadstring(props.code, "[action:lua]")
		local fenv = {
			minetest=minetest,
			env=props._env,
			print=print,
			global=_GLOBAL,
			variables = require('registry').variables,
			triggers= require('registry').triggers_by_name,
			math=math,
		}
		for k,v in pairs(props._env) do fenv[k] = v end
		setfenv(fn, fenv)
		local ok, err = pcall(fn)
		if not ok then print(err) end
	end
}

trigger.register_action {
	name = "Nothing",
	properties = {
	},
	preform = function(self, props, env) end
}

trigger.register_action {
	name = "Teleport All In Bounds",
	properties = {
		to = {type="Vec3", env="pos"},
        bounds = {type="Bounds", env="bounds"},
        yaw = {type="Float"}
	},
	preform = function(self, props)
        local players = util.get_players_in_bounds(props.bounds)
        for _,player in ipairs(players) do
            player:setpos(props.to)
            if props.yaw then player:set_look_horizontal(math.rad(props.yaw)) end
        end
	end
}

trigger.register_action {
	name = "Teleport",
	properties = {
		to = {type="Vec3", env="pos"},
		player = {type="Player", env="player"},
		yaw = {type="Float"}
	},
	preform = function(self, props)
		props.player:setpos(props.to)
		if props.yaw then props.player:set_look_horizontal(math.rad(props.yaw)) end
	end
}

trigger.register_action {
	name = "Teleport Relative",
	properties = {
		base = {type="Position", env="pos"},
		offset = {type="Vec3", default={x=0, y=0, z=0}},
		player = {type="Player", env="player"}
	},
	preform = function(self, props)
		print(dump(props))
		local final = vector.add(props.base, props.offset)
		props.player:setpos(final)
	end
}

trigger.register_action {
	name = "Set Nodes",
	properties = {
		area = {type="Bounds", env="bounds"},
		block = {type="String", default="default:stone"}
	},
	preform = function(self, props)
		local manip = minetest.get_voxel_manip()
		local e1, e2 = manip:read_from_map(unpack(props.area))
		local area = VoxelArea:new{MinEdge=e1, MaxEdge=e2}
		local data = manip:get_data()
		local s = minetest.get_content_id(props.block)
		-- Set cobble and wood, I chose randomly some line pattern
		for i = 1,#data do
			local p = area:position(i)
			if util.inside_bounds(p, unpack(props.area)) then
				data[i] = s
			end
		end
		manip:set_data(data)
		manip:write_to_map()
		manip:update_map()
	end
}

trigger.register_action {
	name = "Set Time Of Day",
	properties = {
		to = {type="Float"},
	},
	preform = function(self, props)
		minetest.set_timeofday(props.to)
	end
}

trigger.register_action {
	name = "Spawn Entity",
	properties = {
		at = {type="Vec3", env="pos"},
		entity = {type="String"},
		unloaded = {type="Boolean", default=false, description="Load enties into unloaded areas"}
	},
	preform = function(self, props)
		if not props.unloaded then
			local node = minetest.get_node(props.at)
			if node.name == "ignore" then
				return
			end
		end
		minetest.add_entity(props.at, props.entity)
	end
}

trigger.register_action {
	name = "Wait",
	properties = {
		time = {type="Float", default=1}
	},
	preform_async = function(self, props, done)
		minetest.after(props.time, done)
	end
}

-- The image should be present in the world's textures subfolder
trigger.register_action {
    name = "Show Image",
    properties = {
        image = {type="String"},
        player = {type="Player", env="player"},
        bounds = {type="Bounds", env="bounds"}
    },
    preform = function(self, props)
        print("show image!")
        local players = util.get_players_in_bounds(props.bounds)
        if players then
            print("players!")
            for _,player in ipairs(players) do
                print("player")
                minetest.show_formspec(player:get_player_name(), player:get_player_name(),
                    "size[15,10]" ..
                    --"bgcolor[#080808BB;true]" ..
                    "background[0,0;15,10;" .. props.image .. ";]")
            end
        end
    end
}

trigger.register_action {
    name = "Close Image",
    properties = {
        player = {type="Player", env=player},
        bounds = {type="Bounds", env="bounds"}
    },
    preform = function(self, props)
        local players = util.get_players_in_bounds(props.bounds)
        for _,player in ipairs(players) do
            minetest.show_formspec(player:get_player_name(), player:get_player_name(), "")
        end
    end
}

trigger.register_action {
    name = "Give Item",
    properties = {
        item = {type="String"},
        player={type="Player", env="player"}
    },
    preform = function(self, props)
        -- TODO: move the checks into setup
        local itemstack = ItemStack(props.item)
        assert(not itemstack:is_empty() and
               itemstack:is_known(), "Give Item: unknown item: " .. props.item)

        local receiverref = props.player
        assert(receiverref ~= nil, props.player:get_player_name() .. " is not a known player")

        local leftover = receiverref:get_inventory():add_item("main", itemstack)
    end
}

trigger.register_action {
	name = "Place Schematic",
	properties = {
		schematic = {type="String"},
		bounds = {type="Bounds", env="bounds"},
		force = {type="Boolean", default=true}
	},
	preform = function(self, props)
		local pos = {
			x = math.min(props.bounds[1].x, props.bounds[2].x),
			y = math.min(props.bounds[1].y, props.bounds[2].y),
			z = math.min(props.bounds[1].z, props.bounds[2].z),
		}
		local path = minetest.get_worldpath() .. "/schems/" .. props.schematic .. ".mts"
		minetest.place_schematic(pos, path, 0, nil, props.force)
	end
}

trigger.register_action {
    name = "Run Trigger",
    properties = {
        trigger={type="Trigger"}
    },
    preform = function(self, props)
        local env = {}
        props.trigger:write_env(props)
        props.trigger:run(env)
    end
}

trigger.register_action {
    name = "Set Client Setting",
    properties = {
        key={type="String"},
        value={type="String"},
        player={type="Player", env="player"}
    },
    preform = function(self, props)
        minetest.send_plugin_message(props.player:get_player_name(), "set_setting", props.key .. " " .. props.value) 
    end
}

-- used to clear objects (e.g., entities such as 'current' blocks) within a given bounds
trigger.register_action {
	name = "Clear Objects",
	properties = {
		area = {type="Bounds", env="bounds"},
	},
	preform = function(self, props)
		local pos1, pos2 = unpack(props.area)

		pos1, pos2 = sort_pos(pos1, pos2)

		keep_loaded(pos1, pos2)

		-- Offset positions to include full nodes (positions are in the center of nodes)
		local pos1x, pos1y, pos1z = pos1.x - 0.5, pos1.y - 0.5, pos1.z - 0.5
		local pos2x, pos2y, pos2z = pos2.x + 0.5, pos2.y + 0.5, pos2.z + 0.5

		-- Center of region
		local center = {
			x = pos1x + ((pos2x - pos1x) / 2),
			y = pos1y + ((pos2y - pos1y) / 2),
			z = pos1z + ((pos2z - pos1z) / 2)
		}
		-- Bounding sphere radius
		local radius = math.sqrt(
				(center.x - pos1x) ^ 2 +
				(center.y - pos1y) ^ 2 +
				(center.z - pos1z) ^ 2)
		local count = 0
		for _, obj in pairs(minetest.get_objects_inside_radius(center, radius)) do
			local entity = obj:get_luaentity()
			-- Avoid players and WorldEdit entities
			if not obj:is_player() and (not entity or
					not entity.name:find("^worldedit:")) then
				local pos = obj:getpos()
				if pos.x >= pos1x and pos.x <= pos2x and
						pos.y >= pos1y and pos.y <= pos2y and
						pos.z >= pos1z and pos.z <= pos2z then
					-- Inside region
					obj:remove()
					count = count + 1
				end
			end
		end
	end
}

-- used to move or animate nodes within bounds. Currently uses worldedit's 'move' function, but perhaps make our own...
trigger.register_action {
	name = "Move Nodes",
	properties = {
		area = {type="Bounds", env="bounds"},
		axis = {type="String", default="y"},
		amount = {type="Float", default=1},
		--interval = {type="Float", default=1},
		--delay = {type="Float", default=0}
	},
	preform = function(self, props)
		local pos1, pos2 = unpack(props.area)

		pos1, pos2 = sort_pos(pos1, pos2)

		keep_loaded(pos1, pos2)

		-- TODO (worldedit): Move slice by slice using schematic method in the move axis
		-- and transfer metadata in separate loop (and if the amount is
		-- greater than the length in the axis, copy whole thing at a time and
		-- erase original after, using schematic method).
		local get_node, get_meta, set_node, remove_node = minetest.get_node,
				minetest.get_meta, minetest.set_node, minetest.remove_node
		-- Copy things backwards when negative to avoid corruption.
		--- FIXME (worldedit): Lots of code duplication here.
		if props.amount < 0 then
			local pos = {}
			pos.x = pos1.x
			while pos.x <= pos2.x do
				pos.y = pos1.y
				while pos.y <= pos2.y do
					pos.z = pos1.z
					while pos.z <= pos2.z do
						local node = get_node(pos) -- Obtain current node
						local meta = get_meta(pos):to_table() -- Get metadata of current node
						remove_node(pos) -- Remove current node
						local value = pos[props.axis] -- Store current position
						pos[props.axis] = value + props.amount -- Move along props.axis
						set_node(pos, node) -- Move node to new position
						get_meta(pos):from_table(meta) -- Set metadata of new node
						pos[props.axis] = value -- Restore old position
						pos.z = pos.z + 1
					end
					pos.y = pos.y + 1
				end
				pos.x = pos.x + 1
			end
		else
			local pos = {}
			pos.x = pos2.x
			while pos.x >= pos1.x do
				pos.y = pos2.y
				while pos.y >= pos1.y do
					pos.z = pos2.z
					while pos.z >= pos1.z do
						local node = get_node(pos) -- Obtain current node
						local meta = get_meta(pos):to_table() -- Get metadata of current node
						remove_node(pos) -- Remove current node
						local value = pos[props.axis] -- Store current position
						pos[props.axis] = value + props.amount -- Move along props.axis
						set_node(pos, node) -- Move node to new position
						get_meta(pos):from_table(meta) -- Set metadata of new node
						pos[props.axis] = value -- Restore old position
						pos.z = pos.z - 1
					end
					pos.y = pos.y - 1
				end
				pos.x = pos.x - 1
			end
		end
	end
}
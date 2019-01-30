local trigger = require('trigger')
local minetest = require('minetest')
local util = require('util')
local vector = require('vector')

trigger.register_condition {
	name = "True",
	properties = {
	},
	check = function(self, props)
		return true
	end
}

trigger.register_condition {
	name = "Check Nodes",
	properties = {
		bounds = {type="Bounds", description="Area to check for nodes.", env="bounds"},
		block = {type="String", description="Node type to require"}
	},
	check = function(self, props)
		local p1 = props.bounds[1]
		local p2 = props.bounds[2]
		local target = props.block
		for x = p1.x,p2.x do
			for y = p1.y,p2.y do
				for z = p1.z,p2.z do
					local node = minetest.get_node({x=x,y=y,z=z})
					if node.name ~= target then
						return false
					end
				end
			end
		end
		return true
	end
}

trigger.register_condition {
	name = "Check Node Player On",
	properties = {
		bounds = {type="Bounds", description="Area to check for node player on.", env="bounds"},
		block = {type="String", description="Node type to require"},
		player = {type="Player", description="Player to Check For", env="player"}
	},
	check = function(self, props)
		local pos = props.player:getpos()
		local target = props.block
		pos.y = pos.y - 1
		local node = minetest.get_node({x=pos.x,y=pos.y,z=pos.z})
		if node.name ~= target then
			return false
		else
			return true
		end
	end
}

trigger.register_condition {
	name = "Player In Bounds",
	properties = {
		bounds = {type="Bounds", description="Area to check for given player.", env="bounds"},
		player = {type="Player", description="Player to Check For", env="player"}
	},
	check = function(self, props)
		return util.inside_bounds_block(props.player:getpos(), props.bounds[1], props.bounds[2])
	end
}

trigger.register_condition {
	name = "Any Player In Bounds",
	properties = {
		bounds = {type="Bounds", description="Area to check for any player.", env="bounds"},
	},
	check = function(self, props)
		for _,player in ipairs(minetest.get_connected_players()) do
			if util.inside_bounds_block(player:getpos(), props.bounds[1], props.bounds[2]) then
				return true
			end
		end
		return false
	end
}

trigger.register_condition {
	name = "Any Player In Radius",
	properties = {
		center = {type="Position", description="Center of sphere.", env="pos"},
		radius = {type="Float", default=1.0}
	},
	check = function(self, props)
		for _,player in ipairs(minetest.get_connected_players()) do
			if vector.distance(player:getpos(), props.center) <= props.radius then
				return true
			end
		end
		return false
	end
}

trigger.register_condition {
	name = "Trigger Active",
	properties = {
		trigger = {type="Trigger", description="Trigger to Check."},
	},
	check = function(self, props)
		return props.trigger.state.active
	end
}

trigger.register_condition {
	name = "Trigger Inactive",
	properties = {
		trigger = {type="Trigger", description="Trigger to Check."},
	},
	check = function(self, props)
		return not props.trigger.state.active
	end
}

trigger.register_condition {
	name = "Random Chance",
	properties = {
		percent = {type="Int", description="Chance to pass.", default=100},
	},
	check = function(self, props)
		return math.random() < (props.percent / 100)
	end
}

local trigger_debouces = {}
trigger.register_condition {
	name = "Debounce",
	properties = {
		trigger = {type="Trigger", hidden="true", env="trigger"},
		delay = {type="Float", default=0}
	},
	check = function(self, props)
		local now = minetest.get_gametime()
		local time = trigger_debouces[props.trigger.id]
		if time ~= nil and time > now then
			return false
		end
		trigger_debouces[props.trigger.id] = now + props.delay
		return true
	end
}

local trigger_player_debouces = {}
trigger.register_condition {
	name = "Debounce by Player",
	properties = {
		trigger = {type="Trigger", hidden="true", env="trigger"},
		player = {type="Player", env="player"},
		delay = {type="Float", default=0}
	},
	check = function(self, props)
		local now = minetest.get_gametime()
		if not props.player then return true end
		local name = props.player:get_player_name()
		local plr = trigger_player_debouces[name]
		if plr == nil then
			plr = {}
			trigger_player_debouces[name] = plr
		end
		local time = plr[props.trigger.id]
		if time ~= nil and time > now then
			return false
		end
		plr[props.trigger.id] = now + props.delay
		return true
	end
}


trigger.register_condition {
	name = "Once Per Player",
	properties = {
		trigger = {type="Trigger", hidden="true", env="trigger"},
		player = {type="Player", env="player"}
	},
	check = function(self, props)
		local tstate = props.trigger.state
		if not tstate.players then tstate.players = {} end
		if not props.player then return false end
		local name = props.player:get_player_name()
		if tstate.players[name] then return false end
		tstate.players[name] = true
		props.trigger:save_state()
		return true

	end
}
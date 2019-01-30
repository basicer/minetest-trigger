local trigger = require('trigger')
local minetest = require('minetest')
local util = require('util')

trigger.register_event {
	name = "Never"
}

trigger.register_event {
	name = "Static",
	env = {state = {type = "String"}},
	on_watch = function(self, handle, props)
		minetest.log("Scheduled delayed " .. handle)
		minetest.after(0, function()
			minetest.log("trigger delayed " .. handle)
			self:emit(handle, {state="on"})
		end)
	end,
	on_unwatch = function(self, handle)
		self:emit(handle, {state="off"})
	end
}


trigger.register_event {
	name = "On Tick",
	step = function(self) self:emitAll() end
}

trigger.register_event {
	name = "Timer",
	properties = {
		interval = {type="Float", description="Time interval in seconds.", default=1.0}
	},
	setup = function(self)
		self.delays = {}
	end,
	on_watch = function(self, handle, props)
		self.delays[handle] = props.interval
	end,
	on_unwatch = function(self, handle)
		self.delays[handle] = nil
	end,
	step = function(self, dt)
		for handle,v in pairs(self.instances) do
			if self.delays[handle] ~= nil then
				self.delays[handle] = self.delays[handle] - dt
				if ( self.delays[handle] < 0 ) then
					self.delays[handle] = v.interval --self.delays[handle] + v.interval
					self:emit(handle)
				end
			end
		end
	end
}

trigger.register_event {
	name = "Timer Per Player",
	properties = {
		interval = {type="Float", description="Time interval in seconds.", default=1.0}
	},
	env = {
		player = {type="Player"}
	},
	setup = function(self)
		self.delays = {}
	end,
	on_watch = function(self, handle, props)
		self.delays[handle] = props.interval
	end,
	on_unwatch = function(self, handle)
		self.delays[handle] = nil
	end,
	step = function(self, dt)
		for handle,v in pairs(self.instances) do
			self.delays[handle] = self.delays[handle] - dt
			if ( self.delays[handle] < 0 ) then
				self.delays[handle] = self.delays[handle] + v.interval
				for _,player in ipairs(minetest.get_connected_players()) do
					local name = player:get_player_name()
					self:emit(handle, {player=player})
				end
			end
		end
	end
}


local function inOutStep(inside)
	return function(self, dt)
		for handle,params in pairs(self.instances) do
			for _,player in ipairs(minetest.get_connected_players()) do
				local name = player:get_player_name()
				local pos = player:getpos()
				pos.y = pos.y + 0.51 -- Weird offset in this here game.
				if util.inside_bounds_block(pos, params.bounds[1], params.bounds[2]) then
					if not self.data[handle].inside[name] then
						self.data[handle].inside[name] = true
						if inside then self:emit(handle, {player=player, where=pos}) end
					end
				elseif self.data[handle].inside[name] then
					self.data[handle].inside[name] = nil
					if not inside then self:emit(handle, {player=player, where=pos}) end
				end
			end
		end
	end
end

trigger.register_event {
	name = "Player Enter Area",
	properties = {
		bounds = {type="Bounds", description="Area to check for players.", env="bounds"}
	},
	env = {
		player = {type="Player"},
		where= {type="Vec3"}
	},
	on_watch = function(self, handle, props)
		self.data[handle] = {inside={}}
	end,
	on_unwatch = function(self, handle)
		self.data[handle] = nil
	end,
	step = inOutStep(true)
}


trigger.register_event {
	name = "Player Exit Area",
	properties = {
		bounds = {type="Bounds", description="Area to check for players.", env="bounds"}
	},
	env = {
		player = {type="Player"},
		where= {type="Vec3"}
	},
	setup = function(self) self.data = {} end,
	on_watch = function(self, handle, props)
		self.data[handle] = {inside={}}
	end,
	on_unwatch = function(self, handle)
		self.data[handle] = nil
	end,
	step = inOutStep(false)
}

trigger.register_event {
	name = "On Debug",
	env = {
		player = {type="Player"},
		text = {type="String"}
	},
	setup = function(self)
		minetest.register_chatcommand("td", {
    		privs={server=true},
			func = function(pl, pr)
				if #pr == 0 then pr = nil end
				local player = minetest.get_player_by_name(pl)
				self:emitAll({player=player, text=pr}) end
			})
		end
}

trigger.register_event {
	name = "Chat Command",
	env = {
		player = {type="Player"},
		text = {type="String"}
	},
	properties = {
		command = {type="String"}
	},
	setup = function(self) end,
	on_watch = function(self, handle, props)
		if not props.command then return end
		minetest.register_chatcommand(props.command, {
			func = function(pl, pr)
				local player = minetest.get_player_by_name(pl)
				self:emit(handle, {player=player, text=pr}) end
			}
		)
	end,
	on_unwatch = function(self, handle)
		-- TODO: Can we fix that?
	end
}

local function on_node_hit(self, pos, node, puncher, pointed_thing)
	if not puncher:is_player() then return false end

	local handledit = false
	for handle,v in pairs(self.instances) do
		(function()
			if v.bounds and not util.inside_bounds(pos, unpack(v.bounds)) then return end
			if v.block and (not node or v.block ~= node.name) then return end
			if v.pos and v.pos ~= pos then return end
			handledit = true
			self:emit(handle, {player=puncher, where=pos})
		end)()
	end
	return handledit
end


trigger.register_event {
	name = "On Hit",
	properties = {
		block = {type="String"},
		pos = {type="Vec3"},
		bounds = {type="Bounds", description="Area to check for hits.", env="bounds"}
	},
	env = {
		player = {type="Player"},
		where = {type="Vec3"}
	},
	setup = function(self)
		-- Handle left clicks
		minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
            return on_node_hit(self,pos,node,puncher,pointed_thing)
		end)

		if minetest.register_on_interactnodes then
			minetest.register_on_interactnodes(function(pos, puncher) -- PULL AND RECOMPILE MINETEST
            	return on_node_hit(self,pos,minetest.get_node_or_nil(pos),puncher,nil)
        	end)
        else
        	print("RECOMPILE YOUR MINETEST PLZ!!")
        end
    end
}


trigger.register_event {
	name = "Player Joined Server",
	properties = {
		player = {type="Player", env="player"},
		bounds = {type="Bounds"}
	},
	env = {
		player = {type="Player"},
	},
	setup = function(self)
		minetest.register_on_joinplayer(function(player)
			for handle,v in pairs(self.instances) do
				if (not v.bounds) or util.inside_bounds(player:getpos(), unpack(v.bounds)) then
					self:emit(handle, {player=player})
				end
			end
		end)
	end
}

trigger.register_event {
	name = "On Dig",
	properties = {
		block = {type="String"},
		pos = {type="Vec3"},
		bounds = {type="Bounds", description="Area to check for hits.", env="bounds"}
	},
	env = {
		player = {type="Player"},
		where = {type="Vec3"}
	},
	setup = function(self)
		minetest.register_on_dignode(function(pos, node, puncher, pointed_thing)
			if (puncher and puncher:is_player()) then
				for handle,v in pairs(self.instances) do
					if (not v.bounds or util.inside_bounds(pos, unpack(v.bounds))) and
					   (not v.block or v.block == node.name) and
					   (not v.pos or v.pos == pos) then
						   self:emit(handle, {player=puncher, where=pos})
					end
				end
			end
		end)
	end
}

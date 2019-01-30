local trigger = require('trigger')
local minetest = require('minetest')
local util = require('util')
local variables = require('registry').variables
local type_resolver = require('type_resolver')

local function add(spec)
	trigger.register_action {
		name = spec.name,
		properties = spec.properties,
		preform = function(self, props)
			spec.action(self, props)
		end
	}
	trigger.register_condition {
		name = spec.name,
		properties = spec.properties,
		check = function(self, props)
			local val = spec.action(self, props)
			if spec.returns then
				return val
			else
				return true
			end
		end
	}
end

add {
	name = "Read Variable",
	properties = {variable = {type="String"}, to={type="String"}},
	action = function(self, props)
		local to = props.to or props.variable
		props._env[to] = variables[props.variable]
	end
}

add {
	name = "Set Variable",
	properties = {from={type="String"}, val={type="Float"}, variable = {type="String"}},
	action = function(self, props)
		local from = props.from or props.variable
		--  The original version of this wasn't working. I'm not sure if 
		--  I was using it incorrectly, but I changed it to this for the 
		--  sake of Rainbow Bridge functionality
		--  If switching back to the original, remove val={type="Float"} from properties as well.
		variables[props.variable] = props.val -- props._env[from]
	end
}

add {
	name = "Increment Variable",
	properties = {
		variable = {type="String"},
		amount={type="Float", default=1.0},
		mod={type="Int"}
	},
	action = function(self, props)
		local val = variables[props.variable] or 0
		if props.mod ~= nil then val = val % props.mod end
		variables[props.variable] = val + props.amount
	end
}

local operators = {"==", "!=", ">", "<"}
local function compare(a, op, b)
	if op == "==" then
		return a == b
	elseif op == "!=" then
		return a ~= b
	elseif op == ">" then
		return a > b
	elseif op == "<" then
		return a < b
	else
		return false
	end
end

trigger.register_condition {
	name = "Check Variable",
	properties = {
		variable = {type="String"},
		comparison = {type="String", options=operators, default="=="},
		value = {type="String"},
		cast = {type="String", options={"None", "Float", "String"}, default="None"}
	},
	check = function(self, props)
		if not props.variable or not variables[props.variable] then return false end
		local a = variables[props.variable]
		local b = props.value
		if props.cast ~= "None" then
			a = type_resolver(a, props.cast)
			b = type_resolver(b, props.cast)
		end
		return compare(a, props.comparison, b)
	end
}


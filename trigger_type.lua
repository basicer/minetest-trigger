local normalize = require('util').normalize
local action_types = require('registry').action_types
local event_types = require('registry').event_types
local condition_types = require('registry').condition_types
local triggers_by_id = require('registry').triggers_by_id
local type_resolver = require('type_resolver')
local abs = math.abs
local eval_param = require('util').eval_param
local deepcopy = require('util').deepcopy
local minetest = require('minetest')
local util = require('util')

local function fill_in_props(input, props, specs, env)
	props._env = env
	for k,v in pairs(specs) do
		if input[k] then
			-- TODO: Paramater needs to be resolved
			props[k] = eval_param(input[k], v.type, nil, env)
		elseif v.env and env[v.env] then
			props[k] = type_resolver(env[v.env], v.type)
		elseif not v.required then
			-- TODO: Default should be resolved
			props[k] = v.default -- perhaps nil
		else
			error("Malformed tirgger passed validation :(")
		end
	end
end

local function invoke(id, action, spec, env, done)
	local at = action_types[normalize(action.type)]
    assert(at ~= nil, "Action type not recognized: " .. action.type)

	local props = {}
	fill_in_props(action, props, at.properties, env)
	props._key = spec.uuid .. '/' .. id
	local okay, err = pcall(at.perform_async, at, props, done)
	if not okay then
		minetest.log('error', action.type .. " trigger action error " .. err)
	end
end



-- static
function trigger_type.new(spec)
	local ids = spec.id or 1+#triggers_by_id
	if not spec.name then spec.name = "New Trigger " .. ids end
	if not spec.bounds then
		spec.bounds = {{x=0, y=0, z=0}, {x=0, y=0, z=0}}
	end
	if not spec.uuid then
		spec.uuid = util.uuid4()
	end
	if not spec.actions then
		spec.actions = {}
	end
	if not spec.conditions then
		spec.conditions = {}
	end
	if spec.enabled == nil then spec.enabled = true end
	local state = {
		active = spec.enabled
	}
	local stored_state = require('storage'):get_string('state:' .. spec.uuid)
	if stored_state and #stored_state > 0 then

		local okay, parts = pcall(minetest.parse_json, stored_state)
		if okay and type(parts) == "table" then
			for k,v in pairs(parts) do
				state[k] = v
			end
		end
	end
	local trigger = {
		spec=spec,
		id=ids,
		state = state,
		time = 0,
	}
	if triggers_by_id[trigger.id] then error("Trigger ID overlap.") end
	triggers_by_id[trigger.id] = trigger
	setmetatable(trigger, {__index=trigger_type, type="Trigger"})
	return trigger
end

function trigger_type:write_env(to)
	to.trigger = self
	to.pos = self:get_position()
	to.bounds = self:get_bounds()
	to.vars = require('registry').variables
	to.variables = require('registry').variables
end

function trigger_type:get_position()
	local b1 = self.spec.bounds[1]
	local b2 = self.spec.bounds[2]
	return {x=(b1.x+b2.x)/2, y=(b1.y+b2.y)/2, z=(b1.z+b2.z)/2}
end

function trigger_type:get_bounds()
	return deepcopy(self.spec.bounds)
end


function trigger_type:get_size()
	local b1 = self.spec.bounds[1]
	local b2 = self.spec.bounds[2]
	return {abs(b1.x-b1.x), abs(b1.y-b1.y), abs(b1.z-b1.z)}
end

function trigger_type.check_conditions(self, env)
	for k,v in ipairs(self.spec.conditions) do
		local ct = condition_types[normalize(v.type)]
        --assert(ct ~= nil, "Unknown condition type: " .. v.type)
        if ct == nil then return false end
		local props = {}
		fill_in_props(v, props, ct.properties, env)
		local okay = ct:check(props)
		if v.invert then okay = not okay end
		if not okay then return false end
	end
	return true
end

function trigger_type:reset(env)
	self.state = {
		active = self.spec.enabled
	}
	self:save_state()
end

function trigger_type:run(env)
	local i,t,k = ipairs(self.spec.actions)
	local ah = {}
	ah.next = function()
		local action
		k, action = i(t, k)
		if k then
			local started = minetest.get_us_time()
			invoke(k, action, self.spec, env, ah.next)
			self.time = self.time + minetest.get_us_time() - started
		end
	end
	ah.next()
end

function trigger_type:write_props_for_event(event)
	local env = {}
	self:write_env(env)
	local props = {}
	local eval_param = require('util').eval_param
	local spec = self.spec
	for k,v in pairs(event.properties or {}) do
		if spec.event[k] then
			-- TODO: Paramater needs to be resolved
			props[k] = eval_param(spec.event[k], v.type, nil, env)
		elseif v.env and env[v.env] then
			props[k] = type_resolver(env[v.env], v.type)
		elseif not v.required then
			-- TODO: Default should be resolved
			props[k] = v.default -- perhaps nil
		else
			error("Malformed tirgger passed validation :(")
		end
	end
	return props
end

function trigger_type:refresh_event()
	local event = self:get_event_type()
	if event.on_unwatch then event:on_unwatch(self.id) end
	local props = self:write_props_for_event(event)
	event.instances[self.id] = props
	if event.on_watch then event:on_watch(self.id, props) end
end

function trigger_type:change(param, value)
	if param == 'name' then
		local triggers_by_name = require('registry').triggers_by_name
		local nn = normalize(value)
		if triggers_by_name[nn] ~= nil then error('Trigger name conflict.') end
		if self.spec.name then triggers_by_name[self.spec.name] = nil end
		self.spec.name = value
		triggers_by_name[nn] = self
	elseif param == 'file' then
		if value == "default" then
			self.file = nil
		else
			self.file = value
		end
	elseif param == 'bounds' then
		self.spec.bounds = value
		self:refresh_event()
	elseif param == "b1" then
		self.spec.bounds[1] = value
		self:refresh_event()
	elseif param == "b2" then
		self.spec.bounds[2] = value
		self:refresh_event()
	elseif param == "event" then
		local event = self:get_event_type()
		if event.on_unwatch then event:on_unwatch(self.id) end
		event.instances[self.id] = nil
		event = event_types[normalize(value)]
		local props = self:write_props_for_event(event)
		self.spec.event.type = event.name
		event.instances[self.id] = props
		if event.on_watch then event:on_watch(self.id, props) end
	else
		error('Unknown param ' .. param)
	end
end

function trigger_type:import(spec)
	-- Teardown
	local event = self:get_event_type()
	if event.on_unwatch then event:on_unwatch(self.id) end
	event.instances[self.id] = nil
	local triggers_by_name = require('registry').triggers_by_name
	local no = normalize(self.spec.name)
	triggers_by_name[no] = nil

	if not spec.actions then spec.actions = {} end
	if not spec.conditions then spec.conditions = {} end

	-- Swap
	self.spec = spec

	-- Setup
	local nn = normalize(spec.name)
	if triggers_by_name[nn] ~= nil then error('Trigger name conflict.') end
	triggers_by_name[nn] = self

	event = self:get_event_type()
	local props = self:write_props_for_event(event)
	event.instances[self.id] = props
	if event.on_watch then event:on_watch(self.id, props) end


end

function  trigger_type:get_event_type()
	local et = event_types[normalize(self.spec.event.type)]
	return et or event_types["never"]
end

function trigger_type:set_state(param, value)
	self.state[param] = value
	self:save_state()	

end

function trigger_type:save_state()
	require('storage'):set_string('state:' .. self.spec.uuid, minetest.write_json(self.state))
end

function trigger_type:is_active()
	return self.state.active
end

function  trigger_type:in_group(g)
	if g == "all" then return true end
	if g == "none" then return false end
	if g == "active" then return self:is_active() end
	if g == "inactive" then return not self:is_active() end
	if g == self.file then return true end
	return false
end

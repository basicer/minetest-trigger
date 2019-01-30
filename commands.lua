local minetest = require('minetest')
local trigger = require('trigger')
local type_resolver = require('type_resolver')
local deepcopy = require('util').deepcopy
local vector = require('vector')
local util = require('util')
local triggers_by_id = require('registry').triggers_by_id
local variables = require('registry').variables
local markers = require("markers")

local subcommands = {}
local aliases = {}
local c = minetest.colorize

local last_spec = {}
local last_file = nil


local function registerSubCommand(spec)
	assert(#spec.name > 0)
	assert(type(spec.name) == "string")
	--assert(type(spec.func) == "function")
	subcommands[spec.name] = spec
	if spec.aliases then
		for k,v in ipairs(spec.aliases) do aliases[v] = spec end
	end
end

local function one(triggers)
	if #triggers ~= 1 then
		error({
			message='Must match exactly one trigger.'
		})
	end
	return triggers[1]
end

local function punit(n, unit)
	return tostring(n) .. " " .. unit .. (n > 1 and "s" or "")
end

registerSubCommand({
	name = "list",
	aliases = {"l"},
	params = {"filter:TriggerSpec=:all"},
	description = "List triggers",
	func = function(p, triggers)
		local listing = {}
		if #triggers < 1 then
			return c('red', 'No matching triggers.')
		end
		for k,v in ipairs(triggers) do
			local line = '#' .. c('cyan', tostring(v.id))  .. ' - '
			if v.spec.name then line = line .. v.spec.name else line = line .. '[no name]' end
			if not v.state.active then line = line .. ' - ' .. c('red', 'Inactive') end
			if v.file then line = line .. ' - ' .. c('green', v.file) end
			table.insert(listing, line)
		end
		return table.concat(listing, "\n")
	end
})

registerSubCommand({
	name = "rename",
	params = {"target:TriggerSpec=$", "name:String" },
	description = "Rename a trigger",
	func = function(p, triggers, name)
		one(triggers):change('name', name)
		return c('green', "Tigger renamed.")
	end
})

registerSubCommand({
	name = "setfile",
	params = {"name:String" },
	description = "Set the file to save created triggers to",
	func = function(p, name)
		last_file = name
	end
})

registerSubCommand({
	name = "create",
	aliases = {"new", "c"},
	params = {"name:String", "event:String=Never"},
	description = "Creates a new trigger",
	func = function(p, name, evt)
		name = name or ("Trigger " .. tostring(1+#triggers_by_id))
		local b = vector.round(minetest.get_player_by_name(p):getpos())
		local spec = {
			event = {type=evt},
			name = name,
			actions = {},
			bounds = {b,b},
			uuid = util.uuid4()
		}
		local new_trig = trigger.add(spec)
		new_trig.file = last_file or new_trig.file

		last_spec[p] = {new_trig}
		last_file = file
	end
})

registerSubCommand({
	name = "clone",
	params = {"target:TriggerSpec=$" },
	description = "Copys a trigger",
	func = function(p, triggers, name)
		for k,v in ipairs(triggers) do
			local spec = deepcopy(v.spec)
			spec.uuid = nil
			spec.id = nil
			spec.name = spec.name .. " Copy"
			trigger.add(spec)
		end
	end
})


registerSubCommand({
	name = "activate",
	aliases = {"on"},
	params = {"target:TriggerSpec=$" },
	description = "Sets triggers to active",
	func = function(p, triggers)
		local out = {}
		for k,v in ipairs(triggers) do
			v:set_state("active", true)
		end
		return "Activated " .. punit(#triggers,'trigger')
	end
})

registerSubCommand({
	name = "reset",
	params = {"target:TriggerSpec=$" },
	description = "Resets triggers",
	func = function(p, triggers)
		local out = {}
		for k,v in ipairs(triggers) do
			v:reset()
		end
		return "Reset " .. punit(#triggers,'trigger')
	end
})

registerSubCommand({
	name = "run",
	aliases = {"r"},
	params = {"target:TriggerSpec=$" },
	description = "Runs triggers actions",
	func = function(p, triggers)
		local out = {}
		for k,v in ipairs(triggers) do
			local env = {}
			env.player = minetest.get_player_by_name(p)
			v:write_env(env)
			v:run(env)
		end
	end
})

registerSubCommand({
	name = "deactivate",
	aliases = {"off"},
	params = {"target:TriggerSpec=$" },
	description = "Sets triggers to inactive.",
	func = function(p, triggers)
		local out = {}
		for k,v in ipairs(triggers) do
			v:set_state("active", false)
		end
		return "Deactivated " .. punit(#triggers,'trigger')
	end
})

registerSubCommand({
	name = "tpto",
	aliases = {"tp2", "goto"},
	params = {"target:TriggerSpec=$" },
	description = "Teleport to the center of a trigger's bounds",
	func = function(p, triggers, name)
		minetest.get_player_by_name(p):setpos(one(triggers):get_position())
	end
})

registerSubCommand({
	name = "show",
	params = {"target:TriggerSpec=$" },
	description = "Display info on a triger",
	func = function(p, triggers)
		local out = {}
		for k,v in ipairs(triggers) do
			local spec = v.spec
			table.insert(out, "==[" ..  c(v.state.active and 'green' or 'red', v.id) .. "]===================================================")
			table.insert(out, c('cyan', "Name      ") .. ": " .. spec.name)
			table.insert(out, c('cyan', "File      ") .. ": " .. (v.file or "default"))
			table.insert(out, c('cyan', "Bounds    ") .. ": " .. util.stringify(spec.bounds, true))
			table.insert(out, c('cyan', "Event     ") .. ": " .. util.showSpecThing(spec.event))

			for ak, av in ipairs(spec.conditions) do
				local pz = ak == 1 and (c('cyan', "Conditions") .. ": ") or "            "
				table.insert(out, pz .. tostring(ak) .. '. ' .. util.showSpecThing(av))
			end


			for ak, av in ipairs(spec.actions) do
				local pz = ak == 1 and (c('cyan', "Actions   ") .. ": ") or "            "
				table.insert(out, pz .. tostring(ak) .. '. ' .. util.showSpecThing(av))
			end

		end
		table.insert(out, "========================================================")
		return table.concat(out, "\n")
	end
})

registerSubCommand({
	name = "we:load",
	aliases = {"wel"},
	params = {"target:TriggerSpec=$" },
	description = "Marks a trigger area in worldedit",
	func = function(p, triggers, name)
		local we = require('worldedit')
		local v = one(triggers)
		local b = v:get_bounds()
		if we then
			we.pos1[p] = b[1]
			we.pos2[p] = b[2]
			we.mark_region(p)
		end
	end
})

registerSubCommand({
	name = "we:save",
	aliases = {"wes"},
	params = {"target:TriggerSpec=$" },
	description = "Sets a triggers bounds to the world edit selection",
	func = function(p, triggers, name)
		local we = require('worldedit')
		for k,v in ipairs(triggers) do
			v:change('bounds', {we.pos1[p], we.pos2[p]})
		end
		return "Position of " .. punit(#triggers,'trigger') .. " set to " .. util.stringify({we.pos1[p], we.pos2[p]})
	end
})

registerSubCommand({
	name = "edit:json",
	aliases = {"ej"},
	params = {"target:TriggerSpec=$" },
	description = "Edit triggers spec as JSON",
	func = function(p, triggers, name)
		if #triggers < 1 then return end
		require('ui').show_json_editor(p, triggers[1])
	end
})

registerSubCommand({
	name = "edit",
	aliases = {"e"},
	params = {"target:TriggerSpec=$" },
	description = "Edit triggers spec as JSON",
	func = function(p, triggers, name)
		if #triggers < 1 then return end
		require('ui').show_editor(p, triggers[1])
	end
})

registerSubCommand({
	name = "pause",
	params = {},
	description = "Pause trigger system.",
	func = function(p, triggers, name)
		trigger.pause()
		return "Paused."
	end
})


registerSubCommand({
	name = "unpause",
	params = {},
	description = "Pause trigger system.",
	func = function(p, triggers, name)
		trigger.unpause()
		return "Unaused."
	end
})

local st = {
	bounds = "Bounds",
	b1 = "Position",
	b2 = "Position",
	active = "Boolean",
	event = "String",
	file = "String"
}

registerSubCommand({
	name = "set",
	params = {"target:TriggerSpec=$", "paramater:String", "value:String" },
	description = "Sets a trigger paramater",
	func = function(p, triggers, name, val)
		local pl = minetest.get_player_by_name(p)
		for k,v in ipairs(triggers) do
			-- TODO: Eeh not so fast, we should change it to the refrence... sometimes.
			v:change(name, util.eval_param(val, st[name], pl))
		end
	end
})

registerSubCommand({
	name = "showjson",
	params = {"target:TriggerSpec=$" },
	description = "Show the json spec for a trigger",
	func = function(p, triggers, name, val)
		local out = {}
		for k,v in ipairs(triggers) do
			table.insert(out, "" .. v.id .. ":" .. minetest.write_json(v.spec, true))
		end
		return table.concat(out, "\n")
	end
})

registerSubCommand({
	name = "hide",
	params = {"target:TriggerSpec=$" },
	description = "Show the json spec for a trigger",
	func = function(p, triggers)
		for triggerKey, trigger in pairs(triggers) do
			markers.hideTrigger(trigger)
		end
	end
})

registerSubCommand({
	name = "display",
	aliases = {"d"},
	params = {"target:TriggerSpec=$" },
	description = "Show the json spec for a trigger",
	func = function(p, triggers)

		for triggerKey, trigger in pairs(triggers_by_id) do
			markers.hideTrigger(trigger)
		end

		for triggerKey, trigger in pairs(triggers) do
			markers.drawTrigger(trigger)
		end
	end
})

registerSubCommand({
	name = "reload",
	params = {},
	description = "Reload triggers from disk",
	func = function(...)
		trigger.reload()
	end
})

registerSubCommand({
	name = "save",
	aliases = {"flush"},
	params = {},
	description = "Flush triggers to disk",
	func = function(...)
		trigger.flush()
	end
})

registerSubCommand({
	name = "var:set",
	aliases = {"vs"},
	params = {"variable:String", "value:String"},
	description = "Flush triggers to disk",
	func = function(p, variable, value)
		print("S", variable, value)
		variables[variable] = value
	end
})

registerSubCommand {
	name = "profiler:reset",
	params = {},
	description = "Reset profiling timers.",
	func = function(p)
		for k,v in pairs(triggers_by_id) do
			v.time = 0
		end
	end
}

registerSubCommand {
	name = "profiler:show",
	params = {"from:TriggerSpec=:all"},
	description = "Show timer info.",
	func = function(p, triggers)
		local listing = {}
		if #triggers < 1 then
			return c('red', 'No matching triggers.')
		end
		table.sort(triggers, function(a,b) return a.time < b.time end)
		for k,v in ipairs(triggers) do
			local t = math.floor(v.time/1000)
			if t > 0 then
				local line = '#' .. c('cyan', tostring(v.id))  .. ' - '
				if v.spec.name then line = line .. v.spec.name else line = line .. '[no name]' end
				line = line .. ' - ' .. c('red',t) .. c('white', 'ms')
				table.insert(listing, line)
			end
		end
		return table.concat(listing, "\n")
	end
}


local function command(player, params)
	if #params < 1 then
		local help = {}
		for k,v in pairs(subcommands) do
			table.insert(help, (c('cyan', v.name) .. ' - ' .. v.description))
		end
		return true, table.concat(help, "\n")
	end
	local parts = {}
	for word in params:gmatch('[^ ]+') do parts[#parts+1] = word end
	local subcmd = table.remove(parts, 1)
	local cmd = subcommands[subcmd]
	if not cmd then cmd = aliases[subcmd] end
	if not cmd then
		return false, c('red', "Unknown sub command: ") .. c('cyan', subcmd)
	end

	-- TODO: Fanagle args
	local args = {}
	for i, param in ipairs(cmd.params) do
		local name, type, rest = param:match('([a-z:]+):([a-zA-Z]+)(.*)$')
		local val = parts[i]
		local default = false
		if val == nil and rest:sub(0,1) == '=' then
			val = rest:sub(2)
			default = true
		end
		if type == "TriggerSpec" and val == "$" then
			args[i] = last_spec[player] or {}
		elseif val ~= nil then
			local worked, val = pcall(type_resolver, val, type, player)
			if not worked then
				return false, c('red', "Error") .. ': ' .. val
			end
			args[i] = val
			if type == "TriggerSpec" and not default then
				last_spec[player] = args[i]
			end
		end
	end
	local okay, result = pcall(cmd.func, player, unpack(args))
	if okay then
		if result then
			return true, result
		else
			return true, c('green', "As you wish.")
		end
	end

	if type(result) == "table" then
		return false, c('red', "Error") .. ": " .. result.message
	else
		return false, result
	end
end


minetest.register_chatcommand("trigger", {
	description = "Trigger System",
	privs = {server = true},
	func =  command
})

minetest.register_chatcommand("t", {
	description = "Trigger System",
	privs = {server = true},
	func =  command
})


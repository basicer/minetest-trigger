local minetest = require('minetest')
local event_types = require('registry').event_types
local action_types = require('registry').action_types
local condition_types = require('registry').condition_types
local type_resolver = require('type_resolver')
local util = require('util')
local c = minetest.colorize

local function p(name,...)
	local parts = {}
	table.insert(parts, name)
	table.insert(parts, "[")
	for k,v in ipairs({...}) do
		if k ~= 1 then table.insert(parts, ";") end
		if type(v) == "string" then
			table.insert(parts, minetest.formspec_escape(v))
		elseif type(v) == "table" then
			for kk,vv in ipairs(v) do
				if kk ~= 1 then table.insert(parts, ",") end
				table.insert(parts, tostring(vv))
			end
		else
			table.insert(parts, tostring(v))
		end
	end
	table.insert(parts, "]")
	return table.concat(parts, "")
end

local id = 0
local fsr = {}

minetest.register_on_player_receive_fields(function(p, formname, fields)
	local player = p:get_player_name()
	if fsr[player] then
		if fsr[player].name == formname then
			local cr = fsr[player].coroutine
			if fields.quit then
				fsr[player] = nil
			end
			local okay, err = coroutine.resume(cr, fields)
			if not okay then error(err) end
			if coroutine.status(cr) == "dead" then
				fsr[player] = nil
				print("Closed " .. player)
			end
		else
			fsr[player] = nil
		end
	else
		print("M " .. player)
		print(dump(fsr))
	end
end)

local function show(player, fs)
	local name
	if fsr[player] then
		name = fsr[player].name
	else
		id = id + 1
		name = "trigger:ui:" .. tostring(id)
		fsr[player] = { name=name, coroutine=coroutine.running() }
	end
	minetest.show_formspec(player, name, table.concat(fs, "\n"))
end

local function close(player)
	minetest.show_formspec(player, "", "")
	fsr[player] = nil
end


local function findIdx(tbl, val)
	for k,v in ipairs(tbl) do
		if v == val then return k end
	end
	return -1
end

local function frm_json_editor(player, trigger)
	local message = ""
	local text = minetest.write_json(trigger.spec, true)
	while true do
		local lines = {
			p("size", {15, 10}),

			p("label", {0, 0}, c("green", "Editing Trigger: ") .. trigger.spec.name),
			p("label", {5, 0}, message),
			p("box", {0,0}, {15,1}, "#000000FF"),
			p("box", {0,1}, {15,9}, "#000000FF"),
			p("textarea", {0.25,1}, {15,9}, "data", "JSON Spec", text),
			p("button", {0,9},{5,1}, "save", c('green',"Save")),
			p("button_exit", {5,9},{5,1}, "exit", c('red',"Cancel"))
		}
		print(dump(lines))
		show(player, lines)
		local fields = coroutine.yield()
		if fields.save then
			text = fields.data
			local table = minetest.parse_json(fields.data)
			if not table then
				message = c('red', "Couln't parse JSON")
			else
				local okay, x = pcall(trigger.import, trigger, table)
				if okay then
					close(player)
					return
				else
					message = c('red', "Error: " .. x)
				end
			end

		end
		if fields.quit then
			close(player)
			return
		end
	end
end

local function keyz(tbl, fn)
	local out = {}
	for k,v in pairs(tbl) do
		if not fn or fn(v) then
			table.insert(out, v.name)
		end
	end
	table.sort(out)
	return out
end

local function frm_editor(player, trigger)
	local offset = 0
	while true do
		local event_dd = keyz(event_types)
		local condition_dd = keyz(condition_types)
		local action_dd
		if trigger.spec.event.type == "Static" then
			action_dd = keyz(action_types, function(v) return v.uses_static end)
		else
			action_dd = keyz(action_types, function(v) return not v.uses_static end)
		end

		local lines = {}
		local top = 0 - math.floor(offset/10)
		local function e(...) if top > -1 and top < 9 then table.insert(lines,p(...)) end end
		local function a(...) table.insert(lines,p(...)) end
		local function advance(n) top = top + n end

		a("size", {15, 10})
		--scrollbar[<X>,<Y>;<W>,<H>;<orientation>;<name>;<value>]
		a("scrollbar", {14.5,1},{0.5,9}, "vertical", "scroll", offset)

		e("container", {0,top})
		e("label", {0, 0}, c(trigger.state.active and "green" or "red", "Editing Trigger: ") .. trigger.spec.name)
		e("checkbox", {10,0}, "active", "Active", tostring(trigger.state.active))
		e("button", {13,0}, {2,1}, "json", "JSON")
		e("container_end")
		advance(1)
		e("container", {0,top})
		e("label", {0, 0}, "Event:")
		e("dropdown", {2, 0}, 5, "event_type", event_dd, findIdx(event_dd, trigger.spec.event.type))
		local eid = 0
		for k,v in pairs(trigger:get_event_type().properties or {}) do
			eid = eid + 1
			e("label", {0, eid}, k)
			e("label", {8, eid}, v.type .. '(' .. tostring(v.env or v.default) .. ')')
			e("field", {2.1, eid}, {5,1}, "event_" .. k, "", trigger.spec.event[k] or "")
			e("field_close_on_enter", "event_" .. k, "false")
		end
		e("box", {-0.1,-0.1}, {15,eid+1}, "#00FF0099")
		e("container_end")
		advance(eid+1)


		e("container", {0,top})
		local cid = 0
		local ctop = 0
		for k,v in ipairs(trigger.spec.conditions) do
			cid = cid + 1
			e("label", {0, ctop}, "Condition " .. tostring(k))
			local scid = tostring(cid)
			e("dropdown", {2, ctop}, 5, "condition_" .. scid .. "_type", condition_dd, findIdx(condition_dd, v.type))
			e("button", {7, ctop}, {1,1}, "condition_" .. scid .. "_del", c('red', 'X'))
			e("checkbox", {8, ctop}, "condition_" .. scid .. "_invert", "Invert", tostring(v.invert))
			local at = condition_types[util.normalize(v.type)]
			for ak, av in pairs(at.properties or {}) do
				if not av.hidden and ak ~= "invert" then
					ctop = ctop + 1
					e("label", {0, ctop}, ak)
					e("label", {8, ctop}, av.type .. '(' .. tostring(av.env or av.default or 'nil') .. ')')
					if type(av.options) == "table" then
						e("dropdown", {2, ctop}, 5, "condition_" .. scid .. "_" .. ak, av.options, findIdx(av.options, v[ak] or av.default))
					else
						e("field", {2.1, ctop}, {5,1}, "condition_" .. scid .. "_" .. ak, "", v[ak] or "")
						e("field_close_on_enter", "condition_" .. scid .. "_" .. ak, "false")
					end
				end
			end
			ctop = ctop + 1
		end
		e("button", {11, 0}, {3,1}, "add_condition", "Add Condition")
		if ctop < 1 then ctop = 1 end
		e("box", {-0.1,-0.1}, {15,ctop}, "#FF00FF99")
		e("container_end")
		advance(ctop-1)



		local aid = 0
		local actions = trigger.spec.actions
		for k,v in ipairs(actions) do
			local atop = 0
			e("container", {0,top})
			aid = aid + 1
			atop = atop + 1
			e("label", {0, atop}, "Action " .. tostring(k))
			local said = tostring(aid)
			e("dropdown", {2, atop}, 5, "action_" .. said .. "_type", action_dd, findIdx(action_dd, v.type))
			e("button", {7, atop}, {1,1}, "action_" .. said .. "_del", c('red', 'X'))
			if k ~= 1 then e("button", {8, atop}, {0.5,1}, "action_" .. said .. "_up", c('green', '↑')) end
			if k ~= #actions then e("button", {8.3, atop}, {0.5,1}, "action_" .. said .. "_down", c('green', '↓')) end
			local at = action_types[util.normalize(v.type)]
			for ak, av in pairs(at.properties or {}) do
				if not av.hidden then
					atop = atop + 1
					local avv = actions[k][ak]
					local avs = type_resolver(actions[k][ak], 'String')
					local field_name = "action_" .. said .. "_" .. ak
					if av.type == 'Table' or av.multiline then
						e("textarea", {2.1, atop}, {10,3}, field_name, ak, avs or "")
						atop = atop + 2
					elseif type(av.options) == "Table" then
						e("dropdown", {2, atop}, 5, field_name, av.options, findIdx(av.options, avs or av.default))
					elseif av.type == 'Boolean' and (type(avv) == 'boolean' or type(avv) == 'nil') then
						e("checkbox", {2, atop-0.5}, field_name, ak, not not avs)
					else
						e("label", {0, atop}, ak)
						e("label", {8, atop}, av.type .. '(' .. tostring(v.default) .. ')')
						e("field", {2.1, atop}, {5,1}, field_name, "", avs or "")
					end
					e("field_close_on_enter", field_name, "false")
				end
			end
			e("box", {0-0.1,1-0.1}, {15,atop+0.1}, "#FF000099")
			e("container_end")
			advance(atop)
		end
		if #actions == 0 then
			advance(1)
		end
		e("container", {0,top})
		e("button", {11, 0}, {3,1}, "add_action", "Add Action")
		e("container_end")



		print(dump(lines))
		show(player, lines)
		local fields = coroutine.yield()
		print(dump(fields))
		if fields.quit then return end
		if fields.json then frm_json_editor(player, trigger) end
		if fields.active then
			trigger:set_state("active", fields.active == "true")
		end

		if fields.scroll then
			local se = minetest.explode_scrollbar_event(fields.scroll)
			offset = se.value
		end

		if fields.event_type then
			trigger:change("event", fields.event_type)
		end

		for k,v in pairs(trigger:get_event_type().properties or {}) do
			local val = fields["event_" .. tostring(k)]
			print(k,val)
			if val and val ~= "" then
				trigger.spec.event[k] = val
				trigger:refresh_event()
			end
		end

		if fields.add_action then
			table.insert(trigger.spec.actions, {type="Nothing"})
		end

		if fields.add_condition then
			table.insert(trigger.spec.conditions, {type="True"})
		end

		for k,v in ipairs(trigger.spec.actions) do
			local val = fields["action_" .. tostring(k) .. "_type" ]
			if val and val ~= "" then
				if trigger.spec.actions[k].type ~= val then
					v = {type=val}
					trigger.spec.actions[k] = v
				end
			end
			if fields["action_" .. tostring(k) .. "_del"] then
				table.remove(trigger.spec.actions, k)
				break
			end
			if fields["action_" .. tostring(k) .. "_down"] then
				trigger.spec.actions[k] = trigger.spec.actions[k+1]
				trigger.spec.actions[k+1] = v
				break
			end
			if fields["action_" .. tostring(k) .. "_up"] then
				trigger.spec.actions[k] = trigger.spec.actions[k-1]
				trigger.spec.actions[k-1] = v
				break
			end
			local at = action_types[util.normalize(v.type)]
			for ak, av in pairs(at.properties or {}) do
				local val = fields["action_" .. tostring(k) .. "_" .. ak]
				if val and val ~= "" then
					local numeric = tonumber(val)
					if numeric ~= nil then
						trigger.spec.actions[k][ak] = numeric
					elseif val == "true" then
						trigger.spec.actions[k][ak] = true
					elseif val == "false" then
						trigger.spec.actions[k][ak] = false
					else
						trigger.spec.actions[k][ak] = val
					end
				end
			end
		end


		for k,v in ipairs(trigger.spec.conditions) do
			local val = fields["condition_" .. tostring(k) .. "_type" ]
			if val and val ~= "" then
				if trigger.spec.conditions[k].type ~= val then
					v = {type=val}
					trigger.spec.conditions[k] = v
				end
			end
			if fields["condition_" .. tostring(k) .. "_del"] then
				table.remove(trigger.spec.conditions, k)
				break
			end
			if fields["condition_" .. tostring(k) .. "_invert"] ~= nil then
				trigger.spec.conditions[k].invert = ("true" == fields["condition_" .. tostring(k) .. "_invert"])
			end
			local ct = condition_types[util.normalize(v.type)]
			for ak, av in pairs(ct.properties or {}) do
				local val = fields["condition_" .. tostring(k) .. "_" .. ak]
				if val and val ~= "" then
					trigger.spec.conditions[k][ak] = val
				end
			end
		end

	end
end



function ui.show_json_editor(player, trigger)
	coroutine.resume(coroutine.create(frm_json_editor), player, trigger)
end

function ui.show_editor(player, trigger)
	print(coroutine.resume(coroutine.create(frm_editor), player, trigger))
end

if not Global.editor_mode then
	return
end

if true then
	return
end

core:module("CoreMissionManager")
core:import("CoreMissionScriptElement")
core:import("CoreEvent")
core:import("CoreClass")
core:import("CoreDebug")
core:import("CoreCode")
core:import("CoreTable")
require("core/lib/managers/mission/CoreElementDebug")
local Mission = MissionManager
function Mission:parse(params, stage_name, offset, file_type)
	local file_path, activate_mission
	if CoreClass.type_name(params) == "table" then
		file_path = params.file_path
		file_type = params.file_type or "mission"
		activate_mission = params.activate_mission
		offset = params.offset
	else
		file_path = params
		file_type = file_type or "mission"
	end
	CoreDebug.cat_debug("gaspode", "MissionManager", file_path, file_type, activate_mission)
	if not DB:has(file_type, file_path) then
		Application:error("Couldn't find", file_path, "(", file_type, ")")
		return false
	end
	local reverse = string.reverse(file_path)
	local i = string.find(reverse, "/")
	local file_dir = string.reverse(string.sub(reverse, i))
	local continent_files = self:_serialize_to_script(file_type, file_path)
	continent_files._meta = nil
	self._start_id = 100000
	self._start_ids = {}
	local i = 1
	for name, data in pairs(continent_files) do
		self._start_ids[name] = self._start_id * i
		i = i + 1
		if not managers.worlddefinition:continent_excluded(name) then
			self:_load_mission_file(name, file_dir, data)
		end
	end
	self._activate_script = activate_mission
	managers.editor.managers.mission:set_elements_vis()
	return true
end

function Mission:store_element_id(continent, id)
	self._ids = self._ids or {}
	self._ids[continent] = self._ids[continent] or {}
	self._ids[continent][id] = true
end

function Mission:delete_element_id(continent, id)
	self._ids[continent][id] = nil
end

function Mission:get_new_id(continent)
	if continent then		
		self._ids = self._ids or {}
		self._ids[continent] = self._ids[continent] or {}
		local tbl = self._ids[continent]
		local i = self._start_ids[continent]
		while tbl[i] do
			i = i + 1
		end
		tbl[i] = true
		return i
	else
		_G.BeardLibEditor:log("[ERROR] continent needed for element id")
	end
end

function Mission:activate()
	if not self._activated then
		self._activated = true
		self:_activate_mission(self._activate_script)
	end
end

function Mission:_load_mission_file(name, file_dir, data)
	self._missions = self._missions or {}
	local file_path = file_dir .. data.file
	self._missions[name] = self:_serialize_to_script("mission", file_path) 
	for sname, data in pairs(self._missions[name]) do	
		data.name = sname
		data.continent = name
		self:_add_script(data)
	end
end

function Mission:set_element(element, old_script)
	if not element then
		return
	end
	local new_continent = self._scripts[element.script]._continent
	local old_continent = old_script and self._scripts[old_script]._continent
	if old_script and element.script ~= old_script then
		if new_continent ~= old_continent then
			self:delete_links(element.id, true)
			self:delete_element_id(old_continent, element.id)
			local new_id = self:get_new_id(new_continent)
			self:store_element_id(new_continent, new_id)
			element.id = new_id
		end

		self._scripts[element.script]._elements[element.id] = self._scripts[old_script]._elements[element.id]
		self._scripts[old_script]._elements[element.id] = nil
		for k, s_element in pairs(self._missions[new_continent][element.script].elements) do
			if s_element.id == element.id then
				self._missions[new_continent][element.script].elements[k] = nil
			end
		end
	end
	for k, s_element in pairs(self._missions[new_continent][element.script].elements) do
		if s_element.id == element.id then
			self._missions[new_continent][element.script].elements[k] = element
		end
	end
	local script_element = self._scripts[element.script]._elements[element.id]
	script_element._values = _G.deep_clone(element.values)
	if script_element._finalize_values then
		script_element:_finalize_values(script_element._values)
	end
end

--Fucking hell overkill
function core:import_without_crashing(module_name)
	if self.__filepaths[module_name] ~= nil then
		local fp = self.__filepaths[module_name]
		require(fp)
		local m = self.__modules[module_name]
		rawset(getfenv(2), module_name, m)
		return m
	end
end

function Mission:add_element(element)
	local script
	local script_name
	local mission = self._missions.world
	local m = "Core" .. element.class
	if rawget(_G, "CoreMissionManager")[m] or core:import_without_crashing(m) then
		element.module = m
	end
	if element.script then
		for _, v in pairs(self._missions) do 
			if mission[element.script] then
				script = mission[element.script]
				script_name = element.script
				break	
			end
		end
	else
		_G.BeardLibEditor:log("[ERROR] Something went wrong when trying to add the element(1)")
	end
	if not script then
		if not mission then
			for _, v in pairs(self._missions) do mission = v break end
		end
		if mission then
			script = mission.default
			script_name = "default"
			if not script then
				for k, v in pairs(mission) do
					if type(v) == "table" then
						script = v
						script_name = k
						break
					end
				end
			end
		else
			_G.BeardLibEditor:log("[ERROR] Something went wrong when trying to add the element(2)")
		end
	end

	if script then
		table.insert(script.elements, element)
		return self._scripts[script_name]:create_element(element, true)
	else
		_G.BeardLibEditor:log("[ERROR] No mission scripts found in the map! cannot add elements")
	end
end

function Mission:delete_element(id)	
	self:delete_links(id, true)
	for m_name, mission in pairs(self._missions) do
		for s_name, script in pairs(mission) do
			for i, element in pairs(script.elements) do
				if element.id == id then
					_G.BeardLibEditor:log("Deleting element %s in mission %s in script %s", tostring(element.editor_name), tostring(m_name), tostring(s_name))
					self._scripts[s_name]:delete_element(element)
					script.elements[i] = nil
					return
				end
			end
		end
	end
end

_G.Hooks:PreHook(MissionScript, "init", "BeardLibEditorMissionScriptPreInit", function(self, data)
	self._continent = data.continent
end)

function Mission:execute_element(element)
    for _, script in pairs(self._scripts) do
        if script._elements[element.id] then
            script:execute_element(element)
        end
    end
end

function Mission:get_executors(element)
	local executors = {}
	if element then
		for _, script in pairs(self._missions) do
			for _, tbl in pairs(script) do
				if tbl.elements then
					for i, s_element in pairs(tbl.elements) do
						if s_element.values.on_executed then
							for _, exec in pairs(s_element.values.on_executed) do									
								if exec.id == element.id then
									table.insert(executors, s_element)
								end
							end
						end
					end
				end
			end	
		end
	end
	return executors
end

function Mission:delete_links(id, is_element)
	for _, link in pairs(managers.mission:get_links_paths(id, is_element)) do
		if tonumber(link.key) then
			table.remove(link.tbl, link.key)
		elseif link.upper_tbl[link.upper_k][link.key] == id then
            link.upper_tbl[link.upper_k][link.key] = nil
        else
			table.delete(link.upper_tbl[link.upper_k], link.tbl)
		end
	end
end

local units_upper_keys = {"unit_ids", "graph_ids", "nav_segs", "digital_gui_unit_ids", "obstacle_list"}
local units_keys = {"unit_id", "notify_unit_id", "camera_u_id", "att_unit_id"}
local elements_upper_keys = {
    "elements", "instigator_ids", "spawn_unit_elements", "use_shape_element_ids", "rules_element_ids", "spawn_groups", "spawn_points", "sequence", "followup_elements", "spawn_instigator_ids", "Stopwatch_value_ids"
}
local elements_keys = {{upper_k = "on_executed", k = "id"}, "counter_id"}
function Mission:identify_key_and_upper_key(upper_k, k)
    local current_is_unit, current_is_element
    for _, key in pairs(units_upper_keys) do
        if upper_k == key then
            current_is_unit = true
            break
        end
    end
    if not current_is_unit then
        for _, key in pairs(units_keys) do
            if k == key then
                current_is_unit = true
                break
            end
        end
    end
    if not current_is_unit then
        for _, key in pairs(elements_upper_keys) do
            if upper_k == key then
                current_is_element = true
                break
            end
        end
        if not current_is_element then
            for _, key in pairs(elements_keys) do
				local tbl = type(key) == "table"
                if k == (tbl and key.k or key) and (not tbl or upper_k == key.upper_k) then
                    current_is_element = true
                    break
                end
            end
        end
    end
    return current_is_unit, current_is_element
end

function Mission:is_linked(id, is_element, upper_k, tbl, stop)
    for k, v in pairs(tbl) do
        local current_is_unit, current_is_element = self:identify_key_and_upper_key(upper_k, k)
        if not stop and type(v) == "table" then
            local new_upper_key = not tonumber(k) and k or upper_k
            if self:is_linked(id, is_element, new_upper_key, v) then
                return true
            end
        elseif ((is_element and current_is_element) or (not is_element and current_is_unit)) and v == id then
            return true
        end
    end
end

function Mission:get_links(id, is_element)
 	if not tonumber(id) or tonumber(id) < 0 then
		return {}
	end
	local modifiers = {}
	for _, script in pairs(self._missions) do
		for _, tbl in pairs(script) do
			if tbl.elements then
				for _, element in pairs(tbl.elements) do
					if self:is_linked(id, is_element, "values", element.values) then
						table.insert(modifiers, element)
					end
				end
			end
		end
	end
	return modifiers
end

function Mission:get_links_paths(id, is_element, elements)   
    if not tonumber(id) or tonumber(id) < 0 then
        return {}
    end
    local id_paths = {}
	local function GetLinks(upper_k, upper_tbl, tbl, element, stop)
		upper_tbl = upper_tbl or element
        for k, v in pairs(tbl) do
            local current_is_unit, current_is_element = self:identify_key_and_upper_key(upper_k, k)
            if not stop and type(v) == "table" then
                local new_upper_key = not tonumber(k) and k or upper_k
                local new_upper_tbl = not tonumber(k) and tbl or upper_tbl
                GetLinks(new_upper_key, new_upper_tbl, v, element)
            elseif ((is_element and current_is_element) or (not is_element and current_is_unit)) and v == id then
                table.insert(id_paths, {tbl = tbl, key = k, upper_k = upper_k, upper_tbl = upper_tbl, element = element})
            end
        end
    end
    if elements then
        for _, element in pairs(elements) do
            if element.mission_element_data and element.mission_element_data.values then
                GetLinks("values", nil, element.mission_element_data.values)
            end
        end
    else
        for _, script in pairs(self._missions) do
            for _, tbl in pairs(script) do
                if tbl.elements then
                    for k, element in pairs(tbl.elements) do
                        GetLinks("values", nil, element.values, element)
                    end
                end
            end
        end
    end
    return id_paths
end

function Mission:get_mission_element(id)
	for _, script in pairs(self._missions) do
		for _, tbl in pairs(script) do
			if tbl.elements then
				for i, element in pairs(tbl.elements) do	
					if element.id == id then
						return element
					end
				end
			end
		end
	end
	return nil
end

--Instance elements--
local MScript = MissionScript
function MScript:_preload_instance_class_elements(prepare_mission_data)
	prepare_mission_data.instance_name = nil
	for _, instance_mission_data in pairs(prepare_mission_data) do
		for _, element in ipairs(instance_mission_data.elements) do
			self:_element_class(element.module, element.class)
		end
	end
end

function MScript:create_instance_elements(prepare_mission_data)
	local new_elements = {}
	local instance_name = prepare_mission_data.instance_name
	prepare_mission_data.instance_name = nil
	for _, instance_mission_data in pairs(prepare_mission_data) do
		new_elements = self:_create_elements(instance_mission_data.elements, instance_name)
	end
	return new_elements
end
--Instance elements code end

function MScript:_create_elements(elements, instance_name)
	local new_elements = {}
	for _, element in pairs(elements) do
		element.instance = instance_name
		new_elements[element.id] = self:create_element(element, false, instance_name)
	end
	return new_elements
end

function MScript:create_element(element, return_unit, instance_name)
	local class = element.class	
	if not element.id then
		element.id = managers.mission:get_new_id(self._continent)
	end
	managers.mission:store_element_id(self._continent, element.id)
	local new_element = self:_element_class(element.module, class):new(self, _G.deep_clone(element))
	element.script = self._name
	new_element.class = element.class
	new_element.module = element.module
	new_element.instance = instance_name
	self._elements[element.id] = new_element
	self._element_groups[class] = self._element_groups[class] or {}
	table.insert(self._element_groups[class], new_element)
	local new_unit = not instance_name and self:create_mission_element_unit(element)
	if return_unit then
		return new_unit
	end
	return new_element
end

function MScript:execute_element(element)
	self._elements[element.id]:on_executed(managers.player:player_unit())
end

function MScript:create_mission_element_unit(element)
	local enabled = element.values.position ~= nil
	element.values.position = element.values.position or Vector3(math.random(9999), math.random(9999), 0)
	element.values.rotation = type(element.values.rotation) ~= "number" and element.values.rotation or Rotation()

	local unit_name = "units/mission_element/element"
	local unit = World:spawn_unit(Idstring(unit_name), element.values.position, element.values.rotation)
	unit:mission_element():set_enabled(enabled, true)
    unit:unit_data().position = element.values.position   
   	unit:unit_data().rotation = element.values.rotation 
    unit:unit_data().local_pos = Vector3()
    unit:unit_data().local_rot = Rotation()
	unit:mission_element().element = element
	unit:mission_element():update_text()
	if managers.editor then
		managers.editor.managers.mission:add_element_unit(unit)
	end
	return unit
end

function MScript:delete_element(element)
	local id = element.id
	managers.mission:delete_element_id(self._continent, id)
	self._elements[id]:set_enabled(false)
	self._elements[id] = nil
	self._element_groups[element.class] = nil
end

function MScript:debug_output(debug, color)
	if managers.editor then
		managers.editor.managers.console:LogMission(debug)
	end
end
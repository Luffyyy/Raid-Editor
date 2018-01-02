StaticEditor = StaticEditor or class(EditorPart)
local Static = StaticEditor
function Static:init(parent, menu)
    Static.super.init(self, parent, menu, "Selection")
    self._selected_units = {}
    self._disabled_units = {}
    self._nav_surfaces = {}
    self._ignore_raycast = {}
    self._nav_surface = Idstring("core/units/nav_surface/nav_surface")
    self._widget_slot_mask = World:make_slot_mask(1)
end

function Static:enable()
    self:bind_opt("DeleteSelection", callback(self, self, "delete_selected_dialog"))
    self:bind_opt("CopyUnit", callback(self, self, "CopySelection"))
    self:bind_opt("PasteUnit", callback(self, self, "Paste"))
    self:bind_opt("TeleportToSelection", callback(self, self, "KeyFPressed"))
    local menu = self:Manager("menu")
    self:bind_opt("ToggleRotationWidget", callback(menu, menu, "toggle_widget", "rotation"))
    self:bind_opt("ToggleMoveWidget", callback(menu, menu, "toggle_widget", "move"))
end

function Static:mouse_pressed(button, x, y)
    if button == Idstring("0") then
        self._parent:reset_widget_values()
        local from = self._parent:get_cursor_look_point(0)
        local to = self._parent:get_cursor_look_point(100000)
        local unit = self._parent:widget_unit()
        if unit then
            if self._parent._move_widget:enabled() then
                local ray = World:raycast("ray", from, to, "ray_type", "widget", "target_unit", self._parent._move_widget:widget())
                if ray and ray.body then
                    if (alt() and not ctrl()) then self:Clone() end
                    self._parent._move_widget:add_move_widget_axis(ray.body:name():s())      
                    self._parent._move_widget:set_move_widget_offset(unit, unit:rotation())
                    self._parent._using_move_widget = true
                end
            end
            if self._parent._rotate_widget:enabled() and not self._parent._using_move_widget then
                local ray = World:raycast("ray", from, to, "ray_type", "widget", "target_unit", self._parent._rotate_widget:widget())
                if ray and ray.body then
                    self._parent._rotate_widget:set_rotate_widget_axis(ray.body:name():s())
                    self._parent._rotate_widget:set_world_dir(ray.position)
                    self._parent._rotate_widget:set_rotate_widget_start_screen_position(self._parent:world_to_screen(ray.position):with_z(0))
                    self._parent._rotate_widget:set_rotate_widget_unit_rot(self._selected_units[1]:rotation())
                    self._parent._using_rotate_widget = true
                end
            end         
        end  
        if not self._parent._using_rotate_widget and not self._parent._using_move_widget then
            self:select_unit()
        end
    elseif button == Idstring("1") then
        self:select_unit(true)
        self._mouse_hold = true
    end  
end

function Static:update_grid_size() self:set_unit() end
function Static:deselect_unit(menu, item) self:set_unit(true) end
function Static:mouse_released(button, x, y) self._mouse_hold = false end

function Static:loaded_continents()
    self._nav_surfaces = {}
    for _, unit in pairs(managers.worlddefinition._all_units) do
        if alive(unit) and unit:name() == self._nav_surface then
            table.insert(self._nav_surfaces, unit)
        end
    end
end

function Static:build_default_menu()
    Static.super.build_default_menu(self)
    self._editors = {}
    self:SetTitle("Selection")
    self:Divider("No selection >.<", {bordr_left = false})
    self:Button("World Menu", ClassClbk(self:Manager("world"), "Switch"))
end

function Static:build_quick_buttons(cannot_be_saved)
    self:SetTitle("Selection")
    local quick_buttons = self:Group("QuickButtons")
    self:Button("Deselect", callback(self, self, "deselect_unit"), {group = quick_buttons})
    self:Button("DeleteSelection", callback(self, self, "delete_selected_dialog"), {group = quick_buttons})
    if not cannot_be_saved then
        self:Button("CreatePrefab", callback(self, self, "add_selection_to_prefabs"), {group = quick_buttons})
        self:Button("AddRemovePortal", callback(self, self, "addremove_unit_portal"), {group = quick_buttons, text = "Add To / Remove From Portal", visible = false})
        local group = self:Group("Group", {visible = false}) --lmao
        self:build_group_options()
    end
end

function Static:build_group_options()
    local selected_unit = self:selected_unit()
    local selected_units = self:selected_units()
    local all_same_continent
    if #selected_units > 1 then
        all_same_continent = true
        for _, unit in pairs(selected_units) do
        	if not selected_unit:unit_data().unit_id or not selected_unit:unit_data().continent then
        		all_same_continent = false
        		return
        	end
            if selected_unit:unit_data().continent ~= unit:unit_data().continent then
                all_same_continent = false
                break
            end
        end
    end
    local group = self:GetItem("Group")
    group:ClearItems()
    group:SetVisible(all_same_continent)
    if all_same_continent then
        if self._selected_group then
            self:Divider("GroupToolTip", {text = "Hold ctrl and press mouse 2 to add units to/remove units from group", group = group})
            self:TextBox("GroupName", callback(self, self, "set_group_name"), self._selected_group.name, {group = group})
            self:Button("UngroupUnits", callback(self, self, "remove_group"), {group = group})
        else
            self:Button("GroupUnits", callback(self, self, "add_group"), {group = group})
        end
    end
end

function Static:build_unit_editor_menu()
    Static.super.build_default_menu(self)
    self:SetTitle("Selection")
    local other = self:Group("Main")    
    self:build_positions_items()
    self:TextBox("Name", callback(self, self, "set_unit_data"), nil, {group = other, help = "the name of the unit"})
    self:TextBox("Id", callback(self, self, "set_unit_data"), nil, {group = other, enabled = false})
    self:PathItem("UnitPath", callback(self, self, "set_unit_data"), nil, "unit", true, function(unit)
        return BeardLibEditor.Utils:GetUnitType(unit) ~= "being"
    end, false, {group = other})
    self:ComboBox("Continent", callback(self, self, "set_unit_data"), self._parent._continents, 1, {group = other})
    self:Toggle("Enabled", callback(self, self, "set_unit_data"), true, {group = other, help = "Setting the unit enabled or not[Debug purpose only]"})
    self:Toggle("HideOnProjectionLight", callback(self, self, "set_unit_data"), false, {group = other})
    self:Toggle("DisableShadows", callback(self, self, "set_unit_data"), false, {group = other})
    self:Toggle("DisableCollision", callback(self, self, "set_unit_data"), false, {group = other})
    self:Toggle("DisableOnAIGraph", callback(self, self, "set_unit_data"), false, {group = other})
    self:build_extension_items()
end

function Static:build_extension_items()
    self._editors = {}
    for k, v in pairs({light = EditUnitLight, ladder = EditLadder, editable_gui = EditUnitEditableGui, zipline = EditZipLine, wire = EditWire, mesh_variation = EditMeshVariation, ai_data = EditAIData}) do
        self._editors[k] = v:new():is_editable(self)
    end
end

function Static:build_positions_items(cannot_be_saved)
    self._editors = {}
    self:build_quick_buttons(cannot_be_saved)
    local transform = self:Group("Transform")
    self:Button("IgnoreRaycastOnce", function()
        for _, unit in pairs(self:selected_units()) do
            if unit:unit_data().unit_id then
                self._ignore_raycast[unit:unit_data().unit_id] = true
            end
        end      
    end, {group = transform})
    self:AxisControls(callback(self, self, "set_unit_data"), {group = transform, step = self:Manager("opt")._menu:GetItem("GridSize"):Value()})
end

function Static:update_positions()
    local unit = self._selected_units[1]
    if unit then
        if #self._selected_units > 1 or not unit:mission_element() then
            self:SetAxisControls(unit:position(), unit:rotation())
            self:Manager("instances"):update_positions()
            if self:Manager("world"):is_world_unit(unit:name()) then
                self:Manager("world"):update_positions()
            end
            for i, control in pairs(self._axis_controls) do
                self[control]:SetStep(i < 4 and self._parent._grid_size or self._parent._snap_rotation)
            end
        elseif unit:mission_element() and self:Manager("mission")._current_script then
            self:Manager("mission")._current_script:update_positions(unit:position(), unit:rotation())
        end
        for _, unit in pairs(self:selected_units()) do
            if unit:editable_gui() then
                unit:editable_gui():set_blend_mode(unit:editable_gui():blend_mode())
            end
        end
    end
    for _, editor in pairs(self._editors) do
        if editor.update_positions then
            editor:update_positions(unit)
        end
    end
    if self._built_multi then
        self:SetTitle("Selection - " .. tostring(#self._selected_units))
    end
    self:recalc_all_locals()
end

function Static:set_unit_data()
    self._parent:set_unit_positions(self:AxisControlsPosition())
    self._parent:set_unit_rotations(self:AxisControlsRotation())

    if #self._selected_units == 1 then    
        if not self:GetItem("Continent") then
            return
        end 
        local unit = self._selected_units[1]
        if unit:unit_data() and unit:unit_data().unit_id then
            local prev_id = unit:unit_data().unit_id
            local ud = unit:unit_data()
            managers.worlddefinition:set_name_id(unit, self:GetItem("Name"):Value())
            local old_continent = unit:unit_data().continent
            ud.continent = self:GetItem("Continent"):SelectedItem()
            local new_continent = unit:unit_data().continent
            local path_changed = unit:unit_data().name ~= self:GetItem("UnitPath"):Value()
            local u_path = self:GetItem("UnitPath"):Value()
            ud.name = (u_path and u_path ~= "" and u_path) or ud.name
            ud.unit_id = self:GetItem("Id"):Value()
            ud.disable_shadows = self:GetItem("DisableShadows"):Value()
            ud.disable_collision = self:GetItem("DisableCollision"):Value()
            ud.hide_on_projection_light = self:GetItem("HideOnProjectionLight"):Value()
            ud.disable_on_ai_graph = self:GetItem("DisableOnAIGraph"):Value()
            unit:set_enabled(self:GetItem("Enabled"):Value())
            for _, editor in pairs(self._editors) do
                if editor.set_unit_data and editor:editable(unit) then
                    editor:set_unit_data()
                end
            end
            Utils:RemoveAllNumberIndexes(ud, true) --Custom xml issues happen in here also 😂🔫 

            ud.lights = BeardLibEditor.Utils:LightData(unit)
            ud.triggers = BeardLibEditor.Utils:TriggersData(unit)
            ud.editable_gui = BeardLibEditor.Utils:EditableGuiData(unit)
            ud.ladder = BeardLibEditor.Utils:LadderData(unit)
            ud.zipline = BeardLibEditor.Utils:ZiplineData(unit)
            unit:set_editor_id(ud.unit_id)
            managers.worlddefinition:set_unit(prev_id, unit, old_continent, new_continent)
            for index = 0, unit:num_bodies() - 1 do
                local body = unit:body(index)
                if body then
                    body:set_collisions_enabled(not ud.disable_collision)
                    body:set_collides_with_mover(not ud.disable_collision)
                end
            end       
            unit:set_shadows_disabled(unit:unit_data().disable_shadows)     
            if PackageManager:has(Idstring("unit"), Idstring(ud.name)) and path_changed then
                self._parent:SpawnUnit(ud.name, unit)                
                self._parent:DeleteUnit(unit)
            end
        end
    else            
        for _, unit in pairs(self._selected_units) do
            local ud = unit:unit_data()
            managers.worlddefinition:set_unit(ud.unit_id, unit, ud.continent, ud.continent)
        end
    end
end

function Static:StorePreviousPosRot()
    if #self._selected_units > 1 then
        for _, unit in pairs(self._selected_units) do
            unit:unit_data()._prev_pos = unit:position()
            unit:unit_data()._prev_rot = unit:rotation()
        end
    end
end

function Static:set_group_name(menu, item)
    local exists
    for _, group in pairs(managers.worlddefinition._continent_definitions[self._selected_group.continent].editor_groups) do
        if group.name == item:Value() then
            exists = true
        end
    end
    if not exists then
        self._selected_group.name = item:Value()
    end
end

function Static:remove_group(menu, item)
	if self._selected_group then
	    table.delete(managers.worlddefinition._continent_definitions[self._selected_group.continent].editor_groups, self._selected_group)
	    self._selected_group = nil
	    self:build_group_options()
	end
end

function Static:add_group(menu, item)
    local unit = self:selected_unit()
    BeardLibEditor.managers.InputDialog:Show({title = "Group Name", text = unit:unit_data().name_id, callback = function(name)
        local continent = managers.worlddefinition:get_continent_of_static(unit)
        local exists
        for _, group in pairs(continent.editor_groups) do
            if group.name == name then
                exists = true
            end
        end
        if not exists then
            local group = {continent = unit:unit_data().continent, reference = unit:unit_data().unit_id, name = name, units = {}}
            for _, unit in pairs(self:selected_units()) do
                table.insert(group.units, unit:unit_data().unit_id)
            end
            table.insert(continent.editor_groups, group)        
            self._selected_group = group
            self:build_group_options()
        end
    end})
end


function Static:add_selection_to_prefabs(menu, item, prefab_name)
    local remove_old_links
    local name_id = self._selected_units[1]:unit_data().name_id
    BeardLibEditor.managers.InputDialog:Show({title = "Prefab Name", text = #self._selected_units == 1 and name_id ~= "none" and name_id or prefab_name or "Prefab", callback = function(prefab_name, menu)
    	if prefab_name:len() > 200 then
    		BeardLibEditor.managers.Dialog:Show({title = "ERROR!", message = "Prefab name is too long!", callback = function()
    			self:add_selection_to_prefabs(menu, item, prefab_name)
    		end})
    		return
    	end
        BeardLibEditor.Prefabs[prefab_name] = self:GetCopyData(remove_old_links and remove_old_links:Value() or true)
        FileIO:WriteScriptDataTo(Utils.Path:Combine(BeardLibEditor.PrefabsDirectory, prefab_name..".prefab"), BeardLibEditor.Prefabs[prefab_name], "binary")
    end, create_items = function(input_menu)
        remove_old_links = self:Toggle("RemoveOldLinks", nil, true, {text = "Remove Old Links Of Copied Elements", group = input_menu})
    end})
end

function Static:mouse_moved(x, y)
    if self._mouse_hold then
        self:select_unit(true)
    end
end

function Static:widget_unit()
    local unit = self:selected_unit()
    if self:Enabled() then
        for _, editor in pairs(self._editors) do
            if editor.widget_unit then
                return editor:widget_unit()
            end
        end
    end
    return nil
end

function Static:recalc_all_locals()
    if alive(self._selected_units[1]) then
        local reference = self._selected_units[1]
        reference:unit_data().local_pos = Vector3()
        reference:unit_data().local_rot = Rotation()
        for _, unit in pairs(self._selected_units) do
            if unit ~= reference then
                self:recalc_locals(unit, reference)
            end
        end
    end
end

function Static:recalc_locals(unit, reference)
    local pos = unit:position()
    local ref_pos = reference:position()
    local ref_rot = reference:rotation()
    unit:unit_data().local_pos = pos - ref_pos --:rotate_with(rot:inverse()) Trying to improve widget rotation but sadly failing.
    unit:unit_data().local_rot = ref_rot:inverse() * unit:rotation()
end

function Static:check_unit_ok(unit)
    local ud = unit:unit_data()
    if not ud then
        return false
    end
    if ud.unit_id and self._ignore_raycast[ud.unit_id] == true then
        self._ignore_raycast[ud.unit_id] = nil
        return false
    end
    if ud.instance and not self:Value("SelectInstances") then
        return false
    end
    if ud.unit_id == 0 and ud.name_id == "none" and not ud.name and not ud.position then
        return false
    end
    local mission_element = unit:mission_element() and unit:mission_element().element
    local wanted_elements = self:Manager("opt")._wanted_elements
    if mission_element then    
        return BeardLibEditor.Options:GetValue("Map/ShowElements") and (#wanted_elements == 0 or table.get_key(wanted_elements, managers.mission:get_mission_element(mission_element).class))
    else
        return unit:visible()
    end
end

function Static:reset_selected_units()
    self:Manager("mission"):remove_script()
    self:Manager("world"):reset_selected_units()
    for _, unit in pairs(self:selected_units()) do
        if alive(unit) and unit:mission_element() then unit:mission_element():unselect() end
    end
    self._selected_units = {}
    self._selected_group = nil
end

function Static:set_selected_unit(unit, add)
    add = add == true
    self:recalc_all_locals()
    local units = {unit}
    if alive(unit) then
        local ud = unit:unit_data()
        if ud and ud.instance then
            local instance = managers.world_instance:get_instance_data_by_name(ud.instance)
            local fake_unit
            for _, u in pairs(self:selected_units()) do
                if u:fake() and u:object().name == ud.instance then
                    fake_unit = u
                    break
                end
            end 
            unit = fake_unit or FakeObject:new(instance)
            units[1] = unit
        end
        if add and self._selected_group and ctrl() then
            if not unit:fake() and ud.continent == self._selected_group.continent then
                if table.contains(self._selected_group.units, ud.unit_id) then
                    table.delete(self._selected_group.units, ud.unit_id)
                else
                    table.insert(self._selected_group.units, ud.unit_id)
                end
                if #self._selected_group.units <= 1 then
                    self:remove_group()
                end
            end
        else
            if self:Manager("opt"):get_value("SelectEditorGroups") then
                local continent = managers.worlddefinition:get_continent_of_static(unit)
                if not add then
                    add = true
                    self:reset_selected_units()
                end
                if continent then
                    continent.editor_groups = continent.editor_groups or {}
                    for _, group in pairs(continent.editor_groups) do
                        if group.units then
                            if table.contains(group.units, unit:unit_data().unit_id) then
                                for _, unit_id in pairs(group.units) do
                                    local u = managers.worlddefinition:get_unit(unit_id)
                                    if alive(u) and not table.contains(units, u) then
                                        table.insert(units, u)
                                    end
                                end
                                if self._selected_group then
                                    self._selected_group = nil
                                else
                                    self._selected_group = group
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    if add then
        for _, unit in pairs(self:selected_units()) do
            if unit:mission_element() then unit:mission_element():unselect() end
        end
        for _, u in pairs(units) do
            if not table.contains(self._selected_units, u) then
                table.insert(self._selected_units, u)
            elseif not self._mouse_hold then
                table.delete(self._selected_units, u)
            end
        end
    elseif alive(unit) then
        self:reset_selected_units()
        self._selected_units[1] = unit
    end

    self:StorePreviousPosRot()
    local unit = self:selected_unit()
    self._parent:use_widgets(unit and alive(unit) and unit:enabled())
    for _, unit in pairs(self:selected_units()) do
        if unit:mission_element() then unit:mission_element():select() end
    end
    if #self._selected_units > 1 then
        self:set_multi_selected()
        if self:Value("SelectAndGoToMenu") then
            self:Switch()
        end
    else
        self._editors = {}
        if alive(unit) then
            if unit:mission_element() then
                self:Manager("mission"):set_element(unit:mission_element().element)
            elseif self:Manager("world"):is_world_unit(unit:name()) then
                self:Manager("world"):build_unit_menu()
            elseif unit:fake() then
                self:Manager("instances"):set_instance()
            else
                self:set_unit()
            end
            if self:Value("SelectAndGoToMenu") then
                self:Switch()
            end
        else
            self:set_unit()
        end
    end 
    self:Manager("world"):set_selected_unit()
end

local bain_ids = Idstring("units/payday2/characters/fps_mover/bain")

function Static:select_unit(mouse2)
    local rays = self._parent:select_unit_by_raycast(self._parent._editor_all, callback(self, self, "check_unit_ok"))
    self:recalc_all_locals()
    if rays then
        for _, ray in pairs(rays) do
            if alive(ray.unit) and ray.unit:name() ~= bain_ids then
                if not self._mouse_hold then
                    self._parent:Log("Ray hit " .. tostring(ray.unit:unit_data().name_id).. " " .. ray.body:name())
                end
                self:set_selected_unit(ray.unit, mouse2) 
            end
        end
    end
end

function Static:set_multi_selected()
    if self._built_multi then
        self:update_positions()
        return
    end
    self._built_multi = true
    self._editors = {}
    self:ClearItems()
    self:build_positions_items()
    self:update_positions()
end

function Static:set_unit(reset)
    if reset then
        self:reset_selected_units()
    end
    self._built_multi = false
    local unit = self._selected_units[1]
    if alive(unit) and unit:unit_data() and not unit:mission_element() then
        if not reset then
            self:set_menu_unit(unit)
            return
        end
    end
    self:build_default_menu()
end

function Static:set_menu_unit(unit)   
    self:build_unit_editor_menu()
    self:GetItem("Name"):SetValue(unit:unit_data().name_id, false, true)
    self:GetItem("Enabled"):SetValue(unit:enabled())
    self:GetItem("UnitPath"):SetValue(unit:unit_data().name, false, true)
    self:GetItem("Id"):SetValue(unit:unit_data().unit_id, false, true)
    self:GetItem("DisableShadows"):SetValue(unit:unit_data().disable_shadows, false, true)
    self:GetItem("DisableCollision"):SetValue(unit:unit_data().disable_collision, false, true)
    self:GetItem("HideOnProjectionLight"):SetValue(unit:unit_data().hide_on_projection_light, false, true)
    self:GetItem("DisableOnAIGraph"):SetValue(unit:unit_data().disable_on_ai_graph, false, true)
    for _, editor in pairs(self._editors) do
        if editor.set_menu_unit then
            editor:set_menu_unit(unit)
        end
    end
    self:update_positions()
    self:GetItem("Continent"):SetSelectedItem(unit:unit_data().continent)
    local not_w_unit = not (unit:wire_data() or unit:ai_editor_data())
    self:GetItem("Continent"):SetEnabled(not_w_unit)
    self:GetItem("UnitPath"):SetEnabled(not_w_unit)
    --self:build_links(unit:unit_data().unit_id)
end

function Static:build_links(id, is_element, element)
    local links = managers.mission:get_links_paths(id, is_element)
    local same_links = {}
    local function create_link(element, group, linking_from, warn)
        linking_from = linking_from and " | " .. string.pretty2(linking_from) or ""
        warn = warn or ""
        self:Button(element.editor_name, callback(self._parent, self._parent, "select_element", element), {
            text = tostring(element.editor_name) .. "\n" .. tostring(element.id) .. linking_from .. " | " .. tostring(element.class):gsub("Element", "") .. warn,
            group = group,
            font_size = 16,
            label = "elements"
        })
    end
    if #links > 0 then
        local links_group = self:GetItem("Linked") or self:Group("Linked", {max_height = 200})
        links_group:ClearItems()
        for _, link in pairs(links) do
            same_links[link.element.id] = true
            create_link(link.element, links_group, link.upper_k or link.key)
        end
    end
    if is_element then
        local linking_group = self:GetItem("Linking") or self:Group("Linking", {max_height = 200})
        if alive(linking_group) then
            linking_group:ClearItems()
        end
        for _, script in pairs(managers.mission._missions) do
            for _, tbl in pairs(script) do
                if tbl.elements then
                    for k, e in pairs(tbl.elements) do
                        local id = e.id
                        for _, link in pairs(managers.mission:get_links_paths(id, true, {{mission_element_data = element}})) do
                            local warn
                            if link.upper_k == "on_executed" then
                                if same_links[id] and link.tbl.delay == 0 then
                                    warn = "\nWarning - link already exists and can cause an endless loop, add a delay."
                                end
                            end

                            create_link(e, linking_group, link.upper_k or link.key, warn)
                        end
                    end
                end
            end
        end

        for id, unit in pairs(managers.worlddefinition._all_units) do
            for _, link in pairs(managers.mission:get_links_paths(id, false, {{mission_element_data = element}})) do
                local linking_from = link.upper_k or link.key
                linking_from = linking_from and " | " .. string.pretty2(linking_from) or ""
                self:Button(unit:unit_data().name_id, callback(self, self, "set_selected_unit", unit), {
                    text = tostring(unit:unit_data().name_id) .. "\n" .. tostring(unit:unit_data().unit_id) .. linking_from,
                    group = linking_group,
                    font_size = 16,
                    label = "elements"
                })                
            end
        end
        if #linking_group:Items() == 0 then
            linking_group:Destroy()
        end
    end
    return links
end

function Static:addremove_unit_portal(menu, item)
    local portal = self:Manager("world")._selected_portal
    if portal then
        for _, unit in pairs(self._selected_units) do
            if unit:unit_data().unit_id then
                portal:add_unit_id(unit)
            end
        end
    else
        BeardLibEditor.Utils:Notify("Error", "No portal selected")  
    end    
end      

function Static:delete_selected(menu, item)
    for _, unit in pairs(self._selected_units) do
        if unit:fake() then
            self:Manager("instances"):delete_instance()
        else
            self._parent:DeleteUnit(unit)
        end
    end
    self:reset_selected_units()
    self:set_unit()      
end

function Static:delete_selected_dialog(menu, item)
    if not self:selected_unit() then
        return
    end
    BeardLibEditor.Utils:YesNoQuestion("This will delete the selection", callback(self, self, "delete_selected")) 
end

function Static:update(t, dt)
    self.super.update(self, t, dt)
    for _, unit in pairs(self._nav_surfaces) do 
        Application:draw(unit, 0,0.8,1)
    end
    for _, editor in pairs(self._editors) do
        if editor.update then
            editor:update(t, dt)
        end
    end
    local color = BeardLibEditor.Options:GetValue("AccentColor"):with_alpha(1)
    self._pen:set(color)
    local draw_bodies = self:Value("DrawBodies")
    if managers.viewport:get_current_camera() then
        for _, unit in pairs(self._selected_units) do
            if alive(unit) and not unit:fake() then
                if draw_bodies then
                    for i = 0, unit:num_bodies() - 1 do
                        local body = unit:body(i)
                        if self._parent:_should_draw_body(body) then
                            self._pen:body(body)
                        end
                    end
                else
                    Application:draw(unit, color:unpack())
                end
            end
        end
    end
end

function Static:GetCopyData(remove_old_links)
    self:set_unit_data()
    local copy_data = {}    
    for _, unit in pairs(self._selected_units) do
        local typ = unit:mission_element() and "element" or not unit:fake() and "unit" or "unsupported"
        local copy = {
            type = typ,
            mission_element_data = typ == "element" and unit:mission_element().element and deep_clone(unit:mission_element().element) or nil,
            unit_data = typ == "unit" and unit:unit_data() and deep_clone(unit:unit_data()) or nil,
            wire_data = typ == "unit" and unit:wire_data() and deep_clone(unit:wire_data()) or nil,
            ai_editor_data = typ == "unit" and unit:ai_editor_data() and deep_clone(unit:ai_editor_data()) or nil
        }
        if typ ~= "unsupported" then
            table.insert(copy_data, copy)
        end
    end

    --The id is now used as the number it should add to the latest id before spawning the prefab
    --Why we need to save ids? so elements can function even after copy pasting
    local unit_id = 0
    local world_unit_id = 0
    local element_id = 0
    for _, v in pairs(copy_data) do
        local typ = v.type
        if typ == "element" then
            v.mission_element_data.script = nil
            for _, link in pairs(managers.mission:get_links_paths(v.mission_element_data.id, true, copy_data)) do
                link.tbl[link.key] = element_id
            end
            v.mission_element_data.id = element_id
            element_id = element_id + 1
        elseif typ == "unit" and v.unit_data.unit_id then
            local is_world = v.wire_data or v.ai_editor_data
            v.unit_data.continent = nil
            for _, link in pairs(managers.mission:get_links_paths(v.unit_data.unit_id, false, copy_data)) do
                link.tbl[link.key] = is_world and world_unit_id or unit_id
            end
            v.unit_data.unit_id = is_world and world_unit_id or unit_id
            if is_world then
                world_unit_id = world_unit_id + 1
            else
                unit_id = unit_id + 1
            end
        end
    end
    --Remove old links
    local function remove_link(id, is_element, element)
        for _, link in pairs(managers.mission:get_links_paths(id, is_element, {element})) do
            if tonumber(link.key) then
                table.remove(link.tbl, link.key)
            elseif link.upper_tbl[link.upper_k][link.key] == id then
                link.upper_tbl[link.upper_k][link.key] = nil
            else
                table.delete(link.upper_tbl[link.upper_k], link.tbl)
            end
        end
    end
    if remove_old_links or self:Value("RemoveOldLinks") then
        for _, v in pairs(copy_data) do
            if v.type == "element" then
                for id, _ in pairs(managers.mission._ids) do
                    remove_link(id, true, v)
                end
                for id, _ in pairs(managers.worlddefinition._all_units) do
                    remove_link(id, false, v)
                end
            end
        end
    end
    return copy_data
end

function Static:CopySelection()
    if #self._selected_units > 0 and not self._parent._menu._highlighted then
        self._copy_data = self:GetCopyData() --Sadly thanks for ovk's "crash at all cost" coding I cannot use script converter because it would crash.
        if #self._copy_data == 0 then
        	self._copy_data = nil
        end
    end
end

function Static:Paste()
    if not Global.editor_safe_mode and not self._parent._menu._highlighted and self._copy_data then
        self:SpawnCopyData(self._copy_data)
    end
end

function Static:SpawnPrefab(prefab)
    self:SpawnCopyData(prefab, true)
    if self.x then
        local cam = managers.viewport:get_current_camera()
        self:SetAxisControls(cam:position() + cam:rotation():y(), self:AxisControlsRotation())
        self:set_unit_data()
    end
end

function Static:SpawnCopyData(copy_data, prefab)
    copy_data = deep_clone(copy_data)
    local project = BeardLibEditor.managers.MapProject
    local mod = project:current_mod()
    local missing_units = {}
    local missing
    local assets = self:Manager("world")._assets_manager
    local data = mod and project:get_clean_data(mod._clean_config)
    local unit_ids = Idstring("unit")
    local add
    if data then
        add = project:get_level_by_id(data, Global.game_settings.level_id).add
    end
    self:reset_selected_units()
    local continent = self._parent._current_continent
    for _, v in pairs(copy_data) do
        local is_element = v.type == "element"
        local is_unit = v.type == "unit"
        if v.type == "element" then
            local new_final_id = managers.mission:get_new_id(continent)
            for _, link in pairs(managers.mission:get_links_paths(v.mission_element_data.id, true, copy_data)) do
                link.tbl[link.key] = new_final_id
            end
            v.mission_element_data.id = new_final_id
        elseif v.type == "unit" and v.unit_data.unit_id then
            local new_final_id = managers.worlddefinition:GetNewUnitID(continent, (v.wire_data or v.ai_editor_data) and "wire" or "")
            for _, link in pairs(managers.mission:get_links_paths(v.unit_data.unit_id, false, copy_data)) do
                link.tbl[link.key] = new_final_id
            end
            v.unit_data.unit_id = new_final_id
            local unit = v.unit_data.name
            if missing_units[unit] == nil then
                local is_preview_not_loaded = (not assets and not PackageManager:has(unit_ids, unit:id()))
                local not_loaded = not ((assets and assets:is_asset_loaded(unit, "unit") or (add and FileIO:Exists(Path:Combine(mod.path, add.directory, unit..".unit")))))
                if is_preview_not_loaded or not_loaded then
                    missing_units[unit] = true
                    missing = true
                else
                    missing_units[unit] = false
                end
            end
        end
    end
    local function all_ok_spawn()
        for _, v in pairs(copy_data) do
            if v.type == "element" then
                self:Manager("mission"):add_element(v.mission_element_data.class, true, v.mission_element_data)
            elseif v.unit_data then
                self._parent:SpawnUnit(v.unit_data.name, v, true, v.unit_data.unit_id)
            end
        end
        self:StorePreviousPosRot()
    end
    if missing then
        if assets then
            BeardLibEditor.Utils:QuickDialog({title = ":(", message = "A unit or more are unloaded, to spawn the prefab/copy you have to load all of the units"}, {{"Load Units", function()
                local function find_packages()
                    for unit, is_missing in pairs(missing_units) do
                        if is_missing then
                            if (assets:is_asset_loaded(unit, "unit") or add and FileIO:Exists(Path:Combine(mod.path, add.directory, unit..".unit"))) then
                                missing_units[unit] = nil
                            end
                        else
                            missing_units[unit] = nil
                        end
                    end
                    if table.size(missing_units) > 0 then
                        assets:find_packages(missing_units, find_packages)
                    else
                        BeardLibEditor.Utils:Notify("Nice!", "All units are now loaded, spawning prefab/copy..")
                        all_ok_spawn()
                    end
                end
                find_packages()
            end}})
        else
            BeardLibEditor.Utils:Notify("ERROR!", "Cannot spawn the prefab[Unloaded units]")
        end
    else
        all_ok_spawn()
    end
end

function Static:Clone()
    self:CopySelection()
    self:Paste()
end

function Static:KeyFPressed()
    if self._selected_units[1] then
        self._parent:set_camera(self._selected_units[1]:position())
    end
end

function Static:set_unit_enabled(enabled)
	for _, unit in pairs(self._selected_units) do
        if alive(unit) then
            unit:set_enabled(enabled)
        end
	end
end
ShadowBlock = ShadowBlock or class()
function ShadowBlock:init() self._parameters = {} end
function ShadowBlock:map() return self._parameters end
function ShadowBlock:set(key, value) self._parameters[key] = value end
function ShadowBlock:get(key) return self._parameters[key] end

EnvEditor = EnvEditor or class(EditorPart)
function EnvEditor:init(parent, menu)
    self.super.init(self, parent, menu, "Environment", {items_size = 24, control_slice = 0.55, offset = 2})
    self._posteffect = {}
    self._underlayeffect = {}
    self._sky = {}
    self._environment_effects = {}
    self._reported_data_path_map = {}
    self._shadow_blocks = {}
    self._shadow_params = {}
end

function EnvEditor:load_included_environments()
    local included = self:GetItem("IncludedEnvironments")
    local level = Global.current_custom_level
    if included and level then
        included:ClearItems("temp")
        for _, include in ipairs(level._config.include) do
            if type(include) == "table" and string.ends(include.file, "environment") then
                local file = Path:Combine(level._mod.path, level._config.include.directory, include.file)
                if FileIO:Exists(file) then
                    local env = self:Button(include.file, callback(self, self, "open_environment", file), {group = included})
                    self:SmallImageButton("Uniclude", callback(self, self, "uninclude_environment_dialog"), nil, {184, 2, 48, 48}, env, {
                        label = "temp", size_by_text = true, align = "center", texture = "textures/editor_icons_df", position = "TopRight", highlight_color = Color.red
                    })
                end
            end
        end
        if #included._my_items == 0 then
            self:Divider("Empty.. :(", {group = included, color = false})
        end
    end
end

function EnvEditor:build_default_menu()
    self.super.build_default_menu(self)
    if not managers.viewport:first_active_viewport() then
        return
    end
    local env_path = managers.viewport:first_active_viewport():get_environment_path() or "core/environments/default"
    if Global.current_custom_level then
        local included = self:DivGroup("IncludedEnvironments")
        self:SmallButton("IncludeEnvironment", callback(self, self, "include_current_dialog"), included, {text = "Include current"})
        self:load_included_environments()    
    end
    
    self:Button("Browse", callback(self, self, "open_environment_dialog"))
    self:Button("LoadGameDefault", callback(self, self, "database_load_env", "core/environments/default"))
    self:Button("LoadCurrentDefault", callback(self, self, "database_load_env", env_path))
    self:Button("Save", callback(self, self, "write_to_disk_dialog"))

    --SUN
    local sun = self:DivGroup("Sun")
    self:add_sky_param(self:ColorEnvItem("sun_ray_color", {text = "Color", group = sun}))
    self:add_sky_param(self:Slider("sun_ray_color_scale", nil, 1, {text = "Intensity", step = 0.1, min = 0, max = 10, group = sun}))
    self:add_sky_param(self:Slider("sky_rotation", nil, 1, {text = "rotation", step = 0.1, min = 0, max = 359, group = sun}))

    --FOG
    local fog = self:DivGroup("Fog")
    self:add_post_processors_param("deferred", "apply_ambient", self:ColorEnvItem("fog_start_color", {text = "start color", group = fog}))
    self:add_post_processors_param("deferred", "apply_ambient", self:ColorEnvItem("fog_far_low_color", {text = "far low color", group = fog}))
    self:add_post_processors_param("deferred", "apply_ambient", self:Slider("fog_min_range", nil, 1, {text = "min range", min = 0, max = 5000, group = fog}))
    self:add_post_processors_param("deferred", "apply_ambient", self:Slider("fog_max_range", nil, 1, {text = "max range", min = 0, max = 500000, group = fog}))
    self:add_post_processors_param("deferred", "apply_ambient", self:Slider("fog_max_density", nil, 1, {text = "max density", min = 0, max = 1, group = fog}))

    --SKY DOME LIGHT
    local skydome = self:DivGroup("Sky Dome Light")
    self:add_post_processors_param("deferred", "apply_ambient", self:ColorEnvItem("sky_top_color", {text = "top color", group = skydome}))
    self:add_post_processors_param("deferred", "apply_ambient", self:Slider("sky_top_color_scale", nil, 1, {text = "top scale", step = 0.1, min = 0, max = 10, group = skydome}))
    self:add_post_processors_param("deferred", "apply_ambient", self:ColorEnvItem("sky_bottom_color", {text = "bottom color", group = skydome}))
    self:add_post_processors_param("deferred", "apply_ambient", self:Slider("sky_bottom_color_scale", nil, 1, {text = "bottom scale", step = 0.1, min = 0, max = 10, group = skydome}))

    -- AMBIENT
    local ambient = self:DivGroup("Ambient")
    self:add_post_processors_param("deferred", "apply_ambient", self:ColorEnvItem("ambient_color", {text = "color", group = ambient}))
    self:add_post_processors_param("deferred", "apply_ambient", self:Slider("ambient_color_scale", nil, 1, {text = "color scale", step = 0.1, min = 0, max = 10, group = ambient}))
    self:add_post_processors_param("deferred", "apply_ambient", self:Slider("ambient_scale", nil, 1, {text = "scale", step = 0.1, min = 0, max = 10, group = ambient}))
    self:add_post_processors_param("deferred", "apply_ambient", self:Slider("ambient_falloff_scale", nil, 1, {text = "falloff scale", step = 0.1, min = 0, max = 10, group = ambient}))
    self:add_post_processors_param("deferred", "apply_ambient", self:Slider("effect_light_scale", nil, 1, {text = "Effect lighting scale", step = 0.1, min = 0, max = 10, group = ambient}))

    -- SPEC / GLOSS
    local sepcgloss = self:DivGroup("Spec / Gloss")
    self:add_post_processors_param("deferred", "apply_ambient", self:Slider("spec_factor", nil, 1, {text = "Specular factor", step = 0.1, min = 0, max = 1, group = sepcgloss}))
    self:add_post_processors_param("deferred", "apply_ambient", self:Slider("gloss_factor", nil, 1, {text = "Glossiness factor", step = 0.1, min = -1, max = 1, group = sepcgloss}))

    -- AMBIENT OCCLUSION
    local ao = self:DivGroup("Ambient Occlusion")
    local w = "(value of 0 turns off the effect)"
    self:add_post_processors_param("SSAO_post_processor", "apply_SSAO", self:Slider("ssao_radius", nil, 1, {text = "SSAO radius", min = 1, max = 100, group = ao}))
    self:add_post_processors_param("SSAO_post_processor", "apply_SSAO", self:Slider("ssao_intensity", nil, 1, {text = "SSAO intensity", help = w, step = 0.1, min = 0, max = 10, group = ao}))
    
    -- BLOOM
    local bloom = self:DivGroup("Bloom")
    self:add_post_processors_param("bloom_combine_post_processor", "post_DOF", self:Slider("bloom_intensity", nil, 1, {text = "Intensity", help = w, step = 0.1, min = 0, max = 2, group = bloom}))

    -- VOLUMETRIC LIGHT SCATTERING
    local volume_matt = self:DivGroup("Volumemetric Light Scattering")
    self:add_post_processors_param("volumetric_light_scatter", "post_volumetric_light_scatter", self:Slider("light_scatter_density", nil, 1, {text = "Density", step = 0.1, min = 0, max = 1, group = volume_matt}))
    self:add_post_processors_param("volumetric_light_scatter", "post_volumetric_light_scatter", self:Slider("light_scatter_weight", nil, 1, {text = "Weight", step = 0.01, min = 0, max = 0.1, group = volume_matt}))
    self:add_post_processors_param("volumetric_light_scatter", "post_volumetric_light_scatter", self:Slider("light_scatter_decay", nil, 1, {text = "Decay", step = 0.1, min = 0, max = 1, group = volume_matt}))
    self:add_post_processors_param("volumetric_light_scatter", "post_volumetric_light_scatter", self:Slider("light_scatter_exposure", nil, 1, {text = "Exposure", help = w, step = 0.1, min = 0, max = 2, group = volume_matt}))
    
    -- LENS FLARES
    local lens_flares = self:DivGroup("Lens Flares")
    self:add_post_processors_param("lens_flare_post_processor", "lens_flare_material", self:Slider("ghost_dispersal", nil, 1, {text = "ghost dispersal", step = 0.1, min = 0, max = 1, group = lens_flares}))
    self:add_post_processors_param("lens_flare_post_processor", "lens_flare_material", self:Slider("halo_width", nil, 1, {text = "halo width", step = 0.1, min = 0, max = 2, group = lens_flares}))
    self:add_post_processors_param("lens_flare_post_processor", "lens_flare_material", self:Slider("chromatic_distortion", nil, 1, {text = "chromatic distortion", min = 0, max = 30, group = lens_flares}))
    self:add_post_processors_param("lens_flare_post_processor", "lens_flare_material", self:Slider("weight_exponent", nil, 1, {text = "weight exponent", min = 0, max = 50, group = lens_flares}))
    self:add_post_processors_param("lens_flare_post_processor", "lens_flare_material", self:Slider("downsample_scale", nil, 1, {text = "downsample scale", min = 0, max = 10, group = lens_flares}))
    self:add_post_processors_param("lens_flare_post_processor", "lens_flare_material", self:Slider("downsample_bias", nil, 1, {text = "downssample bias", help = "value of 1 turns off the effect", step = 0.1, min = 0, max = 1, group = lens_flares}))

    -- SKY
    local sky = self:DivGroup("Sky")
    self:add_underlay_param("sky", self:ColorEnvItem("color0", {text = "Color top", group = sky}))
    self:add_underlay_param("sky", self:Slider("color0_scale", nil, 1, {text = "Color top scale", step = 0.1, min = 0, max = 10, group = sky}))
    self:add_underlay_param("sky", self:ColorEnvItem("color2", {text = "Color low", group = sky}))
    self:add_underlay_param("sky", self:Slider("color2_scale", nil, 1, {text = "Color low scale", step = 0.1, min = 0, max = 10, group = sky}))

    -- Textures
    local textures = self:DivGroup("Underlay / Textures")

    self:add_sky_param(self:PathItem("underlay", nil, "", "scene", true, function(entry) return not (entry:match("core/levels") or entry:match("levels/zone")) end), true, {text = "Underlay", group = textures})
    self:add_sky_param(self:PathItem("sky_texture", nil, "", "texture", false, nil, true, {text = "Sky Texture", group = textures}))
    self:add_sky_param(self:PathItem("global_texture", nil, "", "texture", false, nil, true, {text = "Global cubemap", group = textures}))
    self:add_sky_param(self:PathItem("global_world_overlay_texture", nil, "", "texture", false, nil, true, {text = "Global world overlay texture", group = textures}))
    self:add_sky_param(self:PathItem("global_world_overlay_mask_texture", nil, "", "texture", false, nil, true, {text = "Global world overlay mask texture", group = textures}))
    self:add_colorgrade(self:PathItem("ColorgradeLUTTexture", nil, "", "texture", false, nil, true, {group = textures}))

    -- Shadows
    local shadows = self:DivGroup("Shadows")
    self._shadow_params.d0 = self:add_post_processors_param("shadow_processor", "shadow_modifier", self:Slider("d0", nil, 1, {text = "1st slice depth start", items_size = 18, min = 0, max = 1000000, group = shadows}))
    self._shadow_params.d1 = self:add_post_processors_param("shadow_processor", "shadow_modifier", self:Slider("d1", nil, 1, {text = "2nd slice depth start", items_size = 18, min = 0, max = 1000000, group = shadows}))
    self._shadow_params.o1 = self:add_post_processors_param("shadow_processor", "shadow_modifier", self:Slider("o1", nil, 1, {text = "Blend overlap(1st & 2nd)", items_size = 18, min = 0, max = 1000000, group = shadows}))
    self._shadow_params.d2 = self:add_post_processors_param("shadow_processor", "shadow_modifier", self:Slider("d2", nil, 1, {text = "3rd slice depth start", items_size = 18, min = 0, max = 1000000, group = shadows}))
    self._shadow_params.d3 = self:add_post_processors_param("shadow_processor", "shadow_modifier", self:Slider("d3", nil, 1, {text = "3rd slice depth end", items_size = 18, min = 0, max = 1000000, group = shadows}))
    self._shadow_params.o2 = self:add_post_processors_param("shadow_processor", "shadow_modifier", self:Slider("o2", nil, 1, {text = "Blend overlap(2nd & 3rd)", items_size = 18, min = 0, max = 1000000, group = shadows}))
    self._shadow_params.o3 = self:add_post_processors_param("shadow_processor", "shadow_modifier", self:Slider("o3", nil, 1, {text = "Blend overlap(3rd & 4th)", items_size = 18, min = 0, max = 1000000, group = shadows}))
 
    self:add_post_processors_param("shadow_processor", "shadow_modifier", DummyItem:new("slice0"))
    self:add_post_processors_param("shadow_processor", "shadow_modifier", DummyItem:new("slice1"))
    self:add_post_processors_param("shadow_processor", "shadow_modifier", DummyItem:new("slice2"))
    self:add_post_processors_param("shadow_processor", "shadow_modifier", DummyItem:new("slice3"))
    self:add_post_processors_param("shadow_processor", "shadow_modifier", DummyItem:new("shadow_slice_overlap"))
    self:add_post_processors_param("shadow_processor", "shadow_modifier", DummyItem:new("shadow_slice_depths"))

    self:database_load_env(env_path)

    managers.viewport:first_active_viewport():set_environment_editor_callback(callback(self, self, "feed"))
    self._built = true
end


function EnvEditor:add_colorgrade(gui)
	self._colorgrade_param = gui
	return gui
end


function EnvEditor:load_shadow_data(block)
    for k, v in pairs(block:map()) do
        local param = self._shadow_params[k]
        if param then
            param:SetValue(v)
        end
    end
end

function EnvEditor:parse_shadow_data()
    local values = {}
    core:import("CoreEnvironmentFeeder")
    values.slice0 = managers.viewport:get_environment_value(self._env_path, CoreEnvironmentFeeder.PostShadowSlice0Feeder.DATA_PATH_KEY)
    values.slice1 = managers.viewport:get_environment_value(self._env_path, CoreEnvironmentFeeder.PostShadowSlice1Feeder.DATA_PATH_KEY)
    values.slice2 = managers.viewport:get_environment_value(self._env_path, CoreEnvironmentFeeder.PostShadowSlice2Feeder.DATA_PATH_KEY)
    values.slice3 = managers.viewport:get_environment_value(self._env_path, CoreEnvironmentFeeder.PostShadowSlice3Feeder.DATA_PATH_KEY)
    values.shadow_slice_overlap = managers.viewport:get_environment_value(self._env_path, CoreEnvironmentFeeder.PostShadowSliceOverlapFeeder.DATA_PATH_KEY)
    values.shadow_slice_depths = managers.viewport:get_environment_value(self._env_path, CoreEnvironmentFeeder.PostShadowSliceDepthsFeeder.DATA_PATH_KEY)
    local block = self:convert_to_block(values)
    self._shadow_blocks[self._env_path] = block
    self:load_shadow_data(block)
end

function EnvEditor:convert_to_block(values)
    local block = ShadowBlock:new()
    block:set("d0", values.shadow_slice_depths.x)
    block:set("d1", values.shadow_slice_depths.y)
    block:set("d2", values.shadow_slice_depths.z)
    block:set("d3", values.slice3.y)
    block:set("o1", values.shadow_slice_overlap.x)
    block:set("o2", values.shadow_slice_overlap.y)
    block:set("o3", values.shadow_slice_overlap.z)
    return block
end

local env_ids = Idstring("environment")
function EnvEditor:database_load_env(env_path)
    if self._last_custom then
        managers.viewport._env_manager._env_data_map[self._last_custom] = nil
        self._last_custom = nil
    end
    self._env_path = env_path
    self:load_env(PackageManager:has(env_ids, env_path:id()) and PackageManager:script_data(env_ids, env_path:id()))
end

function EnvEditor:load_env(env)
    if env then
        for k,v in pairs(env.data) do
            if k == "others" then
                self:database_load_sky(v)
            elseif k == "post_effect" then
                self:database_load_posteffect(v)
            elseif k == "underlay_effect" then
                self:database_load_underlay(v)
            end    
        end
        self:parse_shadow_data()
    end
end

function EnvEditor:database_load_underlay(underlay_effect_node)
    for _, material in pairs(underlay_effect_node) do
        if type(material) == "table" then
            local mat = self._underlayeffect.materials[material._meta]
            if not mat then
                self._underlayeffect.materials[material._meta] = {}
                mat = self._underlayeffect.materials[material._meta]
                mat.params = {}
            end
            for _, param in pairs(material) do
                if type(material) == "table" and param._meta == "param" and param.key and param.key ~= "" and param.value and param.value ~= "" then
                    local k = param.key
                    local l = string.len(k)
                    local parameter = mat.params[k]
                    local remove_param = false
                    if not parameter then
                        local data_path = "underlay_effect/" .. material._meta .. "/" .. k
                        remove_param = not managers.viewport:has_data_path_key(Idstring(data_path):key())
                        if not remove_param then
                            log("Editor doesn't handle value but should: " .. data_path)
                            mat.params[k] = DummyItem:new()
                            parameter = mat.params[k]
                        elseif managers.viewport:is_deprecated_data_path(data_path) then
                        --    log("Deprecated value will be removed next time you save: " .. data_path)
                        else
                            log("Invalid value: " .. data_path)
                        end
                    end
                    if not remove_param and parameter then
                        parameter:SetValue(param.value)
                    end
                end
            end
        end
    end
end

function EnvEditor:database_load_environment_effects(effect_node)
    for _, param in pairs(effect_node) do
        if type(param) == "table" and param._meta == "param" and param.key and param.key ~= "" and param.value and param.value ~= "" then
            self._environment_effects = string.split(param.value, ";")
            table.sort(self._environment_effects)
        end
    end
end

function EnvEditor:database_load_sky(sky_node)
    for _, param in pairs(sky_node) do
        if type(param) == "table" and param._meta == "param" and param.key and param.key ~= "" and param.value and param.value ~= "" then
            local k = param.key
            local l = string.len(k)
            local parameter = self._sky.params[k]
            local remove_param = false
            local is_colorgrade = false

            if not self._sky.params[k] then
                if k == "colorgrade" then
                    self._colorgrade_param:SetValue(param.value)
                    is_colorgrade = true
                else
                    local data_path = "others/" .. k
                    remove_param = not managers.viewport:has_data_path_key(Idstring(data_path):key())
                    if not remove_param then
                        log("Editor doesn't handle value but should: " .. data_path)
                        self._sky.params[k] = DummyItem:new()
                    elseif managers.viewport:is_deprecated_data_path(data_path) then
                    --    log("Deprecated value will be removed next time you save: " .. data_path)
                    else
                        log("Invalid value: " .. data_path)
                    end
                end
            end
            if not remove_param and not is_colorgrade then
                self._sky.params[k]:SetValue(param.value)
            end
        end
    end
end

function EnvEditor:database_load_posteffect(post_effect_node)
    for _, post_processor in pairs(post_effect_node) do
        if type(post_processor) == "table" then
            local post_pro = self._posteffect.post_processors[post_processor._meta]
            if not post_pro then
                self._posteffect.post_processors[post_processor._meta] = {}
                post_pro = self._posteffect.post_processors[post_processor._meta]
                post_pro.modifiers = {}
            end
            for _, modifier in pairs(post_processor) do
                if type(modifier) == "table" then
                    local mod = post_pro.modifiers[modifier._meta]
                    if not mod then
                        post_pro.modifiers[modifier._meta] = {}
                        mod = post_pro.modifiers[modifier._meta]
                        mod.params = {}
                    end
                    for _, param in pairs(modifier) do
                        if type(param) == "table" and param._meta == "param" and param.key and param.key ~= "" and param.value and param.value ~= "" then
                            local k = param.key
                            local l = string.len(k)
                            local parameter = mod.params[k]
                            local remove_param = false
                            if not parameter then
                                local data_path = "post_effect/" .. post_processor._meta .. "/" .. effect._meta .. "/" .. modifier._meta .. "/" .. k
                                remove_param = not managers.viewport:has_data_path_key(Idstring(data_path):key())
                                if not remove_param then
                                    log("Editor doesn't handle value but should: " .. data_path)
                                    mod.params[k] = DummyItem:new()
                                    parameter = mod.params[k]
                                elseif managers.viewport:is_deprecated_data_path(data_path) then
                                --    log("Deprecated value will be removed next time you save: " .. data_path)
                                else
                                    log("Invalid value: " .. data_path)
                                end
                            end
                            if not remove_param and parameter then
                                parameter:SetValue(param.value)
                            end
                        end
                    end
                end
            end
        end
    end
end

function EnvEditor:add_sky_param(gui)
    self._sky.params = self._sky.params or {}
    self._sky.params[gui.name] = gui
    return gui
end

local effect_names = {
    deferred = "deferred_lighting",
    shadow_processor = "shadow_rendering",
    volumetric_light_scatter = "volumetric_light_scatter",
    bloom_combine_post_processor = "bloom_DOF_combine",
    lens_flare_post_processor = "lens_flare_effect",
    SSAO_post_processor = "SSAO",
}

function EnvEditor:_get_post_process_effect_name(post_processor)
    return effect_names[post_processor] or "default"
end

function EnvEditor:add_post_processors_param(pro, mod, gui)
    local param = gui.name
	self._posteffect.post_processors = self._posteffect.post_processors or {}
	self._posteffect.post_processors[pro] = self._posteffect.post_processors[pro] or {}
	self._posteffect.post_processors[pro].modifiers = self._posteffect.post_processors[pro].modifiers or {}
	self._posteffect.post_processors[pro].modifiers[mod] = self._posteffect.post_processors[pro].modifiers[mod] or {}
	self._posteffect.post_processors[pro].modifiers[mod].params = self._posteffect.post_processors[pro].modifiers[mod].params or {}
	self._posteffect.post_processors[pro].modifiers[mod].params[param] = gui
	
	local e = self:_get_post_process_effect_name(pro)

	local processor = managers.viewport:first_active_viewport():vp():get_post_processor_effect("World", Idstring(pro))
	if processor then
		local modifier = processor:modifier(Idstring(mod))
		if modifier and modifier:material():variable_exists(Idstring(param)) then
			local value = modifier:material():get_variable(Idstring(param))
			if value then
				gui:SetValue(value)
			end
		end
	end
	
	return gui
end

function EnvEditor:add_underlay_param(mat, gui)
    self._underlayeffect.materials = self._underlayeffect.materials or {}
    self._underlayeffect.materials[mat] = self._underlayeffect.materials[mat] or {}
    self._underlayeffect.materials[mat].params = self._underlayeffect.materials[mat].params or {}
    self._underlayeffect.materials[mat].params[gui.name] = gui

    local material = Underlay:material(Idstring(mat))
    if material and material:variable_exists(Idstring(gui.name)) then
        local value = material:get_variable(Idstring(gui.name))
        if value then
            gui:SetValue(value)
        end
    end
    return gui
end

function EnvEditor:set_data_path(data_path, handler, value)
    local data_path_key = Idstring(data_path):key()
    if value and not self._reported_data_path_map[data_path_key] and not handler:editor_set_value(data_path_key, value) then
        self._reported_data_path_map[data_path_key] = true
        log("Data path is not supported: " .. tostring(data_path))
    end
end

function EnvEditor:feed(handler, viewport, scene)
	for kpro,vpro in pairs(self._posteffect.post_processors) do
		if kpro == "shadow_processor" then
			local shadow_param_map = {}
			self:shadow_feed_params(shadow_param_map)
			for kpar,vpar in pairs(shadow_param_map) do
				self:set_data_path("post_effect/" .. kpro .. "/shadow_rendering/shadow_modifier/" .. kpar, handler, vpar)
			end
		else
			for kmod,vmod in pairs(vpro.modifiers) do
				for kpar,vpar in pairs(vmod.params) do
					self:set_data_path("post_effect/" .. kpro .. "/" .. self:_get_post_process_effect_name(kpro) .. "/" .. kmod .. "/" .. kpar, handler, vpar:Value())
				end
			end
		end
	end

	for kmat,vmat in pairs(self._underlayeffect.materials) do
		for kpar,vpar in pairs(vmat.params) do
			self:set_data_path("underlay_effect/" .. kmat .. "/" .. kpar, handler, vpar:Value())
		end
	end

	for kpar,vpar in pairs(self._sky.params) do
		self:set_data_path("others/" .. kpar, handler, vpar:Value())
	end

	self:set_data_path("others/colorgrade", handler, self._colorgrade_param:Value())
end

function EnvEditor:shadow_feed_params(feed_params)
    local interface_params = self._posteffect.post_processors.shadow_processor.modifiers.shadow_modifier.params
    local d0 = interface_params.d0:Value()
    local d1 = interface_params.d1:Value()
    local d2 = interface_params.d2:Value()
    local d3 = interface_params.d3:Value()
    local o1 = interface_params.o1:Value()
    local o2 = interface_params.o2:Value()
    local o3 = interface_params.o3:Value()
    local s0 = Vector3(0, d0, 0)
    local s1 = Vector3(d0 - o1, d1, 0)
    local s2 = Vector3(d1 - o2, d2, 0)
    local s3 = Vector3(d2 - o3, d3, 0)
    local shadow_slice_depths = Vector3(d0, d1, d2)
    local shadow_slice_overlaps = Vector3(o1, o2, o3)
    feed_params.slice0 = s0
    feed_params.slice1 = s1
    feed_params.slice2 = s2
    feed_params.slice3 = s3
    feed_params.shadow_slice_depths = shadow_slice_depths
    feed_params.shadow_slice_overlap = shadow_slice_overlaps
    return feed_params
end

function EnvEditor:update(t, dt)
    if not self._built and managers.viewport:first_active_viewport() then
        self:build_default_menu()
    end
end

function EnvEditor:open_default_custom_environment()
    local data = self:Manager("world"):data()
    local environment = data.environment.environment_values.environment
    local level = Global.current_custom_level
    local map_dbpath = Path:Combine("levels/mods/", level._config.id)
    if string.begins(environment, map_dbpath) then
        local file_path = string.gsub(environment, map_dbpath, Path:Combine(level._mod.path, level._config.include.directory)) .. ".environment"
        if FileIO:Exists(file_path) then
            self:open_environment(file_path)
        else
            BeardLibEditor.Utils:Notify("ERROR!", "This is not a valid environment file!! "..file_path)
        end
    end
end

function EnvEditor:uninclude_environment_dialog(menu, item)
    BeardLibEditor.Utils:YesNoQuestion("This will uninclude the environment from your level and will delete the file itself", function()
        local level = Global.current_custom_level
        FileIO:Delete(Path:Combine(level._mod.path, level._config.include.directory, menu.name))
        self:Manager("opt"):save_main_xml()
        local env = menu.name:gsub(".environment", "")
        table.delete(Global.DBPaths.environment, Path:Combine("levels/mods/", level.id, env))
        BeardLibEditor:LoadCustomAssets()
        self:load_included_environments()
    end)
end

function EnvEditor:include_current_dialog(name)
    local level = Global.current_custom_level
    local env_dir = Path:Combine(level._mod.path, level._config.include.directory, "environments")
    BeardLibEditor.managers.InputDialog:Show({
        title = "Environment name:",
        text = type(name) == "string" and name or self._last_custom and Path:GetFileNameWithoutExtension(self._last_custom) or "",
        check_value = function(name)
            if FileIO:Exists(Path:Combine(env_dir, name..".environment")) then
                BeardLibEditor.Utils:Notify("Error", string.format("Envrionment with the name %s already exists! Please use a unique name", name))
                return false
            elseif name == "" then
                BeardLibEditor.Utils:Notify("Error", string.format("Name cannot be empty!", name))
                return false
            elseif string.begins(name, " ") then
                BeardLibEditor.Utils:Notify("Error", "Invalid ID!")
                return false
            end
            return true
        end,
        callback = function(name)
            self:write_to_disk(Path:Combine(env_dir, name..".environment"))
            self:Manager("opt"):save_main_xml({{_meta = "file", file = Path:Combine("environments", name..".environment"), type = "custom_xml"}})
            BeardLibEditor.managers.MapProject:_reload_mod(level._mod.Name)
            BeardLibEditor:LoadCustomAssets()
            self:load_included_environments()
        end
    })
end

function EnvEditor:open_environment(file)
    if not file then
        return
    end
    local read = FileIO:ReadFrom(file, "rb")
    local data
    if read then
        data = read:match("<environment") and FileIO:ConvertScriptData(read, "custom_xml") or FileIO:ConvertScriptData(read, "binary")
    end
    local valid = data and data.data and data.data.others and type(data.data.others) == "table"
    local underlay
    if valid then
        for _, param in pairs(data.data.others) do
            if param._meta == "param" and param.key == "underlay" then
                underlay = param.value
                break
            end
        end
    end
    if underlay then
        if PackageManager:has(Idstring("scene"), underlay:id()) then
            BeardLibEditor.managers.FBD:hide()
            local env_mangaer = managers.viewport._env_manager
            env_mangaer._env_data_map[file] = {}
            env_mangaer:_load_env_data(nil, env_mangaer._env_data_map[file], data.data)
            self._env_path = file
            self._last_custom = file
            self:load_env(data)
            BeardLibEditor.Utils:Notify("Success!", "Environment is loaded "..file)
        else
            BeardLibEditor.managers.FBD:hide()
            BeardLibEditor.Utils:Notify("ERROR!", "Could not loaded environment because underlay scene is unloaded "..file)
        end
    else
        BeardLibEditor.managers.FBD:hide()
        BeardLibEditor.Utils:Notify("ERROR!", "This is not a valid environment file!! "..file)
    end
end

function EnvEditor:open_environment_dialog()
    BeardLibEditor.managers.FBD:Show({force = true, where = string.gsub(Application:base_path(), "\\", "/"), extensions = {"environment", "xml"}, file_click = callback(self, self, "open_environment")})
end

function EnvEditor:write_to_disk(filepath)
    self._last_custom = filepath
    FileIO:MakeDir(Path:GetDirectory(filepath))
    local file = FileIO:Open(filepath, "w")
    if file then
        file:print("<environment>\n")
        file:print("\t<metadata>\n")
        file:print("\t</metadata>\n")
        file:print("\t<data>\n")
        self:write_sky(file)
        self:write_posteffect(file)
        self:write_underlayeffect(file)
        file:print("\t</data>\n")
        file:print("</environment>\n")
        file:close()
        BeardLibEditor.Utils:Notify("Success!", "Saved environment "..filepath)
    end
end

function EnvEditor:write_to_disk_dialog()
    BeardLibEditor.managers.InputDialog:Show({force = true, title = "Environment file save path:", text = self._last_custom or "new_environment.environment", callback = function(filepath)
        if filepath == "" then
            BeardLibEditor.managers.Dialog:Show({force = true, title = "ERROR!", message = "Environment file path cannot be empty!", callback = function()
                self:write_to_disk_dialog()
            end})
            return
        end
        self:write_to_disk(filepath)
    end})
end

function EnvEditor:write_posteffect(file)
    file:print("\t\t<post_effect>\n")
    for post_processor_name, post_processor in pairs(self._posteffect.post_processors) do
        if next(post_processor.modifiers) then
            file:print("\t\t\t<" .. post_processor_name .. ">\n")
            if post_processor_name == "shadow_processor" then
                self:write_shadow_params(file)
            else
                local e = self:_get_post_process_effect_name(post_processor_name)
                file:print("\t\t\t\t<" .. e .. ">\n")
                for modifier_name, mod in pairs(post_processor.modifiers) do
                    if next(mod.params) then
                        file:print("\t\t\t\t\t<" .. modifier_name .. ">\n")
                        for param_name, param in pairs(mod.params) do
                            local v = param:Value()
                            if getmetatable(v) == _G.Vector3 then
                                v = "" .. param:Value().x .. " " .. param:Value().y .. " " .. param:Value().z
                            else
                                v = tostring(param:Value())
                            end
                            file:print("\t\t\t\t\t\t<param key=\"" .. param_name .. "\" value=\"" .. v .. "\"/>\n")
                        end
                        file:print("\t\t\t\t\t</" .. modifier_name .. ">\n")
                    end
                end
                file:print("\t\t\t\t</" .. e .. ">\n")
            end
            file:print("\t\t\t</" .. post_processor_name .. ">\n")
        end
    end
    file:print("\t\t</post_effect>\n")
end

function EnvEditor:write_shadow_params(file)
    local params = self:shadow_feed_params({})
    file:print("\t\t\t\t<shadow_rendering>\n")
    file:print("\t\t\t\t\t<shadow_modifier>\n")
    for param_name, param in pairs(params) do
        local v = param
        if getmetatable(v) == _G.Vector3 then
            v = "" .. param.x .. " " .. param.y .. " " .. param.z
        else
            v = tostring(param)
        end
        file:print("\t\t\t\t\t\t<param key=\"" .. param_name .. "\" value=\"" .. v .. "\"/>\n")
    end
    file:print("\t\t\t\t\t</shadow_modifier>\n")
    file:print("\t\t\t\t</shadow_rendering>\n")
end

function EnvEditor:write_underlayeffect(file)
    file:print("\t\t<underlay_effect>\n")
    for underlay_name, material in pairs(self._underlayeffect.materials) do
        if next(material.params) then
            file:print("\t\t\t<" .. underlay_name .. ">\n")
            for param_name, param in pairs(material.params) do
                local v = param:Value()
                if getmetatable(v) == _G.Vector3 then
                    v = "" .. param:Value().x .. " " .. param:Value().y .. " " .. param:Value().z
                else
                    v = tostring(param:Value())
                end
                file:print("\t\t\t\t<param key=\"" .. param_name .. "\" value=\"" .. v .. "\"/>\n")
            end
            file:print("\t\t\t</" .. underlay_name .. ">\n")
        end
    end
    file:print("\t\t</underlay_effect>\n")
end

function EnvEditor:write_sky(file)
	file:print("\t\t<others>\n")
    for param_name, param in pairs(self._sky.params) do
        local v = param:Value()
        if getmetatable(v) == _G.Vector3 then
            v = "" .. param:Value().x .. " " .. param:Value().y .. " " .. param:Value().z
        else
            v = tostring(param:Value())
        end
        file:print("\t\t\t<param key=\"" .. param_name .. "\" value=\"" .. v .. "\"/>\n")
    end
    local cg_value = tostring(self._colorgrade_param:Value())
    file:print("\t\t\t<param key=\"colorgrade\" value=\"" .. cg_value .. "\"/>\n")
	file:print("\t\t</others>\n")
end
local BLE = BeardLibEditor
--The internal name stays BeardLibEditor.
function BLE:Init()
    self.ExtractDirectory = self.Options:GetValue("ExtractDirectory").."/"
    self.AssetsDirectory = self.path .. "Assets/"
    self.HooksDirectory = self.path .. "Hooks/"
    self.ClassDirectory = self.path .. "Classes/"
    self.MapClassesDir = self.ClassDirectory .. "Map/"
    self.PrefabsDirectory = Path:Combine(BLT.Mods.Constants.maps_directory, "prefabs")
    self.ElementsDir = self.MapClassesDir .. "Elements/"
    self.Version = self.auto_updates._config.version or 2
    self.ExtractImportHelp = [[
This will search for assets of the unit to load it, you shouldn't use this method for any networked units, 
units that have animations(bags, drills, bags, npcs, etc) and you can't use this method to load any units that need an effect file.
]]
 
    self.managers = {}
    self.modules = {}
    self.DBPaths = {}
    self.DBEntries = {}
    self.Prefabs = {}
    self:LoadHashlist()
    self.InitDone = true
end

function BLE:InitManagers()
    local acc_color = BeardLibEditor.Options:GetValue("AccentColor")
    local bg_color = BeardLibEditor.Options:GetValue("BackgroundColor")
    local M = BeardLibEditor.managers
    self._dialogs_opt = {accent_color = acc_color, background_color = bg_color}
    M.Dialog = MenuDialog:new(self._dialogs_opt)
    M.ListDialog = ListDialog:new(self._dialogs_opt)
    M.SelectDialog = SelectListDialog:new(self._dialogs_opt)
    M.SelectDialogValue = SelectListDialogValue:new(self._dialogs_opt)
    M.ColorDialog = ColorDialog:new(self._dialogs_opt)
    M.InputDialog = InputDialog:new(self._dialogs_opt)
    M.FBD = FileBrowserDialog:new(self._dialogs_opt)
    local opt = clone(BeardLibEditor._dialogs_opt)
    opt.position = function(item)
        item:SetPositionByString("CenterBottom")
        item:Panel():move(0, -20)
    end
    opt.h = 500
    M.LowerListDialog = ListDialog:new(opt)

    if Global.editor_mode then
        M.MapEditor = MapEditor:new()
    end

    M.Menu = EditorMenu:new()
    M.ScriptDataConverter = ScriptDataConverterManager:new()
    M.MapProject = MapProjectManager:new()
    M.LoadLevel = LoadLevelMenu:new()
    M.EditorOptions = EditorOptionsMenu:new()
    AboutMenu:new()

    local prefabs = FileIO:GetFiles(self.PrefabsDirectory)
    if prefabs then
        for _, prefab in pairs(prefabs) do
            self.Prefabs[Path:GetFileNameWithoutExtension(prefab)] = FileIO:ReadScriptDataFrom(Path:Combine(self.PrefabsDirectory, prefab), "binary")
        end
    end
    --Packages that are always loaded
    self.ConstPackages = {
        "packages/game_base_init",
        "packages/game_base",
        "packages/start_menu",
        "packages/load_level",
        "packages/load_default",
        "packages/boot_screen",
        "packages/toxic",
        "packages/dyn_resources",
        "packages/wip/game_base",
        "core/packages/base",
        "core/packages/editor"
    }
    local prefix = "packages/dlcs/"
    local sufix = "/game_base"
    for dlc_package, bundled in pairs(tweak_data.BUNDLED_DLC_PACKAGES) do
        table.insert(self.ConstPackages, prefix .. tostring(dlc_package) .. sufix)
    end
    for i, difficulty in ipairs(tweak_data.difficulties) do
        table.insert(self.ConstPackages, "packages/" .. (difficulty or "normal"))
    end
    
    self:LoadCustomAssets()
end

function BLE:LoadCustomAssets()
    local project = self.managers.MapProject
    local mod = project:current_mod()
    local data = mod and project:get_clean_data(mod._clean_config)
    if data then
        if data.AddFiles then
            self:LoadCustomAssetsToHashList(data.AddFiles)
        end
        local level = project:get_level_by_id(data, Global.game_settings.level_id)
        if level then
            self:log("Loading Custom Assets to Hashlist")
            level.add = level.add or {}
            if not level.add.file then
                local add = table.merge({directory = "assets"}, deep_clone(level.add))
                local add_path = Path:Combine(level.include.directory, "add.xml")
                project:map_editor_save_xml(add_path, add)
                level.add = {file = add_path}
                project:map_editor_save_main_xml(data)
            end
            local add = project:map_editor_read_xml(level.add.file)
            if add then
                self:LoadCustomAssetsToHashList(add)
            end
            for i, include_data in ipairs(level.include) do
                if include_data.file then
                    local file_split = string.split(include_data.file, "[.]")
                    local typ = file_split[2]
                    local path = Path:Combine("levels/mods/", level.id, file_split[1])
                    if FileIO:Exists(Path:Combine(mod.path, level.include.directory, include_data.file)) then
                        self.DBPaths[typ] = self.DBPaths[typ] or {}
                        if not table.contains(self.DBPaths[typ], path) then
                            table.insert(self.DBPaths[typ], path)
                        end     
                    end
                end
            end            
        end
    end
end

function BLE:RegisterModule(key, module)
    if not self.modules[key] then
        self:log("Registered module editor with key %s", key)
        self.modules[key] = module
    else
        self:log("[ERROR] Module editor with key %s already exists", key or "")
    end
end

function BLE:LoadHashlist()
    local t = os.clock()
    self:log("Loading DBPaths")
    if Global.DBPaths and Global.DBPackages then
        self.DBPaths = Global.DBPaths
        self.DBPackages = Global.DBPackages
        self.WorldSounds = Global.WorldSounds
        self:log("DBPaths already loaded")
    else
        --TEMP
        self.DBPaths = FileIO:ReadScriptDataFrom(Path:Combine(self.path, "Data", "Paths.bin"), "binary") 
        self.DBPackages = FileIO:ReadScriptDataFrom(Path:Combine(self.path, "Data", "PackagesPaths.bin"), "binary") 
        self.WorldSounds = FileIO:ReadScriptDataFrom(Path:Combine(self.path, "Data", "WorldSounds.bin"), "binary") 
        self:log("Successfully loaded DBPaths, It took %.2f seconds", os.clock() - t)
        Global.DBPaths = self.DBPaths
        Global.DBPackages = self.DBPackages
        Global.WorldSounds = self.WorldSounds
    end
end

--Converts a list of packages - assets of packages to premade tables to be used in the editor
function BLE:GeneratePackageData()
    local types = table.list_add(clone(BeardLibEditor._config.script_data_types), {"unit", "texture", "movie", "effect", "scene"})
    local file = io.open(self.path .. "packages.txt", "r")
    local packages_paths = {}
    local paths = {}
    local current_pkg
    self:log("[GeneratePackageData] Writing package data...")
    if file then
        for line in file:lines() do 
            if string.sub(line, 1, 1) == "@" then
                current_pkg = string.sub(line, 2)
            elseif current_pkg then
                packages_paths[current_pkg] = packages_paths[current_pkg] or {}
                local pkg = packages_paths[current_pkg]
                local path, typ = unpack(string.split(line, "%."))
                if typ then                    
                    pkg[typ] = pkg[typ] or {}
                    paths[typ] = paths[typ] or {}
                    if DB:has(typ, path) then
                        if not table.contains(paths[typ], path) then
                            table.insert(paths[typ], path)
                        end
                        if not table.contains(pkg[typ], path) then
                            table.insert(pkg[typ], path)
                        end
                    end
                end
            end
        end
        file:close()
        self:log("[GeneratePackageData] Done!")
    else
        self:log("[GeneratePackageData] packages.txt is missing...")
    end
    
    FileIO:WriteScriptDataTo(Path:Combine(self.path, "Data", "Paths.bin"), paths, "binary")
    FileIO:WriteScriptDataTo(Path:Combine(self.path, "Data", "PackagesPaths.bin"), packages_paths, "binary")
    Global.DBPaths = nil
    self:LoadHashlist()
end

--Gets all emitters and occasionals from extracted .world_sounds
function BLE:GenerateSoundData()
    local sounds = {}
    local function get_sounds(path)
        for _, file in pairs(FileIO:GetFiles(path)) do
            if string.ends(file, ".world_sounds") then
                local data = FileIO:ReadScriptDataFrom(Path:Combine(path, file), "binary")
                if not table.contains(sounds, data.default_ambience) then
                    table.insert(sounds, data.default_ambience)
                end
                if not table.contains(sounds, data.default_occasional) then
                    table.insert(sounds, data.default_occasional)
                end
                for _, v in pairs(data.sound_area_emitters) do
                    if not table.contains(sounds, v.emitter_event) then
                        table.insert(sounds, v.emitter_event)
                    end
                end
                for _, v in pairs(data.sound_emitters) do
                    if not table.contains(sounds, v.emitter_event) then
                        table.insert(sounds, v.emitter_event)
                    end
                end
                for _, v in pairs(data.sound_environments) do
                    if not table.contains(sounds, v.ambience_event) then
                        table.insert(sounds, v.ambience_event)
                    end
                    if not table.contains(sounds, v.occasional_event) then
                        table.insert(sounds, v.occasional_event)
                    end
                end
            end
        end
        for _, folder in pairs(FileIO:GetFolders(path)) do
            get_sounds(Path:Combine(path, folder))
        end
    end
    get_sounds(self.ExtractDirectory.."levels")
    FileIO:WriteScriptDataTo(Path:Combine(self.path, "Data", "WorldSounds.bin"), sounds, "binary")
    self.WorldSounds = sounds
    Global.WorldSounds = sounds
end

function BLE:LoadCustomAssetsToHashList(add)
    for _, v in pairs(add) do
        if type(v) == "table" then
            if v._meta == "unit_load" then
                self:LoadCustomAssetsToHashList(v)
            else
                self.DBPaths[v._meta] = self.DBPaths[v._meta] or {}
                if not table.contains(self.DBPaths[v._meta], v.path) then
                    table.insert(self.DBPaths[v._meta], v.path)
                end
                self.Utils.allowed_units[v.path] = true
            end
        end
    end
end

function BLE:Update(t, dt)
    for _, manager in pairs(self.managers) do
        if manager.update then
            manager:update(t, dt)
        end
    end
end

function BLE:PausedUpdate(t, dt)
    for _, manager in pairs(self.managers) do
        if manager.paused_update then
            manager:paused_update(t, dt)
        end
    end
end

function BLE:SetLoadingText(text)
    if alive(Global.LoadingText) then
        local project = Global.current_custom_level and Global.current_custom_level._mod
        local s = "Level ".. tostring(Global.game_settings.level_id)
        if project then
            s = "Project " .. tostring(project.Name) .. ":" .. tostring(Global.game_settings.level_id)
        end
        if Global.editor_safe_mode then
        	s = "[SAFE MODE]" .. "\n" .. s
        end
        s = s .. "\n" .. tostring(text)
        Global.LoadingText:set_name(s)
        return s
    end
end

if not BLE.InitDone then
    BeardLibEditor:Init()
end

Hooks:Add("MenuUpdate", "BeardLibEditorMenuUpdate", ClassClbk(BLE, "Update"))
Hooks:Add("GameSetupUpdate", "BeardLibEditorGameSetupUpdate", ClassClbk(BLE, "Update"))
Hooks:Add("GameSetupPauseUpdate", "BeardLibEditorGameSetupPausedUpdate", ClassClbk(BLE, "PausedUpdate"))
Hooks:Add("SetupInitManagers", "BeardLibEditorInitManagers", ClassClbk(BLE, "InitManagers"))
Hooks:PostHook(GameSetup, "init_finalize", "BeardLibEditorInitFinalize", function()
	BeardLibEditor:SetLoadingText("Almost There")
	if Global.editor_mode then 
		if Global.game_settings.single_player then
			game_state_machine:change_state_by_name("editor")
		end
	end
end)

Hooks:PostHook(GameSetup, "load_packages", "BeardLibEditorLoadPackages", function(self)
	local function load_difficulty_package(package_name)
		if PackageManager:package_exists(package_name) and not PackageManager:loaded(package_name) then
			table.insert(self._loaded_diff_packages, package_name)
			PackageManager:load(package_name)
		end
	end
	for i, difficulty in ipairs(tweak_data.difficulties) do
		local diff_package = "packages/" .. (difficulty or "normal")
		load_difficulty_package(diff_package)
	end	
end)

Hooks:PostHook(GameSetup, "destroy", "BeardLibEditorDestroy",function()
	if managers.editor then
		managers.editor:destroy()
	end
end)
function MenuManager:create_controller()
    if not self._controller then
        self._controller = managers.controller:create_controller("MenuManager", nil, true)
        local setup = self._controller:get_setup()
        local look_connection = setup:get_connection("look")
        self._look_multiplier = look_connection:get_multiplier()
        if not managers.savefile:is_active() then
            self._controller:enable()
        end
    end
end
 

local o = MenuCallbackHandler._dialog_end_game_yes
function MenuCallbackHandler:_dialog_end_game_yes(...)
    Global.editor_mode = nil
    o(self, ...)
end

Hooks:PostHook(MenuManager, "toggle_menu_state", "RaidEditorToggleMenuState", function(self)
    if managers.editor and managers.editor:enabled() then
        managers.hud:set_disabled()
    end
end)
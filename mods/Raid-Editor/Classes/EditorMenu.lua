EditorMenu = EditorMenu or class() 
function EditorMenu:init()
    self._menus = {}
    local accent_color = BeardLibEditor.Options:GetValue("AccentColor")
	self._main_menu = MenuUI:new({
        name = "Editor",
        layer = 1500,
        background_blur = true,
        auto_foreground = true,
        accent_color = accent_color,
        highlight_color = accent_color,
		create_items = callback(self, self, "create_items"),
	})
    RaidMenuCallbackHandler.BeardLibEditorMenu = callback(self, self, "set_enabled", true)
    RaidMenuHelper:InjectButtons("raid_menu_left_options", nil, {
        RaidMenuHelper:PrepareListButton("Raid Editor", false, "BeardLibEditorMenu")
    }, true)
end

function EditorMenu:make_page(name, clbk, opt)
    self._menus[name] = self._menus[name] or self._main_menu:Menu(table.merge({
        name = name,
        background_color = BeardLibEditor.Options:GetValue("BackgroundColor"),
        items_size = 32,
        visible = false,
        position = "RightBottom",
        w = self._main_menu._panel:w() - 300,
    }, opt or {}))
    self._menus[name].highlight_color = self._menus[name].foreground:with_alpha(0.1)
    self:Button(name, clbk or callback(self, self, "select_page", name), {offset = 4, highlight_color = self._menus[name].highlight_color})

    return self._menus[name]
end

function EditorMenu:create_items(menu)
	self._main_menu = menu
	self._tabs = menu:Menu({
		name = "tabs",
        scrollbar = false,
        background_color = BeardLibEditor.Options:GetValue("BackgroundColor"),
        border_color = BeardLibEditor.Options:GetValue("AccentColor"),
        visible = true,
        items_size = 36,
        w = 250,
        h = self._main_menu._panel:h(),
        position = "Left",
	})
	MenuUtils:new(self, self._tabs)   
    local div = self:Divider("Raid Editor", {items_size = 42, offset = 0, background_color = self._tabs.highlight_color}) 
    self:SmallImageButton("Close", callback(self, self, "set_enabled", false), "ui/atlas/raid_atlas_menu", {761, 721, 18, 18}, div, {
        w = self._tabs.items_size - 6, h = self._tabs.items_size - 6, inherit = div, img_rot = 45
    })
end

function EditorMenu:should_close()
    return self._main_menu:ShouldClose()
end

function EditorMenu:hide()
    self:set_enabled(false)
    return true
end

function EditorMenu:set_enabled(enabled)
    local in_editor = managers.editor and game_state_machine:current_state_name() == "editor"
    local opened = BLT.Dialogs:DialogOpened(self)
    if enabled then
        if not opened then
            BLT.Dialogs:ShowDialog(self)
            self._main_menu:Enable()
            if in_editor then
                managers.editor._enabled = false
            end
        end
    elseif opened then
        BLT.Dialogs:CloseDialog(self)
        self._main_menu:Disable()
        if in_editor then
            managers.editor._enabled = true
        end
    end
end

function EditorMenu:select_page(page, menu, item)
    for name, m in pairs(self._menus) do
        self._tabs:GetItem(name):SetBorder({left = false})
        m:SetVisible(false)
    end 
    if not page or self._current_page == page then
        self._current_page = nil
        return
    end
    self._current_page = page
    item:SetBorder({left = true})
    self._menus[page]:SetVisible(true)
end
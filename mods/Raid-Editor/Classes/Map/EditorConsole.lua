EditorConsole = EditorConsole or class()
function EditorConsole:init(parent, menu)
    self._parent = parent
    --unused atm
    self._options_menu = menu:Menu({
        name = "console_options",
        background_color = BeardLibEditor.Options:GetValue("BackgroundColor"),
        w = 600,
        h = 18,
        visible = false,
        offset = 0,
        items_size = 18,
        scrollbar = false,
        align_method = "grid",
    })       
    self._menu = menu:Menu({
        name = "console_output",
        w = 600,
        h = 100,
        size_by_text = true,
        override_size_limit = true,
        should_scroll_down = true,
        position = "CenterBottom",
        background_color = BeardLibEditor.Options:GetValue("BackgroundColor"),
    })
    MenuUtils:new(self, self._options_menu)
    self._options_menu:Panel():set_leftbottom(self._menu:Panel():lefttop())    
    local opt = {border_bottom = true, text_align = "center", border_size = 1, border_color = BeardLibEditor.Options:GetValue("AccentColor"), w = self._options_menu.w / 5}
    self:Button("Console", callback(self, self, "ToggleConsole"), opt)
    self:Button("Clear", callback(self, self, "Clear"), table.merge(opt, {border_color = Color("ffc300")}))
    self.info = self:Toggle("Info", callback(self, self, "FilterConsole"), true, table.merge(opt, {border_color = Color.yellow}))
    self.mission = self:Toggle("Mission", callback(self, self, "FilterConsole"), false, table.merge(opt, {border_color = Color.green}))
    self.errors = self:Toggle("Errors", callback(self, self, "FilterConsole"), true, table.merge(opt, {border_color = Color.red}))
    MenuUtils:new(self)
    self:Clear()
    self:ToggleConsole()
end

function EditorConsole:ToggleConsole()
    self.closed = not self.closed
    if self.closed then
        self._options_menu:SetPosition("Bottom")
    else
        self._options_menu:SetPosition(function(menu)
            menu:Panel():set_bottom(self._menu:Panel():top() - 2)
        end)
    end
    self._menu:SetVisible(not self.closed)
end

function EditorConsole:PrintMessage(type, message, ...)
    message = type == "info" and string.format(message, ...) or message
    local date = Application:date("%X")  
    self:Divider(date .. ": " .. tostring(message), {type = type, visible = self[type]:Value(), border_color = type == "mission" and Color.green or type == "error" and Color.red or Color.yellow})
end

function EditorConsole:FilterConsole(menu, item)
    for _, item in pairs(self._menu._my_items) do
        item:SetVisible(self[item.type]:Value())
    end
end

function EditorConsole:Log(msg, ...) self:PrintMessage("info", msg, ...) end 
function EditorConsole:LogMission(msg, ...) self:PrintMessage("mission", msg, ...) end
function EditorConsole:Error(msg, ...) self:PrintMessage("error", msg, ...) end
function EditorConsole:Clear() self:ClearItems() end
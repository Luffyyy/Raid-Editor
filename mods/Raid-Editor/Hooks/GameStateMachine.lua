Hooks:PostHook(GameStateMachine, "init", "BeardLibEditorGameStateInit", function(self)
	local editor
	local editor_func
	local ingame_waiting_for_players
	local ingame_waiting_for_players_func
	local ingame_waiting_for_respawn
	for state in pairs(self._transitions) do
		if state._name == "ingame_waiting_for_respawn" then
			ingame_waiting_for_respawn = state
		end
		if state._name == "ingame_waiting_for_players" then
			ingame_waiting_for_players = state
			ingame_waiting_for_players_func = callback(nil, state, "default_transition")
		end
		if state._name == "editor" then
			editor = state
			editor_func = callback(nil, state, "default_transition")
		end
	end
	if editor and ingame_waiting_for_players and ingame_waiting_for_respawn then
		self:add_transition(editor, ingame_waiting_for_players, editor_func)
		self:add_transition(editor, ingame_waiting_for_respawn, editor_func)
		self:add_transition(ingame_waiting_for_players, editor, ingame_waiting_for_players_func)
	end
end)
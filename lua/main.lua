local LevelsTweakData_get_music_event_original = LevelsTweakData.get_music_event
local firstrun = true
local wave_counter = 0
local last_stage = nil

function LevelsTweakData:get_music_event(stage, ...)
    -- Ensure mod handles enablement checks properly
    local is_enabled = shuffle_play.save_data.shuffle_play_enable_toggled
    if is_enabled == nil then is_enabled = true end

	local original_event = LevelsTweakData_get_music_event_original(self, stage, ...)

	if is_enabled and stage == "control" and last_stage ~= "control" then
		if not firstrun then
			wave_counter = wave_counter + 1
			local freq = shuffle_play.save_data.shuffle_play_frequency or 1
			if type(freq) ~= "number" then freq = tonumber(freq) or 1 end
			if wave_counter >= freq then
				shuffle_play.set_random_track(original_event)
				wave_counter = 0
			end
		else
			firstrun = false
		end
	end
	last_stage = stage

	return original_event
end


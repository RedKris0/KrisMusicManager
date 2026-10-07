local LevelsTweakData_get_music_event_original = LevelsTweakData.get_music_event

function LevelsTweakData:get_music_event(stage, ...)
    local original_event = LevelsTweakData_get_music_event_original(self, stage, ...)

    if not shuffle_play or shuffle_play._in_set_random_track then
        return original_event
    end

    local is_enabled = shuffle_play.save_data and shuffle_play.save_data.shuffle_play_enable_toggled
    if is_enabled == nil then is_enabled = true end

    shuffle_play.current_stage = stage
    shuffle_play.wave_counter = shuffle_play.wave_counter or 0

    -- Reset upcoming banner flag when entering an assault wave
    if stage == "assault" or stage == "anticipation" then
        shuffle_play._upcoming_banner_shown = nil
    end

    -- Assault wave concluded: transitioning to control
    if is_enabled and stage == "control" and shuffle_play.last_stage ~= "control" then
        if shuffle_play.last_stage == "assault" or shuffle_play.last_stage == "fade" or shuffle_play.last_stage == "anticipation" then
            shuffle_play._upcoming_banner_shown = nil
            shuffle_play.wave_counter = (shuffle_play.wave_counter or 0) + 1
            local freq = (shuffle_play.save_data and shuffle_play.save_data.shuffle_play_frequency) or 1
            if type(freq) ~= "number" then freq = tonumber(freq) or 1 end
            local has_queued = shuffle_play.queue and #shuffle_play.queue > 0

            if shuffle_play.wave_counter >= freq or has_queued then
                shuffle_play.set_random_track(original_event)
                shuffle_play.wave_counter = 0
            end
        end
    end

    shuffle_play.last_stage = stage
    return original_event
end

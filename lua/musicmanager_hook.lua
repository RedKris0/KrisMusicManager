_G.shuffle_play = _G.shuffle_play or {}

if rawget(_G, "MusicManager") then
    Hooks:PreHook(MusicManager, "check_music_switch", "KrisMM_MusicManager_check_music_switch", function(self)
        local cur = Global.music_manager and Global.music_manager.current_track
        if cur and cur ~= "default" and cur ~= "heist" and cur ~= "ghost" and cur ~= "" then
            shuffle_play.prep_fixed_track = cur
            log("[KrisMusicManager] Fixed track detected in check_music_switch: " .. tostring(cur))
        end
    end)

    Hooks:PostHook(MusicManager, "post_event", "KrisMM_MusicManager_post_event", function(self, name)
        if not name or type(name) ~= "string" then return end

        if name == "music_heist_setup" or name == "music_stealth_setup" or name == "suspense_1" then
            shuffle_play.last_music_event = "music_heist_setup"
            shuffle_play.current_stage = "setup"
        elseif name == "music_heist_control" or name == "music_stealth_control" or name == "suspense_2" then
            shuffle_play.last_music_event = "music_heist_control"
            shuffle_play.current_stage = "control"
        elseif name == "music_heist_anticipation" or name == "music_stealth_anticipation" or name == "suspense_3" or name == "suspense_4" then
            shuffle_play.last_music_event = "music_heist_anticipation"
            shuffle_play.current_stage = "anticipation"
        elseif name == "music_heist_assault" or name == "music_stealth_assault" or name == "suspense_5" then
            shuffle_play.last_music_event = "music_heist_assault"
            shuffle_play.current_stage = "assault"
        end

        -- Synchronize initial track cleanly at heist start / restart
        if not shuffle_play._in_set_random_track and not shuffle_play.heist_started then
            if name == "music_heist_setup" or name == "music_stealth_setup" or name == "music_heist_control" or name == "music_stealth_control" or name == "suspense_1" or name == "suspense_2" then
                shuffle_play.heist_started = true

                local has_queued = shuffle_play.queue and #shuffle_play.queue > 0
                local fixed_track = shuffle_play.prep_fixed_track
                if not fixed_track and not shuffle_play._track_switched_in_game then
                    local cur = Global.music_manager and Global.music_manager.current_track
                    if cur and cur ~= "default" and cur ~= "heist" and cur ~= "ghost" and cur ~= "" then
                        fixed_track = cur
                    end
                end

                local is_shuffle_enabled = shuffle_play.save_data and shuffle_play.save_data.shuffle_play_enable_toggled
                if is_shuffle_enabled == nil then is_shuffle_enabled = true end

                if has_queued then
                    -- Priority 1: Queued track in Kris Music Manager
                    if shuffle_play.set_random_track then
                        shuffle_play.set_random_track(name)
                    end
                elseif fixed_track then
                    -- Priority 2: Fixed track chosen in preparation screen: KEEP IT!
                    log("[KrisMusicManager] Keeping player's chosen fixed track from preparation: " .. tostring(fixed_track))
                    Global.music_manager.current_track = fixed_track
                    if managers.music then
                        managers.music._current_track = fixed_track
                    end
                    local track_name = shuffle_play.get_track_name(fixed_track)
                    if managers.hud and managers.hud.show_kris_music_banner and track_name and track_name ~= "" then
                        local text = managers.localization:text("krismm_now_playing", {track = track_name})
                        managers.hud:show_kris_music_banner({text})
                    end
                    if is_shuffle_enabled then
                        shuffle_play.prepare_next_track()
                    end
                elseif is_shuffle_enabled then
                    -- Priority 3: No fixed track, Shuffle Play is ON -> randomize initial track
                    if shuffle_play.set_random_track then
                        shuffle_play.set_random_track(name)
                    end
                else
                    -- Priority 4: No fixed track, Shuffle Play is OFF -> do nothing, let vanilla play
                    log("[KrisMusicManager] Shuffle Play is OFF and no fixed track. Keeping vanilla level music.")
                    local cur_lvl_track = tweak_data and tweak_data.levels and Global.level_data and Global.level_data.level_id and tweak_data.levels[Global.level_data.level_id] and tweak_data.levels[Global.level_data.level_id].music
                    if cur_lvl_track and cur_lvl_track ~= "heist" and cur_lvl_track ~= "default" and cur_lvl_track ~= "ghost" then
                        local track_name = shuffle_play.get_track_name(cur_lvl_track)
                        if managers.hud and managers.hud.show_kris_music_banner and track_name and track_name ~= "" then
                            local text = managers.localization:text("krismm_now_playing", {track = track_name})
                            managers.hud:show_kris_music_banner({text})
                        end
                    end
                end
            end
        end
    end)
end
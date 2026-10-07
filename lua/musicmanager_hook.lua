_G.shuffle_play = _G.shuffle_play or {}

if rawget(_G, "MusicManager") then
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
                local is_enabled = shuffle_play.save_data and shuffle_play.save_data.shuffle_play_enable_toggled
                if is_enabled ~= false then
                    if shuffle_play.queue and #shuffle_play.queue > 0 and shuffle_play.set_random_track then
                        shuffle_play.set_random_track(name)
                    else
                        local cur_track = (shuffle_play.get_current_track and shuffle_play.get_current_track()) or (Global.music_manager and Global.music_manager.current_track)
                        if cur_track then
                            Global.music_manager.current_track = cur_track
                            if managers.hud and managers.hud.show_kris_music_banner then
                                local track_name = shuffle_play.get_track_name(cur_track)
                                local text_list = {
                                    managers.localization:to_upper_text("krismm_now_playing", {track = track_name})
                                }
                                managers.hud:show_kris_music_banner(text_list)
                            end
                        end
                        if shuffle_play.prepare_next_track then
                            shuffle_play.prepare_next_track()
                        end
                    end
                end
            end
        end
    end)
end

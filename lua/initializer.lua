_G.shuffle_play = _G.shuffle_play or {}
shuffle_play.mod_path = ModPath
shuffle_play.save_path = SavePath .. "shuffle_play.json"
shuffle_play.save_data = {}
shuffle_play.tracks = {}
shuffle_play.track_menu_save_keys = {}
shuffle_play.next_track = nil
shuffle_play.queue = {}
shuffle_play.history = shuffle_play.history or {}

function shuffle_play.get_current_track()
    local track = Global.music_manager and Global.music_manager.current_track
    if not track or track == "default" or track == "heist" or track == "ghost" then
        if managers.music and managers.music._current_track and managers.music._current_track ~= "default" and managers.music._current_track ~= "heist" and managers.music._current_track ~= "ghost" then
            track = managers.music._current_track
        else
            track = nil
        end
    end
    return track
end

function shuffle_play.get_track_name(track_id)
    if not track_id or track_id == "heist" or track_id == "ghost" or track_id == "default" or track_id == "" then return "" end
    if CustomOST and CustomOST.track_manager then
        local cost_track = CustomOST.track_manager:get_track(track_id)
        if cost_track and cost_track.get_name then
            return cost_track:get_name()
        end
    end
    if BeardLib and BeardLib.MusicMods and BeardLib.MusicMods[track_id] and BeardLib.MusicMods[track_id].name then
        return BeardLib.MusicMods[track_id].name
    end
    if managers and managers.localization then
        local loc_key = "menu_jukebox_" .. track_id
        if tweak_data and tweak_data.music and tweak_data.music[track_id] and tweak_data.music[track_id].name_id then
            loc_key = tweak_data.music[track_id].name_id
        end
        if managers.localization:exists(loc_key) then
            local text = managers.localization:text(loc_key)
            if not text:find("ERROR:") then
                return text
            end
        end
        local screen_loc_key = "menu_jukebox_screen_" .. track_id
        if managers.localization:exists(screen_loc_key) then
            local text = managers.localization:text(screen_loc_key)
            if not text:find("ERROR:") then
                return text
            end
        end
    end
    return track_id
end

function shuffle_play.get_loaded_tracks()
    if managers and managers.music and managers.music.jukebox_music_tracks then
        return managers.music:jukebox_music_tracks()
    end
    local tracks = {}
    local seen = {}
    local track_list = tweak_data and tweak_data.music and tweak_data.music.track_list or {}

    for _, entry in ipairs(track_list) do
        local track_id = entry and entry.track
        if track_id and not seen[track_id] then
            seen[track_id] = true
            table.insert(tracks, track_id)
        end
    end
    return tracks
end

if rawget(_G, "Setup") and Setup.init_managers then
    local Setup_init_managers_original = Setup.init_managers
    function Setup:init_managers(...)
        Setup_init_managers_original(self, ...)
        shuffle_play.heist_started = nil
        shuffle_play.wave_counter = 0
        shuffle_play._upcoming_banner_shown = nil
        shuffle_play._track_switched_in_game = nil
        shuffle_play.tracks = shuffle_play.get_loaded_tracks()
        shuffle_play.prepare_next_track()
    end
end

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_shuffle_play_init", function(menu_manager)
    shuffle_play.prep_fixed_track = nil
    shuffle_play._track_switched_in_game = nil
    if Global.music_manager then Global.music_manager.current_track = nil end
    if not shuffle_play.tracks or #shuffle_play.tracks == 0 then
        shuffle_play.tracks = shuffle_play.get_loaded_tracks()
        shuffle_play.prepare_next_track()
    end
end)

function shuffle_play.is_track_playable(track)
    if not track then return false end

    -- CustomOST track
    if CustomOST and CustomOST.track_manager and CustomOST.track_manager:get_track(track) then
        return true
    end

    -- BeardLib custom track
    if BeardLib and BeardLib.MusicMods and BeardLib.MusicMods[track] then
        local mod_data = BeardLib.MusicMods[track]
        if not mod_data.xaudio then
            return false
        end
        local events = mod_data.events
        if not events then return false end
        -- Verify it is a heist track with combat events (not menu-only)
        if events.assault or events.control or events.setup or events.anticipation
           or events.music_heist_assault or events.music_heist_control then
            return true
        end
        return false
    end

    -- Vanilla track
    if tweak_data and tweak_data.music and tweak_data.music[track] then
        local data = tweak_data.music[track]
        if type(data) == "table" and (data.assault or data.control) then
            return true
        end
    end

    return true
end

function shuffle_play.get_valid_tracks()
    local valid = {}
    for _, track in ipairs(shuffle_play.tracks) do
        if shuffle_play.is_track_playable(track) then
            local is_enabled = true
            if shuffle_play.save_data then
                local save_key1 = "shuffle_play_track_" .. track .. "_toggled"
                local save_key2 = "shuffle_play_" .. track .. "_toggled"
                if shuffle_play.save_data[save_key1] == false or shuffle_play.save_data[save_key2] == false then
                    is_enabled = false
                end
            end
            if is_enabled then
                table.insert(valid, track)
            end
        end
    end
    return valid
end

function shuffle_play.prepare_next_track()
    -- 1. QUEUE HAS HIGHEST PRIORITY
    if #shuffle_play.queue > 0 then
        shuffle_play.next_track = shuffle_play.queue[1]
        shuffle_play.next_track_is_queued = true
        return
    end

    shuffle_play.next_track_is_queued = false

    local valid_tracks = shuffle_play.get_valid_tracks()
    if #valid_tracks == 0 then 
        valid_tracks = shuffle_play.tracks
        if #valid_tracks == 0 then return end
    end
    
    local current_track = (shuffle_play.get_current_track and shuffle_play.get_current_track()) or (Global.music_manager and Global.music_manager.current_track)
    
    if shuffle_play.save_data and shuffle_play.save_data.shuffle_play_no_repeat_toggled then
        shuffle_play.unplayed_tracks = shuffle_play.unplayed_tracks or {}
        
        local new_unplayed = {}
        for _, ut in ipairs(shuffle_play.unplayed_tracks) do
            local still_valid = false
            for _, vt in ipairs(valid_tracks) do
                if ut == vt then
                    still_valid = true
                    break
                end
            end
            if still_valid and ut ~= current_track then
                table.insert(new_unplayed, ut)
            end
        end
        shuffle_play.unplayed_tracks = new_unplayed
        
        if #shuffle_play.unplayed_tracks == 0 then
            for _, vt in ipairs(valid_tracks) do
                if vt ~= current_track or #valid_tracks == 1 then
                    table.insert(shuffle_play.unplayed_tracks, vt)
                end
            end
        end
        
        if #shuffle_play.unplayed_tracks > 0 then
            local idx = math.random(#shuffle_play.unplayed_tracks)
            shuffle_play.next_track = shuffle_play.unplayed_tracks[idx]
            table.remove(shuffle_play.unplayed_tracks, idx)
        end
    else
        local candidates = {}
        for _, vt in ipairs(valid_tracks) do
            if (vt ~= current_track and vt ~= shuffle_play.next_track) or #valid_tracks == 1 then
                table.insert(candidates, vt)
            end
        end
        if #candidates > 0 then
            shuffle_play.next_track = candidates[math.random(#candidates)]
        else
            shuffle_play.next_track = valid_tracks[math.random(#valid_tracks)]
        end
    end
end

function shuffle_play.hsv_to_rgb(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b
    
    if h >= 0 and h < 60 then
        r, g, b = c, x, 0
    elseif h >= 60 and h < 120 then
        r, g, b = x, c, 0
    elseif h >= 120 and h < 180 then
        r, g, b = 0, c, x
    elseif h >= 180 and h < 240 then
        r, g, b = 0, x, c
    elseif h >= 240 and h < 300 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end
    
    return r + m, g + m, b + m
end

function shuffle_play.get_current_event()
    local ai_state = managers.groupai and managers.groupai:state()
    if ai_state then
        -- 1. Stealth check
        if ai_state.whisper_mode and ai_state:whisper_mode() then
            return "music_heist_setup"
        end

        -- 2. Hunt mode (endless assault)
        if ai_state._hunt_mode then
            return "music_heist_assault"
        end

        -- 3. Police Assault check
        local assault = ai_state._task_data and ai_state._task_data.assault
        if assault and assault.active then
            if assault.phase == "anticipation" then
                return "music_heist_anticipation"
            else
                -- build, sustain, fade are all active combat assault music
                return "music_heist_assault"
            end
        end

        -- Check HUD assault corner as backup
        local hud = managers.hud and managers.hud._hud_assault_corner
        if hud and (hud._assault or hud._is_assault) then
            return "music_heist_assault"
        end

        -- 4. Between waves or loud casing / control
        if not ai_state:enemy_weapons_hot() and shuffle_play.current_stage == "setup" then
            return "music_heist_setup"
        end
    end

    if shuffle_play.current_stage == "assault" then
        return "music_heist_assault"
    elseif shuffle_play.current_stage == "anticipation" then
        return "music_heist_anticipation"
    elseif shuffle_play.current_stage == "setup" then
        return "music_heist_setup"
    end

    return "music_heist_control"
end

function shuffle_play.set_random_track(forced_event, specific_track, is_rewind)

    if shuffle_play._in_set_random_track then
        return
    end
    shuffle_play._in_set_random_track = true

    -- 1. Determine which track to play (Specific / Queue / Random)
    local track_to_play = nil
    if specific_track then
        track_to_play = specific_track
    elseif #shuffle_play.queue > 0 then
        track_to_play = table.remove(shuffle_play.queue, 1)
        shuffle_play.next_track = nil
    elseif shuffle_play.next_track then
        track_to_play = shuffle_play.next_track
        shuffle_play.next_track = nil
    else
        shuffle_play.prepare_next_track()
        track_to_play = shuffle_play.next_track
        shuffle_play.next_track = nil
    end

    if track_to_play and not shuffle_play.is_track_playable(track_to_play) then
        log("[KrisMusicManager] Track " .. tostring(track_to_play) .. " is not playable in heists. Skipping.")
        shuffle_play.prepare_next_track()
        track_to_play = shuffle_play.next_track
        shuffle_play.next_track = nil
    end

    if not track_to_play then
    shuffle_play._track_switched_in_game = true
    shuffle_play.prep_fixed_track = nil
    shuffle_play._in_set_random_track = false
        return
    end

    -- Save previously played track to history (unless this is a rewind)
    local cur_track = Global.music_manager and Global.music_manager.current_track
    if cur_track and not is_rewind and cur_track ~= track_to_play then
        shuffle_play.history = shuffle_play.history or {}
        table.insert(shuffle_play.history, cur_track)
        if #shuffle_play.history > 30 then
            table.remove(shuffle_play.history, 1)
        end
    end

    -- 2. Target Event Detection
    local event = forced_event or shuffle_play.get_current_event()

    -- 3. Prepare next track for future transitions / announcements
    shuffle_play.prepare_next_track()

    -- 4. Clean Audio Switch: stop previous custom or vanilla sounds
    if Global.music_manager and Global.music_manager.source then
        Global.music_manager.source:stop()
        Global.music_manager.source:post_event("stop_all_music")
    end
    if managers.music then
        if managers.music.stop then
            pcall(function() managers.music:stop() end)
        end
        if managers.music.stop_custom then
            pcall(function() managers.music:stop_custom() end)
        end
        managers.music._current_custom_track = nil
    end
    if CustomOST and CustomOST.force_stop then
        pcall(function() CustomOST:force_stop(false, 0) end)
    end

    -- 5. Trigger playback
    local played_custom = false

    -- CustomOST tracks
    if CustomOST and CustomOST.track_manager and CustomOST.track_manager:get_track(track_to_play) then
        if managers.music and managers.music.track_listen_start then
            managers.music:track_listen_start(event, track_to_play)
            played_custom = true
        end
    end

    -- BeardLib / Custom Heist Music tracks (must support XAudio in heists)
    if not played_custom and BeardLib and BeardLib.MusicMods and BeardLib.MusicMods[track_to_play] and BeardLib.MusicMods[track_to_play].xaudio then
        if managers.music and managers.music.attempt_play then
            -- Stop any vanilla music
            if Global.music_manager and Global.music_manager.source then
                Global.music_manager.source:post_event("stop_all_music")
            end
            local success = managers.music:attempt_play(track_to_play, event, true)
            if success then
                played_custom = true
            end
        end
    end

    -- Vanilla / Wwise tracks
    if not played_custom then
        -- Tell BeardLib that this is NOT a custom track so BeardLib clears its custom state and stops XAudio
        if BeardLib and managers.music and managers.music.attempt_play then
            managers.music:attempt_play(track_to_play, event, true)
        end
        if managers.music then
            if managers.music.stop_custom then
                pcall(function() managers.music:stop_custom() end)
            end
            managers.music._current_custom_track = nil
        end

        if Global.music_manager and Global.music_manager.source then
            Global.music_manager.source:set_switch("music_randomizer", track_to_play)

            -- Wwise music container must be started via setup Play-event before any state transitions
            Global.music_manager.source:post_event("music_heist_setup")
            if event and event ~= "music_heist_setup" then
                Global.music_manager.source:post_event(event)
            end
        end

        Global.music_manager.current_event = event
        Global.music_manager.current_track = track_to_play
        if managers.music then
            managers.music._current_event = event
            managers.music._current_track = track_to_play
        end
    end

    log("[KrisMusicManager] Switched track to: " .. tostring(track_to_play) .. " | Event: " .. tostring(event) .. " | Custom: " .. tostring(played_custom))

    Global.music_manager.current_track = track_to_play
    Global.music_manager.current_event = event
    if managers.music then
        managers.music._current_track = track_to_play
        managers.music._current_event = event
    end
    shuffle_play.last_music_event = event

    -- 6. HUD Notification Banner (Permanent, updates text & color)
    local track_name = shuffle_play.get_track_name(track_to_play)
    if managers.hud and managers.hud.show_kris_music_banner and track_name and track_name ~= "" then
        local text = managers.localization:text("krismm_now_playing", {track = track_name})
        managers.hud:show_kris_music_banner({text})
    end

    shuffle_play._track_switched_in_game = true
    shuffle_play.prep_fixed_track = nil
    shuffle_play._in_set_random_track = false
end

function shuffle_play.play_previous_track()

    if not shuffle_play.history or #shuffle_play.history == 0 then
        if managers.hud then
            managers.hud:show_hint({text = managers.localization:text("krismm_no_previous_track"), time = 2})
        end
        return
    end

    local prev_track = table.remove(shuffle_play.history)

    -- Preserve the current track at the start of the queue so skipping goes forward cleanly
    local current_track = Global.music_manager and Global.music_manager.current_track
    if current_track and current_track ~= prev_track then
        table.insert(shuffle_play.queue, 1, current_track)
        shuffle_play.next_track = current_track
        shuffle_play.next_track_is_queued = true
    end

    if managers.hud then
        managers.hud:show_hint({text = managers.localization:text("krismm_previous_track_title"), time = 1.5})
    end

    shuffle_play.set_random_track(nil, prev_track, true)
end

function shuffle_play.trigger_upcoming_banner()
    local is_enabled = shuffle_play.save_data and shuffle_play.save_data.shuffle_play_enable_toggled
    if is_enabled == nil then is_enabled = true end
    if not is_enabled then return end

    local show_banner = shuffle_play.save_data and shuffle_play.save_data.krismm_show_banner_toggled
    if show_banner == nil then show_banner = true end
    if not show_banner then return end

    if shuffle_play._upcoming_banner_shown then return end

    -- Check if the track will actually change
    local freq = (shuffle_play.save_data and shuffle_play.save_data.shuffle_play_frequency) or 1
    if type(freq) ~= "number" then freq = tonumber(freq) or 1 end
    local wave_counter = shuffle_play.wave_counter or 0
    local has_queued = shuffle_play.queue and #shuffle_play.queue > 0
    local will_change = has_queued or ((wave_counter + 1) >= freq)

    if not will_change then
        return
    end

    shuffle_play._upcoming_banner_shown = true

    if not shuffle_play.next_track then
        shuffle_play.prepare_next_track()
    end

    if shuffle_play.next_track and shuffle_play.get_track_name then
        local track_to_play = shuffle_play.next_track
        local track_name = shuffle_play.get_track_name(track_to_play)
        if managers.hud and managers.hud.show_kris_music_banner and track_name and track_name ~= "" then
            local text = managers.localization:text("krismm_upcoming_song", {track = track_name})
            managers.hud:show_kris_music_banner({text}, Color(1, 0.8, 0.2))
        end
    end
end

function shuffle_play.check_assault_timing(t)
    if shuffle_play._upcoming_banner_shown then return end

    if not TimerManager or not TimerManager:game() then return end

    local ai = managers.groupai and managers.groupai:state()
    if not ai or not ai._task_data then return end

    local assault = ai._task_data.assault
    if not assault then return end

    if ai.whisper_mode and ai:whisper_mode() then return end

    local game_t = t or TimerManager:game():time()

    if assault.phase == "fade" then
        local time_left = assault.phase_end_t and (assault.phase_end_t - game_t)
        if not time_left or time_left <= 15 then
            shuffle_play.trigger_upcoming_banner()
        end
    end
end

if Setup then
    Hooks:PostHook(Setup, "update", "KrisMM_Setup_update_assault", function(self, t, dt)
        if shuffle_play and shuffle_play.check_assault_timing then
            if not shuffle_play._next_setup_check_t or t > shuffle_play._next_setup_check_t then
                shuffle_play._next_setup_check_t = t + 0.25
                shuffle_play.check_assault_timing(t)
            end
        end
    end)
end
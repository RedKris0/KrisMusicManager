_G.shuffle_play = _G.shuffle_play or {}
shuffle_play.mod_path = ModPath
shuffle_play.save_path = SavePath .. "shuffle_play.json"
shuffle_play.save_data = {}
shuffle_play.tracks = {}
shuffle_play.track_menu_save_keys = {}
shuffle_play.next_track = nil
shuffle_play.queue = {}

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

local Setup_init_managers_original = Setup.init_managers
function Setup:init_managers(...)
    Setup_init_managers_original(self, ...)
    shuffle_play.tracks = shuffle_play.get_loaded_tracks()
    shuffle_play.prepare_next_track()
end

function shuffle_play.get_valid_tracks()
    local valid = {}
    for _, track in ipairs(shuffle_play.tracks) do
        local is_enabled = true
        if shuffle_play.save_data then
            local save_key = "shuffle_play_" .. track .. "_toggled"
            if shuffle_play.save_data[save_key] == false then
                is_enabled = false
            end
        end
        if is_enabled then
            table.insert(valid, track)
        end
    end
    return valid
end

function shuffle_play.prepare_next_track()
    if #shuffle_play.queue > 0 then
        shuffle_play.next_track = shuffle_play.queue[1]
        table.remove(shuffle_play.queue, 1)
        
        shuffle_play.next_track_is_queued = true
        if shuffle_play.next_track then
            if BeardLib and BeardLib.MusicMods and BeardLib.MusicMods[shuffle_play.next_track] then
                shuffle_play._preload_co = coroutine.create(function()
                    local music_mod = BeardLib.MusicMods[shuffle_play.next_track]
                    if music_mod and music_mod.events then
                        for _, event in pairs(music_mod.events) do
                            if event.tracks then
                                for _, track in pairs(event.tracks) do
                                    if track.start_source and track.start_source.path and not track.start_source.buffer then
                                        track.start_source.buffer = XAudio.Buffer:new(track.start_source.path)
                                        coroutine.yield()
                                    end
                                    if track.source and track.source.path and not track.source.buffer then
                                        track.source.buffer = XAudio.Buffer:new(track.source.path)
                                        coroutine.yield()
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
        return
    end

    local valid_tracks = shuffle_play.get_valid_tracks()
    if #valid_tracks == 0 then 
        valid_tracks = shuffle_play.tracks
        if #valid_tracks == 0 then return end
    end
    
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
            if still_valid and ut ~= Global.music_manager.current_track then
                table.insert(new_unplayed, ut)
            end
        end
        shuffle_play.unplayed_tracks = new_unplayed
        
        if #shuffle_play.unplayed_tracks == 0 then
            for _, vt in ipairs(valid_tracks) do
                if vt ~= Global.music_manager.current_track or #valid_tracks == 1 then
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
            if vt ~= Global.music_manager.current_track and vt ~= shuffle_play.next_track or #valid_tracks == 1 then
                table.insert(candidates, vt)
            end
        end
        if #candidates > 0 then
            shuffle_play.next_track = candidates[math.random(#candidates)]
        else
            shuffle_play.next_track = valid_tracks[math.random(#valid_tracks)]
        end
    end
    
    if shuffle_play.next_track then
        if BeardLib and BeardLib.MusicMods and BeardLib.MusicMods[shuffle_play.next_track] then
            shuffle_play._preload_co = coroutine.create(function()
                local music_mod = BeardLib.MusicMods[shuffle_play.next_track]
                if music_mod and music_mod.events then
                    for _, event in pairs(music_mod.events) do
                        if event.tracks then
                            for _, track in pairs(event.tracks) do
                                if track.start_source and track.start_source.path and not track.start_source.buffer then
                                    track.start_source.buffer = XAudio.Buffer:new(track.start_source.path)
                                    coroutine.yield()
                                end
                                if track.source and track.source.path and not track.source.buffer then
                                    track.source.buffer = XAudio.Buffer:new(track.source.path)
                                    coroutine.yield()
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end

Hooks:Add("GameSetupUpdate", "GameSetupUpdate_shuffle_play_co", function()
    if shuffle_play._preload_co and coroutine.status(shuffle_play._preload_co) ~= "dead" then
        local success, err = coroutine.resume(shuffle_play._preload_co)
        if not success then
            log("[ShufflePlay] Preload error: " .. tostring(err))
            shuffle_play._preload_co = nil
        end
    end
    
    if shuffle_play._switch_co and coroutine.status(shuffle_play._switch_co) ~= "dead" then
        local success, err = coroutine.resume(shuffle_play._switch_co)
        if not success then
            log("[ShufflePlay] Switch error: " .. tostring(err))
            shuffle_play._switch_co = nil
        end
    end
end)

function shuffle_play.set_random_track(forced_event)
    if shuffle_play.save_data.shuffle_play_enable_toggled == false then return end

    if not shuffle_play.next_track then
        shuffle_play.prepare_next_track()
    end
    
    local track_to_play = shuffle_play.next_track
    if not track_to_play then return end
    
    local event = forced_event or Global.music_manager.current_event or "music_heist_control"
    
    shuffle_play.prepare_next_track()
    
    if shuffle_play._switch_co then
        shuffle_play._switch_co = nil
    end
    
    shuffle_play._switch_co = coroutine.create(function()
        local steps = 30
        for i = 1, steps do
            local mul = 1 - (i / steps)
            if managers.music and managers.music._xa_source then
                managers.music._xa_source:set_volume((managers.music._xa_volume or 1) * mul * managers.music._volume_mul)
            end
            if managers.music and managers.music._player then
                managers.music._player:set_volume_gain((managers.music._player_volume or 1) * Global.music_manager.volume * managers.music._volume_mul * mul)
            end
            coroutine.yield()
        end
        
        if managers.music.stop_custom then
            managers.music:stop_custom()
        end
        
        if CustomOST and CustomOST.track_manager and CustomOST.track_manager:get_track(track_to_play) then
            managers.music:track_listen_start(event, track_to_play)
        elseif BeardLib and BeardLib.MusicMods and BeardLib.MusicMods[track_to_play] then
            managers.music._current_custom_track = track_to_play
            Global.music_manager.source:stop()
            managers.music:post_event(event)
        else
            if managers.music and managers.music._current_custom_track then
                managers.music._current_custom_track = nil
                if managers.music.stop then managers.music:stop() end
            end
            Global.music_manager.source:stop()
            Global.music_manager.source:set_switch("music_randomizer", track_to_play)
            if managers.music and managers.music.post_event then
                managers.music:post_event(event)
            else
                Global.music_manager.source:post_event(event)
            end
        end
        
        Global.music_manager.current_track = track_to_play
    end)
end








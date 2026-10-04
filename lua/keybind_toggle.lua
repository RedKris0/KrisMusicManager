if shuffle_play and shuffle_play.save_data then
    shuffle_play.save_data.shuffle_play_enable_toggled = not shuffle_play.save_data.shuffle_play_enable_toggled
    if shuffle_play.save then
        shuffle_play:save()
    end
    
    local state = shuffle_play.save_data.shuffle_play_enable_toggled and "ON" or "OFF"
    local msg = "Shuffle Play: " .. state
    
    if managers.hud then
        managers.hud:show_hint({text = msg, time = 3})
    elseif BLT and BLT.Notifications then
        BLT.Notifications:add_notification({ title = "KrisMusicManager", text = msg, priority = 1000 })
    end
    if managers.menu_component then
        managers.menu_component:post_event("menu_enter")
    end
end

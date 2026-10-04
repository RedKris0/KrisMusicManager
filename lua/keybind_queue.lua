if managers.menu then
    if not managers.menu:active_menu() then
        managers.menu:open_menu("menu_pause")
    end
    managers.menu:open_node("krismm_queue_menu")
end

local my_data = {}

local function get_day_identifier()
  -- Use game ticks to create a daily identifier
  -- 60 ticks per second * 60 seconds * 60 minutes * 24 hours = 5184000 ticks per day
  local ticks_per_day = 60 * 60 * 60 * 24
  local day_number = math.floor(game.tick / ticks_per_day)
  return "day_" .. day_number
end

local function init_storage()
  if not storage then storage = {} end
  storage.memorial_dates = storage.memorial_dates or {}

  my_data.start_tick = game.tick
  my_data.timer_enabled = true
  my_data.warning_shown = false

  local minutes = settings.global["addiction-timer-minutes"].value
  game.print("Addiction timer enabled: Game will save and close in " .. minutes .. " minutes.", {r=1, g=0.8, b=0})
  game.print("A memorial fish will be placed when the session ends.", {r=0, g=0.8, b=1})
end
local function create_fish_memorial_surface()
  -- Create or get the memorial surface
  local surface_name = "addiction-timer-memorial"
  local surface = game.get_surface(surface_name)
  
  if not surface then
    -- Create a new surface that players can't access
    surface = game.create_surface(surface_name, {
      width = 64,
      height = 64,
      peaceful_mode = true,
      water = 1, -- Make it all water
      starting_area = "none",
      property_expression_names = {
        elevation = "0", -- Flat water surface
        temperature = "15",
        moisture = "1",
        aux = "0",
        cliffiness = "0",
        enemy_base_intensity = "0",
        enemy_base_frequency = "0"
      }
    })
    
    -- Disable all spawners and evolution
    surface.peaceful_mode = true
    surface.freeze_daytime = true
    surface.daytime = 0.5 -- Noon lighting
  end
  
  return surface
end

local function check_existing_memorial_fish()
  local today_id = get_day_identifier()
  
  -- Check storage storage first
  if not storage then storage = {} end
  storage.memorial_dates = storage.memorial_dates or {}
  if storage.memorial_dates[today_id] then
    return true
  end
  
  -- Check if memorial surface exists
  local surface = game.get_surface("addiction-timer-memorial")
  if surface then
    local fish_count = surface.count_entities_filtered{name = "fish"}
    if fish_count > 0 then
      -- If we have fish but no date record, assume we need to check more carefully
      -- For existing saves, we'll be conservative and allow the timer
      return false
    end
  end
  
  return false
end

local function place_memorial_fish()
  local today_id = get_day_identifier()
  local surface = create_fish_memorial_surface()
  
  -- Check if we already have a fish for today
  --local existing_fish = surface.find_entities_filtered{ name = "fish", area = {{-32, -32}, {32, 32}} }

    if check_existing_memorial_fish() then
        game.print("Already have memorial fish for today")
        return false
    end
  
  -- Find a water tile to place the fish
  local water_tiles = surface.find_tiles_filtered{
    name = {"water", "deepwater", "water-green", "deepwater-green"},
    area = {{-16, -16}, {16, 16}}
  }
  
  if #water_tiles > 0 then
    local tile = water_tiles[math.random(#water_tiles)]
    local fish = surface.create_entity{
      name = "fish",
      position = {tile.position.x + 0.5, tile.position.y + 0.5}
    }
  end
    
  -- Use a creative way to store the date - create a dummy player name
  -- Since we can't directly tag entities, we'll use the surface's map settings
  local fish_count = surface.count_entities_filtered{name = "fish"} 
  --local memorial_text = "Addiction Timer Memorial - Session ended " .. today_id .. " (Fish #" .. fish_count .. ")"
  
  -- Store the date in storage for checking
  if not storage then storage = {} end
  storage.memorial_dates = storage.memorial_dates or {}
  storage.memorial_dates[today_id] = true
  
  game.print("Memorial fish placed for " .. today_id .. ". Total sessions ended: " .. fish_count, {r=0, g=0.8, b=1})
  
  return true
end

local function on_game_created_from_scenario(event)
  init_storage()
  
  -- Check if we already have a memorial fish for today
  if check_existing_memorial_fish() then
    local today_id = get_day_identifier()
    game.print("Memorial fish already exists for " .. today_id .. ". Timer disabled for today. The factory must rest.", {r=1, g=0.5, b=0})
    my_data.timer_enabled = false
    return
  end
  
  -- Show initial message
  local minutes = settings.global["addiction-timer-minutes"].value
  game.print("Addiction timer enabled: Game will save and close in " .. minutes .. " minutes.", {r=1, g=0.8, b=0})
  game.print("A memorial fish will be placed when the session ends.", {r=0, g=0.8, b=1})
end

local function on_configuration_changed(event)
  if not my_data.start_tick then
    init_storage()
    
    -- Check for existing memorial fish when loading existing saves
    if check_existing_memorial_fish() then
      local today_id = get_day_identifier()
      game.print("Memorial fish already exists for " .. today_id .. ". Timer disabled for today. The factory must rest.", {r=1, g=0.5, b=0})
      my_data.timer_enabled = false
    end
  end
end

local function on_tick(event)
  if not my_data then my_data = {} end
  if not my_data.timer_enabled or not my_data.start_tick then
    init_storage()
    return
  end
  
  local minutes_setting = settings.global["addiction-timer-minutes"].value
  local target_ticks = minutes_setting * 60 * 60 -- Convert minutes to ticks (60 ticks per second)
  local elapsed_ticks = game.tick - my_data.start_tick
  local remaining_ticks = target_ticks - elapsed_ticks

    -- Check for existing memorial fish when loading existing saves
    if check_existing_memorial_fish() then
      local today_id = get_day_identifier()
      game.print("Memorial fish already exists for " .. today_id .. ". Timer disabled for today. The factory must rest.", {r=1, g=0.5, b=0})
      remaining_ticks = 0
    end
  
  -- Show warning at 5 minutes remaining
  if remaining_ticks <= 5 * 60 * 60 and not my_data.warning_shown then
    my_data.warning_shown = true
    game.print("WARNING: Game will automatically save and close in 5 minutes!", {r=1, g=0, b=0})
    
    -- Play alert sound for all players
    for _, player in pairs(game.connected_players) do
      player.play_sound{path = "utility/alert_destroyed"}
    end
  end
  
  -- Show final countdown in last 60 seconds
  if remaining_ticks <= 60 * 60 and remaining_ticks > 0 then
    local remaining_seconds = math.ceil(remaining_ticks / 60)
    if remaining_seconds <= 10 or remaining_seconds % 10 == 0 then
      game.print("Addition timer closing " .. remaining_seconds .. " seconds...", {r=1, g=0, b=0})

      if remaining_seconds == 2 then
        -- Place memorial fish first
        place_memorial_fish()

        -- Save the game
        local save_name = "addiction-timer-" .. get_day_identifier() .. "-" .. game.tick
        game.auto_save(save_name)
      end
    end
  end
  
  -- Time's up!
  if remaining_ticks <= 0 then
    -- game.print("Time limit reached! Placing memorial fish and saving game...", {r=1, g=0, b=0})
    
    -- Place memorial fish first
    -- place_memorial_fish()
    
    -- Save the game
    -- local save_name = "addiction-timer-" .. get_day_identifier() .. "-" .. game.tick
    -- game.auto_save(save_name)
    
    -- Wait a moment for save to complete, then quit
    --my_data.timer_enabled = false
    --storage.quit_scheduled = true
    --storage.quit_tick = game.tick + 120 -- Wait 2 seconds after save
  --end
  
  -- Execute delayed quit
  --if storage.quit_scheduled and game.tick >= storage.quit_tick then
    game.print("Goodbye!", {r=1, g=1, b=1})
    
    -- For multiplayer, kick all players
    if game.is_multiplayer() then
        for _, player in pairs(game.connected_players) do
          game.kick_player(player, "Session time limit reached")
        end
    end
    
    -- Quit the game
    -- game.quit()

    -- Crash on purpose
    exit_game.invalid_request = 917
  end
end

-- Command to check remaining time
local function on_remaining_time_command(event)
  if not my_data then my_data = {} end
  if not my_data.timer_enabled or not my_data.start_tick then
    game.print("Addiction timer is not active.")
    return
  end
  
  local minutes_setting = settings.global["addiction-timer-minutes"].value
  local target_ticks = minutes_setting * 60 * 60
  local elapsed_ticks = game.tick - my_data.start_tick
  local remaining_ticks = target_ticks - elapsed_ticks
  
  if remaining_ticks <= 0 then
    game.print("Time limit has been reached!")
  else
    local remaining_minutes = math.ceil(remaining_ticks / (60 * 60))
    local remaining_seconds = math.ceil((remaining_ticks % (60 * 60)) / 60)
    game.print("Time remaining: " .. remaining_minutes .. " minutes, " .. remaining_seconds .. " seconds")
  end
end

-- Command to disable timer (admin only)
local function on_disable_timer_command(event)
  local player = game.get_player(event.player_index)
  if player and player.admin then
    if not my_data then my_data = {} end
    my_data.timer_enabled = false
    game.print("Adiction timer disabled by admin: " .. player.name, {r=1, g=1, b=0})
  else
    game.print("Only admins can disable the addiction timer.")
  end
end

-- Command to view memorial fish
local function on_view_memorial_command(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  
  local surface = game.get_surface("addiction-timer-memorial")
  if not surface then
    player.print("No memorial surface exists yet.")
    return
  end
  
  local fish_count = surface.count_entities_filtered{name = "fish"}
  if fish_count == 0 then
    player.print("No memorial fish have been placed yet.")
    return
  end
  
  player.print("Memorial fish count: " .. fish_count .. " session(s) ended by addiction timer.")
  
  -- Show dates we have records for
  if not storage then storage = {} end
  storage.memorial_dates = storage.memorial_dates or {}
  if storage.memorial_dates then
    local dates = {}
    for date, _ in pairs(storage.memorial_dates) do
      table.insert(dates, date)
    end
    table.sort(dates)
    if #dates > 0 then
      player.print("Recorded sessions: " .. table.concat(dates, ", "))
    end
  end
  
  -- Temporarily allow player to visit the memorial surface
  if player.admin then
    player.print("Admin privilege: You can visit the memorial surface with /c game.player.teleport({0,0}, 'addiction-timer-memorial')")
  end
end

-- Event handlers
script.on_init(on_game_created_from_scenario)
script.on_configuration_changed(on_configuration_changed)
script.on_nth_tick(60, on_tick)
script.on_event(defines.events.on_player_created, init_storage)

-- Register commands
commands.add_command("time-remaining", "Check how much time is left before addiction timer closes the game", on_remaining_time_command)
commands.add_command("disable-timer", "Disable the addiction timer (admin only)", on_disable_timer_command)
commands.add_command("view-memorial", "View information about memorial fish from past sessions", on_view_memorial_command)

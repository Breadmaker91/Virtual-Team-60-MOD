dofile(LockOn_Options.script_path .. "command_defs.lua")
dofile(LockOn_Options.script_path.."devices.lua")



local updateTimeStep = 1/30
make_default_activity(updateTimeStep)



local misc = GetSelf()
local sensor_data = get_base_data()

misc:listen_command(Keys.pilotToggle)
misc:listen_command(Keys.EjectionSeatSafetyLever)
misc:listen_command(Keys.EjectionSeatSafetyLeverOn)
misc:listen_command(Keys.EjectionSeatSafetyLeverOff)
misc:listen_command(Keys.EjectionSeatEject)


local pilotToggle = get_param_handle("pilotToggle")
local leftPilotBodyArg = get_param_handle("LEFT_PILOT_BODY_VISIBLE")
local leftPilotHeadArg = get_param_handle("LEFT_PILOT_HEAD_VISIBLE")
local rightPilotBodyArg = get_param_handle("RIGHT_PILOT_BODY_VISIBLE")
local rightPilotHeadArg = get_param_handle("RIGHT_PILOT_HEAD_VISIBLE")
local cockpitLeftPilotHeadLRArg = get_param_handle("COCKPIT_LEFT_PILOT_HEAD_LR")
local cockpitLeftPilotHeadUDArg = get_param_handle("COCKPIT_LEFT_PILOT_HEAD_UD")
local cockpitRightPilotHeadLRArg = get_param_handle("COCKPIT_RIGHT_PILOT_HEAD_LR")
local cockpitPilotBodyLeanLRArg = get_param_handle("COCKPIT_PILOT_BODY_LEAN_LR")
local cockpitPilotHeadLeanLRArg = get_param_handle("COCKPIT_PILOT_HEAD_LEAN_LR")
local cockpitPilotEyesLRArg = get_param_handle("COCKPIT_PILOT_EYES_LR")
local cockpitPilotEyesUDArg = get_param_handle("COCKPIT_PILOT_EYES_UD")
local cockpitPilotEyesBlinkArg = get_param_handle("COCKPIT_PILOT_EYES_BLINK")
local cockpitPilotClearVisorArg = get_param_handle("COCKPIT_PILOT_CLEAR_VISOR")
local cockpitPilotTintedVisorArg = get_param_handle("COCKPIT_PILOT_TINTED_VISOR")
local canopyInsideArg = get_param_handle("Inside_Canopy")
local ejectionSeatArmed = get_param_handle("EJECTION_SEAT_ARMED")
local ejectionSeatSafetyLeverArg = get_param_handle("PTN_51")

local EJECTION_SEAT_SAFETY_LEVER_ARG = 51
local EJECTION_COMMAND = 83

-- These draw arguments must be assigned to the matching mesh visibility
-- controllers in the cockpit/external EDMs:
--   * LEFT_PILOT_BODY_VISIBLE_ARG  shows/hides the left-seat pilot body.
--   * LEFT_PILOT_HEAD_VISIBLE_ARG  shows/hides the left-seat pilot head.
--   * RIGHT_PILOT_BODY_VISIBLE_ARG shows/hides the right-seat pilot body.
--   * RIGHT_PILOT_HEAD_VISIBLE_ARG shows/hides the right-seat pilot head.
-- A value of 1.0 means visible; 0.0 means hidden.
local PLAYER_SEAT_BODY_VISIBLE_ARG = 3100
local LEFT_PILOT_BODY_VISIBLE_ARG = 3101
local LEFT_PILOT_HEAD_VISIBLE_ARG = 3102
local RIGHT_PILOT_BODY_VISIBLE_ARG = 3103
local RIGHT_PILOT_HEAD_VISIBLE_ARG = 3104

-- The external and cockpit EDMs use separate head animation arguments so
-- writing the cockpit animation cannot feed back into or override the
-- external animation.
local EXTERNAL_LEFT_PILOT_HEAD_LR_ARG = 39
local EXTERNAL_LEFT_PILOT_HEAD_UD_ARG = 99
local EXTERNAL_LEFT_PILOT_BODY_LEAN_LR_ARG = 800
local EXTERNAL_LEFT_PILOT_HEAD_LEAN_LR_ARG = 801
local EXTERNAL_LEFT_PILOT_EYES_LR_ARG = 802
local EXTERNAL_LEFT_PILOT_EYES_UD_ARG = 803
local EXTERNAL_LEFT_PILOT_EYES_BLINK_ARG = 804
local EXTERNAL_LEFT_PILOT_CLEAR_VISOR_ARG = 805
local EXTERNAL_LEFT_PILOT_TINTED_VISOR_ARG = 806
local EXTERNAL_RIGHT_PILOT_HEAD_LR_ARG = 337
local HEAD_MIN = -1.0
local HEAD_MAX = 1.0

local head_position = 0.0
local head_start = 0.0
local head_target = 0.0
local head_turn_duration = 1.2
local head_turn_elapsed = 0.0
local head_pause_remaining = 0.0
local HEAD_PAUSE_MIN = 1.4
local HEAD_PAUSE_MAX = 4.2
local prng_state = 100337
local EJECTION_SEAT_SAFETY_LEVER_TRAVEL_TIME = 1.0
local ejection_seat_safety_lever_position = 0.0
local ejection_seat_safety_lever_target = 0.0
local solo_flight = false

local pilot_body_lean = 0.0
local pilot_head_counter_lean = 0.0
local previous_roll = 0.0
local eyes_lr_position = 0.0
local eyes_ud_position = 0.0
local eyes_lr_start = 0.0
local eyes_ud_start = 0.0
local eyes_lr_target = 0.0
local eyes_ud_target = 0.0
local eyes_move_elapsed = 0.0
local eyes_move_duration = 0.08
local eyes_pause_remaining = 0.0
local blink_elapsed = 0.0
local blink_next_delay = 3.8
local blink_duration = 0.16
local blink_count_remaining = 0
local blink_gap_remaining = 0.0
local blink_position = 0.0
local visor_arm_position = 0.0
local tinted_visor_position = 0.0
local visor_animation_elapsed = 0.0
local visor_animation_active = false
local visor_animation_completed = false
local visor_animation_direction = 0
local visor_use_tinted = false
local last_canopy_closed = false
local VISOR_ANIMATION_DURATION = 3.0
local mission_weather = nil
local mission_weather_loaded = false


local function set_draw_argument(arg_number, value)
	set_aircraft_draw_argument_value(arg_number, value)
	if type(set_cockpit_draw_argument_value) == "function" then
		set_cockpit_draw_argument_value(arg_number, value)
	end
end

local function get_player_seat_index()
	if type(get_player_crew_index) ~= "function" then
		return 0
	end

	local seat_index = get_player_crew_index()
	if type(seat_index) ~= "number" then
		return 0
	end

	return seat_index
end

local function is_player_in_right_seat()
	local seat_index = get_player_seat_index()
	-- DCS modules commonly report the first crew station as 0, but some
	-- multicrew APIs/examples use 1-based indexes. Treat only explicit
	-- second-seat values as the right seat so single-seat/offline fallback
	-- remains left-seat behavior.
	return seat_index == 1 or seat_index == 2
end

local function aircraft_property_is_enabled(property_name)
	if type(get_aircraft_property) ~= "function" then
		return false
	end

	local value = get_aircraft_property(property_name)
	if type(value) == "string" then
		value = value:lower()
		return value == "1" or value == "true" or value == "yes" or value == "on"
	end

	return value == true or value == 1
end

local function update_pilot_body_visibility()
	local show_bodies = pilotToggle:get() >= 0.5
	local player_body_visible = show_bodies and 1.0 or 0.0
	local other_body_visible = show_bodies and 1.0 or 0.0
	local player_head_visible = 0.0
	local other_head_visible = show_bodies and 1.0 or 0.0
	local right_body_visible = 0.0
	local right_head_visible = 0.0

	if is_player_in_right_seat() then
		leftPilotBodyArg:set(other_body_visible)
		leftPilotHeadArg:set(other_head_visible)
		set_draw_argument(LEFT_PILOT_BODY_VISIBLE_ARG, other_body_visible)
		set_draw_argument(LEFT_PILOT_HEAD_VISIBLE_ARG, other_head_visible)
		right_body_visible = player_body_visible
		right_head_visible = player_head_visible
	else
		leftPilotBodyArg:set(player_body_visible)
		leftPilotHeadArg:set(player_head_visible)
		set_draw_argument(LEFT_PILOT_BODY_VISIBLE_ARG, player_body_visible)
		set_draw_argument(LEFT_PILOT_HEAD_VISIBLE_ARG, player_head_visible)
		right_body_visible = other_body_visible
		right_head_visible = other_head_visible
	end

	if solo_flight then
		right_body_visible = 0.0
		right_head_visible = 0.0
	end

	rightPilotBodyArg:set(right_body_visible)
	rightPilotHeadArg:set(right_head_visible)
	set_draw_argument(RIGHT_PILOT_BODY_VISIBLE_ARG, right_body_visible)
	set_draw_argument(RIGHT_PILOT_HEAD_VISIBLE_ARG, right_head_visible)
	set_draw_argument(PLAYER_SEAT_BODY_VISIBLE_ARG, player_body_visible)
end

local function next_random_unit()
	-- Deterministic PRNG so all clients generate the same target/pause sequence.
	prng_state = (prng_state * 16807) % 2147483647
	return prng_state / 2147483647
end

local function random_range(min_value, max_value)
	return min_value + (max_value - min_value) * next_random_unit()
end

local function clamp(value, min_value, max_value)
	return math.max(min_value, math.min(max_value, value))
end

local function smooth_step(alpha)
	alpha = clamp(alpha, 0.0, 1.0)
	return alpha * alpha * (3.0 - 2.0 * alpha)
end

local function approach(current, target, rate)
	local alpha = clamp(rate * updateTimeStep, 0.0, 1.0)
	return current + (target - current) * alpha
end

local function get_table_value(source_table, key)
	if type(source_table) ~= "table" then
		return nil
	end

	return source_table[key]
end

local function read_sensor_number(sensor_function_name, default_value)
	local sensor_function = sensor_data[sensor_function_name]
	if type(sensor_function) ~= "function" then
		return default_value
	end

	local value = sensor_function()
	if type(value) ~= "number" then
		return default_value
	end

	return value
end
local function load_mission_weather()
	if mission_weather_loaded then
		return mission_weather
	end

	mission_weather_loaded = true
	if do_mission_file ~= nil then
		do_mission_file("mission")
		if type(mission) == "table" then
			mission_weather = mission.weather
		end
	end

	return mission_weather
end

local function get_daylight_factor()
	local time_seconds = 12.0 * 3600.0
	if type(get_absolute_model_time) == "function" then
		time_seconds = get_absolute_model_time()
	end

	local hour = (time_seconds / 3600.0) % 24.0
	if hour < 5.0 or hour >= 20.5 then
		return 0.0
	elseif hour < 7.0 then
		return (hour - 5.0) / 2.0
	elseif hour <= 18.0 then
		return 1.0
	elseif hour < 20.5 then
		return 1.0 - ((hour - 18.0) / 2.5)
	end

	return 0.0
end

local function get_weather_light_reduction()
	local weather = load_mission_weather()
	local clouds = get_table_value(weather, "clouds") or {}
	local fog = get_table_value(weather, "fog") or {}
	local preset = string.lower(tostring(clouds.preset or clouds.name or ""))
	local density = clamp(tonumber(clouds.density) or 0.0, 0.0, 10.0) / 10.0
	local precipitation = tonumber(clouds.iprecptns or clouds.precipitation) or 0.0

	local cloud_factor = density
	if preset ~= "" and not preset:find("clear") then
		cloud_factor = math.max(cloud_factor, 0.40)
	end
	if preset:find("overcast") or preset:find("rain") or preset:find("storm") then
		cloud_factor = math.max(cloud_factor, 0.75)
	end

	local fog_factor = 0.0
	if fog.enable == true or fog.enabled == true or (tonumber(fog.visibility) or 0.0) > 0.0 then
		fog_factor = 1.0
	elseif preset:find("fog") or preset:find("mist") then
		fog_factor = 0.8
	end

	local rain_factor = precipitation > 0.0 and 1.0 or 0.0
	if preset:find("rain") or preset:find("shower") or preset:find("storm") or preset:find("thunder") then
		rain_factor = 1.0
	end

	return clamp((cloud_factor * 0.45) + (fog_factor * 0.50) + (rain_factor * 0.35), 0.0, 0.90)
end

local function get_pilot_brightness_factor()
	return clamp(get_daylight_factor() - get_weather_light_reduction(), 0.0, 1.0)
end


local function start_new_head_turn()
	head_start = head_position
	head_target = random_range(HEAD_MIN, HEAD_MAX)
	local retry_count = 0
	while math.abs(head_target - head_start) < 0.12 and retry_count < 6 do
		head_target = random_range(HEAD_MIN, HEAD_MAX)
		retry_count = retry_count + 1
	end

	-- Keep neck turning speed realistic by scaling movement time with travel distance.
	-- Full sweep (-1 to 1) typically takes ~0.8-1.7 seconds.
	local travel_distance = math.abs(head_target - head_start)
	local travel_speed = random_range(1.15, 2.35) -- argument units per second
	head_turn_duration = math.max(0.16, travel_distance / travel_speed)
	head_turn_elapsed = 0.0
end

local function choose_next_eye_target()
	eyes_lr_start = eyes_lr_position
	eyes_ud_start = eyes_ud_position

	-- Bias most glances near the panel/HUD, with occasional larger canopy checks.
	if next_random_unit() < 0.76 then
		eyes_lr_target = random_range(-0.32, 0.32)
		eyes_ud_target = random_range(-0.20, 0.18)
	else
		eyes_lr_target = random_range(-0.78, 0.78)
		eyes_ud_target = random_range(-0.38, 0.34)
	end

	eyes_move_elapsed = 0.0
	eyes_move_duration = random_range(0.045, 0.13)
	eyes_pause_remaining = random_range(0.18, 1.65)
end

local function update_eye_scan_motion()
	if eyes_pause_remaining > 0.0 then
		eyes_pause_remaining = eyes_pause_remaining - updateTimeStep
		return
	end

	eyes_move_elapsed = math.min(eyes_move_elapsed + updateTimeStep, eyes_move_duration)
	local alpha = smooth_step(eyes_move_elapsed / eyes_move_duration)
	eyes_lr_position = eyes_lr_start + (eyes_lr_target - eyes_lr_start) * alpha
	eyes_ud_position = eyes_ud_start + (eyes_ud_target - eyes_ud_start) * alpha

	if eyes_move_elapsed >= eyes_move_duration then
		eyes_lr_position = eyes_lr_target
		eyes_ud_position = eyes_ud_target
		choose_next_eye_target()
	end
end

local function schedule_next_blink()
	blink_next_delay = random_range(2.4, 7.2)
	blink_count_remaining = next_random_unit() < 0.14 and 2 or 1
end

local function update_blink_motion()
	if blink_count_remaining <= 0 then
		blink_next_delay = blink_next_delay - updateTimeStep
		blink_position = 0.0
		if blink_next_delay <= 0.0 then
			schedule_next_blink()
			blink_elapsed = 0.0
		end
		return
	end

	if blink_gap_remaining > 0.0 then
		blink_gap_remaining = blink_gap_remaining - updateTimeStep
		blink_position = 0.0
		return
	end

	blink_elapsed = blink_elapsed + updateTimeStep
	local phase = blink_elapsed / blink_duration
	if phase < 0.45 then
		blink_position = smooth_step(phase / 0.45)
	elseif phase < 1.0 then
		blink_position = 1.0 - smooth_step((phase - 0.45) / 0.55)
	else
		blink_position = 0.0
		blink_count_remaining = blink_count_remaining - 1
		blink_elapsed = 0.0
		blink_gap_remaining = blink_count_remaining > 0 and random_range(0.08, 0.18) or 0.0
	end
end

local function update_pilot_roll_reaction()
	local roll = read_sensor_number("getRoll", 0.0)
	local measured_roll_rate = read_sensor_number("getRateOfRoll", nil)
	local roll_rate = measured_roll_rate or ((roll - previous_roll) / updateTimeStep)
	local roll_input = clamp(read_sensor_number("getStickRollPosition", 0.0) / 100.0, -1.0, 1.0)
	previous_roll = roll

	-- The body lean should be most visible while the aircraft is starting to
	-- roll.  Roll input makes the response immediate even on airframes where
	-- getRateOfRoll is unavailable or too damped for external animation.
	local roll_input_component = -roll_input * 0.55
	local roll_rate_component = -clamp(roll_rate * 0.32, -0.65, 0.65)

	-- Keep only a small sustained bank contribution so the pilot initially
	-- reacts opposite the roll, then settles closer to center in steady turns.
	local bank_component = -clamp(math.sin(roll) * 0.12, -0.12, 0.12)
	local lateral_component = clamp(read_sensor_number("getLateralAcceleration", 0.0) * 0.12, -0.25, 0.25)

	local target_body_lean = clamp(roll_input_component + roll_rate_component + bank_component + lateral_component, -1.0, 1.0)
	pilot_body_lean = approach(pilot_body_lean, target_body_lean, 8.0)
	pilot_head_counter_lean = approach(pilot_head_counter_lean, -pilot_body_lean * 0.78, 9.5)
end

local function is_canopy_closed()
	local canopy_position = canopyInsideArg:get() or get_aircraft_draw_argument_value(38)
	return canopy_position <= 0.02
end

local function start_pilot_visor_animation(direction)
	visor_animation_direction = direction
	visor_animation_active = true
	visor_animation_completed = false

	if direction > 0 then
		visor_use_tinted = get_pilot_brightness_factor() >= 0.50
	else
		visor_use_tinted = visor_use_tinted or tinted_visor_position > 0.01
	end

	visor_animation_elapsed = clamp(visor_arm_position * VISOR_ANIMATION_DURATION, 0.0, VISOR_ANIMATION_DURATION)
	tinted_visor_position = visor_use_tinted and tinted_visor_position or 0.0
end

local function reset_pilot_visor_animation()
	visor_animation_elapsed = 0.0
	visor_animation_active = false
	visor_animation_completed = false
	visor_animation_direction = 0
	visor_use_tinted = false
	visor_arm_position = 0.0
	tinted_visor_position = 0.0
end

local function update_pilot_visor_selection()
	local canopy_closed = is_canopy_closed()
	if canopy_closed and (not last_canopy_closed or (not visor_animation_active and not visor_animation_completed)) then
		start_pilot_visor_animation(1)
	elseif (not canopy_closed) and last_canopy_closed then
		start_pilot_visor_animation(-1)
	end
	last_canopy_closed = canopy_closed

	if visor_animation_active then
		visor_animation_elapsed = clamp(visor_animation_elapsed + (updateTimeStep * visor_animation_direction), 0.0, VISOR_ANIMATION_DURATION)
		local alpha = visor_animation_elapsed / VISOR_ANIMATION_DURATION
		visor_arm_position = alpha
		tinted_visor_position = visor_use_tinted and alpha or 0.0

		if visor_animation_elapsed >= VISOR_ANIMATION_DURATION then
			visor_animation_active = false
			visor_animation_completed = true
			visor_animation_direction = 0
			visor_arm_position = 1.0
			tinted_visor_position = visor_use_tinted and 1.0 or 0.0
		elseif visor_animation_elapsed <= 0.0 then
			reset_pilot_visor_animation()
		end
	end
end

local function initialize_pilot_visor_selection()
	last_canopy_closed = is_canopy_closed()
	if last_canopy_closed then
		start_pilot_visor_animation(1)
	else
		reset_pilot_visor_animation()
	end
end

local function write_pilot_dynamic_animation_args()
	cockpitPilotBodyLeanLRArg:set(pilot_body_lean)
	cockpitPilotHeadLeanLRArg:set(pilot_head_counter_lean)
	cockpitPilotEyesLRArg:set(eyes_lr_position)
	cockpitPilotEyesUDArg:set(eyes_ud_position)
	cockpitPilotEyesBlinkArg:set(blink_position)
	cockpitPilotClearVisorArg:set(visor_arm_position)
	cockpitPilotTintedVisorArg:set(tinted_visor_position)

	if type(set_cockpit_draw_argument_value) == "function" then
		set_cockpit_draw_argument_value(EXTERNAL_LEFT_PILOT_BODY_LEAN_LR_ARG, pilot_body_lean)
		set_cockpit_draw_argument_value(EXTERNAL_LEFT_PILOT_HEAD_LEAN_LR_ARG, pilot_head_counter_lean)
		set_cockpit_draw_argument_value(EXTERNAL_LEFT_PILOT_EYES_LR_ARG, eyes_lr_position)
		set_cockpit_draw_argument_value(EXTERNAL_LEFT_PILOT_EYES_UD_ARG, eyes_ud_position)
		set_cockpit_draw_argument_value(EXTERNAL_LEFT_PILOT_EYES_BLINK_ARG, blink_position)
		set_cockpit_draw_argument_value(EXTERNAL_LEFT_PILOT_CLEAR_VISOR_ARG, visor_arm_position)
		set_cockpit_draw_argument_value(EXTERNAL_LEFT_PILOT_TINTED_VISOR_ARG, tinted_visor_position)
	end

	set_aircraft_draw_argument_value(EXTERNAL_LEFT_PILOT_BODY_LEAN_LR_ARG, pilot_body_lean)
	set_aircraft_draw_argument_value(EXTERNAL_LEFT_PILOT_HEAD_LEAN_LR_ARG, pilot_head_counter_lean)
	set_aircraft_draw_argument_value(EXTERNAL_LEFT_PILOT_EYES_LR_ARG, eyes_lr_position)
	set_aircraft_draw_argument_value(EXTERNAL_LEFT_PILOT_EYES_UD_ARG, eyes_ud_position)
	set_aircraft_draw_argument_value(EXTERNAL_LEFT_PILOT_EYES_BLINK_ARG, blink_position)
	set_aircraft_draw_argument_value(EXTERNAL_LEFT_PILOT_CLEAR_VISOR_ARG, visor_arm_position)
	set_aircraft_draw_argument_value(EXTERNAL_LEFT_PILOT_TINTED_VISOR_ARG, tinted_visor_position)
end

local function update_head_motion()
	if head_pause_remaining > 0.0 then
		head_pause_remaining = head_pause_remaining - updateTimeStep
		return
	end

	head_turn_elapsed = math.min(head_turn_elapsed + updateTimeStep, head_turn_duration)
	local alpha = head_turn_elapsed / head_turn_duration
	local smooth_alpha = smooth_step(alpha)
	head_position = head_start + (head_target - head_start) * smooth_alpha

	if head_turn_elapsed >= head_turn_duration then
		head_position = head_target
		head_pause_remaining = random_range(HEAD_PAUSE_MIN, HEAD_PAUSE_MAX)
		start_new_head_turn()
	end
end

local function update_external_visible_crew_head_motion()
	-- DCS owns the occupied seat's external head argument and updates it from
	-- the player's view/head tracker. Writing a neutral value to that argument
	-- every frame fights the simulator and causes the visible L/R jitter.
	-- Only animate the unoccupied/opposite seat here.
	if is_player_in_right_seat() then
		set_aircraft_draw_argument_value(EXTERNAL_LEFT_PILOT_HEAD_LR_ARG, head_position)
	else
		set_aircraft_draw_argument_value(EXTERNAL_RIGHT_PILOT_HEAD_LR_ARG, head_position)
	end
end

local function mirror_external_head_motion_to_cockpit()
	cockpitLeftPilotHeadLRArg:set(
		get_aircraft_draw_argument_value(EXTERNAL_LEFT_PILOT_HEAD_LR_ARG)
	)
	cockpitLeftPilotHeadUDArg:set(
		get_aircraft_draw_argument_value(EXTERNAL_LEFT_PILOT_HEAD_UD_ARG)
	)
	cockpitRightPilotHeadLRArg:set(
		get_aircraft_draw_argument_value(EXTERNAL_RIGHT_PILOT_HEAD_LR_ARG)
	)
end


local function update_ejection_seat_armed_state()
	local is_armed = ejection_seat_safety_lever_position >= 0.999 and ejection_seat_safety_lever_target >= 0.999
	ejectionSeatArmed:set(is_armed and 1.0 or 0.0)
end

local function set_ejection_seat_safety_lever_draw_argument()
	ejectionSeatSafetyLeverArg:set(ejection_seat_safety_lever_position)
	if type(set_cockpit_draw_argument_value) == "function" then
		set_cockpit_draw_argument_value(EJECTION_SEAT_SAFETY_LEVER_ARG, ejection_seat_safety_lever_position)
	end
	update_ejection_seat_armed_state()
end

local function set_ejection_seat_safety_lever_immediate(armed)
	ejection_seat_safety_lever_target = armed and 1.0 or 0.0
	ejection_seat_safety_lever_position = ejection_seat_safety_lever_target
	set_ejection_seat_safety_lever_draw_argument()
end

local function update_ejection_seat_safety_lever_motion()
	local delta = ejection_seat_safety_lever_target - ejection_seat_safety_lever_position
	if math.abs(delta) <= 0.0001 then
		ejection_seat_safety_lever_position = ejection_seat_safety_lever_target
		return
	end

	local max_step = updateTimeStep / EJECTION_SEAT_SAFETY_LEVER_TRAVEL_TIME
	if delta > 0 then
		ejection_seat_safety_lever_position = math.min(ejection_seat_safety_lever_position + max_step, ejection_seat_safety_lever_target)
	else
		ejection_seat_safety_lever_position = math.max(ejection_seat_safety_lever_position - max_step, ejection_seat_safety_lever_target)
	end
end

--function post_initialize()
	--show_param_handles_list(true) --For testing.
--end

function post_initialize()
	local birth = LockOn_Options.init_conditions.birth_place
	solo_flight = aircraft_property_is_enabled("SoloFlight")
	set_ejection_seat_safety_lever_immediate(birth ~= "GROUND_COLD")

	start_new_head_turn()
	head_pause_remaining = random_range(HEAD_PAUSE_MIN, HEAD_PAUSE_MAX)
	choose_next_eye_target()
	schedule_next_blink()
	previous_roll = read_sensor_number("getRoll", 0.0)
	initialize_pilot_visor_selection()
	update_external_visible_crew_head_motion()
	mirror_external_head_motion_to_cockpit()
	update_pilot_body_visibility()
end

function update()
	update_pilot_body_visibility()
	update_head_motion()
	update_pilot_roll_reaction()
	update_eye_scan_motion()
	update_blink_motion()
	update_pilot_visor_selection()
	write_pilot_dynamic_animation_args()
	update_external_visible_crew_head_motion()
	mirror_external_head_motion_to_cockpit()
	update_ejection_seat_safety_lever_motion()
	set_ejection_seat_safety_lever_draw_argument()
end

local function set_ejection_seat_safety_lever(armed)
	ejection_seat_safety_lever_target = armed and 1.0 or 0.0
	set_ejection_seat_safety_lever_draw_argument()
end

local function toggle_ejection_seat_safety_lever()
	set_ejection_seat_safety_lever(ejection_seat_safety_lever_target < 0.5)
end

local function command_ejection_if_armed()
	if ejectionSeatArmed:get() >= 0.5 then
		dispatch_action(nil, EJECTION_COMMAND)
	end
end

function SetCommand(command, value)
	if command == Keys.pilotToggle then
		if pilotToggle:get() == 1 then
			pilotToggle:set(0)
		else
			pilotToggle:set(1)
		end
		update_pilot_body_visibility()
	elseif command == Keys.EjectionSeatSafetyLever then
		if value ~= nil and value < 0 then
			set_ejection_seat_safety_lever(false)
		else
			toggle_ejection_seat_safety_lever()
		end
	elseif command == Keys.EjectionSeatSafetyLeverOn then
		set_ejection_seat_safety_lever(true)
	elseif command == Keys.EjectionSeatSafetyLeverOff then
		set_ejection_seat_safety_lever(false)
	elseif command == Keys.EjectionSeatEject then
		command_ejection_if_armed()
	end
end



need_to_be_closed = false

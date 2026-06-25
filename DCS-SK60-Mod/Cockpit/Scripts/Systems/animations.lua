dofile(LockOn_Options.script_path .. "command_defs.lua")
dofile(LockOn_Options.script_path.."devices.lua")



local updateTimeStep = 1/30
make_default_activity(updateTimeStep)



local misc = GetSelf()

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

local function update_head_motion()
	if head_pause_remaining > 0.0 then
		head_pause_remaining = head_pause_remaining - updateTimeStep
		return
	end

	head_turn_elapsed = math.min(head_turn_elapsed + updateTimeStep, head_turn_duration)
	local alpha = head_turn_elapsed / head_turn_duration
	local smooth_alpha = alpha * alpha * (3.0 - 2.0 * alpha)
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
	update_external_visible_crew_head_motion()
	mirror_external_head_motion_to_cockpit()
	update_pilot_body_visibility()
end

function update()
	update_pilot_body_visibility()
	update_head_motion()
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

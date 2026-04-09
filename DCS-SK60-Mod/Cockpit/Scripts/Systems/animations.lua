dofile(LockOn_Options.script_path .. "command_defs.lua")
dofile(LockOn_Options.script_path.."devices.lua")



local updateTimeStep = 1/30
make_default_activity(updateTimeStep)



local misc = GetSelf()

misc:listen_command(Keys.pilotToggle)


local pilotToggle = get_param_handle("pilotToggle")

local COPILOT_HEAD_ARG = 337
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



--function post_initialize()
	--show_param_handles_list(true) --For testing.
--end

function post_initialize()
	start_new_head_turn()
	head_pause_remaining = random_range(HEAD_PAUSE_MIN, HEAD_PAUSE_MAX)
	set_aircraft_draw_argument_value(COPILOT_HEAD_ARG, head_position)
end

function update()
	update_head_motion()
	set_aircraft_draw_argument_value(COPILOT_HEAD_ARG, head_position)
end

function SetCommand(command, value)
	if command == Keys.pilotToggle then
		if pilotToggle:get() == 1 then
			pilotToggle:set(0)
		else
			pilotToggle:set(1)
		end
	end
end



need_to_be_closed = false
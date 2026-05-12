dofile(LockOn_Options.script_path.."command_defs.lua")
local dev = GetSelf()
make_default_activity(0.05)
local fr31_display_enable = get_param_handle("FR31_DSP_ENABLE")
local fr31_active_freq = get_param_handle("FR31_ACTIVE_FREQ")
local main_power = get_param_handle("PTN_401")
local radio_upper_text = get_param_handle("RADIO_DSP_UPPER_TEXT")

local relay = {
 [Keys.FR31_Key_0]=Keys.UHF_Key_0,[Keys.FR31_Key_1]=Keys.UHF_Key_1,[Keys.FR31_Key_2]=Keys.UHF_Key_2,[Keys.FR31_Key_3]=Keys.UHF_Key_3,
 [Keys.FR31_Key_4]=Keys.UHF_Key_4,[Keys.FR31_Key_5]=Keys.UHF_Key_5,[Keys.FR31_Key_6]=Keys.UHF_Key_6,[Keys.FR31_Key_7]=Keys.UHF_Key_7,
 [Keys.FR31_Key_8]=Keys.UHF_Key_8,[Keys.FR31_Key_9]=Keys.UHF_Key_9,[Keys.FR31_Key_ENT]=Keys.UHF_Key_ENT,[Keys.FR31_Key_CLR]=Keys.UHF_Key_MAN,
}
for c,_ in pairs(relay) do dev:listen_command(c) end
local function is_powered() return main_power:get() > 0.5 end
local function update_display()
 fr31_display_enable:set(is_powered() and 1 or 0)
 if not is_powered() then fr31_active_freq:set("---.---"); return end
 local t = radio_upper_text:get()
 if t == nil or t == "" then t = "---.---" end
 fr31_active_freq:set(t)
end
function SetCommand(command, value)
 if value <= 0 or not is_powered() then return end
 local uhf_cmd = relay[command]
 if uhf_cmd then dispatch_action(nil, uhf_cmd) end
 update_display()
end
function post_initialize() update_display() end
function update() update_display() end
need_to_be_closed = false

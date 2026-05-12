dofile(LockOn_Options.script_path.."FR31/FR31_def.lua")
SHOW_MASKS = false
local aspect = GetAspect()
local clip = CreateElement "ceMeshPoly"
clip.name = "fr31_base_clip"
clip.primitivetype = "triangles"
clip.vertices = {{1.0, aspect}, {1.0, -aspect}, {-1.0, -aspect}, {-1.0, aspect}}
clip.indices = {0,1,2,0,2,3}
clip.material = "DBG_GREY"
clip.h_clip_relation = h_clip_relations.REWRITE_LEVEL
clip.level = RNAV_DEFAULT_NOCLIP_LEVEL
clip.isdraw = true
clip.element_params = {"FR31_DSP_ENABLE"}
clip.controllers = {{"opacity_using_parameter",0}}
clip.isvisible = SHOW_MASKS
Add(clip)

local freq = CreateElement "ceStringPoly"
freq.name = "fr31_freq"
freq.material = "LCD_font_white"
freq.init_pos = {0.0, 0.0}
freq.alignment = "CenterCenter"
freq.stringdefs = {0.8 * 0.0095, 0.8 * 0.0095, 0, 0}
freq.formats = {"%s"}
freq.element_params = {"FR31_ACTIVE_FREQ", "FR31_DSP_ENABLE"}
freq.controllers = {{"text_using_parameter",0},{"change_color_when_parameter_equal_to_number",1,1,230/255,40/255,40/255},{"opacity_using_parameter",1}}
freq.collimated = true
freq.use_mipfilter = true
freq.additive_alpha = true
freq.h_clip_relation = h_clip_relations.COMPARE
freq.level = RNAV_DEFAULT_NOCLIP_LEVEL
freq.parent_element = "fr31_base_clip"
Add(freq)

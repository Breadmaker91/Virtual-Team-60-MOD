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

local digit_positions = {-0.78, -0.39, 0.0, 0.39, 0.78}
local FR31_FONT_SIZE = 1.55 * 0.0095

local function add_digit(index, x_pos)
    local digit = CreateElement "ceStringPoly"
    digit.name = "fr31_digit_" .. index
    digit.material = "FR31_radio_font"
    digit.init_pos = {x_pos, 0.0}
    digit.alignment = "CenterCenter"
    digit.stringdefs = {FR31_FONT_SIZE, FR31_FONT_SIZE, 0, 0}
    digit.formats = {"%.0f"}
    digit.element_params = {"FR31_DIGIT_" .. index, "FR31_DIGIT_" .. index .. "_ENABLE", "FR31_DSP_ENABLE"}
    digit.controllers = {
        {"text_using_parameter", 0},
        {"parameter_in_range", 1, 0.5, 1.5},
        {"opacity_using_parameter", 2},
    }
    digit.collimated = true
    digit.use_mipfilter = true
    digit.additive_alpha = true
    digit.h_clip_relation = h_clip_relations.COMPARE
    digit.level = RNAV_DEFAULT_NOCLIP_LEVEL
    digit.parent_element = "fr31_base_clip"
    Add(digit)
end

for index,x_pos in ipairs(digit_positions) do
    add_digit(index, x_pos)
end

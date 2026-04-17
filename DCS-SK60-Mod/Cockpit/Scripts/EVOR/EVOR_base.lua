dofile(LockOn_Options.script_path.."EVOR/EVOR_def.lua")

SHOW_MASKS = false

local aspect = GetAspect()

-- KNS-81 display dimensions (normalized)
local display_width = 1.0
local display_height = 0.7 * aspect

-- Main clipping layer
local evor_base_clip = CreateElement "ceMeshPoly"
evor_base_clip.name = "evor_base_clip"
evor_base_clip.primitivetype = "triangles"
evor_base_clip.vertices = {{display_width, aspect}, {display_width, -aspect}, {-display_width, -aspect}, {-display_width, aspect}}
evor_base_clip.indices = {0, 1, 2, 0, 2, 3}
evor_base_clip.init_pos = {0, 0, 0}
evor_base_clip.init_rot = {0, 0, 0}
evor_base_clip.material = "DBG_GREY"
evor_base_clip.h_clip_relation = h_clip_relations.REWRITE_LEVEL
evor_base_clip.level = EADI_DEFAULT_NOCLIP_LEVEL
evor_base_clip.isdraw = true
evor_base_clip.change_opacity = false
evor_base_clip.element_params = {"EVOR_ENABLE"}
evor_base_clip.controllers = {{"opacity_using_parameter", 0},}
evor_base_clip.isvisible = SHOW_MASKS
Add(evor_base_clip)

-- Mode indicator (VOR/RNAV/ILS)
local mode_text = CreateElement "ceStringPoly"
mode_text.name = "mode_text"
mode_text.material = "LCD_font_green"
mode_text.init_pos = {-0.75, 0.28}
mode_text.alignment = "LeftCenter"
mode_text.stringdefs = {0.6 * 0.0095, 0.6 * 0.0095, 0, 0}
mode_text.formats = {"%s"}
mode_text.element_params = {"EVOR_MODE"}
mode_text.controllers = {{"text_using_parameter", 0},}
mode_text.collimated = true
mode_text.use_mipfilter = true
mode_text.additive_alpha = true
mode_text.isvisible = true
mode_text.h_clip_relation = h_clip_relations.COMPARE
mode_text.level = EADI_DEFAULT_NOCLIP_LEVEL
mode_text.parent_element = "evor_base_clip"
Add(mode_text)

-- Frequency display (top right)
local freq_text = CreateElement "ceStringPoly"
freq_text.name = "freq_text"
freq_text.material = "LCD_font_white"
freq_text.init_pos = {0.8, 0.28}
freq_text.alignment = "RightCenter"
freq_text.stringdefs = {0.7 * 0.0095, 0.7 * 0.0095, 0, 0}
freq_text.formats = {"%s"}
freq_text.element_params = {"EVOR_FREQ"}
freq_text.controllers = {{"text_using_parameter", 0},}
freq_text.collimated = true
freq_text.use_mipfilter = true
freq_text.additive_alpha = true
freq_text.isvisible = true
freq_text.h_clip_relation = h_clip_relations.COMPARE
freq_text.level = EADI_DEFAULT_NOCLIP_LEVEL
freq_text.parent_element = "evor_base_clip"
Add(freq_text)

-- Selected course (CRS)
local crs_label = CreateElement "ceStringPoly"
crs_label.name = "crs_label"
crs_label.material = "LCD_font_green"
crs_label.init_pos = {-0.75, 0.12}
crs_label.alignment = "LeftCenter"
crs_label.stringdefs = {0.5 * 0.0095, 0.5 * 0.0095, 0, 0}
crs_label.formats = {"CRS"}
crs_label.element_params = {"EVOR_ENABLE"}
crs_label.controllers = {{"text_using_parameter", 0},}
crs_label.collimated = true
crs_label.use_mipfilter = true
crs_label.additive_alpha = true
crs_label.isvisible = true
crs_label.h_clip_relation = h_clip_relations.COMPARE
crs_label.level = EADI_DEFAULT_NOCLIP_LEVEL
crs_label.parent_element = "evor_base_clip"
Add(crs_label)

local crs_text = CreateElement "ceStringPoly"
crs_text.name = "crs_text"
crs_text.material = "LCD_font_white"
crs_text.init_pos = {-0.5, 0.12}
crs_text.alignment = "RightCenter"
crs_text.stringdefs = {0.6 * 0.0095, 0.6 * 0.0095, 0, 0}
crs_text.formats = {"%03.0f"}
crs_text.element_params = {"EVOR_CRS"}
crs_text.controllers = {{"text_using_parameter", 0},}
crs_text.collimated = true
crs_text.use_mipfilter = true
crs_text.additive_alpha = true
crs_text.isvisible = true
crs_text.h_clip_relation = h_clip_relations.COMPARE
crs_text.level = EADI_DEFAULT_NOCLIP_LEVEL
crs_text.parent_element = "evor_base_clip"
Add(crs_text)

-- CDI deviation indicator (horizontal bar that moves left/right)
local cdi_deviation = CreateElement "ceMeshPoly"
cdi_deviation.name = "cdi_deviation"
cdi_deviation.primitivetype = "triangles"
-- Deviation bar: 0.6 wide, 0.04 tall, position controlled by parameter
cdi_deviation.vertices = {{0.06, 0.02}, {0.06, -0.02}, {-0.06, -0.02}, {-0.06, 0.02}}
cdi_deviation.indices = {0, 1, 2, 0, 2, 3}
cdi_deviation.init_pos = {0, 0}
cdi_deviation.init_rot = {0, 0, 0}
cdi_deviation.material = "LCD_font_green"
cdi_deviation.h_clip_relation = h_clip_relations.COMPARE
cdi_deviation.level = EADI_DEFAULT_NOCLIP_LEVEL
cdi_deviation.isdraw = true
cdi_deviation.change_opacity = false
cdi_deviation.element_params = {"EVOR_CDI"}
cdi_deviation.controllers = {{"move_using_parameter", 0, -0.15, 0.15},}
cdi_deviation.isvisible = true
cdi_deviation.parent_element = "evor_base_clip"
Add(cdi_deviation)

-- CDI scale markers (fixed)
local cdi_marker_left = CreateElement "ceMeshPoly"
cdi_marker_left.name = "cdi_marker_left"
cdi_marker_left.primitivetype = "triangles"
cdi_marker_left.vertices = {{0.015, 0.025}, {0.015, -0.025}, {0, -0.025}, {0, 0.025}}
cdi_marker_left.indices = {0, 1, 2, 0, 2, 3}
cdi_marker_left.init_pos = {-0.15, 0}
cdi_marker_left.material = "LCD_font_green"
cdi_marker_left.h_clip_relation = h_clip_relations.COMPARE
cdi_marker_left.level = EADI_DEFAULT_NOCLIP_LEVEL
cdi_marker_left.isdraw = true
cdi_marker_left.isvisible = true
cdi_marker_left.parent_element = "evor_base_clip"
Add(cdi_marker_left)

local cdi_marker_right = CreateElement "ceMeshPoly"
cdi_marker_right.name = "cdi_marker_right"
cdi_marker_right.primitivetype = "triangles"
cdi_marker_right.vertices = {{0, 0.025}, {0, -0.025}, {-0.015, -0.025}, {-0.015, 0.025}}
cdi_marker_right.indices = {0, 1, 2, 0, 2, 3}
cdi_marker_right.init_pos = {0.15, 0}
cdi_marker_right.material = "LCD_font_green"
cdi_marker_right.h_clip_relation = h_clip_relations.COMPARE
cdi_marker_right.level = EADI_DEFAULT_NOCLIP_LEVEL
cdi_marker_right.isdraw = true
cdi_marker_right.isvisible = true
cdi_marker_right.parent_element = "evor_base_clip"
Add(cdi_marker_right)

-- FROM/TO indicator
local from_to_text = CreateElement "ceStringPoly"
from_to_text.name = "from_to_text"
from_to_text.material = "LCD_font_amber"
from_to_text.init_pos = {-0.55, 0}
from_to_text.alignment = "CenterCenter"
from_to_text.stringdefs = {0.7 * 0.0095, 0.7 * 0.0095, 0, 0}
from_to_text.formats = {"%s"}
from_to_text.element_params = {"EVOR_FROM_TO"}
from_to_text.controllers = {{"text_using_parameter", 0},}
from_to_text.collimated = true
from_to_text.use_mipfilter = true
from_to_text.additive_alpha = true
from_to_text.isvisible = true
from_to_text.h_clip_relation = h_clip_relations.COMPARE
from_to_text.level = EADI_DEFAULT_NOCLIP_LEVEL
from_to_text.parent_element = "evor_base_clip"
Add(from_to_text)

-- Distance display
local dist_text = CreateElement "ceStringPoly"
dist_text.name = "dist_text"
dist_text.material = "LCD_font_white"
dist_text.init_pos = {0.3, 0}
dist_text.alignment = "CenterCenter"
dist_text.stringdefs = {0.6 * 0.0095, 0.6 * 0.0095, 0, 0}
dist_text.formats = {"%.1f"}
dist_text.element_params = {"EVOR_DIST"}
dist_text.controllers = {{"text_using_parameter", 0},}
dist_text.collimated = true
dist_text.use_mipfilter = true
dist_text.additive_alpha = true
dist_text.isvisible = true
dist_text.h_clip_relation = h_clip_relations.COMPARE
dist_text.level = EADI_DEFAULT_NOCLIP_LEVEL
dist_text.parent_element = "evor_base_clip"
Add(dist_text)

local dist_unit = CreateElement "ceStringPoly"
dist_unit.name = "dist_unit"
dist_unit.material = "LCD_font_green"
dist_unit.init_pos = {0.55, 0}
dist_unit.alignment = "LeftCenter"
dist_unit.stringdefs = {0.4 * 0.0095, 0.4 * 0.0095, 0, 0}
dist_unit.formats = {"NM"}
dist_unit.element_params = {"EVOR_ENABLE"}
dist_unit.controllers = {{"text_using_parameter", 0},}
dist_unit.collimated = true
dist_unit.use_mipfilter = true
dist_unit.additive_alpha = true
dist_unit.isvisible = true
dist_unit.h_clip_relation = h_clip_relations.COMPARE
dist_unit.level = EADI_DEFAULT_NOCLIP_LEVEL
dist_unit.parent_element = "evor_base_clip"
Add(dist_unit)

-- Warning/Flag indicator (shows when no valid signal)
local flag_text = CreateElement "ceStringPoly"
flag_text.name = "flag_text"
flag_text.material = "LCD_font_red"
flag_text.init_pos = {0, -0.15}
flag_text.alignment = "CenterCenter"
flag_text.stringdefs = {0.6 * 0.0095, 0.6 * 0.0095, 0, 0}
flag_text.formats = {"%s"}
flag_text.element_params = {"EVOR_FLAG"}
flag_text.controllers = {{"text_using_parameter", 0},}
flag_text.collimated = true
flag_text.use_mipfilter = true
flag_text.additive_alpha = true
flag_text.isvisible = true
flag_text.h_clip_relation = h_clip_relations.COMPARE
flag_text.level = EADI_DEFAULT_NOCLIP_LEVEL
flag_text.parent_element = "evor_base_clip"
Add(flag_text)
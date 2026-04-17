dofile(LockOn_Options.common_script_path.."elements_defs.lua")

EADI_IND_TEX_PATH        = LockOn_Options.script_path .. "../Textures/EADI/"

-- set fov here to make sure always same
SetScale(FOV)

DEGREE_TO_MRAD = 17.4532925199433
DEGREE_TO_RAD  = 0.0174532925199433
RAD_TO_DEGREE  = 57.29577951308233
MRAD_TO_DEGREE = 0.05729577951308233

EADI_DEFAULT_LEVEL = 4
EADI_DEFAULT_NOCLIP_LEVEL  = EADI_DEFAULT_LEVEL - 1

DEBUG_COLOR                 = {0,255,0,200}

EADI_DAY_COLOR              = {200,200,200,255}

basic_eadi_material = MakeMaterial(EADI_IND_TEX_PATH.."EADI_BASE_IND.dds", EADI_DAY_COLOR)

default_eadi_x = 2000
default_eadi_y = 2000

default_eadi_z_offset = 0
default_eadi_rot_offset = 0
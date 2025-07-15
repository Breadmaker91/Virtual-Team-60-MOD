local DbOption  = require('Options.DbOption')
local i18n      = require('i18n')
local oms       = require('optionsModsScripts')
local Range     = DbOption.Range

return {
	NWS_Coupled_Separate_Input_Device	= DbOption.new():setValue(true):checkbox(),
}

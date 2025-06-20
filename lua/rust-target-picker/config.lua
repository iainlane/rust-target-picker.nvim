---@class (exact) TargetPickerKeyMaps
---@field key string Keymap for picking Rust target (e.g., "<leader>ct").
---@field desc string Description for the keymap.
---@field mode string Mode for the keymap (e.g., "n").

---@class (exact) TargetPickerOptions
---@field keymaps? TargetPickerKeyMaps Keymap configuration. Set to `nil` to disable keymap creation

local M = {}

---@type TargetPickerOptions
M.defaults = {
	keymaps = {
		key = "<leader>ct",
		desc = "Pick Rust Target",
		mode = "n",
	},
}

return M

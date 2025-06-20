local config = require("rust-target-picker.config")
local utils = require("rust-target-picker.utils")
local target = require("rust-target-picker.target")
local picker = require("rust-target-picker.picker")

---@class RustTargetPicker
---@field default_target string? Cached default target
local RustTargetPicker = {}
RustTargetPicker.__index = RustTargetPicker

--- Create a new RustTargetPicker instance
--- @return RustTargetPicker
function RustTargetPicker.new()
	local self = setmetatable({}, RustTargetPicker)
	self.default_target = nil

	return self
end

--- Get the default rust target for the current toolchain
---
--- @return string? default target triple
function RustTargetPicker:detect_default_target()
	if self.default_target then
		return self.default_target
	end

	self.default_target = target.detect_default_target()
	return self.default_target
end

--- Get the current Rust target for status display (e.g., in lualine)
---
--- @return string? current target or nil if default
function RustTargetPicker:get_current_target()
	return target.get_current_target(self:detect_default_target())
end

--- The main entrypoint: show picker, and update the current rust target with
--- the selection.
function RustTargetPicker:pick_target()
	if vim.bo.filetype ~= "rust" then
		return vim.notify("Not in a Rust file", vim.log.levels.WARN)
	end

	local ok, snacks = pcall(require, "snacks")
	if not ok then
		return vim.notify("Snacks picker not available", vim.log.levels.ERROR)
	end

	local default_target = self:detect_default_target()
	local current_target = self:get_current_target()

	utils.get_rust_targets(function(ts)
		picker.handle_rust_targets(ts, default_target, current_target, snacks)
	end, function(error)
		vim.notify("Error fetching Rust targets: " .. error, vim.log.levels.ERROR)
	end)
end

local M = RustTargetPicker.new()

--- Setup the plugin with user configuration
---
--- @param opts TargetPickerOptions? User configuration options
function RustTargetPicker.setup(opts)
	-- Merge user options with defaults
	---@type TargetPickerOptions
	local merged_config = vim.tbl_deep_extend("force", {}, config.defaults, opts or {})

	-- Cache the default target early
	M:detect_default_target()

	if merged_config.keymaps then
		vim.keymap.set(merged_config.keymaps.mode, merged_config.keymaps.key, function()
			M:pick_target()
		end, { desc = merged_config.keymaps.desc, noremap = true, silent = true })
	end
end

M.setup = RustTargetPicker.setup

return M

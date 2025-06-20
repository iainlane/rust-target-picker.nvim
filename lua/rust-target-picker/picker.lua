local target = require("rust-target-picker.target")

---@alias RustTarget string
---@alias RustTargetItem { text: string, value: RustTarget?, current: boolean }

local M = {}

--- Render the snacks.nvim picker and handle the choice.
---
--- @param targets RustTarget[] all available targets
--- @param default_target RustTarget? the default target, if any
--- @param current RustTarget? what's active now
--- @param snacks_mod table
function M.handle_rust_targets(targets, default_target, current, snacks_mod)
	if vim.tbl_isempty(targets) then
		return vim.notify("No Rust targets installed. Run 'rustup target add <target>'", vim.log.levels.WARN)
	end

	if #targets == 1 then
		return vim.notify("Only one Rust target installed: " .. targets[1], vim.log.levels.INFO)
	end

	local default_text = default_target and ("Default (" .. default_target .. ")") or "Default"

	local items = {
		{ text = default_text, value = nil, current = (current == default_target) },
	}
	for _, t in ipairs(targets) do
		if t == default_target then
			-- Skip the default target, it's already in the list
			goto continue
		end

		items[#items + 1] = {
			text = t,
			value = t,
			current = (current == t),
		}
		::continue::
	end

	snacks_mod.picker.pick("rust_targets", {
		items = items,
		confirm = function(picker, item)
			if not item then
				return
			end

			target.set_rust_target(item.value)

			picker:close()
		end,
		format = function(item)
			local prefix = item.current and { "● ", "DiagnosticOk" } or { "  " }

			return { prefix, { item.text, "Title" } }
		end,
		layout = { hidden = { "preview" }, preset = "dropdown" },
		title = "Select Rust Target",
	})
end

return M

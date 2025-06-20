local Job = require("plenary.job")
local utils = require("rust-target-picker.utils")

---@alias RustTarget string

local M = {}

--- Get the default rust target for the current toolchain
---
--- @return RustTarget? default target triple
function M.detect_default_target()
	--- @diagnostic disable-next-line: missing-fields
	local job = Job:new({
		command = "rustc",
		args = { "-vV" },
	})

	local result = job:sync()

	if not result then
		vim.notify("Failed to run `rustc -vV`", vim.log.levels.DEBUG)
		return nil
	end

	if job.code ~= 0 then
		vim.notify("rustc not found - cannot detect default target", vim.log.levels.DEBUG)
		return nil
	end

	for _, line in ipairs(result) do
		local target = line:match("^host:%s*(.+)$")
		if target then
			return target
		end
	end

	vim.notify("Could not parse rustc output for default target", vim.log.levels.DEBUG)
	return nil
end

--- Set (or clear) the rust-analyzer cargo.target for every workspace.
---
--- @param target RustTarget? new triple or nil to reset
function M.set_rust_target(target)
	-- Find all the rust-analyzer instances
	local clients = vim.lsp.get_clients({ name = "rust-analyzer" })
	if vim.tbl_isempty(clients) then
		return vim.notify("rust-analyzer not found", vim.log.levels.WARN)
	end

	-- This is what we're going to set on them
	local override = {
		["rust-analyzer"] = {
			cargo = { target = target },
		},
	}

	for _, client in ipairs(clients) do
		-- Grab their settings and merge ours with it
		local merged_settings = vim.tbl_deep_extend("force", client.config.settings or {}, override)

		-- Or clear it
		if not target then
			local rust_settings = merged_settings["rust-analyzer"] --[[@as table?]]
			if rust_settings and rust_settings.cargo then
				rust_settings.cargo.target = nil
			end
		end

		-- Set it, then the LSP needs to be notified that something changed
		client.config.settings = merged_settings
		client:notify("workspace/didChangeConfiguration", { settings = merged_settings })

		-- This block here is an attempt to get the diagnostics to refresh, so that
		-- you see messages about the new target.
		-- TODO :this needs some work - doesn't seem to reliably refresh diagnostics
		-- just yet.
		client:request("rust-analyzer/reloadWorkspace", nil, function(err)
			if err then
				vim.notify("Failed to reload rust-analyzer workspace: " .. err.message, vim.log.levels.ERROR)
				return
			end

			client:request("rust-analyzer/rebuildProcMacros", nil, function(rebuild_err)
				if rebuild_err then
					vim.notify("Failed to rebuild proc macros: " .. rebuild_err.message, vim.log.levels.ERROR)
					return
				end

				vim.defer_fn(function()
					local attached_buffers = vim.lsp.get_buffers_by_client_id(client.id)
					for _, bufnr in ipairs(attached_buffers) do
						vim.diagnostic.reset(vim.lsp.diagnostic.get_namespace(client.id), bufnr)

						client:notify("textDocument/didChange", {
							textDocument = {
								uri = vim.uri_from_bufnr(bufnr),
								version = (vim.lsp.util.buf_versions[bufnr] or 0) + 1,
							},
							contentChanges = {
								{ text = utils.get_buffer_text(bufnr) },
							},
						})
					end
				end, 1000)
			end)
		end)
	end

	vim.notify("Rust target set to: " .. (target or "default"), vim.log.levels.INFO)

	-- Emit event for integrations (lualine, custom statuslines, etc.)
	vim.api.nvim_exec_autocmds("User", {
		pattern = "RustTargetChanged",
		data = { target = target },
	})
end

--- Get the current Rust target for status display (e.g., in lualine)
---
--- @return string? current target or nil if default
function M.get_current_target(default_target)
	local root = utils.get_project_root()
	local lsp_target = utils.get_lsp_rust_target()
	local toolchain_tgt = utils.read_rust_toolchain(root)

	return lsp_target or toolchain_tgt or default_target
end

return M

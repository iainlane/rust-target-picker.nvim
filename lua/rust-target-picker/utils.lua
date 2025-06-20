local Path = require("plenary.path")
local Job = require("plenary.job")

local M = {}

--- Determine project root via LazyVim util or fallback to LSP.
--
--- @return string? root directory
function M.get_project_root()
	local ok, util = pcall(require, "lazyvim.util")
	if ok and util and util.root then
		local r = util.root()
		if r ~= "" then
			return r
		end
	end
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
		if client.config and client.config.root_dir then
			return client.config.root_dir
		end
	end
	return nil
end

--- Read rust-toolchain{,.toml} and return the first target.
---
--- @param root string?
--- @return string? target triple
function M.read_rust_toolchain(root)
	if not root then
		return nil
	end

	local candidates = {
		Path:new(root, "rust-toolchain.toml"),
		Path:new(root, "rust-toolchain"),
	}

	for _, p in ipairs(candidates) do
		if not (p:exists() and p:is_file()) then
			goto continue
		end

		local content = p:read()
		local fp = tostring(p)

		-- TOML format
		if fp:match("%.toml$") then
			local ok, toml = pcall(require, "toml")
			if not ok then
				vim.notify("toml.lua not available - cannot parse rust-toolchain.toml", vim.log.levels.WARN)
				goto continue
			end

			local parse_ok, tbl = pcall(toml.parse, content)
			if not parse_ok then
				vim.notify("Failed to parse " .. fp .. ": " .. tostring(tbl), vim.log.levels.WARN)
				goto continue
			end
			if type(tbl) ~= "table" then
				vim.notify("Invalid TOML structure in " .. fp, vim.log.levels.WARN)
				goto continue
			end

			if tbl.toolchain and type(tbl.toolchain.targets) == "table" and #tbl.toolchain.targets > 0 then
				return tbl.toolchain.targets[1]
			end

			if tbl.toolchain and tbl.toolchain.target then
				return tbl.toolchain.target
			end

			goto continue
		end

		-- plain rust-toolchain: first token of first line
		local first = content:match("^%s*([%w%-%_]+)")
		if first then
			return first
		end

		::continue::
	end

	return nil
end

--- Find the currently‐set cargo.target in rust-analyzer's settings.
--
--- @return string? target triple
function M.get_lsp_rust_target()
	local clients = vim.lsp.get_clients({ name = "rust-analyzer" })

	for _, client in ipairs(clients) do
		local settings = client.config and client.config.settings
		if not settings then
			goto continue
		end

		local rust_analyzer = settings["rust-analyzer"]
		if rust_analyzer and rust_analyzer["cargo"] and rust_analyzer["cargo"]["target"] then
			return rust_analyzer["cargo"]["target"]
		end

		::continue::
	end

	return nil
end

--- Async fetch of `rustup target list --installed`
---
--- @param on_result fun(targets: string[])
--- @param on_error fun(error: string)?
function M.get_rust_targets(on_result, on_error)
	--- Job callbacks happen in a [fast context]. Most Neovim APIs aren't avaiable
	--- there - an error will be thrown - so we need to send it back to the main
	--- loop.
	---
	--- [fast context]: https://neovim.io/doc/user/lua.html#vim.in_fast_event()
	---
	--- @type fun(target: string[])
	local cb = vim.schedule_wrap(on_result)

	--- Looks like `Job` has all its fields marked as required, so we get a lot of
	--- warnings here.
	--- @diagnostic disable-next-line: missing-fields
	Job:new({
		command = "rustup",
		args = { "target", "list", "--installed" },
		on_exit = function(job, code)
			if code ~= 0 then
				local stderr = job:stderr_result() or {}
				local error_msg = table.concat(stderr, "\n")
				if error_msg == "" then
					error_msg = "rustup command failed with exit code " .. code
				end
				if on_error then
					return vim.schedule_wrap(on_error)(error_msg)
				end
				vim.schedule(function()
					vim.notify("Failed to get Rust targets: " .. error_msg, vim.log.levels.ERROR)
				end)
				return cb({})
			end

			local lines = job:result()
			if not lines or vim.tbl_isempty(lines) then
				if on_error then
					return vim.schedule_wrap(on_error)("No installed targets found")
				end
				vim.schedule(function()
					vim.notify("No Rust targets installed. Run 'rustup target add <target>'", vim.log.levels.WARN)
				end)
				return cb({})
			end

			local out = {}
			for _, l in ipairs(lines) do
				local t = l:match("^([%w%-%_]+)")
				if t then
					out[#out + 1] = t
				end
			end

			cb(out)
		end,
	}):start()
end

--- Get the contents of a buffer as a string
---
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
--- @return string
function M.get_buffer_text(bufnr)
	bufnr = bufnr or 0
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- Get the file format to determine line endings
	local fileformat = vim.bo[bufnr].fileformat
	local format_line_ending = {
		["unix"] = "\n",
		["dos"] = "\r\n",
		["mac"] = "\r",
	}

	local line_ending = format_line_ending[fileformat] or "\n"

	local result = table.concat(lines, line_ending)

	if vim.bo[bufnr].eol then
		result = result .. line_ending
	end

	return result
end

return M

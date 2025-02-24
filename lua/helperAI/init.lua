local api = vim.api
local fn = vim.fn

-- Highlight group for unknown terms
api.nvim_set_hl(0, "UnknownTerm", { bg = "#ff5555", fg = "#ffffff" })

-- Create a namespace for our highlights
local ns_id = api.nvim_create_namespace("helperAI")

-- Function to show results with line-by-line animation
local function animate_text(bufnr, lines)
	if not api.nvim_buf_is_valid(bufnr) then
		return
	end

	local current_lines = {}
	local timer = vim.loop.new_timer()
	local line_idx = 1

	-- Ensure buffer is modifiable
	api.nvim_buf_set_option(bufnr, "modifiable", true)

	-- Show "Searching..." message initially
	api.nvim_buf_set_lines(bufnr, 0, -1, false, { "HelperAI is searching..." })

	-- Start animation with a shorter delay and faster updates
	vim.defer_fn(function()
		timer:start(
			100, -- Initial delay between lines (milliseconds)
			100, -- Interval between lines (milliseconds)
			vim.schedule_wrap(function()
				-- Check if buffer still exists
				if not api.nvim_buf_is_valid(bufnr) then
					timer:stop()
					return
				end

				-- Ensure buffer is modifiable before each update
				api.nvim_buf_set_option(bufnr, "modifiable", true)

				if line_idx > #lines then
					timer:stop()
					-- Set buffer as non-modifiable after animation
					api.nvim_buf_set_option(bufnr, "modifiable", false)
					return
				end

				-- Add the complete line
				current_lines[line_idx] = lines[line_idx]
				line_idx = line_idx + 1

				pcall(api.nvim_buf_set_lines, bufnr, 0, -1, false, current_lines)

				-- Apply highlighting for the last added line
				if current_lines[line_idx - 1] then
					if current_lines[line_idx - 1]:match("^%d+%.") then
						pcall(api.nvim_buf_add_highlight, bufnr, ns_id, "Identifier", line_idx - 2, 0, -1)
					elseif current_lines[line_idx - 1]:match("^%s+Description:") then
						pcall(api.nvim_buf_add_highlight, bufnr, ns_id, "String", line_idx - 2, 0, -1)
					elseif current_lines[line_idx - 1]:match("^%s+URL:") then
						pcall(api.nvim_buf_add_highlight, bufnr, ns_id, "Underlined", line_idx - 2, 0, -1)
					end
				end
			end)
		)
	end, 500) -- Reduced initial delay to 500ms
end

-- Highlight unknown terms
local function highlight_unknown_terms()
	local lines = api.nvim_buf_get_lines(0, 0, -1, false)
	for i, line in ipairs(lines) do
		for word in line:gmatch("%w+") do
			if not fn.synIDattr(fn.synID(i, fn.col("."), 1), "name") then
				pcall(fn.matchadd, "UnknownTerm", "\\<" .. word .. "\\>", 10, -1, { window = 0 })
			end
		end
	end
end

-- Search with helperAI
local function search_helperai()
	local mode = fn.mode()
	if mode ~= "v" and mode ~= "V" then
		vim.notify("Please select text in visual mode first!", vim.log.levels.WARN)
		return
	end

	local start_pos = api.nvim_buf_get_mark(0, "<")
	local end_pos = api.nvim_buf_get_mark(0, ">")
	local lines = api.nvim_buf_get_text(0, start_pos[1] - 1, start_pos[2], end_pos[1] - 1, end_pos[2] + 1, {})
	local query = table.concat(lines, " "):gsub("%s+", " ")

	if query == "" then
		vim.notify("No text selected!", vim.log.levels.WARN)
		return
	end

	-- Create result buffer
	local buf = api.nvim_create_buf(false, true)
	-- Set buffer options
	local buffer_options = {
		modifiable = true,
		filetype = "helperai",
		buftype = "nofile",
		swapfile = false,
	}

	for option, value in pairs(buffer_options) do
		api.nvim_buf_set_option(buf, option, value)
	end

	-- Open floating window
	local width = api.nvim_get_option_value("columns", {})
	local win_config = {
		relative = "editor",
		width = math.floor(width * 0.4),
		height = api.nvim_get_option_value("lines", {}) - 4,
		col = width - math.floor(width * 0.4),
		row = 2,
		style = "minimal",
		border = "rounded",
	}

	local win = api.nvim_open_win(buf, true, win_config)
	api.nvim_win_set_option(win, "wrap", true)
	api.nvim_win_set_option(win, "cursorline", true)

	-- Execute search in background
	local script_path = fn.expand(fn.stdpath("config") .. "/helperAI/search.py")
	if not vim.loop.fs_stat(script_path) then
		vim.notify("search.py script not found at " .. script_path, vim.log.levels.ERROR)
		return
	end

	local cmd = string.format("python3 %s --query %q", script_path, query)
	fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				vim.schedule(function()
					if api.nvim_buf_is_valid(buf) then
						animate_text(buf, data)
					end
				end)
			end
		end,
		on_exit = function()
			vim.schedule(function()
				if api.nvim_buf_is_valid(buf) then
					api.nvim_buf_set_option(buf, "modifiable", false)
				end
			end)
		end,
	})
end

-- Setup function for LazyVim
local M = {}

M.setup = function(opts)
	opts = opts or {}
	local keymap = opts.keymap or "<leader>s"

	-- Visual mode mapping
	vim.keymap.set("v", keymap, search_helperai, { noremap = true, silent = true })

	-- Autocommand for highlighting
	api.nvim_create_autocmd("BufEnter", {
		pattern = "*",
		callback = highlight_unknown_terms,
	})

	-- Register user command
	api.nvim_create_user_command("HelperAISearch", search_helperai, {})
end

M.search = search_helperai

return M

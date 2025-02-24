local api = vim.api
local fn = vim.fn

-- Enhanced highlight groups
local function setup_highlights()
	-- Result highlights
	api.nvim_set_hl(0, "HelperAITitle", { fg = "#7aa2f7", bold = true }) -- For titles
	api.nvim_set_hl(0, "HelperAIDescription", { fg = "#9ece6a" }) -- For descriptions
	api.nvim_set_hl(0, "HelperAIURL", { fg = "#bb9af7", underline = true }) -- For URLs
	api.nvim_set_hl(0, "HelperAISearchTerm", { bg = "#3b4261", fg = "#7dcfff" }) -- For search terms
end

-- Create a namespace for our highlights
local ns_id = api.nvim_create_namespace("helperAI")

-- Function to highlight search terms in a line
local function highlight_search_terms(bufnr, line_num, line, query_terms)
	for _, term in ipairs(query_terms) do
		local start_idx = 1
		while true do
			local s, e = string.find(line:lower(), term:lower(), start_idx, true)
			if not s then
				break
			end
			pcall(api.nvim_buf_add_highlight, bufnr, ns_id, "HelperAISearchTerm", line_num, s - 1, e)
			start_idx = e + 1
		end
	end
end

-- Function to show results with line-by-line animation
local function animate_text(bufnr, lines, query)
	if not api.nvim_buf_is_valid(bufnr) then
		return
	end

	local current_lines = {}
	local timer = vim.loop.new_timer()
	local line_idx = 1

	-- Parse query into terms for highlighting
	local query_terms = {}
	for term in query:gmatch("%S+") do
		table.insert(query_terms, term)
	end

	-- Ensure buffer is modifiable
	api.nvim_buf_set_option(bufnr, "modifiable", true)

	-- Show "Searching..." message initially
	api.nvim_buf_set_lines(bufnr, 0, -1, false, { "HelperAI is searching..." })

	-- Start animation
	vim.defer_fn(function()
		timer:start(
			100,
			100,
			vim.schedule_wrap(function()
				if not api.nvim_buf_is_valid(bufnr) then
					timer:stop()
					return
				end

				api.nvim_buf_set_option(bufnr, "modifiable", true)

				if line_idx > #lines then
					timer:stop()
					api.nvim_buf_set_option(bufnr, "modifiable", false)
					return
				end

				-- Add the complete line
				current_lines[line_idx] = lines[line_idx]
				line_idx = line_idx + 1

				pcall(api.nvim_buf_set_lines, bufnr, 0, -1, false, current_lines)

				-- Apply highlighting for the last added line
				local current_line = current_lines[line_idx - 1]
				if current_line then
					if current_line:match("^%d+%.") then
						pcall(api.nvim_buf_add_highlight, bufnr, ns_id, "HelperAITitle", line_idx - 2, 0, -1)
					elseif current_line:match("^%s+Description:") then
						pcall(api.nvim_buf_add_highlight, bufnr, ns_id, "HelperAIDescription", line_idx - 2, 0, -1)
						-- Highlight search terms in description
						highlight_search_terms(bufnr, line_idx - 2, current_line, query_terms)
					elseif current_line:match("^%s+URL:") then
						pcall(api.nvim_buf_add_highlight, bufnr, ns_id, "HelperAIURL", line_idx - 2, 0, -1)
					end
				end
			end)
		)
	end, 500)
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
						animate_text(buf, data, query)
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

	-- Set up highlights
	setup_highlights()

	-- Visual mode mapping
	vim.keymap.set("v", keymap, search_helperai, { noremap = true, silent = true })

	-- Register user command
	api.nvim_create_user_command("HelperAISearch", search_helperai, {})
end

M.search = search_helperai

return M

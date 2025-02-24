local api = vim.api
local fn = vim.fn

-- Highlight group for unknown terms
api.nvim_set_hl(0, "UnknownTerm", { bg = "#ff5555", fg = "#ffffff" })

-- Create a namespace for our highlights
local ns_id = api.nvim_create_namespace("helperAI")

-- Function to show typing animation
local function animate_text(bufnr, lines)
	local current_lines = {}
	local timer = vim.loop.new_timer()
	local line_idx = 1
	local char_idx = 1
	local current_line = ""

	-- Show "Searching..." message initially
	api.nvim_buf_set_lines(bufnr, 0, -1, false, { "HelperAI is searching..." })

	-- Start animation after 1 second
	vim.defer_fn(function()
		timer:start(
			50,
			50,
			vim.schedule_wrap(function()
				if line_idx > #lines then
					timer:stop()
					return
				end

				if char_idx > #lines[line_idx] then
					current_lines[line_idx] = lines[line_idx]
					line_idx = line_idx + 1
					char_idx = 1
					current_line = ""
				else
					current_line = current_line .. lines[line_idx]:sub(char_idx, char_idx)
					current_lines[line_idx] = current_line
					char_idx = char_idx + 1
				end

				api.nvim_buf_set_lines(bufnr, 0, -1, false, current_lines)

				-- Apply highlighting
				if current_lines[line_idx] and current_lines[line_idx]:match("^%d+%.") then
					api.nvim_buf_add_highlight(bufnr, ns_id, "Identifier", line_idx - 1, 0, -1)
				elseif current_lines[line_idx] and current_lines[line_idx]:match("^%s+Description:") then
					api.nvim_buf_add_highlight(bufnr, ns_id, "String", line_idx - 1, 0, -1)
				elseif current_lines[line_idx] and current_lines[line_idx]:match("^%s+URL:") then
					api.nvim_buf_add_highlight(bufnr, ns_id, "Underlined", line_idx - 1, 0, -1)
				end
			end)
		)
	end, 1000)
end

-- Highlight unknown terms
local function highlight_unknown_terms()
	local lines = api.nvim_buf_get_lines(0, 0, -1, false)
	for i, line in ipairs(lines) do
		for word in line:gmatch("%w+") do
			if not fn.synIDattr(fn.synID(i, fn.col("."), 1), "name") then
				fn.matchadd("UnknownTerm", "\\<" .. word .. "\\>", 10, -1, { window = 0 })
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
	api.nvim_set_option_value("modifiable", true, { buf = buf })
	api.nvim_set_option_value("filetype", "helperai", { buf = buf })

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
	api.nvim_set_option_value("wrap", true, { win = win })
	api.nvim_set_option_value("cursorline", true, { win = win })

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
				animate_text(buf, data)
			end
		end,
		on_exit = function()
			api.nvim_set_option_value("modifiable", false, { buf = buf })
		end,
	})
end

-- Setup function for LazyVim
local M = {}

M.setup = function(opts)
	opts = opts or {}
	local keymap = opts.keymap or "<leader>s"

	-- Visual mode mapping
	vim.keymap.set("v", keymap, ":<C-u>lua require('helperAI').search()<CR>", { noremap = true, silent = true })

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

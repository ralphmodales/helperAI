local api = vim.api
local fn = vim.fn

local function setup_highlights()
	api.nvim_set_hl(0, "HelperAITitle", { fg = "#7aa2f7", bold = true })
	api.nvim_set_hl(0, "HelperAIDescription", { fg = "#9ece6a" })
	api.nvim_set_hl(0, "HelperAIURL", { fg = "#bb9af7", underline = true, link = "URL" })
	api.nvim_set_hl(0, "HelperAISearchTerm", { bg = "#3b4261", fg = "#7dcfff" })
	api.nvim_set_hl(0, "HelperAIContent", { fg = "#c0caf5" })
end

local ns_id = api.nvim_create_namespace("helperAI")

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

-- Function to make URLs clickable
local function setup_url_mapping(bufnr, win)
	vim.keymap.set("n", "<CR>", function()
		local line = api.nvim_get_current_line()
		local url = line:match("URL:%s*(https?://%S+)")
		if url then
			vim.notify("Attempting to open URL: " .. url, vim.log.levels.INFO)

			local cmd
			if fn.has("mac") == 1 then
				cmd = { "open", url }
			elseif fn.has("win32") == 1 or fn.has("win64") == 1 then
				cmd = { "cmd.exe", "/c", "start", url }
			else
				cmd = { "xdg-open", url }
			end

			local success, result = pcall(fn.system, cmd)
			if not success then
				vim.notify("Failed to open URL: " .. tostring(result), vim.log.levels.ERROR)
			end
		else
			vim.notify("No URL found on this line", vim.log.levels.WARN)
		end
	end, { buffer = bufnr, silent = true })

	api.nvim_create_autocmd("CursorHold", {
		buffer = bufnr,
		callback = function()
			local line = api.nvim_get_current_line()
			local url = line:match("URL:%s*(https?://%S+)")
			if url then
				vim.lsp.util.open_floating_preview({ "Press Enter to open URL: " .. url }, "markdown", {
					border = "rounded",
					close_events = { "CursorMoved", "BufHidden", "InsertCharPre" },
				})
			end
		end,
	})
end

local function animate_text(bufnr, lines, query)
	if not api.nvim_buf_is_valid(bufnr) then
		return
	end

	local current_lines = {}
	local timer = vim.loop.new_timer()
	local line_idx = 1
	local query_terms = {}
	local content_lines = {} -- Store content for toggling
	local showing_content = {} -- Track which results show content

	for term in query:gmatch("%S+") do
		table.insert(query_terms, term)
	end

	api.nvim_buf_set_option(bufnr, "modifiable", true)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, { "HelperAI is searching..." })

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

				current_lines[line_idx] = lines[line_idx]
				if lines[line_idx]:match("^%s+Content:") then
					content_lines[#current_lines] = lines[line_idx]
				end

				line_idx = line_idx + 1
				pcall(api.nvim_buf_set_lines, bufnr, 0, -1, false, current_lines)

				local current_line = current_lines[line_idx - 1]
				if current_line then
					if current_line:match("^%d+%.") then
						pcall(api.nvim_buf_add_highlight, bufnr, ns_id, "HelperAITitle", line_idx - 2, 0, -1)
					elseif current_line:match("^%s+Description:") then
						pcall(api.nvim_buf_add_highlight, bufnr, ns_id, "HelperAIDescription", line_idx - 2, 0, -1)
						highlight_search_terms(bufnr, line_idx - 2, current_line, query_terms)
					elseif current_line:match("^%s+URL:") then
						pcall(api.nvim_buf_add_highlight, bufnr, ns_id, "HelperAIURL", line_idx - 2, 0, -1)
					elseif current_line:match("^%s+Content:") then
						pcall(api.nvim_buf_add_highlight, bufnr, ns_id, "HelperAIContent", line_idx - 2, 0, -1)
					end
				end
			end)
		)
	end, 500)

	-- Toggle content visibility with 'c'
	vim.keymap.set("n", "c", function()
		local cursor = api.nvim_win_get_cursor(0)
		local line_num = cursor[1] - 1
		local result_num = nil

		for i = line_num, 0, -1 do
			if current_lines[i + 1] and current_lines[i + 1]:match("^%d+%.") then
				result_num = tonumber(current_lines[i + 1]:match("^(%d+)%."))
				break
			end
		end

		if result_num and content_lines[result_num] then
			showing_content[result_num] = not showing_content[result_num]
			local new_lines = {}
			for i, line in ipairs(current_lines) do
				table.insert(new_lines, line)
				if
					line:match("^%d+%.")
					and tonumber(line:match("^(%d+)%.")) == result_num
					and showing_content[result_num]
				then
					table.insert(new_lines, content_lines[result_num])
				end
			end
			api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
		end
	end, { buffer = bufnr, silent = true })
end

local function search_helperai()
	local mode = fn.mode()
	if mode == "v" or mode == "V" then
		api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
	else
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

	local buf = api.nvim_create_buf(false, true)
	local buffer_options = {
		modifiable = true,
		filetype = "helperai",
		buftype = "nofile",
		swapfile = false,
	}

	for option, value in pairs(buffer_options) do
		api.nvim_buf_set_option(buf, option, value)
	end

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

	setup_url_mapping(buf, win) -- Add URL click mapping

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

local M = {}

M.setup = function(opts)
	opts = opts or {}
	local keymap = opts.keymap or "<leader>s"
	local num_results = opts.num_results or 5
	setup_highlights()
	vim.keymap.set("v", keymap, function()
		search_helperai(num_results)
	end, { noremap = true, silent = true })
	api.nvim_create_user_command("HelperAISearch", function()
		search_helperai(num_results)
	end, {})
end

function search_helperai(num_results)
	local mode = fn.mode()
	if mode == "v" or mode == "V" then
		api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
	else
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

	local buf = api.nvim_create_buf(false, true)
	local buffer_options = {
		modifiable = true,
		filetype = "helperai",
		buftype = "nofile",
		swapfile = false,
	}

	for option, value in pairs(buffer_options) do
		api.nvim_buf_set_option(buf, option, value)
	end

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

	setup_url_mapping(buf, win)

	local script_path = fn.expand(fn.stdpath("config") .. "/helperAI/search.py")
	if not vim.loop.fs_stat(script_path) then
		vim.notify("search.py script not found at " .. script_path, vim.log.levels.ERROR)
		return
	end

	local cmd = string.format("python3 %s --query %q --num-results %d", script_path, query, num_results)
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

M.search = search_helperai

return M

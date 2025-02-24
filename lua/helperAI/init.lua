local api = vim.api
local fn = vim.fn

-- Highlight group for unknown terms
api.nvim_set_hl(0, "UnknownTerm", { bg = "#ff5555", fg = "#ffffff" })

-- Highlight unknown terms
local function highlight_unknown_terms()
	local lines = api.nvim_buf_get_lines(0, 0, -1, false)
	for i, line in ipairs(lines) do
		for word in line:gmatch("%w+") do
			if not vim.fn.synIDattr(vim.fn.synID(i, vim.fn.col("."), 1), "name") then
				vim.fn.matchadd("UnknownTerm", "\\<" .. word .. "\\>", 10, -1, { window = 0 })
			end
		end
	end
end

-- Search with helperAI
local function search_helperai()
	local start_pos = api.nvim_buf_get_mark(0, "<")
	local end_pos = api.nvim_buf_get_mark(0, ">")
	local lines = api.nvim_buf_get_text(0, start_pos[1] - 1, start_pos[2], end_pos[1] - 1, end_pos[2] + 1, {})
	local query = table.concat(lines, " "):gsub("%s+", " ")

	if query == "" then
		print("No text selected!")
		return
	end

	local script_path = vim.fn.expand(vim.fn.stdpath("config") .. "/../helperAI/search.py")
	if not vim.loop.fs_stat(script_path) then
		print("search.py script not found at " .. script_path)
		return
	end

	local cmd = string.format("python3 %s --query %q", script_path, query)
	local output = fn.systemlist(cmd)

	local buf = api.nvim_create_buf(false, true)
	api.nvim_buf_set_lines(buf, 0, -1, false, output)
	api.nvim_buf_set_option(buf, "modifiable", false)
	api.nvim_buf_set_option(buf, "filetype", "helperai")

	api.nvim_command("vsplit | buffer " .. buf)

	for i, line in ipairs(output) do
		if line:match("^%d+%.") then
			api.nvim_buf_add_highlight(buf, -1, "Identifier", i - 1, 0, -1)
		elseif line:match("^%s+Description:") then
			api.nvim_buf_add_highlight(buf, -1, "String", i - 1, 0, -1)
		elseif line:match("^%s+URL:") then
			api.nvim_buf_add_highlight(buf, -1, "Underlined", i - 1, 0, -1)
		end
	end
end

-- Autocommand for highlighting
api.nvim_create_autocmd("BufEnter", {
	pattern = "*",
	callback = highlight_unknown_terms,
})

-- Keymap
api.nvim_set_keymap("x", "<leader>s", ":lua require('helperAI').search()<CR>", { noremap = true, silent = true })

return {
	search = search_helperai,
}

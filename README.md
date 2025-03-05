# Neovim HelperAI

**Search smarter, not harder.**

A Neovim plugin that lets you highlight text, hit a key, and get the top 5 search results from the Exa API—titles, descriptions, and URLs—right in a floating window. No more tabbing out to Google. Plus, it highlights "unknown" terms in your code for quick lookups.

## Features

- **Instant Search**: Highlight text in visual mode, press `<leader>s`, and see the top 5 results in a floating window.
- **Smart Highlighting**: Unknown terms (words not in syntax scope) get a red highlight automatically.
- **No Browser Needed**: Powered by the Exa API, delivering concise info directly in Neovim.
- **Clean Output**: Each result includes the title, a description, and a clickable URL.
- **Syntax Highlighting**: Search results are color-coded for better readability.
- **Animated Results**: Results appear with a smooth animation for a better UX.
- **Interactive URLs**: Press Enter on a URL to open it in your default browser.
- **Expandable Content**: Press 'c' on a result to toggle its full content view.
- **Query Term Highlighting**: Search terms are highlighted in the results for quick scanning.

### Top 5 Results:

```
Understanding Python Asyncio 
Description: Asyncio is a library to write concurrent code using the async/await syntax. It's ideal for I/O-bound and high-level structured network code...
URL: https://example.com/python-asyncio

Python Async Programming Guide
Description: Asynchronous programming in Python allows for better handling of I/O-bound tasks by not blocking the execution thread...
URL: https://example.com/async-guide
```

## Installation

### Prerequisites

- Neovim 0.10+ (`nvim --version` to check)
- Python 3 installed (`python3 --version` to check)
- Required Python packages:
  ```bash
  pip install exa_py python-dotenv
  ```
- An Exa API key (grab one from [Exa](https://exa.ai/), set it as `EXA_API_KEY` in a `.env` file)

### Steps

1. **Clone the Repo**: Clone helperAI into a directory LazyVim can find. Since LazyVim uses Git-based plugin management, we'll place it temporarily and let Lazy handle it.
   ```bash
   git clone https://github.com/ralphmodales/helperAI ~/helperAI-temp
   ```
   - This creates a temp folder; we'll configure LazyVim to pull it directly from GitHub later

2. Add to LazyVim: LazyVim manages plugins via Lua specs in ~/.config/nvim/lua/plugins/. Create or edit a file for helperAI:
   ```bash
   mkdir -p ~/.config/nvim/lua/plugins
   nvim ~/.config/nvim/lua/plugins/helperAI.lua
   ```
   Add this content:
   ```lua
    return {
      "ralphmodales/helperAI",
      config = function()
        require("helperAI").setup()
      end,
    }
   ```
   - This tells LazyVim to fetch the plugin from GitHub and run its setup function.

3. **Install the Plugin**:
  - Open Neovim: nvim.
  - Run :Lazy to open the LazyVim plugin manager.
  - Find helperAI in the list (it'll show as ralphmodales/helperAI).
  - Press I (or your keybbind for install) to download it.
  - LazyVim clones it to ~/.local/share/nvim/lazy/helperAI/ automatically.

4. **Set Up the Python Script**: The plugin needs search.py in a specific location. Copy it from the cloned repo:
   ```bash
   mkdir -p ~/.config/nvim/helperAI
   cp ~/helperAI-temp/search.py ~/.config/nvim/helperAI/
   ```
   - Alternatively, if you've installed via Lazy, the path is: 
   ```bash
    cp ~/.local/share/nvim/lazy/helperAI/search.py ~/.config/nvim/helperAI/
   ```
   - Verify it's there ls ~/.config/nvim/helperAI/search.py

5. **Configure the API Key**: The repo includes .env.example as a template. Copy it and add your key:
   ```bash
   cp ~/helperAI-temp/.env.example ~/.config/nvim/helperAI/.env
   ```
   - Or, if using the Lazy-installed path:
   ```bash
    cp ~/.local/share/nvim/lazy/helperAI/.env.example ~/.config/nvim/helperAI/.env
   ```
  - Edit .env:
    ```bash
    nvim ~/.config/nvim/helperAI/.env
    ```
      Replace your-api-key-here with you actual Exa API Key:
      ```text
      EXA_API_KEY=your-actual-exa-api-key
      ```
  - Save and exit (:wq).

6. **(Optional) Clean Up**: If you used the temp clone, remove it:
   ```bash
   rm -rf ~/helperAI-temp
   ```

7. **Verify Setup:**
  - Restart Neovim
  - Check if the plugin loaded: :Lazy (look for helperAI marked as loaded).
  - Test it: Open a file, select text in visual mode (v), press <leader>s (default \s), and see if a floating window appears with "HelperAI is searching...".

## Usage

### Highlight Unknowns
- Open any file. Words not recognized by syntax (e.g., undefined variables) get a red background highlight (`#ff5555`).
- The highlighting runs automatically when entering any buffer.

### Search
- Enter visual mode (`v`), select some text (e.g., "python async").
- Press `<leader>s` (default: `\s`—customize in your keymaps if you want).
- A floating window opens with the top 5 results, animated and syntax-highlighted for readability:
  - Titles in blue
  - Descriptions in green
  - URLs underlined in purple
  - Your search terms highlighted in the results

### Interactive Features
- **URL Opening**: Press `Enter` on a URL line to open it in your default browser
- **Content Viewing**: Press `c` to toggle the full content of a result
- **Hover Info**: Hover over a URL to see a floating tooltip with the URL

## Technical Details

### Plugin Structure

```
helperAI/
├── lua/
│   └── helperAI/
│       └── init.lua    # Core plugin logic (highlight + search)
├── search.py          # Exa API search implementation
├── README.md          # You're reading it
├── LICENSE            # MIT license
└── .gitignore        # Ignores .env, pycache, etc.
```

### Search Implementation

The Python script:
- Uses the Exa API to search and fetch content
- Ranks results by content length and query word matches
- Truncates descriptions to 200 characters and full content to 500 characters
- Returns formatted output with titles, descriptions, URLs, and full content

### Neovim Integration

The Lua plugin:
- Sets up automatic unknown term highlighting
- Handles visual selection and search triggering
- Creates and manages the floating window with results
- Applies syntax highlighting to search results
- Provides interactive features (URL opening, content toggling)
- Animates the results appearance for better UX

## Configuration

### Change Number of Results
By default, the plugin shows 5 results. You can easily change this in your `init.lua`:

```lua
require('helperAI').setup({
    keymap = '<leader>s',    -- Optional: change the default keymap
    num_results = 10         -- Optional: change the number of results (default is 5)
})
```

### Change Keymap
Redefine the search trigger in your `init.lua`:
```lua
vim.keymap.set("v", "<leader>q", ":lua require('helperAI').search()<CR>", { noremap = true, silent = true })
```

### Tweak Unknown Term Highlighting
Modify the UnknownTerm highlight group:
```lua
vim.api.nvim_set_hl(0, "UnknownTerm", { bg = "#ff5555", fg = "#ffffff" })
```

### Customize Result Colors
The plugin uses these highlight groups that you can customize:
```lua
vim.api.nvim_set_hl(0, "HelperAITitle", { fg = "#7aa2f7", bold = true })
vim.api.nvim_set_hl(0, "HelperAIDescription", { fg = "#9ece6a" })
vim.api.nvim_set_hl(0, "HelperAIURL", { fg = "#bb9af7", underline = true })
vim.api.nvim_set_hl(0, "HelperAISearchTerm", { bg = "#3b4261", fg = "#7dcfff" })
vim.api.nvim_set_hl(0, "HelperAIContent", { fg = "#c0caf5" })
```

## Contributing

Found a bug? Any suggestions? 

- Fork it, hack it, PR it.
- Issues welcome at github.com/ralphmodales/helperAI/issues.

## License

MIT License - Meh, do what you want.

Copyright (c) 2025 ralphmodales

## Credits

- Built with Exa for search magic.
- Powered by caffeine and late night coding sessions.

Happy coding! 🚀

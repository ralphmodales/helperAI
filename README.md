# Neovim HelperAI

**Search smarter, not harder.**

A Neovim plugin that lets you highlight text, hit a key, and get the top 5 search results from the Exa API—titles, descriptions, and URLs—right in a buffer. No more tabbing out to Google. Plus, it highlights "unknown" terms in your code for quick lookups.

## Features

- **Instant Search**: Highlight text in visual mode, press `<leader>s`, and see the top 5 results in a split buffer.
- **Smart Highlighting**: Unknown terms (words not in syntax scope) get a red highlight automatically.
- **No Browser Needed**: Powered by the Exa API, delivering concise info directly in Neovim.
- **Clean Output**: Each result includes the title, a 200-char description, and a clickable URL.
- **Syntax Highlighting**: Search results are color-coded for better readability.

## Screenshot

Imagine this in your Neovim split after searching "python async":

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

- Neovim 0.7 or later
- Python 3 installed (`python3 --version` to check)
- Required Python packages:
  ```bash
  pip install exa_py python-dotenv
  ```
- An Exa API key (grab one from [Exa](https://exa.ai/), set it as `EXA_API_KEY` in a `.env` file)

### Steps

1. **Clone the Repo**:
   ```bash
   git clone https://github.com/ralphmodales/helperAI ~/.config/nvim/pack/plugins/start/helperAI
   ```

2. **Load the Plugin**:
   Add this line to your `init.lua`:
   ```lua
   require("helperAI")
   ```

3. **Set Up the Python Script**:
   Create the directory and copy both Python files:
   ```bash
   mkdir -p ~/.config/nvim/../helperAI
   cp helperAI/search.py ~/.config/nvim/../helperAI/
   ```

4. **Add Your API Key**:
   ```bash
   echo "EXA_API_KEY=your-api-key-here" > ~/.config/nvim/../helperAI/.env
   ```

5. **Restart Neovim**: Open Neovim, and you're good to go!

## Usage

### Highlight Unknowns
- Open any file. Words not recognized by syntax (e.g., undefined variables) get a red background highlight (`#ff5555`).
- The highlighting runs automatically when entering any buffer.

### Search
- Enter visual mode (`v`), select some text (e.g., "python async").
- Press `<leader>s` (default: `\s`—customize in your keymaps if you want).
- A vertical split opens with the top 5 results, syntax-highlighted for readability:
  - Titles in identifier color
  - Descriptions in string color
  - URLs underlined

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
- Truncates descriptions to 200 characters
- Returns formatted output with titles, descriptions, and URLs

### Neovim Integration

The Lua plugin:
- Sets up automatic unknown term highlighting
- Handles visual selection and search triggering
- Creates and manages the results buffer
- Applies syntax highlighting to search results

## Configuration

### Change Keymap
Redefine the search trigger in your `init.lua`:
```lua
vim.keymap.set("x", "<leader>q", ":lua require('helperAI').search()<CR>", { noremap = true, silent = true })
```

### Tweak Unknown Term Highlighting
Modify the UnknownTerm highlight group:
```lua
vim.api.nvim_set_hl(0, "UnknownTerm", { bg = "#ff5555", fg = "#ffffff" })
```

### Buffer Style
Swap the vsplit for a floating window by editing `init.lua`—replace `vsplit | buffer` with:
```lua
api.nvim_open_win(buf, true, { relative='win', width=80, height=20, col=10, row=10, border='single' })
```

## Contributing

Found a bug? Any suggestions? 

- Fork it, hack it, PR it.
- Issues welcome at github.com/ralphmodales/helperAI/issues.

## License

MIT License - Meh, do what you want.

Copyright (c) 2025 [ralphmodales]

## Credits

- Built with Exa for search magic.
- Powered by caffeine and late night coding sessions.

Happy coding! 🚀

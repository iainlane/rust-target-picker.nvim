# rust-target-picker.nvim

[![CI][ci-badge]][ci-link]

[ci-badge]: https://github.com/iainlane/rust-target-picker.nvim/actions/workflows/ci.yml/badge.svg
[ci-link]: https://github.com/iainlane/rust-target-picker.nvim/actions/workflows/ci.yml

## Introduction

When working on Rust projects that target multiple platforms, you often need to
switch between different compilation targets. This plugin makes that process
straightforward by providing an interactive picker that lets you select from
your installed Rust targets without leaving Neovim.

The plugin integrates directly with rust-analyzer, automatically updating your
LSP configuration when you change targets. This means you get proper
IntelliSense and error checking for your chosen target immediately, without
needing to restart your editor or LSP server.

## Features

- Interactive target picker using [snacks.nvim]
- Automatic target detection from `rustup`, rust-toolchain files, and LSP settings
- Live LSP integration with rust-analyzer - no restart required
- Status line integration with lualine and custom status bars
- Configurable keymaps with sensible defaults
- Event-driven updates for seamless integrations

[snacks.nvim]: https://github.com/folke/snacks.nvim

## Requirements

- Neovim 0.8+ with Lua support
- [rust-analyzer] LSP server
- [rustup] toolchain manager
- Rust targets installed via `rustup target add <target>`

[rustup]: https://rustup.rs/

## Installation

### lazy.nvim

```lua
{
  "iainlane/rust-target-picker.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
    "LebJe/toml.lua", -- For rust-toolchain.toml support
  },
  ft = "rust",
  opts = {
    -- Default configuration
    keymaps = {
      key = "<leader>ct",
      desc = "Pick Rust Target",
      mode = "n",
    },
  },
}
```

### packer.nvim

```lua
use {
  "iainlane/rust-target-picker.nvim",
  requires = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
    "LebJe/toml.lua",
  },
  ft = "rust",
  config = function()
    require("rust-target-picker").setup()
  end,
}
```

### vim-plug

```vim
Plug 'nvim-lua/plenary.nvim'
Plug 'folke/snacks.nvim'
Plug 'LebJe/toml.lua'
Plug 'iainlane/rust-target-picker.nvim'

" In your init.lua or a Lua file
lua require("rust-target-picker").setup()
```

## Configuration

### Default Setup

```lua
require("rust-target-picker").setup({
  keymaps = {
    key = "<leader>ct",
    desc = "Pick Rust Target",
    mode = "n",
  },
})
```

### Custom Configuration

```lua
require("rust-target-picker").setup({
  keymaps = {
    key = "<leader>rt",           -- Change the keymap
    desc = "Choose Rust Target",  -- Custom description
    mode = "n",                   -- Normal mode
  },
})
```

### Disable Default Keymap

```lua
require("rust-target-picker").setup({
  keymaps = nil, -- Disable automatic keymap creation
})

-- Set up your own keymap
vim.keymap.set("n", "<leader>rt", function()
  require("rust-target-picker"):pick_target()
end, { desc = "Pick Rust Target" })
```

## Usage

### Basic Usage

1. Open any Rust file in your project
2. Press `<leader>ct` (or your configured keymap)
3. Select a target from the picker
4. The rust-analyzer LSP will automatically update

### Target Detection Priority

The plugin detects targets in this order:

1. LSP Settings - Previously set via this plugin
2. rust-toolchain files - `rust-toolchain.toml` or `rust-toolchain`
3. System default - Detected via `rustc -vV`

### Picker Interface

- Navigation: Arrow keys or `j`/`k`
- Select: `<Enter>`
- Cancel: `<Escape>`
- Current target: Marked with `●`

## Integrations

### Lualine Status Line

Add the current Rust target to your status line:

```lua
-- Efficient event-driven approach (recommended)
local function rust_target_status()
  local current_target = nil

  -- Create autocmd to update on target changes
  vim.api.nvim_create_autocmd("User", {
    pattern = "RustTargetChanged",
    callback = function()
      current_target = require("rust-target-picker"):get_current_target()
    end,
  })

  return function()
    if current_target == nil then
      current_target = require("rust-target-picker"):get_current_target()
    end
    return current_target or "default"
  end
end

require("lualine").setup({
  sections = {
    lualine_x = {
      {
        rust_target_status(),
        icon = "🎯",
        cond = function()
          return vim.bo.filetype == "rust"
        end,
      },
    },
  },
})
```

### Custom Integrations

Listen for target change events:

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "RustTargetChanged",
  callback = function(event)
    local new_target = event.data.target
    print("Rust target changed to:", new_target or "default")

    -- Your custom logic here
    -- Update custom status bars, send notifications, etc.
  end,
})
```

## API Reference

### Functions

#### `setup(opts)`

Initialize the plugin with configuration options.

```lua
require("rust-target-picker").setup({
  keymaps = {
    key = "<leader>ct",
    desc = "Pick Rust Target",
    mode = "n",
  },
})
```

#### `pick_target()`

Open the interactive target picker (must be in a Rust file).

```lua
require("rust-target-picker"):pick_target()
```

#### `get_current_target()`

Get the currently active Rust target.

```lua
local current = require("rust-target-picker"):get_current_target()
print("Current target:", current or "default")
```

### Events

#### `RustTargetChanged`

Triggered when the target is changed via the picker.

```lua
-- Event data structure
{
  data = {
    target = "x86_64-pc-windows-gnu" -- or nil for default
  }
}
```

## Troubleshooting

### No targets in picker

Install Rust targets first:

```bash
# List installed targets
rustup target list --installed

# Install additional targets
rustup target add wasm32-unknown-unknown
rustup target add x86_64-pc-windows-gnu
rustup target add aarch64-apple-darwin
```

### rust-analyzer not found

Check LSP status and ensure rust-analyzer is running:

```vim
:LspInfo
```

### TOML parsing errors

Ensure you have the TOML dependency installed:

```lua
-- In your plugin manager
"LebJe/toml.lua"
```

## Contributing

Send a pull request.

### Development Setup

1. Clone the repository
2. Install dependencies: `luarocks install --only-deps *.rockspec`
3. Install pre-commit hooks: `pre-commit install`
4. Run tests: `make test`

## License

[GPL-3.0+][license]

[license]: ./COPYING

## Acknowledgments

- [rust-analyzer] team for the excellent LSP server
- [snacks.nvim] for the picker interface
- [plenary.nvim] for Lua utilities

[rust-analyzer]: https://rust-analyzer.github.io/
[plenary.nvim]: https://github.com/nvim-lua/plenary.nvim

---

<!-- markdownlint-disable-next-line MD033 -->
<div align="center">

[Documentation][docs] • [Issues][issues] • [Discussions][discussions]

</div>

[docs]: https://iainlane.github.io/rust-target-picker.nvim
[issues]: https://github.com/iainlane/rust-target-picker.nvim/issues
[discussions]: https://github.com/iainlane/rust-target-picker.nvim/discussions

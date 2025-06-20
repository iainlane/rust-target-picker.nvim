# rust-target-picker.nvim

A Neovim plugin for selecting and switching Rust compilation targets.

## Introduction

This plugin provides an interface for selecting and switching Rust compilation
targets in Neovim. It integrates with rust-analyzer LSP to dynamically change
the cargo target, enabling cross-compilation workflows without restarting the
LSP server.

### Features

- Interactive target picker using snacks.nvim
- Automatic detection of available targets via `rustup`
- Integration with rust-toolchain.toml files
- Status line integration (lualine and others)
- Configurable keymaps
- Event-driven notifications for custom integrations

## Requirements

- Neovim with Lua support
- rust-analyzer LSP server configured and running
- rustup toolchain manager
- Rust targets installed via `rustup target add <target>`

### Dependencies

- [nvim-lua/plenary.nvim][plenary] (for Job and Path utilities)
- [folke/snacks.nvim][snacks] (for the picker interface)
- [LebJe/toml.lua][toml] (for parsing rust-toolchain.toml files)

[plenary]: https://github.com/nvim-lua/plenary.nvim
[snacks]: https://github.com/folke/snacks.nvim
[toml]: https://github.com/LebJe/toml.lua

## Installation

### lazy.nvim

```lua
{
  "your-username/rust-target-picker.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
    "LebJe/toml.lua",
  },
  ft = "rust",
  opts = {},
}
```

## Configuration

The `setup` function accepts an optional options table with the following fields:

### Options

#### `keymaps`

Type: `table|nil`
Default: `{ key = "<leader>ct", desc = "Pick Rust Target", mode = "n" }`

Configuration for the target picker keymap. If set to `nil`, no keymap will be
created, allowing manual setup.

- `keymaps.key` (`string`): The key sequence to trigger the target picker.
  Default: `"<leader>ct"`
- `keymaps.desc` (`string`): Description shown in which-key and similar
  plugins. Default: `"Pick Rust Target"`
- `keymaps.mode` (`string`): Vim mode for the keymap. Default: `"n"` (normal mode)

### Example Configuration

```lua
require("rust-target-picker").setup({
  keymaps = {
    key = "<leader>rt",
    desc = "Choose Rust Target",
    mode = "n",
  },
})
```

To disable automatic keymap creation:

```lua
require("rust-target-picker").setup({
  keymaps = nil,
})
```

## Usage

### Target Detection

The plugin detects the current Rust target from multiple sources, in order of precedence:

1. rust-analyzer LSP settings (if target was set via this plugin)
2. rust-toolchain.toml or rust-toolchain files in the project root
3. Default host target (detected via `rustc -vV`)

The project root is determined using LazyVim utilities or LSP client root
directory as fallback.

### Picker Interface

The target picker displays:

- "Default (host-target)" option to reset to system default
- All installed Rust targets from `rustup target list --installed`
- Current target marked with a bullet point (●)

#### Navigation

- Use arrow keys or j/k to navigate
- Press Enter to select a target
- Press Escape to cancel

## API Reference

### Functions

#### `RustTargetPicker.setup(opts)`

Initialize the plugin with optional configuration.

Parameters:

- `opts` (`table|nil`): Configuration options

#### `RustTargetPicker:pick_target()`

Open the interactive target picker. Only works in Rust files.

#### `RustTargetPicker:get_current_target()`

Get the currently active Rust target.

Returns:

- `string|nil`: Current target triple, or nil if using default

#### `RustTargetPicker:detect_default_target()`

Detect and cache the system's default Rust target.

Returns:

- `string|nil`: Default target triple from rustc

### Example Usage

```lua
local picker = require("rust-target-picker")

-- Get current target for display
local current = picker:get_current_target()
if current then
  print("Current target: " .. current)
else
  print("Using default target")
end

-- Open picker programmatically
picker:pick_target()
```

## Integration

### Lualine Integration

For optimal performance with lualine, use this cached function approach:

```lua
-- Efficient lualine integration with event-driven updates
local function rust_target()
  local current_target = nil

  return function()
    if current_target == nil then
      current_target = require("rust-target-picker"):get_current_target()
    end

    vim.api.nvim_create_autocmd("User", {
      pattern = "RustTargetChanged",
      callback = function()
        current_target = require("rust-target-picker"):get_current_target()
      end,
    })

    return current_target
  end
end

-- Add to your lualine sections
sections = {
  lualine_x = {
    {
      rust_target(),
      cond = function() return vim.bo.filetype == "rust" end,
    },
  }
}
```

This approach caches the target value and only updates it when the
`RustTargetChanged` event is fired, avoiding repeated function calls.

### Custom Integrations

Listen to target change events for custom integrations:

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "RustTargetChanged",
  callback = function(event)
    local new_target = event.data.target
    print("Rust target changed to:", new_target or "default")

    -- Custom handling here
    -- Refresh custom statusline, update UI, etc.
  end,
})
```

## Events

### `RustTargetChanged`

Fired when a Rust target is changed via the picker.

Event data:

- `data.target` (`string|nil`): The new target triple, or nil for default

This event allows other plugins and configurations to react to target changes
without tight coupling to the rust-target-picker implementation.

## Troubleshooting

### Common Issues

#### No targets shown in picker

Ensure you have Rust targets installed:

```bash
rustup target list --installed
```

Install additional targets:

```bash
rustup target add wasm32-unknown-unknown
rustup target add x86_64-pc-windows-gnu
```

#### rust-analyzer not found

Check that rust-analyzer is running:

```vim
:LspInfo
```

Verify the LSP client name matches "rust-analyzer" (with hyphen).

#### Target not updating in status line

Ensure you're using the event-driven lualine integration pattern shown above
rather than calling `get_current_target()` directly in the status function.

#### TOML parsing errors

Install the `toml.lua` dependency:

```lua
{ "LebJe/toml.lua" }
```

#### Default target not detected

Ensure rustc is available in PATH:

```bash
rustc --version
```

### Additional Help

For additional help, check:

- `:messages` for error details
- `:LspLog` for rust-analyzer communication issues
- Plugin logs in the notification area

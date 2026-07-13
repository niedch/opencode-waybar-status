# opencode-waybar-status

OpenCode plugin that reports instance status to a Waybar widget — shows when OpenCode is working, idle, waiting for permissions, or hit an error, across all active projects.

## Installation

### Nix Flake + Home Manager

```nix
# flake.nix
{
  inputs.opencode-waybar-status.url = "github:fiffy/opencode-waybar-status";
}

# home.nix
{ inputs, ... }: {
  imports = [ inputs.opencode-waybar-status.homeModules.default ];
  programs.opencode-waybar-status = {
    enable = true;
    package = inputs.opencode-waybar-status.packages.${pkgs.system}.default;
  };
}
```

Then in your Waybar config:

```jsonc
// ~/.config/waybar/config.jsonc
{
  "include": ["~/.config/waybar/indicators/opencode/waybar-config.json"],
}
```

And in your Waybar style:

```css
@import "indicators/opencode/style.css";
```

### Manual

```bash
npm install -g @fiffy/opencode-waybar-status
```

1. Symlink the plugin into OpenCode's plugin directory:
   ```bash
   ln -s $(npm root -g)/@fiffy/opencode-waybar-status/opencode-plugin.js \
     ~/.config/opencode/plugins/opencode-waybar-status.js
   ```
2. Copy the status script into Waybar's scripts directory:
   ```bash
   cp waybar/scripts/opencode-status.sh ~/.config/waybar/scripts/
   ```
3. Add a `custom/opencode` module to your Waybar config (see `waybar/config.example.json`).
4. Add the CSS styles (see `waybar/style.example.css`).
5. Restart Waybar.

## Configuration

### Home Manager Options

| Option           | Type    | Default     | Description                        |
| ---------------- | ------- | ----------- | ---------------------------------- |
| `enable`         | bool    | `false`     | Enable the plugin                  |
| `package`        | package | —           | Must be set to the flake package   |
| `waybarInterval` | int     | `2`         | Waybar polling interval in seconds |
| `formatIcons`    | attrs   | (see below) | Icons per state                    |

Default `formatIcons`:

```nix
{
  working = "󰒋";    # nf-md-puzzle
  idle = "󰄬";       # nf-md-check_circle
  permission = "󰀪"; # nf-md-help_circle
  error = "󰅙";      # nf-md-close_circle
}
```

## How It Works

1. The plugin runs inside OpenCode and writes JSON status files to `$XDG_RUNTIME_DIR/opencode-waybar-status/<project>.json`
2. A bash script (`opencode-status.sh`) runs every 2 seconds via Waybar's `custom/opencode` module, reading all status files
3. Files older than 20 seconds are considered stale (session ended) and ignored
4. The worst status across all active sessions is shown (error > permission > working > idle)
5. When no sessions are active, the widget hides
6. Status changes trigger an instant update via `pkill -RTMIN+6 waybar` (no polling delay)

The tooltip shows per-project details: project name, status, active tool, agent, and model.

## Development

```bash
npm run build    # compile TypeScript
npm run dev      # watch mode
```

A Nix dev shell with all dependencies is provided:

```bash
nix develop
```

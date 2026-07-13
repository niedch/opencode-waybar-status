{ config, lib, pkgs, ... }:

let
  cfg = config.programs.opencode-waybar-status;
  inherit (lib) mkIf mkEnableOption mkOption types;
in
{
  options.programs.opencode-waybar-status = {
    enable = mkEnableOption "OpenCode Waybar status plugin";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        The opencode-waybar-status package output from the flake.
        Must be set when enable = true.
      '';
    };

    waybarInterval = mkOption {
      type = types.int;
      default = 2;
      description = "Polling interval in seconds for the waybar module";
    };

    formatIcons = mkOption {
      type = types.attrsOf types.str;
      default = {
        working = "󰒋";
        idle = "󰄬";
        permission = "󰀪";
        error = "󰅙";
      };
      description = "Icons for each status state";
    };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = cfg.package != null;
      message = "programs.opencode-waybar-status.package must be set";
    }];

    home.packages = [ cfg.package ];

    # OpenCode global plugin
    home.file."${config.xdg.configHome}/opencode/plugins/opencode-waybar-status.js" = {
      source = "${cfg.package}/lib/node_modules/@fiffy/opencode-waybar-status/opencode-plugin.js";
    };

    # Waybar CSS for the custom/opencode module
    xdg.configFile."waybar/indicators/opencode/style.css" = {
      source = "${cfg.package}/share/opencode-waybar-status/style.css";
    };

    # Waybar config snippet — include this in your config.jsonc via:
    #   "include": ["~/.config/waybar/indicators/opencode/waybar-config.json"]
    xdg.configFile."waybar/indicators/opencode/waybar-config.json" = {
      source = "${cfg.package}/share/opencode-waybar-status/waybar-config.json";
    };
  };
}

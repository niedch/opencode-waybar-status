{
  description = "opencode-waybar-status — OpenCode plugin that exposes instance status to Waybar";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs = { self, nixpkgs, flake-utils, git-hooks }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          package = pkgs.buildNpmPackage {
            pname = "opencode-waybar-status";
            version = "0.1.2";
            src = ./.;

            npmDepsHash = "sha256-T1DVa8vM+AZvQ/FtR0S7PYgU1dlnajFHvip3vhVu3bc=";

            nativeBuildInputs = [ pkgs.makeWrapper ];

            buildPhase = ''
              runHook preBuild
              npm run build
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              # Install as npm-style package for plugin resolution
              mkdir -p $out/lib/node_modules/@fiffy/opencode-waybar-status
              cp -r dist package.json $out/lib/node_modules/@fiffy/opencode-waybar-status/

              # Global plugin loader — symlink to ~/.config/opencode/plugins/
              cat > $out/lib/node_modules/@fiffy/opencode-waybar-status/opencode-plugin.js << 'EOF'
              export { WaybarStatus } from "./dist/index.js";
              EOF

              # Waybar helper script — wrap with jq on PATH
              mkdir -p $out/share/opencode-waybar-status $out/bin
              cp waybar/scripts/opencode-status.sh $out/share/opencode-waybar-status/opencode-status.sh
              makeWrapper $out/share/opencode-waybar-status/opencode-status.sh \
                $out/bin/opencode-waybar-status-helper \
                --prefix PATH : ${pkgs.jq}/bin

              # Waybar style.css for the custom/opencode module
              cp waybar/style.example.css $out/share/opencode-waybar-status/style.css

              # Waybar config snippet — merge this into your waybar settings
              ${pkgs.jq}/bin/jq -n '{
                "custom/opencode": {
                  "exec": "opencode-waybar-status-helper",
                  "interval": 2,
                  "return-type": "json",
                  "format": "{icon} {text}",
                  "format-icons": {
                    "working": "󰒋",
                    "idle": "󰄬",
                    "permission": "󰀪",
                    "error": "󰅙"
                  },
                  "tooltip": true
                }
              }' > $out/share/opencode-waybar-status/waybar-config.json

              runHook postInstall
            '';

            meta = {
              description = "Waybar status plugin for OpenCode";
              license = pkgs.lib.licenses.mit;
              mainProgram = "opencode-waybar-status-helper";
            };
          };

          precommit-check = git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              prettier.enable = true;
              nixpkgs-fmt.enable = true;
              check-merge-conflicts.enable = true;
              trim-trailing-whitespace.enable = true;
            };
          };
        in
        {
          packages.default = package;
          packages.opencode-waybar-status = package;

          devShells.default = pkgs.mkShell {
            name = "opencode-waybar-status-dev";

            buildInputs = with pkgs; [
              nodejs_22
              corepack
              typescript
              prettier
              jq
              inotify-tools
              nixpkgs-fmt
            ];

            shellHook =
              let
                hook = precommit-check.shellHook;
              in
              hook + ''
                npm install --prefer-offline --no-audit --no-fund 2>/dev/null || true
                echo ""
                echo "  opencode-waybar-status devShell"
                echo "  Node $(node --version) — $(which node)"
                echo ""
                echo "  Commands:"
                echo "    npm run build    — compile TypeScript to dist/"
                echo "    npm run dev      — watch mode (tsc --watch)"
                echo "    nix build        — build with Nix"
                echo "    nix flake check  — run checks"
                echo ""
              '';
          };

          checks = {
            inherit precommit-check;
          };

          formatter = pkgs.nixpkgs-fmt;
        }
      ) // {
      homeModules = {
        default = import ./hm-module.nix;
      };
    };
}

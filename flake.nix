{
  description = "opencode-waybar-status — OpenCode plugin that exposes instance status to Waybar";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs = { self, nixpkgs, flake-utils, git-hooks }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        package = pkgs.buildNpmPackage {
          pname = "opencode-waybar-status";
          version = "0.1.0";
          src = ./.;

          npmDepsHash = "sha256-0WP5jRMgL2lT6D7YC8cF7QKayoOV/dxZcCGd+3DYnhw=";

          buildPhase = ''
            runHook preBuild
            npm run build
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out/lib
            cp -r dist package.json $out/lib/
            runHook postInstall
          '';

          meta = {
            description = "Waybar status plugin for OpenCode";
            license = pkgs.lib.licenses.mit;
            mainProgram = "opencode-waybar-status";
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
              corepack enable
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
    );
}

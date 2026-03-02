{
  description = "Tela";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
        lib = pkgs.lib;
        beam = pkgs.beamMinimal28Packages;

        # Pre-fetched Mix deps (test env includes stream_data and styler).
        # Update sha256 whenever mix.lock changes by running `nix flake check`
        # and copying the hash from the error output.
        mixDeps = beam.fetchMixDeps {
          pname = "tela-deps";
          version = "0.1.0";
          src = ./.;
          mixEnv = "test";
          sha256 = "sha256-5zQMU7qDBjzLhqUsyFnjCv0J/oxfmhCye7RalGzFoFE=";
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs;
            [
              beam.elixir_1_19
              zig
              xz
            ]
            ++ lib.optionals stdenv.isLinux [inotify-tools]
            ++ lib.optionals stdenv.isDarwin [git];
          env = {
            ERL_AFLAGS = "-kernel shell_history enabled";
          };
          shellHook = ''
            export MIX_HOME="$PWD/.mix";
            export HEX_HOME="$PWD/.hex";
          '';
        };

        apps.publish = {
          type = "app";
          program = "${pkgs.writeShellApplication {
            name = "tela-publish";
            runtimeInputs = [beam.elixir_1_19 beam.hex];
            text = ''
              if [[ -z "''${HEX_API_KEY:-}" ]]; then
                echo "error: HEX_API_KEY is not set" >&2
                exit 1
              fi
              mix hex.publish --yes
            '';
          }}/bin/tela-publish";
        };

        checks.format = pkgs.stdenv.mkDerivation {
          name = "tela-format-check";
          src = ./.;

          nativeBuildInputs = [beam.elixir_1_19 beam.hex];

          env = {
            LANG = "C.UTF-8";
            HEX_OFFLINE = "1";
            MIX_ENV = "test";
          };

          buildPhase = ''
            export MIX_HOME="$TMPDIR/.mix"
            export HEX_HOME="$TMPDIR/.hex"
            export MIX_BUILD_PATH="$TMPDIR/_build"
            export MIX_DEPS_PATH="${mixDeps}"
            mix format --check-formatted
          '';

          installPhase = "touch $out";
        };

        checks.test = pkgs.stdenv.mkDerivation {
          name = "tela-test";
          src = ./.;

          nativeBuildInputs = [beam.elixir_1_19 beam.hex];

          env = {
            LANG = "C.UTF-8";
            HEX_OFFLINE = "1";
            MIX_ENV = "test";
          };

          buildPhase = ''
            export MIX_HOME="$TMPDIR/.mix"
            export HEX_HOME="$TMPDIR/.hex"
            export MIX_BUILD_PATH="$TMPDIR/_build"
            export MIX_DEPS_PATH="${mixDeps}"
            mix test
          '';

          installPhase = "touch $out";
        };
      }
    );
}

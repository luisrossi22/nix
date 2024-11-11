{
  description = "Luis Darwin system flake";
  # Not configurable
  # softwareupdate --install-rosetta --agree-to-license 
  inputs = {
    # Package sets 
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-24.05-darwin";
    # "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Environment/system management
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    #"nixpkgs-darwin";
    #"nixpkgs";
  };
  outputs = inputs@{ self, nix-darwin, nixpkgs }:
  let
    configuration = { pkgs, config, ... }: {
      # This can be configured by app https://nixos.wiki/wiki/Unfree_Software
      nixpkgs.config.allowUnfree = true;
      # direnv
      programs.direnv.enable = true;
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        [
          pkgs.mkalias
          # UI
          pkgs.obsidian
          pkgs.charles
          pkgs.pritunl-client
	  pkgs.rancher
	  pkgs.teams
          # pkgs.firefox ¿no existe in aarch64-apple-darwin?:
          # Terminal
          pkgs.neofetch
          pkgs.fish
          pkgs.tmux
          ##pkgs.neovim
          pkgs.p7zip
          pkgs.alacritty
          # Repos
          pkgs.gh
          # iOS
          pkgs.idb-companion
          pkgs.cocoapods
          # Data
          pkgs.duckdb
        ];
      # Fonts
      fonts.packages = [
        (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
      ];
      # Make installed Mac Apps indexable by Spotlight
      system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
        name = "system-applications";
        paths = config.environment.systemPackages;
        pathsToLink = "/Applications";
      };
      in
        pkgs.lib.mkForce ''
          # Set up applications.
          echo "setting up /Applications..." >&2
          rm -rf /Applications/Nix\ Apps
          mkdir -p /Applications/Nix\ Apps
          find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
          while IFS= read -r src; do
            app_name=$(basename "$src")
            echo "copying $src" >&2
            ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
          done
        '';
      # Auto upgrade nix package and the daemon service.
      services.nix-daemon.enable = true;
      # nix.package = pkgs.nix;
      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";
      # With Rosetta, this enables the system to run binaries for Intel CPUs transparently
      nix.extraOptions = ''
        extra-platforms = x86_64-darwin aarch64-darwin
      '';
      # neat Linux builder that runs a NixOS VM as a service in the background
      nix.linux-builder.enable = true;
      # Create /etc/zshrc that loads the nix-darwin environment.
      programs.zsh.enable = true;  # default shell on catalina
      programs.fish.enable = true;
      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;
      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;
      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
      # Sudo with touch id
      security.pam.enableSudoTouchIdAuth = true;
      # https://daiderd.com/nix-darwin/manual/index.html
      system.defaults = {
        dock.autohide = true;
        # dock.mru-spaces = false;
        finder.AppleShowAllExtensions = true;
        finder.FXPreferredViewStyle = "clmv";
        finder.ShowPathbar = true;
        finder.ShowStatusBar = true;
        finder._FXSortFoldersFirst = true;
        # loginwindow.LoginwindowText = "nixcademy.com";
        screencapture.location = "~/Pictures/screenshots";
        # screensaver.askForPasswordDelay = 10;
      };
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#macbook
    darwinConfigurations."simple" = nix-darwin.lib.darwinSystem {
      modules = [ configuration ];
    };
    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."simple".pkgs;
  };
}

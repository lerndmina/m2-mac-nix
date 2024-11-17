{
  description = "Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    homebrew-bundle.url = "github:homebrew/homebrew-bundle";
    homebrew-bundle.flake = false;
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, homebrew-bundle, homebrew-core, homebrew-cask }:
  let
    configuration = { pkgs, config, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        [ pkgs.mkalias
          pkgs.fastfetch
          pkgs.vscode
          pkgs.alacritty
          pkgs.raycast
          pkgs.wget
          pkgs.git
          pkgs.stow
          pkgs.youtube-music
          pkgs.openjdk
                    # (pkgs.discord.override {
          #   # Mac will have to disable the checksum in privacy and security.
          #   withOpenASAR = true;
          #   withVencord = true;
          # })
          pkgs.flameshot
          pkgs.xsel
          pkgs.zenity
          pkgs.bun
          pkgs.btop
          pkgs.openssh
        ];

      fonts.packages = [
        (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
      ];

      # Allow unfree
      nixpkgs.config.allowUnfree = true;

      homebrew = {
        enable = true;
        brews = [
          "mas"
          "node"
	 "coreutils"
	        "cloudflared"
	        "caddy"
        ];
        casks = [
          "docker"
          "1password"
          "1password-cli"
          "bartender"
          "alt-tab"
          "github"
          "iina"
          "vivaldi"
          "github"
          "istat-menus"
          "middle"
          "iterm2"
          "aldente"
          "openvpn-connect"
          "signal"
          "buzz"
          "discord"
          "utm"
          "tunnelblick"
          "logseq"
          "fork"
        ];
        masApps = {
          "Dropover" = 1355679052;
          "1Password Safari" = 1569813296;
          "Magnet" = 441258766;
          "Pages" = 409201541;
          "Keynote" = 409183694;
          "Numbers" = 409203825;
          "Action Shortcuts" = 1447884454;
          "Transmit" = 1436522307;
        };
        onActivation.cleanup = "zap";
        onActivation.autoUpdate = true;
        onActivation.upgrade = true;
      };

      system.defaults = {
        NSGlobalDomain."com.apple.swipescrolldirection" = false;
        dock.autohide = false;
        dock.persistent-apps = [
          "/Applications/Vivaldi.app"
          "Applications/iTerm.app"
          "${pkgs.vscode}/Applications/Visual Studio Code.app"
          "/Applications/Safari.app"
          "/Applications/1Password.app"
          "/Applications/Signal.app"
          "/Applications/Logseq.app"
          "/Applications/Fork.app"
        ];
        dock.show-recents = false;
        dock.tilesize = 50;
        dock.orientation = "left";
        finder.CreateDesktop = false;
        loginwindow.GuestEnabled = false;
        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.AppleInterfaceStyle = "Dark";
        NSGlobalDomain.KeyRepeat = 2;
        finder.FXPreferredViewStyle = "Nlsv";
        NSGlobalDomain.AppleShowAllFiles = true;
        NSGlobalDomain.AppleShowAllExtensions = true;
        finder.ShowPathbar = true;
        finder.ShowStatusBar = true;
      };

      # Run a script after the configuration is applied.
      system.activationScripts.post = ''
        #!/bin/sh
        echo "Setting up tid and wid for sudo"
        sed -e 's/^#auth/auth/' /etc/pam.d/sudo_local.template | sudo tee /etc/pam.d/sudo_local

        echo "Setting up ssh"
        sudo systemsetup -setremotelogin on

        echo "Setting force touch value"
        defaults write -g com.apple.trackpad.forceClick -int 1

        echo "Disabling window re opening"
        sudo chown root ~/Library/Preferences/ByHost/com.apple.loginwindow*
        sudo chmod 000 ~/Library/Preferences/ByHost/com.apple.loginwindow*
      '';

      # Fix spotlight using macos Alias
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
        while read src; do
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

      # Create /etc/zshrc that loads the nix-darwin environment.
      programs.zsh.enable = true;  # default shell on catalina
      # programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
    darwinConfigurations."steves-Mac-mini" = nix-darwin.lib.darwinSystem {
      modules = [ 
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "steve";
            mutableTaps = false;
            taps = {
              "homebrew/homebrew-core" = inputs.homebrew-core;
              "homebrew/homebrew-cask" = inputs.homebrew-cask;
              "homebrew/homebrew-bundle" = inputs.homebrew-bundle; # <---
            };
          };
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."Wilds-MacBook-Air".pkgs;
  };
}

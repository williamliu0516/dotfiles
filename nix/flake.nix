{
  # Linux 上的 CLI 工具链：tmux、fzf、eza、bat、zoxide、btop、fd、ripgrep、poppler、字体。
  # yazi 不在这里：配置要 26.9.1 之后的版本，由安装脚本下 GitHub 上的 nightly 预编译版（见 modules/terminal/install.sh）。
  # 全部来自 nixpkgs，版本锁在 flake.lock 里，所以每台 Ubuntu（不管 22.04 还是 26.04）装出来都一样，
  # 也不再依赖 apt 源里有没有某个包。系统层的东西（zsh 登录 shell、mosh、Ghostty）仍由 apt/snap 管。
  #
  #   home-manager switch --flake path:~/.dotfiles/nix#linux --impure
  #
  # 由 modules/terminal/install.sh 调用；--impure 是因为 home.nix 用 $USER / $HOME 决定装到哪个用户，
  # 这样同一份配置在任何用户名的机器上都能用。用 path: 前缀是为了让 nix 不去管 git 有没有跟踪这些文件。
  #
  # 升级所有工具到 nixpkgs 最新：  cd ~/.dotfiles/nix && nix flake update && home-manager switch --flake path:.#linux --impure
  description = "dotfiles: CLI 工具链，跨 Linux 发行版版本一致";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forEach = nixpkgs.lib.genAttrs systems;
    in {
      homeConfigurations.linux = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = builtins.currentSystem;   # --impure
        };
        modules = [ ./home.nix ];
      };

      # 让安装脚本能用和 flake.lock 同一版本的 home-manager：nix run path:~/.dotfiles/nix#home-manager
      packages = forEach (system: {
        home-manager = home-manager.packages.${system}.default;
      });
    };
}

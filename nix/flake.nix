{
  # Linux 上的 CLI 工具链：tmux、fzf、eza、bat、zoxide、yazi、lazygit、btop、fd、ripgrep、poppler、字体。
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
    # yazi.toml 用了 sort_by = "custom"（config/yazi/plugins/hidden-last.yazi），需要 26.9.1 之后的版本；
    # nixpkgs 里还是 26.9.1，所以暂时从 yazi 仓库的 flake 编译 main 分支（Rust，首次要几分钟）。
    # 等 nixpkgs 的 yazi 新于 26.9.1 后，删掉这个 input 和 home.nix 里的 overlay 即可。
    yazi = {
      url = "github:sxyazi/yazi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, yazi, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forEach = nixpkgs.lib.genAttrs systems;
    in {
      homeConfigurations.linux = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = builtins.currentSystem;   # --impure
          overlays = [
            yazi.overlays.default
            # yazi 仓库的 release profile 是 fat LTO + codegen-units=1，最后链接时 rustc 要 1.5 GB 以上内存，
            # 4 GiB 的机器会被 OOM 杀掉。改成 thin LTO、多 codegen unit：内存大幅下降，编译也快，二进制略大一点。
            (final: prev: {
              yazi = prev.yazi.override {
                yazi-unwrapped = prev.yazi-unwrapped.overrideAttrs (o: {
                  env = (o.env or { }) // {
                    CARGO_PROFILE_RELEASE_LTO = "thin";
                    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
                  };
                });
              };
            })
          ];
        };
        modules = [ ./home.nix ];
      };

      # 让安装脚本能用和 flake.lock 同一版本的 home-manager：nix run path:~/.dotfiles/nix#home-manager
      packages = forEach (system: {
        home-manager = home-manager.packages.${system}.default;
      });
    };
}

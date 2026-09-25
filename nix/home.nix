# Home Manager 配置。只管"装哪些包"和字体；配置文件仍由 modules/terminal/install.sh 软链到 ~/.dotfiles，
# 这样 macOS（还是 brew）和 Linux 用的是同一份 zshrc / tmux.conf，改完不用 switch。
{ pkgs, lib, ... }:
{
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";

  home.packages = with pkgs; [
    tmux
    fzf
    eza
    bat          # nix 里就叫 bat，不是 Ubuntu 的 batcat（zshrc 两种都认）
    zoxide
    yazi         # 来自 flake.nix 里的 yazi overlay（见那边的注释）
    lazygit
    btop
    fd           # 同上，不是 fdfind
    ripgrep
    poppler-utils   # pdftoppm，yazi 的 PDF 预览
    maple-mono.NF-CN   # Maple Mono NF CN：中文 + Nerd 图标；和 macOS 的 brew cask 同一个字体
  ];

  # 把 ~/.nix-profile 里的字体注册进 fontconfig，fc-list 和 Ghostty 才看得见
  fonts.fontconfig.enable = true;

  # 装完后 home-manager 命令本身也在 PATH 里，以后直接 home-manager switch
  programs.home-manager.enable = true;

  # 首次生成配置时的 Home Manager 版本，只用于兼容旧默认值，不用跟着升级
  home.stateVersion = "26.05";
}

// snappy (dark) — port of ~/.dotfiles/config/ghostty/themes/snappy for Blink Shell
// Palette matches Ghostty exactly, so tmux status bar (colour0-15) looks identical.

black        = '#2c3144';
red          = '#dd7a84';
green        = '#8ac48a';
yellow       = '#d5ad63';
blue         = '#6fb0f4';
magenta      = '#a487eb';
cyan         = '#62bcc6';
white        = '#c9d1e2';
lightBlack   = '#5d6784';
lightRed     = '#e88c95';
lightGreen   = '#9dd29d';
lightYellow  = '#dfbd78';
lightBlue    = '#88bfff';
lightMagenta = '#b79ef5';
lightCyan    = '#7bcdd6';
lightWhite   = '#edf1f9';

t.prefs_.set('color-palette-overrides', [
  black, red, green, yellow, blue, magenta, cyan, white,
  lightBlack, lightRed, lightGreen, lightYellow, lightBlue, lightMagenta, lightCyan, lightWhite
]);

t.prefs_.set('foreground-color', '#c8d0e0');
t.prefs_.set('background-color', '#181a24');
// Ghostty cursor-color #6fb0f4; alpha so text under a block cursor stays readable
t.prefs_.set('cursor-color', 'rgba(111, 176, 244, 0.6)');

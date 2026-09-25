// snappy_light — port of ~/.dotfiles/config/ghostty/themes/snappy_light for Blink Shell

black        = '#5a6275';
red          = '#c95a6a';
green        = '#4f956c';
yellow       = '#ba7f26';
blue         = '#2b7fd6';
magenta      = '#a463d8';
cyan         = '#2f98ab';
white        = '#6d7588';
lightBlack   = '#98a1b5';
lightRed     = '#db7080';
lightGreen   = '#66a981';
lightYellow  = '#cf953e';
lightBlue    = '#4a97e8';
lightMagenta = '#b57be5';
lightCyan    = '#4dafbe';
lightWhite   = '#202533';

t.prefs_.set('color-palette-overrides', [
  black, red, green, yellow, blue, magenta, cyan, white,
  lightBlack, lightRed, lightGreen, lightYellow, lightBlue, lightMagenta, lightCyan, lightWhite
]);

t.prefs_.set('foreground-color', '#202533');
t.prefs_.set('background-color', '#f5efe4');
t.prefs_.set('cursor-color', 'rgba(43, 127, 214, 0.6)');

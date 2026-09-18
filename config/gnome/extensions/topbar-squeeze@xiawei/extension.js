// Hide Top Bar 把顶栏设成不占空间（affectsStruts: false），滑出时会盖住窗口。
// 这里让顶栏只在「完全滑入」时占空间：最大化窗口被挤下来；一开始滑出就释放，窗口铺满。
// 动画过程中不占空间——Hide Top Bar 是逐帧改 y 的，每帧都占空间会让窗口每帧重排。
// 用了 LayoutManager 的私有成员 _trackedActors / _queueUpdateRegions，GNOME 升级后可能要跟着改。
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

export default class TopBarSqueeze extends Extension {
    enable() {
        this._box = Main.layoutManager.panelBox;
        this._box.connectObject(
            'notify::y', () => this._sync(),
            'notify::visible', () => this._sync(),
            this);
        this._sync();
    }

    disable() {
        this._box.disconnectObject(this);
        // 交还给 Hide Top Bar：它启用时顶栏本就不占空间
        this._setStruts(false);
        this._box = null;
    }

    _sync() {
        const fullyShown = this._box.visible &&
            this._box.y >= Main.layoutManager.primaryMonitor.y;
        this._setStruts(fullyShown);
    }

    _setStruts(on) {
        const data = Main.layoutManager._trackedActors.find(a => a.actor === this._box);
        if (!data || data.affectsStruts === on)
            return;
        data.affectsStruts = on;
        Main.layoutManager._queueUpdateRegions();
    }
}

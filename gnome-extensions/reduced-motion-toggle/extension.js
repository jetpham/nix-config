import Gio from 'gi://Gio';
import GObject from 'gi://GObject';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';

const INTERFACE_SCHEMA = 'org.gnome.desktop.interface';
const ENABLE_ANIMATIONS_KEY = 'enable-animations';

const ReducedMotionToggle = GObject.registerClass(
class ReducedMotionToggle extends QuickSettings.QuickToggle {
    constructor() {
        super({
            title: 'Reduced Motion',
            subtitle: 'Prefer fewer animations',
            iconName: 'preferences-desktop-accessibility-symbolic',
            toggleMode: true,
        });

        this._settings = new Gio.Settings({schema_id: INTERFACE_SCHEMA});
        this._syncing = false;
        this._changedId = this._settings.connect(
            `changed::${ENABLE_ANIMATIONS_KEY}`,
            () => this._sync()
        );
        this._checkedId = this.connect('notify::checked', () => {
            if (!this._syncing)
                this._settings.set_boolean(ENABLE_ANIMATIONS_KEY, !this.checked);
        });

        this._sync();
    }

    _sync() {
        const reducedMotionEnabled = !this._settings.get_boolean(ENABLE_ANIMATIONS_KEY);

        if (this.checked === reducedMotionEnabled)
            return;

        this._syncing = true;
        this.checked = reducedMotionEnabled;
        this._syncing = false;
    }

    destroy() {
        if (this._changedId) {
            this._settings.disconnect(this._changedId);
            this._changedId = null;
        }

        if (this._checkedId) {
            this.disconnect(this._checkedId);
            this._checkedId = null;
        }

        super.destroy();
    }
});

const ReducedMotionIndicator = GObject.registerClass(
class ReducedMotionIndicator extends QuickSettings.SystemIndicator {
    constructor() {
        super();

        this._indicator = this._addIndicator();
        this._indicator.icon_name = 'preferences-desktop-accessibility-symbolic';

        this._toggle = new ReducedMotionToggle();
        this._indicator.visible = this._toggle.checked;
        this._toggle.connect('notify::checked', () => {
            this._indicator.visible = this._toggle.checked;
        });

        this.quickSettingsItems.push(this._toggle);
    }

    destroy() {
        this.quickSettingsItems.forEach(item => item.destroy());
        this._toggle = null;

        super.destroy();
    }
});

export default class ReducedMotionToggleExtension extends Extension {
    enable() {
        this._indicator = new ReducedMotionIndicator();
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);
    }

    disable() {
        this._indicator.destroy();
        this._indicator = null;
    }
}

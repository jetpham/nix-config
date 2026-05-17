import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';

const EVIL_BIT_CTL = '@evilBitCtl@';
const PKEXEC = '/run/wrappers/bin/pkexec';
const STATE_FILE = '/run/evil-bit-toggle/enabled';
const ICON_NAME = 'dialog-warning-symbolic';

const EvilBitToggle = GObject.registerClass(
class EvilBitToggle extends QuickSettings.QuickToggle {
    constructor() {
        super({
            title: 'Evil Bit',
            subtitle: 'RFC 3514: good',
            iconName: ICON_NAME,
            toggleMode: true,
        });

        this._syncing = false;
        this._pending = false;
        this._destroyed = false;
        this._syncFromState();

        this._checkedId = this.connect('notify::checked', () => {
            if (this._syncing)
                return;

            this._setEvilBit(this.checked);
        });
    }

    _isEnabled() {
        return GLib.file_test(STATE_FILE, GLib.FileTest.EXISTS);
    }

    _syncFromState() {
        this._syncing = true;
        this.checked = this._isEnabled();
        this._syncing = false;
        this._syncSubtitle();
    }

    _setEvilBit(enabled) {
        if (this._pending)
            return;

        this._pending = true;
        this.reactive = false;
        this.subtitle = 'Applying...';

        const action = enabled ? 'enable' : 'disable';
        let proc;

        try {
            proc = Gio.Subprocess.new(
                [PKEXEC, EVIL_BIT_CTL, action],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
            );
        } catch (error) {
            this._finishSetEvilBit(error);
            return;
        }

        proc.communicate_utf8_async(null, null, (subprocess, result) => {
            try {
                const [, , stderr] = subprocess.communicate_utf8_finish(result);

                if (!subprocess.get_successful())
                    throw new Error(stderr.trim() || `evil-bitctl ${action} failed`);

                this._finishSetEvilBit(null);
            } catch (error) {
                this._finishSetEvilBit(error);
            }
        });
    }

    _finishSetEvilBit(error) {
        if (error)
            console.warn(`Unable to toggle Evil Bit: ${error.message}`);

        if (this._destroyed)
            return;

        this._pending = false;
        this.reactive = true;
        this._syncFromState();
    }

    _syncSubtitle() {
        this.subtitle = this.checked ? 'RFC 3514: evil' : 'RFC 3514: good';
    }

    destroy() {
        this._destroyed = true;

        if (this._checkedId) {
            this.disconnect(this._checkedId);
            this._checkedId = null;
        }

        super.destroy();
    }
});

const EvilBitIndicator = GObject.registerClass(
class EvilBitIndicator extends QuickSettings.SystemIndicator {
    constructor() {
        super();

        this._indicator = this._addIndicator();
        this._indicator.icon_name = ICON_NAME;

        this._toggle = new EvilBitToggle();
        this._indicator.visible = this._toggle.checked;
        this._checkedId = this._toggle.connect('notify::checked', () => {
            this._indicator.visible = this._toggle.checked;
        });

        this.quickSettingsItems.push(this._toggle);
    }

    destroy() {
        if (this._checkedId) {
            this._toggle.disconnect(this._checkedId);
            this._checkedId = null;
        }

        this.quickSettingsItems.forEach(item => item.destroy());
        this._toggle = null;

        super.destroy();
    }
});

export default class EvilBitToggleExtension extends Extension {
    enable() {
        this._indicator = new EvilBitIndicator();
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);
    }

    disable() {
        this._indicator.destroy();
        this._indicator = null;
    }
}

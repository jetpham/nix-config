import Clutter from 'gi://Clutter';
import Cogl from 'gi://Cogl';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const COMMAND = '@opencodeTokenUsage@/bin/opencode-token-usage';
const REFRESH_SECONDS = 60;
const GRAPH_WIDTH = 96;
const GRAPH_HEIGHT = 16;
const CLASSES = [
    'opencode-token-usage-normal',
    'opencode-token-usage-warning',
    'opencode-token-usage-critical',
    'opencode-token-usage-missing',
];

function colorFromString(colorString) {
    if (Cogl.Color.from_string) {
        const [ok, color] = Cogl.Color.from_string(colorString);
        if (ok)
            return color;
    }

    return Clutter.Color.from_string(colorString)[1];
}

function setSourceColor(cr, color) {
    if (Clutter.cairo_set_source_color)
        Clutter.cairo_set_source_color(cr, color);
    else
        cr.setSourceColor(color);
}

const TokenUsageGraph = GObject.registerClass(
class TokenUsageGraph extends St.DrawingArea {
    constructor() {
        super({
            style_class: 'opencode-token-usage-graph',
            reactive: false,
        });

        this._values = [];
        this._background = colorFromString('#ffffff16');
        this._fill = colorFromString('#23863699');
        this._line = colorFromString('#58a6ff');
        this._scaleFactor = St.ThemeContext.get_for_stage(global.stage).scale_factor;
        this.set_width(GRAPH_WIDTH * this._scaleFactor);
        this.set_height(GRAPH_HEIGHT * this._scaleFactor);
        this.connect('repaint', this._draw.bind(this));
    }

    setValues(values) {
        this._values = Array.isArray(values) ? values.filter(value => Number.isFinite(value)) : [];
        this.queue_repaint();
    }

    _point(index, width, height, max) {
        const x = this._values.length <= 1 ? width : index * (width / (this._values.length - 1));
        const y = height - 1 - (this._values[index] / max) * Math.max(1, height - 2);
        return [x, y];
    }

    _draw() {
        const [width, height] = this.get_surface_size();
        const cr = this.get_context();

        setSourceColor(cr, this._background);
        cr.rectangle(0, 0, width, height);
        cr.fill();

        if (this._values.length === 0) {
            cr.$dispose();
            return;
        }

        const max = Math.max(1, ...this._values);

        cr.moveTo(0, height);
        for (let index = 0; index < this._values.length; index++) {
            const [x, y] = this._point(index, width, height, max);
            cr.lineTo(x, y);
        }
        cr.lineTo(width, height);
        cr.closePath();
        setSourceColor(cr, this._fill);
        cr.fill();

        const [x0, y0] = this._point(0, width, height, max);
        cr.moveTo(x0, y0);
        for (let index = 1; index < this._values.length; index++) {
            const [x, y] = this._point(index, width, height, max);
            cr.lineTo(x, y);
        }
        cr.setLineWidth(Math.max(1, this._scaleFactor));
        setSourceColor(cr, this._line);
        cr.stroke();
        cr.$dispose();
    }
});

const TokenUsageIndicator = GObject.registerClass(
class TokenUsageIndicator extends PanelMenu.Button {
    constructor() {
        super(0.0, 'OpenCode Token Usage');

        this.add_style_class_name('opencode-token-usage');
        this._prefix = new St.Label({
            text: 'tok',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'opencode-token-usage-label',
        });
        this._graph = new TokenUsageGraph();
        this._value = new St.Label({
            text: '0',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'opencode-token-usage-label',
        });
        this.add_child(this._prefix);
        this.add_child(this._graph);
        this.add_child(this._value);

        this._refresh();
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, REFRESH_SECONDS, () => {
            this._refresh();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _setClass(nextClass) {
        for (const item of CLASSES)
            this.remove_style_class_name(item);

        this.add_style_class_name(`opencode-token-usage-${nextClass || 'normal'}`);
    }

    _applyPayload(payload) {
        this._value.text = payload.value || '0';
        this._graph.setValues(payload.values || []);
        this.menu.removeAll();
        for (const line of (payload.tooltip || 'OpenCode token usage').split('\n')) {
            const item = new PopupMenu.PopupMenuItem(line, {reactive: false, can_focus: false});
            this.menu.addMenuItem(item);
        }
        this._setClass(payload.class || 'normal');
    }

    _refresh() {
        let proc;
        try {
            proc = Gio.Subprocess.new(
                [COMMAND],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
            );
        } catch (error) {
            this._applyPayload({
                text: 'tok error',
                tooltip: `Unable to start token usage command: ${error.message}`,
                class: 'critical',
            });
            return;
        }

        proc.communicate_utf8_async(null, null, (subprocess, result) => {
            try {
                const [, stdout, stderr] = subprocess.communicate_utf8_finish(result);
                if (!subprocess.get_successful())
                    throw new Error(stderr.trim() || `command exited ${subprocess.get_exit_status()}`);

                this._applyPayload(JSON.parse(stdout));
            } catch (error) {
                this._applyPayload({
                    text: 'tok error',
                    tooltip: `Unable to read OpenCode token usage: ${error.message}`,
                    class: 'critical',
                });
            }
        });
    }

    destroy() {
        if (this._timer) {
            GLib.Source.remove(this._timer);
            this._timer = null;
        }

        super.destroy();
    }
});

export default class OpenCodeTokenUsageExtension extends Extension {
    enable() {
        this._indicator = new TokenUsageIndicator();
        Main.panel.addToStatusArea('opencode-token-usage', this._indicator, 0, 'right');
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}

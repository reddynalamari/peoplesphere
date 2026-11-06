import { LightningElement, api } from 'lwc';

const PALETTE = ['#0b5cab', '#1b96ff', '#04844b', '#fe9339', '#ba01ff', '#ea001e', '#3ba755', '#7f8de1'];

/**
 * Lightweight horizontal bar chart. items: [{label, value}].
 * Set suffix="%" for percentages, max="100" to fix the scale, currency for money.
 */
export default class PsBarChart extends LightningElement {
    @api items = [];
    @api suffix = '';
    @api max;
    @api color;
    @api currency = false;
    @api multicolor = false;

    get hasData() {
        return Array.isArray(this.items) && this.items.length > 0;
    }

    get bars() {
        const values = this.items.map((i) => Number(i.value) || 0);
        const max = Number(this.max) || Math.max(1, ...values);
        return this.items.map((item, idx) => {
            const v = Number(item.value) || 0;
            const pct = Math.max(2, Math.round((v / max) * 100));
            const color = this.multicolor ? PALETTE[idx % PALETTE.length] : this.color || PALETTE[0];
            return {
                key: `${item.label}-${idx}`,
                label: item.label,
                display: this.format(v),
                title: `${item.label}: ${this.format(v)}`,
                style: `width:${pct}%;background:${color}`
            };
        });
    }

    format(v) {
        if (this.currency) {
            if (v >= 10000000) return `${(v / 10000000).toFixed(1)} Cr`;
            if (v >= 100000) return `${(v / 100000).toFixed(1)} L`;
            return v.toLocaleString();
        }
        return `${v.toLocaleString()}${this.suffix || ''}`;
    }
}

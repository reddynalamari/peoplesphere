import { LightningElement, api } from 'lwc';

export default class PsKpi extends LightningElement {
    @api label;
    @api value;
    @api suffix = '';
    @api caption;
    @api icon = 'utility:people';
    @api tone = 'blue'; // blue | green | orange | red | purple | teal

    get displayValue() {
        if (this.value === null || this.value === undefined || this.value === '') return '—';
        return `${this.value}${this.suffix || ''}`;
    }

    get tileClass() {
        return `tile tone-${this.tone}`;
    }
}

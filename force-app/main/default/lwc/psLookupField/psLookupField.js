import { LightningElement, api } from 'lwc';
import API from 'c/psRecordApi';

/** Lookup picker: search records of `referenceTo` and pick one. Fires `lookupselect` with { value, label }. */
export default class PsLookupField extends LightningElement {
    @api label;
    @api referenceTo;
    @api required = false;
    @api disabled = false;
    @api value;
    @api selectedLabel;
    term = '';
    results = [];
    timer;

    get hasValue() { return !!this.value; }
    get hasResults() { return this.results.length > 0; }
    get placeholder() { return `Search ${this.referenceTo === 'User' ? 'users' : 'records'}...`; }

    search(e) {
        e.stopPropagation();
        this.term = e.target.value || '';
        clearTimeout(this.timer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.timer = setTimeout(async () => {
            try {
                this.results = await API.searchLookup({ objectApiName: this.referenceTo, term: this.term });
            } catch (err) {
                this.results = [];
            }
        }, 250);
    }

    pick(e) {
        const { value, label } = e.currentTarget.dataset;
        this.results = [];
        this.term = '';
        this.dispatchEvent(new CustomEvent('lookupselect', { detail: { value, label } }));
    }

    clear() {
        this.dispatchEvent(new CustomEvent('lookupselect', { detail: { value: null, label: null } }));
    }
}

import { LightningElement, api } from 'lwc';
import API, { errorMessage } from 'c/psRecordApi';

const TEXT_TYPES = { string: 'text', email: 'email', phone: 'tel', url: 'url', date: 'date', datetime: 'datetime', time: 'time' };
const NUMBER_TYPES = new Set(['double', 'currency', 'percent', 'integer', 'long']);

/**
 * Schema-driven create / edit form for any PeopleSphere object.
 * Fires `saved` ({ id, isNew }) and `close`.
 */
export default class PsRecordForm extends LightningElement {
    @api objectApiName;
    @api recordId;
    @api defaults; // e.g. { Employee__c: 'a0...' } when creating a child record
    schema;
    values = {};
    lookupLabels = {};
    changed = new Set();
    loading = true;
    saving = false;
    error;

    async connectedCallback() {
        try {
            this.schema = await API.describeObject({ objectApiName: this.objectApiName });
            if (this.recordId) {
                const rec = await API.getRecord({ objectApiName: this.objectApiName, recordId: this.recordId });
                this.values = { ...rec.values };
                this.lookupLabels = { ...(rec.lookupLabels || {}) };
            } else {
                const v = {};
                this.schema.fields.forEach((f) => {
                    if (f.defaultValue !== undefined && f.defaultValue !== null) {
                        v[f.name] = f.type === 'boolean' ? f.defaultValue === true || f.defaultValue === 'true' : f.defaultValue;
                        this.changed.add(f.name);
                    }
                });
                Object.keys(this.defaults || {}).forEach((k) => {
                    v[k] = this.defaults[k];
                    this.changed.add(k);
                });
                this.values = v;
            }
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    get isNew() { return !this.recordId; }
    get title() {
        const label = this.schema ? this.schema.label : '';
        return this.isNew ? `New ${label}` : `Edit ${label}`;
    }

    get fieldViews() {
        if (!this.schema) return [];
        return this.schema.fields.map((f) => {
            const disabled = this.isNew ? !f.createable : !f.updateable;
            const isLookup = f.type === 'reference';
            const isTextarea = f.type === 'textarea';
            const isPicklist = f.type === 'picklist' || f.type === 'multipicklist';
            const isBoolean = f.type === 'boolean';
            const isNumber = NUMBER_TYPES.has(f.type);
            const isText = !isLookup && !isTextarea && !isPicklist && !isBoolean && !isNumber;
            let value = this.values[f.name];
            if (f.type === 'date' && value) value = String(value).slice(0, 10);
            return {
                ...f,
                value,
                disabled,
                isLookup, isTextarea, isPicklist, isBoolean, isNumber, isText,
                inputType: TEXT_TYPES[f.type] || 'text',
                options: f.options ? [{ label: '--None--', value: '' }, ...f.options] : [],
                lookupLabel: this.lookupLabels[f.name] || value,
                cellCls: isTextarea ? 'cell wide' : 'cell'
            };
        });
    }

    handleChange(e) {
        this.setValue(e.target.dataset.name, e.detail.value);
    }
    handleCheckbox(e) {
        this.setValue(e.target.dataset.name, e.target.checked);
    }
    handleLookup(e) {
        const name = e.target.dataset.name;
        this.lookupLabels = { ...this.lookupLabels, [name]: e.detail.label };
        this.setValue(name, e.detail.value);
    }
    setValue(name, value) {
        this.values = { ...this.values, [name]: value };
        this.changed.add(name);
    }

    async save() {
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-textarea, lightning-combobox')];
        const valid = inputs.reduce((ok, el) => (el.reportValidity ? el.reportValidity() && ok : ok), true);
        const missingLookup = this.fieldViews.find((f) => f.isLookup && f.required && !f.disabled && !this.values[f.name]);
        if (!valid || missingLookup) {
            this.error = missingLookup ? `${missingLookup.label} is required.` : 'Please fix the highlighted fields.';
            return;
        }
        const payload = {};
        this.changed.forEach((name) => {
            const f = this.schema.fields.find((x) => x.name === name);
            if (f && (this.isNew ? f.createable : f.updateable)) payload[name] = this.values[name] === undefined ? null : this.values[name];
        });
        this.saving = true;
        this.error = undefined;
        try {
            const id = await API.saveRecord({ objectApiName: this.objectApiName, recordId: this.recordId || null, valuesJson: JSON.stringify(payload) });
            this.dispatchEvent(new CustomEvent('saved', { detail: { id, isNew: this.isNew } }));
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.saving = false;
        }
    }

    close() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}

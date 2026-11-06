import { LightningElement, api } from 'lwc';
import API, { errorMessage } from 'c/psRecordApi';

/**
 * Record detail with every field and related lists.
 * Fires: edit {objectApiName, recordId}, deleted, close, back,
 *        navigate {objectApiName, recordId}, newchild {objectApiName, field, parentId}.
 */
export default class PsRecordView extends LightningElement {
    @api canGoBack = false;
    _objectApiName;
    _recordId;
    data;
    loading = true;
    error;
    confirming = false;

    @api
    get objectApiName() { return this._objectApiName; }
    set objectApiName(v) { this._objectApiName = v; }

    @api
    get recordId() { return this._recordId; }
    set recordId(v) {
        const changed = v !== this._recordId;
        this._recordId = v;
        if (changed && this._connected) this.load();
    }

    connectedCallback() {
        this._connected = true;
        this.load();
    }

    @api
    async load() {
        this.loading = true;
        this.error = undefined;
        this.confirming = false;
        try {
            this.data = await API.getRecord({ objectApiName: this._objectApiName, recordId: this._recordId });
        } catch (e) {
            this.data = undefined;
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    get objectLabel() { return this.data ? this.data.objectLabel : ''; }
    get recordName() { return this.data ? this.data.name : ''; }
    get fields() {
        return ((this.data && this.data.fields) || []).map((f) => ({
            ...f,
            display: f.value === '' || f.value === null || f.value === undefined ? '—' : f.value,
            cls: f.long ? 'field wide' : 'field'
        }));
    }
    get related() {
        return ((this.data && this.data.related) || []).map((r, i) => ({ ...r, key: `${r.objectApiName}-${r.field}-${i}`, empty: r.count === 0 }));
    }

    edit() {
        this.dispatchEvent(new CustomEvent('edit', { detail: { objectApiName: this._objectApiName, recordId: this._recordId } }));
    }
    askDelete() { this.confirming = true; }
    cancelDelete() { this.confirming = false; }
    async confirmDelete() {
        try {
            await API.deleteRecord({ objectApiName: this._objectApiName, recordId: this._recordId });
            this.dispatchEvent(new CustomEvent('deleted', { detail: { objectApiName: this._objectApiName, recordId: this._recordId } }));
        } catch (e) {
            this.confirming = false;
            this.error = errorMessage(e);
        }
    }
    openLink(e) {
        const { id, object } = e.currentTarget.dataset;
        this.dispatchEvent(new CustomEvent('navigate', { detail: { objectApiName: object, recordId: id } }));
    }
    newChild(e) {
        const { object, field } = e.currentTarget.dataset;
        this.dispatchEvent(new CustomEvent('newchild', { detail: { objectApiName: object, field, parentId: this._recordId } }));
    }
    back() { this.dispatchEvent(new CustomEvent('back')); }
    close() { this.dispatchEvent(new CustomEvent('close')); }
}

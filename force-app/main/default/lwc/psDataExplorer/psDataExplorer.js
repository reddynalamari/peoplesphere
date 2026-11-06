import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import isGuest from '@salesforce/user/isGuest';
import getObjects from '@salesforce/apex/PS_DataExplorerController.getObjects';
import getRecords from '@salesforce/apex/PS_DataExplorerController.getRecords';
import hr_getObjects_raw from '@salesforce/apex/PS_GuestHrGateway.getObjects';
import hr_getRecords_raw from '@salesforce/apex/PS_GuestHrGateway.getRecords';
import { withToken } from 'c/psHrAuth';
import RECORD_API, { errorMessage } from 'c/psRecordApi';

// Password-protected HR demo: every gateway call carries the session token.
const hr_getObjects = withToken(hr_getObjects_raw);
const hr_getRecords = withToken(hr_getRecords_raw);

const API = isGuest ? { getObjects: hr_getObjects, getRecords: hr_getRecords } : { getObjects, getRecords };
const ROW_ACTIONS = [
    { label: 'View', name: 'view', iconName: 'utility:preview' },
    { label: 'Edit', name: 'edit', iconName: 'utility:edit' },
    { label: 'Delete', name: 'delete', iconName: 'utility:delete' }
];

/** Browse, create, view, edit and delete every PeopleSphere record from one screen. */
export default class PsDataExplorer extends LightningElement {
    objectList = [];
    selected = 'Employee__c';
    result = {};
    term = '';
    loading = false;
    timer;
    view;        // { objectApiName, recordId }
    form;        // { objectApiName, recordId, defaults }
    history = []; // record views visited, for "Back"

    async connectedCallback() {
        await this.loadObjects();
        this.load();
    }

    async loadObjects() {
        try {
            this.objectList = await API.getObjects();
        } catch (e) {
            this.objectList = [];
        }
    }

    async load() {
        this.loading = true;
        try {
            this.result = await API.getRecords({ objectApiName: this.selected, term: this.term });
        } catch (e) {
            this.result = { columns: [], rows: [], label: errorMessage(e) };
        } finally {
            this.loading = false;
        }
    }

    get objects() {
        return this.objectList.map((o) => ({ ...o, cls: o.value === this.selected ? 'sel' : '' }));
    }
    get title() { return this.result.label || ''; }
    get rows() { return this.result.rows || []; }
    get tableColumns() {
        const cols = this.result.columns || [];
        return [...cols, { type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }];
    }
    get canGoBack() { return this.history.length > 0; }

    pick(e) {
        this.selected = e.currentTarget.dataset.api;
        this.term = '';
        this.load();
    }
    search(e) {
        this.term = e.detail.value;
        clearTimeout(this.timer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.timer = setTimeout(() => this.load(), 350);
    }
    refresh() {
        this.loadObjects();
        this.load();
    }

    // ---------------- actions ----------------------------------------------
    newRecord() {
        this.form = { objectApiName: this.selected, recordId: null, defaults: {} };
    }

    async rowAction(e) {
        const action = e.detail.action.name;
        const row = e.detail.row;
        if (action === 'view') {
            this.history = [];
            this.view = { objectApiName: this.selected, recordId: row.Id };
        } else if (action === 'edit') {
            this.form = { objectApiName: this.selected, recordId: row.Id, defaults: {} };
        } else if (action === 'delete') {
            // eslint-disable-next-line no-alert
            if (!window.confirm(`Delete "${row.Name}"? This cannot be undone from here.`)) return;
            try {
                await RECORD_API.deleteRecord({ objectApiName: this.selected, recordId: row.Id });
                this.toast('Deleted', `${row.Name} was deleted.`, 'success');
                this.refresh();
            } catch (err) {
                this.toast('Could not delete', errorMessage(err), 'error');
            }
        }
    }

    editFromView(e) {
        this.form = { objectApiName: e.detail.objectApiName, recordId: e.detail.recordId, defaults: {} };
    }
    navigate(e) {
        if (this.view) this.history = [...this.history, this.view];
        this.view = { objectApiName: e.detail.objectApiName, recordId: e.detail.recordId };
    }
    back() {
        const prev = this.history[this.history.length - 1];
        this.history = this.history.slice(0, -1);
        this.view = prev;
    }
    newChild(e) {
        this.form = { objectApiName: e.detail.objectApiName, recordId: null, defaults: { [e.detail.field]: e.detail.parentId } };
    }
    deleted() {
        this.toast('Deleted', 'Record deleted.', 'success');
        this.view = this.history.length ? this.history[this.history.length - 1] : null;
        this.history = this.history.slice(0, -1);
        this.refresh();
    }
    closeView() {
        this.view = null;
        this.history = [];
    }

    saved(e) {
        const { id, isNew } = e.detail;
        const objectApiName = this.form.objectApiName;
        this.form = null;
        this.toast('Saved', isNew ? 'Record created. Automation has run (IDs, tasks, notifications).' : 'Changes saved.', 'success');
        this.refresh();
        if (this.view) {
            const v = this.view;
            this.view = null;
            // re-open to refresh the detail (and show the new child in related lists)
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            Promise.resolve().then(() => { this.view = v; });
        } else if (isNew) {
            this.view = { objectApiName, recordId: id };
        }
    }
    closeForm() {
        this.form = null;
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

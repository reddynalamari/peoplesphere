import { LightningElement } from 'lwc';
import isGuest from '@salesforce/user/isGuest';
import getObjects from '@salesforce/apex/PS_DataExplorerController.getObjects';
import getRecords from '@salesforce/apex/PS_DataExplorerController.getRecords';
import hr_getObjects_raw from '@salesforce/apex/PS_GuestHrGateway.getObjects';
import hr_getRecords_raw from '@salesforce/apex/PS_GuestHrGateway.getRecords';
import { withToken } from 'c/psHrAuth';

// Password-protected HR demo: every gateway call carries the session token.
const hr_getObjects = withToken(hr_getObjects_raw);
const hr_getRecords = withToken(hr_getRecords_raw);

const API = isGuest ? { getObjects: hr_getObjects, getRecords: hr_getRecords } : { getObjects, getRecords };

/** Browse every PeopleSphere object from one screen. */
export default class PsDataExplorer extends LightningElement {
    objectList = [];
    selected = 'Employee__c';
    result = {};
    term = '';
    loading = false;
    timer;

    async connectedCallback() {
        try {
            this.objectList = await API.getObjects();
        } catch (e) {
            this.objectList = [];
        }
        this.load();
    }

    async load() {
        this.loading = true;
        try {
            this.result = await API.getRecords({ objectApiName: this.selected, term: this.term });
        } catch (e) {
            this.result = { columns: [], rows: [], label: (e && e.body && e.body.message) || 'Error' };
        } finally {
            this.loading = false;
        }
    }

    get objects() {
        return this.objectList.map((o) => ({ ...o, cls: o.value === this.selected ? 'sel' : '' }));
    }
    get title() { return this.result.label || ''; }
    get columns() { return this.result.columns || []; }
    get rows() { return this.result.rows || []; }

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
}

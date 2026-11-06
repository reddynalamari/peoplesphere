import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getOrgTree from '@salesforce/apex/PS_OrgChartController.getOrgTree';
import isGuest from '@salesforce/user/isGuest';
import gw_getOrgTree from '@salesforce/apex/PS_GuestGateway.getOrgTree';

// Site guests (public demo) go through the locked-down PS_GuestGateway.
const API = isGuest
    ? { getOrgTree: gw_getOrgTree }
    : { getOrgTree };

export default class PsOrgChart extends NavigationMixin(LightningElement) {
    data = {};
    departmentId = '';
    loading = true;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        try {
            this.data = await API.getOrgTree({ departmentId: this.departmentId || null });
        } finally {
            this.loading = false;
        }
    }

    get items() { return this.data.items || []; }
    get hasItems() { return this.items.length > 0; }
    get total() { return this.data.total || 0; }
    get managers() { return this.data.managers || 0; }
    get maxSpan() { return this.data.maxSpan || 0; }
    get departmentOptions() {
        return [{ label: 'All departments', value: '' }, ...(this.data.departments || [])];
    }

    handleDept(e) {
        this.departmentId = e.detail.value;
        this.load();
    }

    handleSelect(e) {
        if (isGuest) return;
        this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: e.detail.name, actionName: 'view' } });
    }
}

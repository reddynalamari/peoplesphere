import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getEmployee360 from '@salesforce/apex/PS_Employee360Controller.getEmployee360';
import searchEmployees from '@salesforce/apex/PS_Employee360Controller.searchEmployees';
import isGuest from '@salesforce/user/isGuest';
import hr_getEmployee360_raw from '@salesforce/apex/PS_GuestHrGateway.getEmployee360';
import hr_searchEmployees_raw from '@salesforce/apex/PS_GuestHrGateway.searchEmployees';

import gw_getEmployee360 from '@salesforce/apex/PS_GuestGateway.getEmployee360';
import gw_searchEmployees from '@salesforce/apex/PS_GuestGateway.searchEmployees';
import { withToken } from 'c/psHrAuth';

// Password-protected HR demo: every gateway call carries the session token.
const hr_getEmployee360 = withToken(hr_getEmployee360_raw);
const hr_searchEmployees = withToken(hr_searchEmployees_raw);

// Site guests (public demo) go through the locked-down PS_GuestGateway.
const API = isGuest
    ? { getEmployee360: gw_getEmployee360, searchEmployees: gw_searchEmployees }
    : { getEmployee360, searchEmployees };

const STAGE_ICON = { complete: 'utility:check', current: 'utility:record', upcoming: 'utility:clock' };
const RISK_ICON = { error: 'utility:error', warning: 'utility:warning', info: 'utility:info' };

const HR_API = { getEmployee360: hr_getEmployee360, searchEmployees: hr_searchEmployees };

export default class PsEmployee360 extends NavigationMixin(LightningElement) {
    @api recordId;
    @api hrMode = false;
    selectedId;
    d;
    error;
    loading = false;
    term = '';
    results = [];
    searchTimer;

    enrollmentCols = [
        { label: 'Course', fieldName: 'course' },
        { label: 'Category', fieldName: 'category' },
        { label: 'Status', fieldName: 'Status__c' },
        { label: 'Progress', fieldName: 'progress', type: 'percent' },
        { label: 'Due', fieldName: 'Due_Date__c', type: 'date-local' },
        { label: 'Score', fieldName: 'Score__c', type: 'number' },
        { label: 'Source', fieldName: 'Assignment_Source__c' }
    ];
    certCols = [
        { label: 'Certification', fieldName: 'Name' },
        { label: 'Issued', fieldName: 'Issued_On__c', type: 'date-local' },
        { label: 'Expires', fieldName: 'Expires_On__c', type: 'date-local' },
        { label: 'Status', fieldName: 'Status__c' }
    ];
    reviewCols = [
        { label: 'Review', fieldName: 'cycle' },
        { label: 'Status', fieldName: 'Status__c' },
        { label: 'Self', fieldName: 'Self_Rating__c', type: 'number' },
        { label: 'Manager', fieldName: 'Manager_Rating__c', type: 'number' },
        { label: 'Final', fieldName: 'Final_Rating__c', type: 'number' },
        { label: 'Reviewer', fieldName: 'reviewer' },
        { label: 'Due', fieldName: 'Due_Date__c', type: 'date-local' }
    ];
    goalCols = [
        { label: 'Goal', fieldName: 'Name' },
        { label: 'Type', fieldName: 'Goal_Type__c' },
        { label: 'Aligned to', fieldName: 'parent' },
        { label: 'Status', fieldName: 'Status__c' },
        { label: 'Progress', fieldName: 'progress', type: 'percent' },
        { label: 'Due', fieldName: 'Due_Date__c', type: 'date-local' }
    ];
    docCols = [
        { label: 'Document', fieldName: 'Name' },
        { label: 'Type', fieldName: 'Document_Type__c' },
        { label: 'Status', fieldName: 'Verification_Status__c' },
        { label: 'Expiry', fieldName: 'Expiry_Date__c', type: 'date-local' },
        { label: 'Mandatory', fieldName: 'Mandatory__c', type: 'boolean' }
    ];
    assetCols = [
        { label: 'Asset', fieldName: 'Name' },
        { label: 'Tag', fieldName: 'Asset_Tag__c' },
        { label: 'Type', fieldName: 'Asset_Type__c' },
        { label: 'Assigned', fieldName: 'Assigned_On__c', type: 'date-local' }
    ];
    leaveCols = [
        { label: 'Request', fieldName: 'Name' },
        { label: 'Type', fieldName: 'Leave_Type__c' },
        { label: 'From', fieldName: 'Start_Date__c', type: 'date-local' },
        { label: 'To', fieldName: 'End_Date__c', type: 'date-local' },
        { label: 'Days', fieldName: 'Number_of_Days__c', type: 'number' },
        { label: 'Status', fieldName: 'Status__c' }
    ];

    connectedCallback() {
        this.load(this.recordId || null);
    }

    async load(id) {
        this.loading = true;
        try {
            this.d = await this.api.getEmployee360({ employeeId: id });
            this.error = undefined;
        } catch (e) {
            this.d = undefined;
            this.error = (e && e.body && e.body.message) || 'Could not load the profile.';
        } finally {
            this.loading = false;
        }
    }

    handleSearch(event) {
        this.term = event.target.value;
        clearTimeout(this.searchTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchTimer = setTimeout(async () => {
            try {
                const rows = await this.api.searchEmployees({ term: this.term });
                this.results = rows.map((r) => ({ ...r, initials: initialsOf(r.name) }));
            } catch (e) {
                this.results = [];
            }
        }, 300);
    }

    pick(event) {
        this.selectedId = event.currentTarget.dataset.id;
        this.results = [];
        this.term = '';
        this.load(this.selectedId);
    }

    openEmployee(event) {
        const id = event.currentTarget.dataset.id;
        if (this.recordId) {
            this.navigate(id);
        } else {
            this.load(id);
        }
    }

    openSelf() {
        this.navigate(this.emp.id);
    }

    navigate(id) {
        this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: id, actionName: 'view' } });
    }

    get showOpen() { return !isGuest; }
    get api() {
        return isGuest && this.hrMode ? HR_API : API;
    }
    get ctc() {
        return this.emp.ctc != null ? Number(this.emp.ctc).toLocaleString() : null;
    }
    get hasResults() {
        return this.results.length > 0;
    }
    get notLinked() {
        return !this.loading && !this.d && !this.error && !this.recordId;
    }
    get emp() {
        return (this.d && this.d.employee) || {};
    }
    get initials() {
        return initialsOf(this.emp.name);
    }
    get tenure() {
        return this.emp.tenure != null ? Number(this.emp.tenure).toFixed(1) : '0';
    }
    get rating() {
        return this.emp.rating != null ? this.emp.rating : '—';
    }
    get points() {
        return this.emp.points || 0;
    }
    get aspiration() {
        return this.emp.aspiration || 'Not captured yet';
    }
    get succession() {
        return this.emp.succession || 'Not identified';
    }
    get critical() {
        return this.emp.critical ? 'Yes' : 'No';
    }
    get statusClass() {
        const s = (this.emp.status || '').toLowerCase().replace(/[^a-z]/g, '');
        return `status s-${s}`;
    }
    get lifecycle() {
        return ((this.d && this.d.lifecycle) || []).map((s) => ({ ...s, cls: `step ${s.state}`, icon: STAGE_ICON[s.state] }));
    }
    get risks() {
        return ((this.d && this.d.risks) || []).map((r) => ({ ...r, cls: `risk ${r.level}`, icon: RISK_ICON[r.level] }));
    }
    get timeline() {
        return ((this.d && this.d.timeline) || []).map((t, i) => ({ ...t, key: `tl-${i}` }));
    }
    get hasRisks() {
        return this.risks.length > 0;
    }
    get skills() {
        return ((this.d && this.d.skills) || []).map((s) => ({ ...s, cls: s.gap ? 'chip gap' : 'chip' }));
    }
    get hasReports() {
        return this.d && this.d.directReports && this.d.directReports.length > 0;
    }
    get reportCount() {
        return this.hasReports ? this.d.directReports.length : 0;
    }
    get enrollments() {
        return ((this.d && this.d.enrollments) || []).map((e) => ({
            ...e,
            course: e.Course__r ? e.Course__r.Name : '',
            category: e.Course__r ? e.Course__r.Category__c : '',
            progress: (e.Progress_Percent__c || 0) / 100
        }));
    }
    get reviews() {
        return ((this.d && this.d.reviews) || []).map((r) => ({
            ...r,
            cycle: `${r.Review_Cycle__c} ${r.Review_Year__c || ''}`,
            reviewer: r.Reviewer__r ? r.Reviewer__r.Name : ''
        }));
    }
    get goals() {
        return ((this.d && this.d.goals) || []).map((g) => ({
            ...g,
            parent: g.Parent_Goal__r ? g.Parent_Goal__r.Name : '',
            progress: (g.Progress__c || 0) / 100
        }));
    }
}

function initialsOf(name) {
    if (!name) return '';
    return name
        .split(' ')
        .filter((p) => p)
        .slice(0, 2)
        .map((p) => p[0].toUpperCase())
        .join('');
}

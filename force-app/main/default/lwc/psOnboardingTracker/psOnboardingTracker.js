import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOnboarding from '@salesforce/apex/PS_OnboardingController.getOnboarding';
import setTaskStatus from '@salesforce/apex/PS_OnboardingController.setTaskStatus';
import verifyDocument from '@salesforce/apex/PS_OnboardingController.verifyDocument';
import isGuest from '@salesforce/user/isGuest';
import hr_getOnboarding_raw from '@salesforce/apex/PS_GuestHrGateway.getOnboarding';
import hr_setTaskStatus_raw from '@salesforce/apex/PS_GuestHrGateway.setTaskStatus';
import hr_verifyDocument_raw from '@salesforce/apex/PS_GuestHrGateway.verifyDocument';
import { withToken } from 'c/psHrAuth';

// Password-protected HR demo: every gateway call carries the session token.
const hr_getOnboarding = withToken(hr_getOnboarding_raw);
const hr_setTaskStatus = withToken(hr_setTaskStatus_raw);
const hr_verifyDocument = withToken(hr_verifyDocument_raw);

const API = isGuest
    ? { getOnboarding: hr_getOnboarding, setTaskStatus: hr_setTaskStatus, verifyDocument: hr_verifyDocument }
    : { getOnboarding, setTaskStatus, verifyDocument };

const DOC_TONE = { Verified: 'green', Rejected: 'red', Expired: 'red', Uploaded: 'blue' };

export default class PsOnboardingTracker extends LightningElement {
    _recordId;
    data;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        const changed = value !== this._recordId;
        this._recordId = value;
        if (changed && this.connected) this.load();
    }
    loading = true;

    connectedCallback() {
        this.connected = true;
        this.load();
    }

    load = async () => {
        this.loading = true;
        try {
            this.data = await API.getOnboarding({ recordId: this.recordId });
        } catch (e) {
            this.toast('Error', (e && e.body && e.body.message) || 'Could not load onboarding.', 'error');
        } finally {
            this.loading = false;
        }
    };

    get onb() { return this.data ? this.data.onboarding : null; }
    get empty() { return !this.loading && !this.data; }
    get percent() { return this.onb ? Math.round(this.onb.Completion_Percent__c || 0) : 0; }
    get ringStyle() {
        const deg = Math.round(this.percent * 3.6);
        return `background: conic-gradient(#2e844a ${deg}deg, #e5e8ee ${deg}deg)`;
    }
    get templateName() { return this.onb && this.onb.Checklist_Template__r ? this.onb.Checklist_Template__r.Name : 'Default'; }
    get teams() {
        return ((this.data && this.data.teams) || []).map((t) => ({
            ...t,
            rows: t.tasks.map((task) => ({
                ...task,
                done: task.Status__c === 'Completed',
                owner: task.Assigned_To__r ? task.Assigned_To__r.Name : 'Unassigned',
                cls: task.Status__c === 'Completed' ? 'task done' : task.Is_Overdue__c ? 'task late' : 'task'
            }))
        }));
    }
    get docs() {
        const canManage = this.data && this.data.canManage;
        return ((this.data && this.data.documents) || []).map((d) => ({
            ...d,
            cls: `pill ${DOC_TONE[d.Verification_Status__c] || ''}`,
            canVerify: canManage && d.Verification_Status__c !== 'Verified'
        }));
    }

    async toggle(e) {
        try {
            await API.setTaskStatus({ taskId: e.target.dataset.id, status: e.target.checked ? 'Completed' : 'In Progress' });
            await this.load();
        } catch (err) {
            this.toast('Error', (err && err.body && err.body.message) || 'Update failed', 'error');
        }
    }

    async verify(e) {
        const approve = e.currentTarget.dataset.approve === 'true';
        try {
            await API.verifyDocument({ documentId: e.currentTarget.dataset.id, approve, reason: approve ? null : 'Please re-upload a clear copy.' });
            this.toast('Saved', approve ? 'Document verified.' : 'Document rejected.', 'success');
            await this.load();
        } catch (err) {
            this.toast('Error', (err && err.body && err.body.message) || 'Update failed', 'error');
        }
    }

    toast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
}

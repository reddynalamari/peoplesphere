import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import isGuest from '@salesforce/user/isGuest';
import getTickets from '@salesforce/apex/PS_HrOpsController.getTickets';
import updateTicket from '@salesforce/apex/PS_HrOpsController.updateTicket';
import runEscalation from '@salesforce/apex/PS_HrOpsController.runEscalation';
import hr_getTickets_raw from '@salesforce/apex/PS_GuestHrGateway.getTickets';
import hr_updateTicket_raw from '@salesforce/apex/PS_GuestHrGateway.updateTicket';
import hr_runEscalation_raw from '@salesforce/apex/PS_GuestHrGateway.runEscalation';
import { withToken } from 'c/psHrAuth';

// Password-protected HR demo: every gateway call carries the session token.
const hr_getTickets = withToken(hr_getTickets_raw);
const hr_updateTicket = withToken(hr_updateTicket_raw);
const hr_runEscalation = withToken(hr_runEscalation_raw);

const API = isGuest
    ? { getTickets: hr_getTickets, updateTicket: hr_updateTicket, runEscalation: hr_runEscalation }
    : { getTickets, updateTicket, runEscalation };
const opts = (v) => v.map((x) => ({ label: x, value: x }));
const PRIO = { Critical: 'p crit', High: 'p high', Medium: 'p med', Low: 'p low' };

/** HR service desk: queues, SLA status, triage details and resolution. */
export default class PsServiceDesk extends LightningElement {
    view = 'open';
    data = {};
    selectedId;
    edit = {};
    loading = true;
    views = [
        { label: 'Open', value: 'open' }, { label: 'SLA breached', value: 'breached' }, { label: 'Assigned to me', value: 'mine' },
        { label: 'Resolved', value: 'closed' }, { label: 'All', value: 'all' }
    ];
    statusOptions = opts(['New', 'In Progress', 'Waiting on Employee', 'Escalated', 'Resolved', 'Closed']);
    priorityOptions = opts(['Low', 'Medium', 'High', 'Critical']);

    connectedCallback() { this.load(); }

    async load() {
        this.loading = true;
        try {
            this.data = await API.getTickets({ view: this.view });
        } catch (e) {
            this.toast('Error', this.msg(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    get counts() { return this.data.counts || {}; }
    get tickets() {
        return (this.data.tickets || []).map((t) => ({
            ...t,
            employee: t.Employee__r ? t.Employee__r.Name : 'Unknown',
            breached: t.SLA_Breached__c,
            prioCls: PRIO[t.Priority__c] || 'p',
            cls: `ticket ${t.Id === this.selectedId ? 'sel' : ''}`
        }));
    }
    get hasTickets() { return this.tickets.length > 0; }
    get current() {
        const t = this.tickets.find((x) => x.Id === this.selectedId);
        if (!t) return null;
        return { ...t, assignee: t.Assigned_To__r ? t.Assigned_To__r.Name : 'Unassigned', policy: t.Related_Policy__r ? t.Related_Policy__r.Name : null };
    }

    changeView(e) { this.view = e.detail.value; this.selectedId = null; this.load(); }
    select(e) {
        this.selectedId = e.currentTarget.dataset.id;
        const t = this.current;
        this.edit = { status: t.Status__c, priority: t.Priority__c, resolution: t.Resolution__c || '' };
    }
    handleEdit(e) { this.edit = { ...this.edit, [e.target.dataset.field]: e.detail.value }; }

    async save() {
        try {
            await API.updateTicket({ ticketId: this.selectedId, status: this.edit.status, priority: this.edit.priority, resolution: this.edit.resolution });
            this.toast('Saved', 'Ticket updated. The employee is notified when it is resolved.', 'success');
            await this.load();
        } catch (e) {
            this.toast('Could not save', this.msg(e), 'error');
        }
    }

    async escalate() {
        try {
            const n = await API.runEscalation();
            this.toast('Escalation run', `${n} ticket(s) escalated.`, 'success');
            await this.load();
        } catch (e) {
            this.toast('Error', this.msg(e), 'error');
        }
    }

    msg(e) { return (e && e.body && e.body.message) || 'Unexpected error'; }
    toast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
}

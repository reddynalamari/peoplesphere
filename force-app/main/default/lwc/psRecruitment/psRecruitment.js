import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import isGuest from '@salesforce/user/isGuest';
import getPipeline from '@salesforce/apex/PS_HrOpsController.getPipeline';
import moveCandidate from '@salesforce/apex/PS_HrOpsController.moveCandidate';
import setRequisitionStatus from '@salesforce/apex/PS_HrOpsController.setRequisitionStatus';
import hr_getPipeline_raw from '@salesforce/apex/PS_GuestHrGateway.getPipeline';
import hr_moveCandidate_raw from '@salesforce/apex/PS_GuestHrGateway.moveCandidate';
import hr_setRequisitionStatus_raw from '@salesforce/apex/PS_GuestHrGateway.setRequisitionStatus';
import { withToken } from 'c/psHrAuth';

// Password-protected HR demo: every gateway call carries the session token.
const hr_getPipeline = withToken(hr_getPipeline_raw);
const hr_moveCandidate = withToken(hr_moveCandidate_raw);
const hr_setRequisitionStatus = withToken(hr_setRequisitionStatus_raw);

const API = isGuest
    ? { getPipeline: hr_getPipeline, moveCandidate: hr_moveCandidate, setRequisitionStatus: hr_setRequisitionStatus }
    : { getPipeline, moveCandidate, setRequisitionStatus };
const STAGES = ['Applied', 'Screening', 'Interview', 'Offer', 'Offer Accepted', 'Hired'];
const STATUS_TONE = { Open: 'green', 'Pending Approval': 'orange', Filled: 'blue', 'On Hold': 'grey', Draft: 'grey' };

/** Recruitment board: move candidates through stages. "Hire" creates the employee and starts onboarding. */
export default class PsRecruitment extends LightningElement {
    data = {};
    loading = true;
    hiredBanner;

    connectedCallback() { this.load(); }

    async load() {
        this.loading = true;
        try {
            this.data = await API.getPipeline();
        } catch (e) {
            this.toast('Error', this.msg(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    get reqs() {
        return (this.data.requisitions || []).map((r) => ({
            ...r,
            statusCls: `pill ${STATUS_TONE[r.status] || ''}`,
            pending: r.status === 'Pending Approval' || r.status === 'Draft',
            filledLabel: `${r.filled || 0}/${r.openings || 0} filled`,
            columns: r.columns.map((col) => ({
                ...col,
                cards: col.candidates.map((c) => {
                    const idx = STAGES.indexOf(c.Stage__c);
                    const next = STAGES[Math.min(idx + 1, STAGES.length - 1)];
                    const bits = [];
                    if (c.Source__c) bits.push(c.Source__c);
                    if (c.Match_Score__c != null) bits.push(`${c.Match_Score__c}% match`);
                    if (c.Overall_Rating__c != null) bits.push(`★ ${c.Overall_Rating__c}`);
                    if (c.Experience_Years__c != null) bits.push(`${c.Experience_Years__c} yrs`);
                    return {
                        ...c,
                        meta: bits.join(' · '),
                        next,
                        nextLabel: next === 'Hired' ? 'Hire' : `→ ${next}`,
                        isHired: c.Stage__c === 'Hired',
                        hiredAs: c.Converted_Employee__r ? c.Converted_Employee__r.Name : null
                    };
                })
            }))
        }));
    }
    get hasReqs() { return this.reqs.length > 0; }

    async move(e) {
        const { id, stage } = e.currentTarget.dataset;
        try {
            const res = await API.moveCandidate({ candidateId: id, stage });
            if (stage === 'Hired' && res && res.employeeId) {
                this.hiredBanner = `${res.employeeName} hired as employee ${res.employeeNumber}. Their onboarding checklist, documents and mandatory training were created automatically.`;
            }
            this.toast('Updated', stage === 'Rejected' ? 'Candidate rejected.' : `Moved to ${stage}.`, 'success');
            await this.load();
        } catch (err) {
            this.toast('Could not move candidate', this.msg(err), 'error');
        }
    }

    async approve(e) {
        try {
            await API.setRequisitionStatus({ requisitionId: e.currentTarget.dataset.id, status: 'Open' });
            this.toast('Approved', 'Requisition is now open and posted.', 'success');
            await this.load();
        } catch (err) {
            this.toast('Error', this.msg(err), 'error');
        }
    }

    msg(e) { return (e && e.body && e.body.message) || 'Unexpected error'; }
    toast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
}

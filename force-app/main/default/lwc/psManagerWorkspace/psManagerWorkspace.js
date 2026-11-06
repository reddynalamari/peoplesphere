import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTeamOverview from '@salesforce/apex/PS_ManagerController.getTeamOverview';
import decideLeave from '@salesforce/apex/PS_ManagerController.decideLeave';
import decideExpense from '@salesforce/apex/PS_ManagerController.decideExpense';
import submitManagerReview from '@salesforce/apex/PS_ManagerController.submitManagerReview';
import updateTaskStatus from '@salesforce/apex/PS_PortalController.updateTaskStatus';
import giveRecognition from '@salesforce/apex/PS_PortalController.giveRecognition';
import getHrOverview from '@salesforce/apex/PS_ManagerController.getHrOverview';
import isGuest from '@salesforce/user/isGuest';
import hr_getHrOverview_raw from '@salesforce/apex/PS_GuestHrGateway.getHrOverview';
import hr_decideLeave_raw from '@salesforce/apex/PS_GuestHrGateway.decideLeave';
import hr_decideExpense_raw from '@salesforce/apex/PS_GuestHrGateway.decideExpense';
import hr_submitManagerReview_raw from '@salesforce/apex/PS_GuestHrGateway.submitManagerReview';
import hr_updateTaskStatus_raw from '@salesforce/apex/PS_GuestHrGateway.updateTaskStatus';
import hr_giveRecognition_raw from '@salesforce/apex/PS_GuestHrGateway.giveRecognition';
import { withToken } from 'c/psHrAuth';

// Password-protected HR demo: every gateway call carries the session token.
const hr_getHrOverview = withToken(hr_getHrOverview_raw);
const hr_decideLeave = withToken(hr_decideLeave_raw);
const hr_decideExpense = withToken(hr_decideExpense_raw);
const hr_submitManagerReview = withToken(hr_submitManagerReview_raw);
const hr_updateTaskStatus = withToken(hr_updateTaskStatus_raw);
const hr_giveRecognition = withToken(hr_giveRecognition_raw);

const NORMAL = { getTeamOverview, getHrOverview, decideLeave, decideExpense, submitManagerReview, updateTaskStatus, giveRecognition };
const HR_GUEST = { getTeamOverview: hr_getHrOverview, getHrOverview: hr_getHrOverview, decideLeave: hr_decideLeave, decideExpense: hr_decideExpense,
    submitManagerReview: hr_submitManagerReview, updateTaskStatus: hr_updateTaskStatus, giveRecognition: hr_giveRecognition };

const TODAY_TONE = { Present: 'green', 'Work From Home': 'blue', 'On Leave': 'orange', Absent: 'red' };

export default class PsManagerWorkspace extends NavigationMixin(LightningElement) {
    @api hrMode = false;
    data = {};
    loading = true;
    reviewOpen = false;
    reviewForm = { id: null, rating: 3, feedback: '', promotion: false, complete: false };

    connectedCallback() {
        this.load();
    }

    load = async () => {
        this.loading = true;
        try {
            this.data = await (this.hrMode ? this.api.getHrOverview : this.api.getTeamOverview)();
        } catch (e) {
            this.toast('Error', this.msg(e), 'error');
        } finally {
            this.loading = false;
        }
    };

    get api() { return isGuest ? HR_GUEST : NORMAL; }
    get heading() { return this.data.orgWide ? 'Organization approvals & reviews' : 'Your team today'; }
    get subheading() {
        return this.data.orgWide
            ? `Every pending approval in the company · team view: ${this.data.managerName || ''}`
            : 'Approvals, attendance, reviews, learning and onboarding in one place.';
    }
    get kpis() { return this.data.kpis || {}; }
    get team() {
        return (this.data.team || []).map((m) => ({
            ...m,
            todayCls: `pill ${TODAY_TONE[m.today] || ''}`,
            ratingLabel: m.rating != null ? m.rating : '—',
            onboardingLabel: m.onboarding != null ? `${Math.round(m.onboarding)}%` : '—'
        }));
    }
    get hasTeam() { return this.team.length > 0; }
    get teamCount() { return this.team.length; }
    get teamEmptyText() {
        return this.data.linked ? 'No direct reports yet.' : 'Link your user to an Employee record to see your team.';
    }
    get leaveApprovals() {
        return (this.data.leaveApprovals || []).map((l) => ({ ...l, employee: l.Employee__r ? l.Employee__r.Name : '' }));
    }
    get expenseApprovals() {
        return (this.data.expenseApprovals || []).map((x) => ({ ...x, employee: x.Employee__r ? x.Employee__r.Name : '' }));
    }
    get approvalCount() { return `${this.leaveApprovals.length + this.expenseApprovals.length} pending`; }
    get hasApprovals() { return this.leaveApprovals.length + this.expenseApprovals.length > 0; }
    get reviewQueue() { return this.data.reviewQueue || []; }
    get hasReviews() { return this.reviewQueue.length > 0; }
    get myTasks() { return this.data.myTasks || []; }
    get hasTasks() { return this.myTasks.length > 0; }
    get upcomingLeave() {
        return (this.data.upcomingLeave || []).map((u, i) => ({ ...u, key: `u${i}`, name: u.Employee__r ? u.Employee__r.Name : '' }));
    }

    async decide(e) {
        const { id, kind, approve } = e.currentTarget.dataset;
        const yes = approve === 'true';
        const fn = kind === 'leave' ? this.api.decideLeave : this.api.decideExpense;
        const params = kind === 'leave' ? { leaveId: id, approve: yes, comments: null } : { claimId: id, approve: yes, comments: null };
        await this.run(() => fn(params), yes ? 'Approved.' : 'Rejected.');
    }

    async completeTask(e) {
        await this.run(() => this.api.updateTaskStatus({ taskId: e.currentTarget.dataset.id, status: 'Completed' }), 'Task completed.');
    }

    async recognize(e) {
        await this.run(() => this.api.giveRecognition({ recipientId: e.currentTarget.dataset.id, badge: 'Above and Beyond', message: 'Thank you for your great work!' }), 'Recognition sent.');
    }

    openReview(e) {
        this.reviewForm = { id: e.currentTarget.dataset.id, rating: 3, feedback: '', promotion: false, complete: false };
        this.reviewOpen = true;
    }
    closeReview() { this.reviewOpen = false; }
    handleRating(e) { this.reviewForm = { ...this.reviewForm, rating: e.detail.value }; }
    handleFeedback(e) { this.reviewForm = { ...this.reviewForm, feedback: e.detail.value }; }
    handlePromotion(e) { this.reviewForm = { ...this.reviewForm, promotion: e.target.checked }; }
    handleComplete(e) { this.reviewForm = { ...this.reviewForm, complete: e.target.checked }; }
    async submitReview() {
        const f = this.reviewForm;
        const ok = await this.run(() => this.api.submitManagerReview({ reviewId: f.id, rating: f.rating, feedback: f.feedback, promotion: f.promotion, complete: f.complete }), 'Review submitted.');
        if (ok) this.reviewOpen = false;
    }

    open(e) {
        if (isGuest) return;
        this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: e.currentTarget.dataset.id, actionName: 'view' } });
    }

    async run(fn, message) {
        try {
            await fn();
            this.toast('Done', message, 'success');
            await this.load();
            return true;
        } catch (e) {
            this.toast('Something went wrong', this.msg(e), 'error');
            return false;
        }
    }
    msg(e) { return (e && e.body && e.body.message) || 'Unexpected error'; }
    toast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
}

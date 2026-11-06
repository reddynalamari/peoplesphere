import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_ID from '@salesforce/user/Id';
import getMyWorkspace from '@salesforce/apex/PS_PortalController.getMyWorkspace';
import applyLeave from '@salesforce/apex/PS_PortalController.applyLeave';
import cancelLeave from '@salesforce/apex/PS_PortalController.cancelLeave';
import checkIn from '@salesforce/apex/PS_PortalController.checkIn';
import checkOut from '@salesforce/apex/PS_PortalController.checkOut';
import raiseTicket from '@salesforce/apex/PS_PortalController.raiseTicket';
import rateTicket from '@salesforce/apex/PS_PortalController.rateTicket';
import acknowledgePolicy from '@salesforce/apex/PS_PortalController.acknowledgePolicy';
import submitExpense from '@salesforce/apex/PS_PortalController.submitExpense';
import giveRecognition from '@salesforce/apex/PS_PortalController.giveRecognition';
import submitSurvey from '@salesforce/apex/PS_PortalController.submitSurvey';
import updateTaskStatus from '@salesforce/apex/PS_PortalController.updateTaskStatus';
import updateGoalProgress from '@salesforce/apex/PS_PortalController.updateGoalProgress';
import submitSelfAssessment from '@salesforce/apex/PS_PortalController.submitSelfAssessment';
import submitResignation from '@salesforce/apex/PS_PortalController.submitResignation';
import applyInternalJob from '@salesforce/apex/PS_PortalController.applyInternalJob';
import searchColleagues from '@salesforce/apex/PS_PortalController.searchColleagues';
import selfEnroll from '@salesforce/apex/PS_LearningController.selfEnroll';
import markContentComplete from '@salesforce/apex/PS_LearningController.markContentComplete';
import isGuest from '@salesforce/user/isGuest';
import gw_getMyWorkspace from '@salesforce/apex/PS_GuestGateway.getMyWorkspace';
import gw_applyLeave from '@salesforce/apex/PS_GuestGateway.applyLeave';
import gw_cancelLeave from '@salesforce/apex/PS_GuestGateway.cancelLeave';
import gw_checkIn from '@salesforce/apex/PS_GuestGateway.checkIn';
import gw_checkOut from '@salesforce/apex/PS_GuestGateway.checkOut';
import gw_raiseTicket from '@salesforce/apex/PS_GuestGateway.raiseTicket';
import gw_rateTicket from '@salesforce/apex/PS_GuestGateway.rateTicket';
import gw_acknowledgePolicy from '@salesforce/apex/PS_GuestGateway.acknowledgePolicy';
import gw_submitExpense from '@salesforce/apex/PS_GuestGateway.submitExpense';
import gw_giveRecognition from '@salesforce/apex/PS_GuestGateway.giveRecognition';
import gw_submitSurvey from '@salesforce/apex/PS_GuestGateway.submitSurvey';
import gw_updateTaskStatus from '@salesforce/apex/PS_GuestGateway.updateTaskStatus';
import gw_updateGoalProgress from '@salesforce/apex/PS_GuestGateway.updateGoalProgress';
import gw_submitSelfAssessment from '@salesforce/apex/PS_GuestGateway.submitSelfAssessment';
import gw_submitResignation from '@salesforce/apex/PS_GuestGateway.submitResignation';
import gw_applyInternalJob from '@salesforce/apex/PS_GuestGateway.applyInternalJob';
import gw_searchColleagues from '@salesforce/apex/PS_GuestGateway.searchColleagues';
import gw_selfEnroll from '@salesforce/apex/PS_GuestGateway.selfEnroll';
import gw_markContentComplete from '@salesforce/apex/PS_GuestGateway.markContentComplete';

// Site guests (public demo) go through the locked-down PS_GuestGateway.
const API = isGuest
    ? { getMyWorkspace: gw_getMyWorkspace, applyLeave: gw_applyLeave, cancelLeave: gw_cancelLeave, checkIn: gw_checkIn, checkOut: gw_checkOut, raiseTicket: gw_raiseTicket, rateTicket: gw_rateTicket, acknowledgePolicy: gw_acknowledgePolicy, submitExpense: gw_submitExpense, giveRecognition: gw_giveRecognition, submitSurvey: gw_submitSurvey, updateTaskStatus: gw_updateTaskStatus, updateGoalProgress: gw_updateGoalProgress, submitSelfAssessment: gw_submitSelfAssessment, submitResignation: gw_submitResignation, applyInternalJob: gw_applyInternalJob, searchColleagues: gw_searchColleagues, selfEnroll: gw_selfEnroll, markContentComplete: gw_markContentComplete }
    : { getMyWorkspace, applyLeave, cancelLeave, checkIn, checkOut, raiseTicket, rateTicket, acknowledgePolicy, submitExpense, giveRecognition, submitSurvey, updateTaskStatus, updateGoalProgress, submitSelfAssessment, submitResignation, applyInternalJob, searchColleagues, selfEnroll, markContentComplete };

const opts = (values) => values.map((v) => ({ label: v, value: v }));
const STATUS_TONE = {
    Approved: 'green', Completed: 'green', Resolved: 'green', Closed: 'green', Present: 'green',
    Rejected: 'red', Cancelled: 'grey', Escalated: 'red',
    Submitted: 'orange', New: 'orange', 'In Progress': 'blue', 'Waiting on Employee': 'orange'
};

export default class PsEmployeePortal extends LightningElement {
    ws = {};
    loading = true;
    activeTab = 'home';
    workMode = 'Office';
    leave = { type: 'Casual Leave', start: null, end: null, half: false, reason: '' };
    ticket = { subject: '', description: '', priority: 'Medium' };
    expense = { category: 'Travel', amount: null, date: null, description: '' };
    resign = { reason: 'Career Growth', lastDay: null, comments: '' };
    kudos = { recipientId: null, badge: 'Team Player', message: '' };
    lastTicket;
    surveyScore = null;
    surveyComment = '';
    selfRating = 3;
    selfText = '';
    quizEnrollmentId;
    kudosOpen = false;
    kudosTerm = '';
    colleagues = [];
    showResign = false;
    goalTimers = {};

    workModeOptions = opts(['Office', 'Hybrid', 'Remote']);
    leaveTypes = opts(['Casual Leave', 'Sick Leave', 'Earned Leave', 'Work From Home', 'Unpaid Leave', 'Comp Off', 'Bereavement Leave', 'Maternity Leave', 'Paternity Leave']);
    priorityOptions = opts(['Low', 'Medium', 'High', 'Critical']);
    ratingOptions = [
        { label: '★★★★★ Excellent', value: '5' }, { label: '★★★★ Good', value: '4' }, { label: '★★★ OK', value: '3' },
        { label: '★★ Poor', value: '2' }, { label: '★ Bad', value: '1' }
    ];
    expenseCategories = opts(['Travel', 'Food', 'Accommodation', 'Internet & Phone', 'Training', 'Medical', 'Relocation', 'Client Entertainment', 'Other']);
    exitReasons = opts(['Better Opportunity', 'Compensation', 'Career Growth', 'Relocation', 'Personal', 'Higher Studies', 'Health', 'Work-Life Balance', 'Management', 'Other']);
    badgeOptions = opts(['Team Player', 'Innovator', 'Customer Hero', 'Leadership', 'Above and Beyond', 'Mentor', 'Quality Champion']);

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        try {
            this.ws = await API.getMyWorkspace();
            if (this.ws.openReview) {
                this.selfRating = this.ws.openReview.Self_Rating__c || 3;
                this.selfText = this.ws.openReview.Self_Assessment__c || '';
            }
        } catch (e) {
            this.toast('Error', this.msg(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    // ------------------------------------------------------------ getters
    get linked() { return this.ws && this.ws.linked; }
    get emp() { return this.ws.employee; }
    get firstName() { return this.emp && this.emp.Name ? this.emp.Name.split(' ')[0] : this.ws.userName || 'there'; }
    get greeting() {
        const h = new Date().getHours();
        return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    }
    get designationName() { return this.emp && this.emp.Designation__r ? this.emp.Designation__r.Name : ''; }
    get deptName() { return this.emp && this.emp.Department__r ? this.emp.Department__r.Name : ''; }
    get points() { return (this.emp && this.emp.Recognition_Points__c) || 0; }
    get today() { return this.ws.today; }
    get canCheckIn() { return !this.today || !this.today.Check_In__c; }
    get canCheckOut() { return this.today && this.today.Check_In__c && !this.today.Check_Out__c; }
    get attendanceLabel() {
        const t = this.today;
        if (!t || !t.Check_In__c) return t && t.Status__c ? `Today: ${t.Status__c}` : 'You have not checked in today';
        const inAt = new Date(t.Check_In__c).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        if (!t.Check_Out__c) return `Checked in at ${inAt}${t.Late_Arrival__c ? ' (late)' : ''}`;
        return `Worked ${Number(t.Hours_Worked__c || 0).toFixed(1)} h today`;
    }
    get onboarding() { return this.ws.onboarding; }
    get onboardingPercent() { return this.onboarding ? Math.round(this.onboarding.Completion_Percent__c || 0) : 0; }
    get onboardingTasks() {
        const tasks = (this.onboarding && this.onboarding.Tasks__r) || [];
        return tasks.map((t) => ({
            ...t,
            mine: t.Assigned_To__c === USER_ID && t.Status__c !== 'Completed',
            cls: `item ${t.Status__c === 'Completed' ? 'done' : ''} ${t.Is_Overdue__c ? 'overdue' : ''}`
        }));
    }
    get myTasks() {
        const a = (this.ws.myTasks || []).map((t) => ({ ...t, kind: t.Assigned_Team__c, who: t.Employee_Name__c }));
        const b = (this.ws.myExitTasks || []).map((t) => ({
            ...t, kind: 'Exit', who: t.Exit_Process__r && t.Exit_Process__r.Employee__r ? t.Exit_Process__r.Employee__r.Name : ''
        }));
        return [...a, ...b].map((t) => ({ ...t, cls: `item ${t.Is_Overdue__c ? 'overdue' : ''}` }));
    }
    get hasMyTasks() { return this.myTasks.length > 0; }
    get myTaskCount() { return `${this.myTasks.length} open`; }
    get hasPendingPolicies() { return (this.ws.pendingPolicies || []).length > 0; }
    get pendingPolicyCount() { return (this.ws.pendingPolicies || []).length; }
    get announcements() {
        return (this.ws.announcements || []).map((a) => ({ ...a, cls: `tag tag-${(a.Category__c || 'general').toLowerCase()}` }));
    }
    get hasAnnouncements() { return this.announcements.length > 0; }
    get hasHolidays() { return (this.ws.holidays || []).length > 0; }
    get survey() { return this.ws.activeSurvey; }
    get scale() {
        return Array.from({ length: 11 }, (_, i) => ({ value: i, cls: `pt ${this.surveyScore === i ? 'sel' : ''}` }));
    }
    get noScore() { return this.surveyScore === null; }
    get myLeaves() {
        const today = new Date().toISOString().slice(0, 10);
        return (this.ws.myLeaves || []).map((l) => ({
            ...l,
            cls: `pill ${STATUS_TONE[l.Status__c] || ''}`,
            cancellable: l.Status__c === 'Submitted' || (l.Status__c === 'Approved' && l.Start_Date__c >= today)
        }));
    }
    get attendance() {
        return (this.ws.recentAttendance || []).slice().reverse().map((a) => ({
            ...a,
            day: a.Attendance_Date__c ? a.Attendance_Date__c.slice(8, 10) : '',
            cls: `day d-${(a.Status__c || '').toLowerCase().replace(/[^a-z]/g, '')} ${a.Late_Arrival__c ? 'late' : ''}`,
            title: `${a.Attendance_Date__c}: ${a.Status__c}${a.Hours_Worked__c ? ' · ' + Number(a.Hours_Worked__c).toFixed(1) + ' h' : ''}`
        }));
    }
    get enrollments() {
        return (this.ws.enrollments || []).map((e) => ({
            ...e,
            progress: e.Progress_Percent__c || 0,
            hasQuiz: e.Course__r && e.Course__r.Total_Questions__c > 0,
            done: e.Status__c === 'Completed'
        }));
    }
    get hasEnrollments() { return this.enrollments.length > 0; }
    get openCourses() { return this.enrollments.filter((e) => !e.done).length; }
    get hasRecommendations() { return (this.ws.recommendations || []).length > 0; }
    get tickets() {
        return (this.ws.myTickets || []).map((t) => ({
            ...t,
            cls: `pill ${STATUS_TONE[t.Status__c] || ''}`,
            rateable: t.Status__c === 'Resolved' && !t.Satisfaction_Rating__c
        }));
    }
    get goals() { return (this.ws.goals || []).map((g) => ({ ...g, progress: g.Progress__c || 0 })); }
    get hasGoals() { return this.goals.length > 0; }
    get review() { return this.ws.openReview; }
    get hasJobs() { return (this.ws.internalJobs || []).length > 0; }
    get exitProcess() { return this.ws.exitProcess && this.ws.exitProcess.length ? this.ws.exitProcess[0] : null; }
    get isGuest() { return isGuest; }
    get noRecipient() { return !this.kudos.recipientId; }

    // ------------------------------------------------------------ actions
    handleWorkMode(e) { this.workMode = e.detail.value; }

    async checkIn() {
        await this.run(() => API.checkIn({ workMode: this.workMode }), 'Checked in. Have a great day!');
    }
    async checkOut() {
        await this.run(() => API.checkOut(), 'Checked out. See you tomorrow!');
    }

    handleLeave(e) {
        const f = e.target.dataset.field;
        this.leave = { ...this.leave, [f]: f === 'half' ? e.target.checked : e.detail.value !== undefined ? e.detail.value : e.target.value };
    }
    async applyLeave() {
        const l = this.leave;
        if (!l.start || !l.end) {
            this.toast('Missing dates', 'Choose a start and end date.', 'warning');
            return;
        }
        const ok = await this.run(() => API.applyLeave({ leaveType: l.type, startDate: l.start, endDate: l.end, halfDay: l.half, reason: l.reason }), 'Leave request submitted to your manager.');
        if (ok) this.leave = { type: 'Casual Leave', start: null, end: null, half: false, reason: '' };
    }
    async cancelLeave(e) {
        await this.run(() => API.cancelLeave({ leaveId: e.currentTarget.dataset.id }), 'Leave cancelled.');
    }

    handleTicket(e) { this.ticket = { ...this.ticket, [e.target.dataset.field]: e.detail.value !== undefined ? e.detail.value : e.target.value }; }
    async raiseTicket() {
        if (!this.ticket.subject && !this.ticket.description) {
            this.toast('Tell us more', 'Add a subject or description.', 'warning');
            return;
        }
        try {
            const t = await API.raiseTicket({ subject: this.ticket.subject, description: this.ticket.description, priority: this.ticket.priority, channel: 'Portal' });
            this.lastTicket = { ...t, category: t.Category__c, policy: t.Related_Policy__r ? t.Related_Policy__r.Name : null };
            this.ticket = { subject: '', description: '', priority: 'Medium' };
            this.toast('Ticket created', `${t.Name} was routed to ${t.Assigned_To__r ? t.Assigned_To__r.Name : 'HR'}.`, 'success');
            this.load();
        } catch (err) {
            this.toast('Error', this.msg(err), 'error');
        }
    }
    async rateTicket(e) {
        await this.run(() => API.rateTicket({ ticketId: e.target.dataset.id, rating: e.detail.value, feedback: null }), 'Thanks for the feedback!');
    }

    async acknowledge(e) {
        await this.run(() => API.acknowledgePolicy({ policyId: e.currentTarget.dataset.id }), 'Policy acknowledged.');
    }

    handleExpense(e) { this.expense = { ...this.expense, [e.target.dataset.field]: e.detail.value !== undefined ? e.detail.value : e.target.value }; }
    async submitExpense() {
        const x = this.expense;
        if (!x.amount || !x.date) {
            this.toast('Missing details', 'Enter an amount and date.', 'warning');
            return;
        }
        const ok = await this.run(() => API.submitExpense({ category: x.category, amount: x.amount, expenseDate: x.date, description: x.description }), 'Expense claim submitted.');
        if (ok) this.expense = { category: 'Travel', amount: null, date: null, description: '' };
    }

    pickScore(e) { this.surveyScore = Number(e.currentTarget.dataset.value); }
    handleSurveyComment(e) { this.surveyComment = e.detail.value; }
    async submitSurvey() {
        const ok = await this.run(() => API.submitSurvey({ surveyId: this.survey.Id, score: this.surveyScore, comment: this.surveyComment }), 'Thank you for sharing!');
        if (ok) { this.surveyScore = null; this.surveyComment = ''; }
    }

    async completeTask(e) {
        await this.run(() => API.updateTaskStatus({ taskId: e.currentTarget.dataset.id, status: 'Completed' }), 'Task completed.');
    }

    updateGoal(e) {
        const id = e.target.dataset.id;
        const value = e.detail.value;
        clearTimeout(this.goalTimers[id]);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.goalTimers[id] = setTimeout(() => this.run(() => API.updateGoalProgress({ goalId: id, currentValue: value }), 'Goal updated.'), 700);
    }

    handleSelfRating(e) { this.selfRating = e.detail.value; }
    handleSelfText(e) { this.selfText = e.detail.value; }
    async submitSelf() {
        await this.run(() => API.submitSelfAssessment({ reviewId: this.review.Id, rating: this.selfRating, assessment: this.selfText }), 'Self-assessment sent to your manager.');
    }

    async applyJob(e) {
        await this.run(() => API.applyInternalJob({ requisitionId: e.currentTarget.dataset.id }), 'Application submitted. Good luck!');
    }

    toggleResign() { this.showResign = !this.showResign; }
    handleResign(e) { this.resign = { ...this.resign, [e.target.dataset.field]: e.detail.value !== undefined ? e.detail.value : e.target.value }; }
    async submitResignation() {
        const r = this.resign;
        const ok = await this.run(() => API.submitResignation({ reason: r.reason, requestedLastDay: r.lastDay, comments: r.comments }), 'Resignation submitted. HR and your manager have been notified.');
        if (ok) this.showResign = false;
    }

    openQuiz(e) { this.quizEnrollmentId = e.currentTarget.dataset.id; }
    closeQuiz() { this.quizEnrollmentId = null; this.load(); }
    openContent(e) { window.open(e.currentTarget.dataset.url, '_blank'); }
    async markComplete(e) {
        await this.run(() => API.markContentComplete({ enrollmentId: e.currentTarget.dataset.id }), 'Course completed!');
    }
    async enroll(e) {
        await this.run(() => API.selfEnroll({ courseId: e.currentTarget.dataset.id }), 'Enrolled. Find it under My courses.');
    }

    showKudos() { this.kudosOpen = true; }
    hideKudos() { this.kudosOpen = false; this.colleagues = []; this.kudosTerm = ''; this.kudos = { recipientId: null, badge: 'Team Player', message: '' }; }
    async searchColleague(e) {
        this.kudosTerm = e.detail.value;
        try {
            const rows = await API.searchColleagues({ term: this.kudosTerm });
            const myId = this.emp ? this.emp.Id : null;
            this.colleagues = rows.filter((r) => r.id !== myId).map((r) => ({ ...r, cls: 'item pick' }));
        } catch (err) {
            this.colleagues = [];
        }
    }
    pickColleague(e) {
        const id = e.currentTarget.dataset.id;
        this.kudos = { ...this.kudos, recipientId: id };
        this.colleagues = this.colleagues.map((c) => ({ ...c, cls: c.id === id ? 'item pick sel' : 'item pick' }));
    }
    handleBadge(e) { this.kudos = { ...this.kudos, badge: e.detail.value }; }
    handleKudosMessage(e) { this.kudos = { ...this.kudos, message: e.detail.value }; }
    async sendKudos() {
        const k = this.kudos;
        const ok = await this.run(() => API.giveRecognition({ recipientId: k.recipientId, badge: k.badge, message: k.message }), 'Kudos sent!');
        if (ok) this.hideKudos();
    }

    // ------------------------------------------------------------ helpers
    async run(fn, successMessage) {
        try {
            await fn();
            this.toast('Done', successMessage, 'success');
            await this.load();
            return true;
        } catch (e) {
            this.toast('Something went wrong', this.msg(e), 'error');
            return false;
        }
    }
    msg(e) {
        return (e && e.body && e.body.message) || (e && e.message) || 'Unexpected error';
    }
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

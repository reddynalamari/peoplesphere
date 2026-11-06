import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getOverview from '@salesforce/apex/PS_DashboardController.getOverview';
import isGuest from '@salesforce/user/isGuest';
import hr_getOverview_raw from '@salesforce/apex/PS_GuestHrGateway.getOverview';
import { withToken } from 'c/psHrAuth';

// Password-protected HR demo: every gateway call carries the session token.
const hr_getOverview = withToken(hr_getOverview_raw);


const ALERT_ICONS = {
    error: { icon: 'utility:error', variant: 'error' },
    warning: { icon: 'utility:warning', variant: 'warning' },
    info: { icon: 'utility:info', variant: '' }
};

export default class PsDashboard extends NavigationMixin(LightningElement) {
    data;
    error;
    loading = true;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        try {
            this.data = await (isGuest ? hr_getOverview : getOverview)();
            this.error = undefined;
        } catch (e) {
            this.error = (e && e.body && e.body.message) || 'Could not load the dashboard.';
        } finally {
            this.loading = false;
        }
    }

    refresh() {
        this.load();
    }

    get canNavigate() {
        return !isGuest;
    }

    get kpis() {
        return (this.data && this.data.kpis) || {};
    }
    get preboardingCaption() {
        return `${this.kpis.preboarding || 0} pre-boarding · ${this.kpis.onNotice || 0} on notice`;
    }
    get exitsCaption() {
        return `${this.kpis.exits12m || 0} exits in 12 months`;
    }
    get overdueTrainingCaption() {
        return `${this.kpis.overdueTraining || 0} overdue assignments`;
    }
    get slaCaption() {
        return `${this.kpis.slaBreached || 0} breached SLA`;
    }
    get enpsCaption() {
        return `${this.kpis.surveyResponses || 0} responses (180d)`;
    }
    get onboardingCaption() {
        return `${this.kpis.delayedOnboarding || 0} past target date`;
    }
    get reqCaption() {
        return `${this.kpis.openRequisitions || 0} open requisitions`;
    }
    get csat() {
        return this.kpis.csat ? `${this.kpis.csat}/5` : 'n/a';
    }

    get trend() {
        const rows = (this.data && this.data.hiringTrend) || [];
        const max = Math.max(1, ...rows.map((r) => Math.max(r.joiners, r.exits)));
        return rows.map((r) => ({
            ...r,
            joinStyle: `height:${Math.max(3, (r.joiners / max) * 100)}%`,
            exitStyle: `height:${Math.max(3, (r.exits / max) * 100)}%`,
            joinTitle: `${r.joiners} joiners`,
            exitTitle: `${r.exits} exits`
        }));
    }

    get alerts() {
        const list = (this.data && this.data.alerts) || [];
        return list.map((a) => ({ ...a, ...ALERT_ICONS[a.level], cls: `alert ${a.level}` }));
    }
    get hasAlerts() {
        return this.alerts.length > 0;
    }
    get onboarding() {
        return (this.data && this.data.onboardingPipeline) || [];
    }
    get hasOnboarding() {
        return this.onboarding.length > 0;
    }

    openRecord(event) {
        if (isGuest) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }

    newEmployee() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Employee__c', actionName: 'new' }
        });
    }
}

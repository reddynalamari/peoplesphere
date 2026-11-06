import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ask from '@salesforce/apex/PS_AssistantController.ask';
import suggestions from '@salesforce/apex/PS_AssistantController.suggestions';
import escalateToHr from '@salesforce/apex/PS_AssistantController.escalateToHr';
import isGuest from '@salesforce/user/isGuest';
import hr_ask_raw from '@salesforce/apex/PS_GuestHrGateway.ask';
import hr_escalateToHr_raw from '@salesforce/apex/PS_GuestHrGateway.escalateToHr';
import hr_suggestions_raw from '@salesforce/apex/PS_GuestHrGateway.suggestions';
import gw_suggestions from '@salesforce/apex/PS_GuestGateway.suggestions';
import gw_ask from '@salesforce/apex/PS_GuestGateway.ask';
import gw_escalateToHr from '@salesforce/apex/PS_GuestGateway.escalateToHr';
import { withToken } from 'c/psHrAuth';

// Password-protected HR demo: every gateway call carries the session token.
const hr_ask = withToken(hr_ask_raw);
const hr_escalateToHr = withToken(hr_escalateToHr_raw);
const hr_suggestions = withToken(hr_suggestions_raw);

// Site guests (public demo) go through the locked-down PS_GuestGateway.
const API = isGuest
    ? { ask: gw_ask, escalateToHr: gw_escalateToHr }
    : { ask, escalateToHr };

const HR_API = { ask: hr_ask, escalateToHr: hr_escalateToHr };

let seq = 0;

export default class PsHrAssistant extends NavigationMixin(LightningElement) {
    @api hrMode = false;
    messages = [];
    draft = '';
    thinking = false;
    suggestions = [];

    connectedCallback() {
        (isGuest ? (this.hrMode ? hr_suggestions : gw_suggestions) : suggestions)()
            .then((data) => { this.suggestions = data || []; })
            .catch(() => { this.suggestions = []; });
    }

    get api() { return isGuest && this.hrMode ? HR_API : API; }
    get hasMessages() { return this.messages.length > 0; }
    get cannotSend() { return this.thinking || !this.draft || !this.draft.trim(); }

    handleDraft(e) { this.draft = e.detail.value; }
    handleKey(e) { if (e.key === 'Enter') this.send(); }
    useSuggestion(e) {
        this.draft = e.currentTarget.dataset.q;
        this.send();
    }

    async send() {
        const q = (this.draft || '').trim();
        if (!q || this.thinking) return;
        this.push({ role: 'user', text: q });
        this.draft = '';
        this.thinking = true;
        try {
            const a = await this.api.ask({ question: q });
            this.push({ role: 'bot', question: q, ...a });
        } catch (e) {
            this.push({ role: 'bot', question: q, text: (e && e.body && e.body.message) || 'Sorry, something went wrong.' });
        } finally {
            this.thinking = false;
            this.scroll();
        }
    }

    push(m) {
        const key = `m${++seq}`;
        const isBot = m.role === 'bot';
        const isTable = isBot && m.mode === 'table' && m.rows && m.rows.length > 0;
        let columns = [];
        let rows = [];
        if (isTable) {
            columns = m.columns.map((label, i) => ({ label, fieldName: `c${i}`, wrapText: true }));
            columns.push({ type: 'button-icon', fixedWidth: 50, typeAttributes: { iconName: 'utility:open', name: 'open', alternativeText: 'Open', disabled: { fieldName: 'noLink' } } });
            rows = m.rows.map((r, i) => ({ ...r, key: `${key}-${i}`, noLink: !r.id || isGuest }));
        }
        this.messages = [
            ...this.messages,
            {
                ...m,
                key,
                isBot,
                isTable,
                columns,
                rows,
                hasSources: isBot && m.sources && m.sources.length > 0,
                canEscalate: isBot && (m.intent === 'policy' || !m.intent),
                cls: `msg ${isBot ? 'bot' : 'user'}`
            }
        ];
        this.scroll();
    }

    scroll() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            const el = this.refs.chat;
            if (el) el.scrollTop = el.scrollHeight;
        });
    }

    openRow(e) {
        if (e.detail.row.id) this.navigate(e.detail.row.id);
    }
    openRecord(e) {
        if (isGuest) return;
        this.navigate(e.currentTarget.dataset.id);
    }
    navigate(id) {
        this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: id, actionName: 'view' } });
    }

    async escalate(e) {
        const m = this.messages.find((x) => x.key === e.currentTarget.dataset.key);
        try {
            const t = await this.api.escalateToHr({ question: m.question, assistantAnswer: m.text });
            this.push({ role: 'bot', text: `I've raised ticket ${t.Name} with HR (${t.Category__c}, ${t.Priority__c} priority). You'll be notified when it's resolved.`, intent: 'escalated' });
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Could not raise ticket', message: (err && err.body && err.body.message) || '', variant: 'error' }));
        }
    }
}

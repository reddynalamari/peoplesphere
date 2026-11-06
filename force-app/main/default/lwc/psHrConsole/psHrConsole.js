import { LightningElement } from 'lwc';
import isGuest from '@salesforce/user/isGuest';
import getOpenOnboardings from '@salesforce/apex/PS_HrOpsController.getOpenOnboardings';
import hr_getOpenOnboardings_raw from '@salesforce/apex/PS_GuestHrGateway.getOpenOnboardings';
import unlock from '@salesforce/apex/PS_GuestHrGateway.unlock';
import checkToken from '@salesforce/apex/PS_GuestHrGateway.checkToken';
import { withToken, getToken, setToken, clearToken, onLocked } from 'c/psHrAuth';

const hr_getOpenOnboardings = withToken(hr_getOpenOnboardings_raw);

/**
 * HR Admin Console: every HR feature on one page. On the public site it is
 * protected by a password that the server verifies (PS_GuestHrGateway.unlock).
 */
export default class PsHrConsole extends LightningElement {
    unlocked = false;
    checking = true;
    password = '';
    error;
    onboardings = [];
    selectedOnboarding;
    stopListening;

    async connectedCallback() {
        this.stopListening = onLocked(() => {
            this.unlocked = false;
            this.error = 'Your HR session expired. Please enter the password again.';
        });
        if (!isGuest) {
            this.unlocked = true;
            this.checking = false;
            return;
        }
        try {
            const token = getToken();
            this.unlocked = token ? await checkToken({ token }) : false;
        } catch (e) {
            this.unlocked = false;
        } finally {
            this.checking = false;
        }
    }

    disconnectedCallback() {
        if (this.stopListening) this.stopListening();
    }

    get showLock() { return !this.checking && !this.unlocked; }
    get canLogOut() { return isGuest; }

    handlePassword(e) { this.password = e.detail.value; }
    handleKey(e) { if (e.key === 'Enter') this.submit(); }

    async submit() {
        if (!this.password) return;
        this.checking = true;
        this.error = undefined;
        try {
            const token = await unlock({ password: this.password });
            setToken(token);
            this.password = '';
            this.unlocked = true;
        } catch (e) {
            this.error = (e && e.body && e.body.message) || 'Incorrect password.';
        } finally {
            this.checking = false;
        }
    }

    logOut() {
        clearToken();
        this.unlocked = false;
        this.onboardings = [];
        this.selectedOnboarding = null;
    }

    async loadOnboardings() {
        try {
            this.onboardings = await (isGuest ? hr_getOpenOnboardings : getOpenOnboardings)();
            if (!this.selectedOnboarding && this.onboardings.length) this.selectedOnboarding = this.onboardings[0].id;
        } catch (e) {
            this.onboardings = [];
        }
    }

    get onboardingRows() {
        return this.onboardings.map((o) => ({ ...o, cls: `item ${o.id === this.selectedOnboarding ? 'sel' : ''}` }));
    }

    pickOnboarding(e) {
        this.selectedOnboarding = e.currentTarget.dataset.id;
    }

    get employeeLink() {
        return window.location.pathname.replace(/\/hr-admin\/?$/, '/');
    }
}

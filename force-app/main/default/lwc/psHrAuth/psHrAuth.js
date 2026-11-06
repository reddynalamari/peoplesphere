/**
 * Session token for the password-protected public HR Admin demo.
 * The token is issued by PS_GuestHrGateway.unlock and verified by the server
 * on every call; this module only stores it for the browser tab and attaches
 * it to gateway calls.
 */
const KEY = 'peoplesphere_hr_token';
const LOCKED_EVENT = 'pshrlocked';
let memoryToken = null;

export function getToken() {
    try {
        return window.sessionStorage.getItem(KEY) || memoryToken;
    } catch (e) {
        return memoryToken;
    }
}

export function setToken(token) {
    memoryToken = token;
    try {
        window.sessionStorage.setItem(KEY, token);
    } catch (e) {
        // storage blocked: keep the in-memory copy
    }
}

export function clearToken() {
    memoryToken = null;
    try {
        window.sessionStorage.removeItem(KEY);
    } catch (e) {
        // ignore
    }
}

/** Listen for an expired / rejected session so the console can ask for the password again. */
export function onLocked(handler) {
    window.addEventListener(LOCKED_EVENT, handler);
    return () => window.removeEventListener(LOCKED_EVENT, handler);
}

/** Wraps a PS_GuestHrGateway Apex method so the token is always sent. */
export function withToken(apexMethod) {
    return async (params) => {
        try {
            return await apexMethod({ ...(params || {}), token: getToken() });
        } catch (e) {
            const message = (e && e.body && e.body.message) || '';
            if (message.indexOf('HR_LOCKED') === 0) {
                clearToken();
                window.dispatchEvent(new CustomEvent(LOCKED_EVENT));
            }
            throw e;
        }
    };
}

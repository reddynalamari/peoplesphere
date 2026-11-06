import { LightningElement, api } from 'lwc';
import getQuiz from '@salesforce/apex/PS_LearningController.getQuiz';
import submitQuiz from '@salesforce/apex/PS_LearningController.submitQuiz';
import isGuest from '@salesforce/user/isGuest';
import gw_getQuiz from '@salesforce/apex/PS_GuestGateway.getQuiz';
import gw_submitQuiz from '@salesforce/apex/PS_GuestGateway.submitQuiz';

// Site guests (public demo) go through the locked-down PS_GuestGateway.
const API = isGuest
    ? { getQuiz: gw_getQuiz, submitQuiz: gw_submitQuiz }
    : { getQuiz, submitQuiz };

/** Quiz player. Correct answers never reach the browser before submission; grading is server side. */
export default class PsQuiz extends LightningElement {
    @api enrollmentId;
    quiz;
    answers = {};
    result;
    error;
    loading = true;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        this.result = undefined;
        this.answers = {};
        try {
            this.quiz = await API.getQuiz({ enrollmentId: this.enrollmentId });
        } catch (e) {
            this.error = (e && e.body && e.body.message) || 'Could not load the quiz.';
        } finally {
            this.loading = false;
        }
    }

    get title() {
        return this.quiz ? this.quiz.courseName : 'Assessment';
    }
    get attempts() {
        return (this.quiz && this.quiz.attempts) || 0;
    }
    get showQuestions() {
        return this.quiz && !this.result;
    }
    get questions() {
        return ((this.quiz && this.quiz.questions) || []).map((q, i) => ({ ...q, index: i + 1, answer: this.answers[q.id] }));
    }
    get incomplete() {
        return this.questions.some((q) => !this.answers[q.id]);
    }
    get resultClass() {
        return this.result && this.result.passed ? 'result pass' : 'result fail';
    }
    get resultText() {
        return this.result.passed ? 'Congratulations, you passed!' : `You need ${this.result.passingScore}% to pass. Review the answers and try again.`;
    }
    get canRetry() {
        return this.result && !this.result.passed;
    }
    get review() {
        return ((this.result && this.result.review) || []).map((r) => ({
            ...r,
            givenLabel: r.given || 'not answered',
            cls: r.correct ? 'rv ok' : 'rv bad'
        }));
    }

    answer(e) {
        this.answers = { ...this.answers, [e.target.dataset.id]: e.detail.value };
    }

    async submit() {
        this.loading = true;
        try {
            this.result = await API.submitQuiz({ enrollmentId: this.enrollmentId, answers: this.answers });
        } catch (e) {
            this.error = (e && e.body && e.body.message) || 'Submission failed.';
        } finally {
            this.loading = false;
        }
    }

    retry() {
        this.load();
    }

    close() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}

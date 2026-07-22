import { LightningElement, api } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

const CHANNEL = '/event/Renewal_Notice__e';
const ICON = { success: 'utility:success', error: 'utility:error', warning: 'utility:warning', info: 'utility:info' };
const THEME = { success: 'success', error: 'error', warning: 'warning', info: 'info' };

export default class RenewalNotice extends LightningElement {
    @api recordId;
    notices = [];
    subscription = {};
    _seq = 0;

    connectedCallback() {
        if (this._subscribed) {
            return;
        }
        this._subscribed = true;
        onError((error) => {
            // eslint-disable-next-line no-console
            console.error('renewalNotice empApi error', JSON.stringify(error));
        });
        subscribe(CHANNEL, -1, (message) => this.handleEvent(message)).then((response) => {
            this.subscription = response;
        });
    }

    disconnectedCallback() {
        this._subscribed = false;
        if (this.subscription && this.subscription.id) {
            unsubscribe(this.subscription, () => {});
        }
    }

    handleEvent(message) {
        const payload = (message && message.data && message.data.payload) || {};
        if (!this.matchesRecord(payload.Opportunity_Id__c)) {
            return;
        }
        const variant = (payload.Variant__c || 'info').toLowerCase();
        const theme = THEME[variant] || 'info';
        const notice = {
            key: ++this._seq,
            variant,
            title: payload.Title__c || '',
            message: payload.Message__c || '',
            linkUrl: payload.Link_Id__c ? '/' + payload.Link_Id__c : null,
            iconName: ICON[variant] || ICON.info,
            themeClass: 'slds-notify slds-notify_alert slds-theme_' + theme + ' slds-var-m-bottom_x-small renewalNotice__alert'
        };
        // Show only the most recent notice (avoids duplicate/accumulated banners)
        this.notices = [notice];
    }

    matchesRecord(oppId) {
        if (!this.recordId) {
            return true;
        }
        if (!oppId) {
            return false;
        }
        return oppId === this.recordId || oppId.substring(0, 15) === this.recordId.substring(0, 15);
    }

    handleDismiss(event) {
        const key = Number(event.currentTarget.dataset.key);
        this.notices = this.notices.filter((n) => n.key !== key);
    }

    get hasNotices() {
        return this.notices.length > 0;
    }
}
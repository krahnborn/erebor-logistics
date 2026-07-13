import { LightningElement, api, wire } from 'lwc';
import getScore from '@salesforce/apex/AccountDataQualityController.getScore';

export default class AccountDataQualityScore extends LightningElement {
    @api recordId;
    score;
    errorMessage;

    @wire(getScore, { recordId: '$recordId' })
    wiredScore({ data, error }) {
        if (data) {
            this.errorMessage = undefined;
            this.score = {
                ...data,
                items: (data.items || []).map((item) => this.decorateItem(item))
            };
        } else if (error) {
            this.score = undefined;
            this.errorMessage = this.reduceError(error);
        }
    }

    get meterStyle() {
        return `width: ${this.score?.score || 0}%`;
    }

    get meterClass() {
        return `meter meter_${(this.score?.status || 'Red').toLowerCase()}`;
    }

    get statusClass() {
        return `status-badge status-badge_${(this.score?.status || 'Red').toLowerCase()}`;
    }

    decorateItem(item) {
        const configured = item.configured !== false;
        const complete = item.complete === true;
        const critical = item.critical === true;
        return {
            ...item,
            fieldLabel: item.fieldLabel || item.fieldApiName,
            rowClass: `rule-item ${complete ? 'rule-item_complete' : 'rule-item_missing'}`,
            iconName: complete ? 'utility:success' : 'utility:warning',
            iconVariant: complete ? 'success' : 'warning',
            importanceClass: critical ? 'pill pill_critical' : 'pill',
            message: configured ? item.message : 'Rule needs admin attention'
        };
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((entry) => entry.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unable to load data quality score.';
    }
}

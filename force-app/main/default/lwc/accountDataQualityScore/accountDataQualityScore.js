import { LightningElement, api, wire } from 'lwc';
import getScore from '@salesforce/apex/AccountDataQualityController.getScore';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

export default class AccountDataQualityScore extends LightningElement {
    @api recordId;
    score;
    errorMessage;
    wiredScoreResult;

    @wire(getScore, { recordId: '$recordId' })
    wiredScore(result) {
        this.wiredScoreResult = result;
        const { data, error } = result;
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
        const editable = item.editable === true;
        const showEditor = configured && !complete && editable;
        return {
            ...item,
            fieldLabel: item.fieldLabel || item.fieldApiName,
            rowClass: `rule-item ${complete ? 'rule-item_complete' : 'rule-item_missing'}`,
            iconName: complete ? 'utility:success' : 'utility:warning',
            iconVariant: complete ? 'success' : 'warning',
            importanceClass: critical ? 'pill pill_critical' : 'pill',
            message: configured ? item.message : 'Rule needs admin attention',
            showEditor,
            blockedMessage: configured && !complete && !editable ? 'Read-only for your profile' : undefined
        };
    }

    async handleFieldSaveSuccess(event) {
        const fieldName = event.target.dataset.fieldName;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Account updated',
                message: `${fieldName} was saved.`,
                variant: 'success'
            })
        );

        await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        await refreshApex(this.wiredScoreResult);
    }

    handleFieldSaveError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Unable to save field',
                message: this.reduceError(event.detail),
                variant: 'error'
            })
        );
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((entry) => entry.message).join(', ');
        }
        if (Array.isArray(error?.output?.errors) && error.output.errors.length > 0) {
            return error.output.errors.map((entry) => entry.message).join(', ');
        }
        if (error?.detail) {
            return this.reduceError(error.detail);
        }
        return error?.body?.message || error?.message || 'Unable to load data quality score.';
    }
}

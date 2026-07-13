import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getOnboardingSummary from '@salesforce/apex/MerchantOnboardingController.getOnboardingSummary';
import createMissingStandardSteps from '@salesforce/apex/MerchantOnboardingController.createMissingStandardSteps';

export default class MerchantOnboardingTracker extends LightningElement {
    @api recordId;

    summary;
    errorMessage;
    creatingSteps = false;
    wiredSummary;

    @wire(getOnboardingSummary, { accountId: '$recordId' })
    wiredOnboardingSummary(result) {
        this.wiredSummary = result;
        if (result.data) {
            this.summary = result.data;
            this.errorMessage = undefined;
        } else if (result.error) {
            this.summary = undefined;
            this.errorMessage = this.reduceError(result.error);
        }
    }

    get hasSteps() {
        return this.summary?.steps?.length > 0;
    }

    get progressVariant() {
        if (this.summary?.blockedSteps > 0 || this.summary?.stalled) {
            return 'warning';
        }
        return 'base-autocomplete';
    }

    async handleCreateSteps() {
        this.creatingSteps = true;
        try {
            const createdCount = await createMissingStandardSteps({ accountId: this.recordId });
            await refreshApex(this.wiredSummary);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: createdCount === 0 ? 'Onboarding steps are current' : 'Onboarding steps added',
                    message:
                        createdCount === 0
                            ? 'All active standard steps already exist for this account.'
                            : `${createdCount} standard step${createdCount === 1 ? '' : 's'} added.`,
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Could not add onboarding steps',
                    message: this.reduceError(error),
                    variant: 'error'
                })
            );
        } finally {
            this.creatingSteps = false;
        }
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
    }
}

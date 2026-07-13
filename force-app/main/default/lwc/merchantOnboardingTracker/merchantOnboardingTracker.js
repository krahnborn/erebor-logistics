import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getOnboardingSummary from '@salesforce/apex/MerchantOnboardingController.getOnboardingSummary';
import createMissingStandardSteps from '@salesforce/apex/MerchantOnboardingController.createMissingStandardSteps';
import createCustomStep from '@salesforce/apex/MerchantOnboardingController.createCustomStep';
import updateStepStatus from '@salesforce/apex/MerchantOnboardingController.updateStepStatus';

const STATUS_OPTIONS = [
    { label: 'Not started', value: 'Not started' },
    { label: 'In Progress', value: 'In Progress' },
    { label: 'Blocked', value: 'Blocked' },
    { label: 'Done', value: 'Done' }
];

export default class MerchantOnboardingTracker extends LightningElement {
    @api recordId;

    summary;
    errorMessage;
    creatingSteps = false;
    creatingCustomStep = false;
    customStepName = '';
    updatingStepIds = [];
    wiredSummary;

    @wire(getOnboardingSummary, { accountId: '$recordId' })
    wiredOnboardingSummary(result) {
        this.wiredSummary = result;
        if (result.data) {
            this.summary = {
                ...result.data,
                steps: (result.data.steps || []).map((step) => this.decorateStep(step))
            };
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

    get statusOptions() {
        return STATUS_OPTIONS;
    }

    get customStepDisabled() {
        return this.creatingCustomStep || !this.customStepName?.trim();
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

    handleCustomStepNameChange(event) {
        this.customStepName = event.target.value;
    }

    async handleCreateCustomStep() {
        if (this.customStepDisabled) {
            return;
        }

        this.creatingCustomStep = true;
        const stepName = this.customStepName.trim();
        try {
            await createCustomStep({ accountId: this.recordId, stepName });
            this.customStepName = '';
            await refreshApex(this.wiredSummary);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Custom onboarding step added',
                    message: `${stepName} is ready to track.`,
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Could not add custom step',
                    message: this.reduceError(error),
                    variant: 'error'
                })
            );
        } finally {
            this.creatingCustomStep = false;
        }
    }

    async handleStatusChange(event) {
        const stepId = event.target.dataset.id;
        const step = this.findStep(stepId);
        await this.saveStep(stepId, event.detail.value, step?.blockedReason);
    }

    async handleBlockedReasonChange(event) {
        const stepId = event.target.dataset.id;
        const blockedReason = event.target.value;
        this.updateLocalStep(stepId, { blockedReason });
    }

    async handleSaveBlockedReason(event) {
        const stepId = event.target.dataset.id;
        const step = this.findStep(stepId);
        await this.saveStep(stepId, 'Blocked', step?.blockedReason);
    }

    async handleMarkInProgress(event) {
        await this.saveStep(event.currentTarget.dataset.id, 'In Progress');
    }

    async handleMarkDone(event) {
        await this.saveStep(event.currentTarget.dataset.id, 'Done');
    }

    async saveStep(stepId, status, blockedReason) {
        if (!stepId || this.isStepUpdating(stepId)) {
            return;
        }

        this.setStepUpdating(stepId, true);
        try {
            await updateStepStatus({ stepId, status, blockedReason });
            await refreshApex(this.wiredSummary);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Onboarding step updated',
                    message: `${this.findStep(stepId)?.name || 'Step'} is now ${status}.`,
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Could not update onboarding step',
                    message: this.reduceError(error),
                    variant: 'error'
                })
            );
            await refreshApex(this.wiredSummary);
        } finally {
            this.setStepUpdating(stepId, false);
        }
    }

    findStep(stepId) {
        return this.summary?.steps?.find((step) => step.id === stepId);
    }

    updateLocalStep(stepId, updates) {
        if (!this.summary?.steps) {
            return;
        }
        this.summary = {
            ...this.summary,
            steps: this.summary.steps.map((step) =>
                step.id === stepId ? this.decorateStep({ ...step, ...updates }) : step
            )
        };
    }

    setStepUpdating(stepId, isUpdating) {
        const ids = new Set(this.updatingStepIds);
        if (isUpdating) {
            ids.add(stepId);
        } else {
            ids.delete(stepId);
        }
        this.updatingStepIds = [...ids];
        this.updateLocalStep(stepId, { isUpdating });
    }

    isStepUpdating(stepId) {
        return this.updatingStepIds.includes(stepId);
    }

    decorateStep(step) {
        const isBlocked = step.status === 'Blocked';
        const isDone = step.status === 'Done';
        return {
            ...step,
            isBlocked,
            isDone,
            isUpdating: this.isStepUpdating(step.id),
            completeDisabled: isDone || this.isStepUpdating(step.id),
            actionLabel: isDone ? 'Completed' : 'Complete',
            blockedReasonInputClass: isBlocked ? 'blocked-input visible' : 'blocked-input'
        };
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
    }
}

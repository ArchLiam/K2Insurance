/**
 * @description Shows the latest saved payout PDF and creates versioned statement Files on request.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { RefreshEvent } from 'lightning/refresh';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import MODIFIED from '@salesforce/schema/Agent_Payout__c.LastModifiedDate';
import getState from '@salesforce/apex/AgentPayoutPdfController.getState';
import generatePdf from '@salesforce/apex/AgentPayoutPdfController.generatePdf';
import title from '@salesforce/label/c.PayoutPdf_Title';
import generate from '@salesforce/label/c.PayoutPdf_Generate';
import regenerate from '@salesforce/label/c.PayoutPdf_Regenerate';
import generating from '@salesforce/label/c.PayoutPdf_Generating';
import open from '@salesforce/label/c.PayoutPdf_Open';
import download from '@salesforce/label/c.PayoutPdf_Download';
import version from '@salesforce/label/c.PayoutPdf_Version';
import generated from '@salesforce/label/c.PayoutPdf_Generated';
import empty from '@salesforce/label/c.PayoutPdf_Empty';
import stale from '@salesforce/label/c.PayoutPdf_Stale';
import voided from '@salesforce/label/c.PayoutPdf_Voided';
import mismatch from '@salesforce/label/c.PayoutPdf_Mismatch';
import loadError from '@salesforce/label/c.PayoutPdf_LoadError';
import large from '@salesforce/label/c.PayoutPdf_Large';
import success from '@salesforce/label/c.PayoutPdf_Success';
import previewTitle from '@salesforce/label/c.PayoutPdf_PreviewTitle';
import refresh from '@salesforce/label/c.PayoutPdf_Refresh';
import unavailable from '@salesforce/label/c.PayoutPdf_Unavailable';

const labels = { title, generate, regenerate, generating, open, download, version, generated, empty, stale, voided, mismatch, loadError, large, success, previewTitle, refresh, unavailable };

export default class AgentPayoutPdf extends NavigationMixin(LightningElement) {
    /** @description The Agent Payout supplied by the record page. */
    @api recordId;
    labels = labels;
    state = {};
    error;
    isGenerating = false;
    isLoading = true;
    modifiedAt;
    stateResult;

    @wire(getState, { payoutId: '$recordId' })
    wiredState(result) {
        this.stateResult = result;
        const { data, error } = result;
        if (data) {
            this.state = data;
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.state = {};
            this.error = this.errorText(error);
            this.isLoading = false;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: [MODIFIED] })
    wiredRecord({ data, error }) {
        if (data) {
            const modified = getFieldValue(data, MODIFIED);
            const changed = this.modifiedAt && this.modifiedAt !== modified;
            this.modifiedAt = modified;
            if (changed && this.stateResult) { this.handleRefresh(); }
        } else if (error) {
            this.error = this.errorText(error);
        }
    }

    get hasFile() { return Boolean(this.state?.versionId); }
    get showEmpty() { return Boolean(this.state && !this.hasFile); }
    get showUnavailable() { return Boolean(this.state && !this.state.canGenerate && !this.state.voided); }
    get showLarge() { return Boolean(this.hasFile && !this.state.inlineAvailable); }
    get isDisabled() { return this.isGenerating || !this.state?.canGenerate; }
    get generateLabel() {
        if (this.isGenerating) { return labels.generating; }
        return this.hasFile ? labels.regenerate : labels.generate;
    }
    get downloadUrl() { return this.hasFile ? '/sfc/servlet.shepherd/version/download/' + this.state.versionId : undefined; }

    /** @description Creates a version only when the user requests it. */
    async handleGenerate() {
        if (this.isDisabled) { return; }
        this.isGenerating = true;
        this.error = undefined;
        try {
            this.state = await generatePdf({ payoutId: this.recordId });
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            this.dispatchEvent(new RefreshEvent());
            await refreshApex(this.stateResult);
            this.dispatchEvent(new ShowToastEvent({ title: labels.title, message: labels.success, variant: 'success' }));
        } catch (error) {
            this.error = this.errorText(error);
        } finally {
            this.isGenerating = false;
        }
    }

    /** @description Refreshes File metadata and source-change detection without generating a PDF. */
    async handleRefresh() {
        try { await refreshApex(this.stateResult); }
        catch (error) { this.error = this.errorText(error); }
    }

    /** @description Opens the same saved File in Salesforce's expanded viewer. */
    handleOpen() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: this.state.documentId, recordIds: this.state.documentId }
        });
    }

    /** @description Embeds an HTTPS Visualforce viewer for the exact stored version under Lightning Web Security. */
    get pdfUrl() {
        if (!this.state?.inlineAvailable || !this.state.versionId) { return undefined; }
        return '/apex/K2AgentPayoutPdfPreview?view=stored&id=' + encodeURIComponent(this.recordId)
            + '&version=' + encodeURIComponent(this.state.versionId);
    }

    /** @description Converts expected wire and imperative error shapes into readable text. */
    errorText(error) {
        if (Array.isArray(error?.body)) { return error.body.map((item) => item.message).join(', '); }
        return error?.body?.message || error?.message || labels.loadError;
    }
}

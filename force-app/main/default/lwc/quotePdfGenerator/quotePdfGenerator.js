/**
 * @description Quote PDF generator placed on the Quote record page. Lets the
 * user preview the K2-branded PDF, save it to the Quote (as a File), or save
 * and email it to the Quote contact.
 * @author Liam Jeong (liam.jeong@5sinfusion.com)
 * @date 2026-05-23
 */
import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";

import QUOTE_NAME from "@salesforce/schema/Quote.Name";
import QUOTE_NUMBER from "@salesforce/schema/Quote.QuoteNumber";
import QUOTE_EMAIL from "@salesforce/schema/Quote.Email";
import QUOTE_CONTACT_NAME from "@salesforce/schema/Quote.Contact.Name";

import generatePdf from "@salesforce/apex/QuotePdfController.generatePdf";
import saveToQuote from "@salesforce/apex/QuotePdfController.saveToQuote";
import saveAndEmail from "@salesforce/apex/QuotePdfController.saveAndEmail";

const RECORD_FIELDS = [QUOTE_NAME, QUOTE_NUMBER, QUOTE_EMAIL, QUOTE_CONTACT_NAME];

export default class QuotePdfGenerator extends NavigationMixin(LightningElement) {
	/** Current Quote Id — provided by the Lightning record page. */
	@api recordId;

	@wire(getRecord, { recordId: "$recordId", fields: RECORD_FIELDS })
	quoteRecord;

	@track pdfDataUrl = null;
	@track fileName = null;
	@track isPreviewOpen = false;
	@track isEmailOpen = false;

	_currentBlobUrl = null;

	@track emailTo = "";
	@track emailSubject = "";
	@track emailBody = "";

	isGenerating = false;
	isSaving = false;
	isSendingEmail = false;
	errorMessage = null;

	// ─── Computed getters ─────────────────────────────────────────────────────

	get quoteNumber() {
		return getFieldValue(this.quoteRecord.data, QUOTE_NUMBER) || "";
	}

	get contactEmail() {
		return getFieldValue(this.quoteRecord.data, QUOTE_EMAIL) || "";
	}

	get contactName() {
		return getFieldValue(this.quoteRecord.data, QUOTE_CONTACT_NAME) || "";
	}

	get previewLabel() {
		return this.isGenerating ? "Generating..." : "Preview PDF";
	}

	get saveLabel() {
		return this.isSaving ? "Saving..." : "Save to Quote";
	}

	get sendEmailLabel() {
		return this.isSendingEmail ? "Sending..." : "Save and Email Quote";
	}

	get isPreviewBusy() {
		return this.isGenerating || this.isSaving;
	}

	// ─── Actions ──────────────────────────────────────────────────────────────

	async handlePreview() {
		this.errorMessage = null;
		this.isGenerating = true;
		try {
			const result = await generatePdf({ quoteId: this.recordId });
			// Chrome blocks PDF rendering inside iframes when the src is a
			// `data:` URL. Decode the base64 into a Blob and use a Blob URL
			// so the iframe can render it.
			this.revokeBlobUrl();
			const binary = atob(result.base64);
			const bytes = new Uint8Array(binary.length);
			for (let i = 0; i < binary.length; i++) {
				bytes[i] = binary.charCodeAt(i);
			}
			const blob = new Blob([bytes], { type: "application/pdf" });
			this._currentBlobUrl = URL.createObjectURL(blob);
			this.pdfDataUrl = this._currentBlobUrl;
			this.fileName = result.fileName;
			this.isPreviewOpen = true;
		} catch (error) {
			this.errorMessage = this.readError(error);
			this.toast("Error", this.errorMessage, "error");
		} finally {
			this.isGenerating = false;
		}
	}

	revokeBlobUrl() {
		if (this._currentBlobUrl) {
			URL.revokeObjectURL(this._currentBlobUrl);
			this._currentBlobUrl = null;
		}
	}

	disconnectedCallback() {
		this.revokeBlobUrl();
	}

	async handleSaveToQuote() {
		this.errorMessage = null;
		this.isSaving = true;
		try {
			const result = await saveToQuote({ quoteId: this.recordId });
			this.toast(
				"Saved",
				`${result.fileName} attached to this Quote.`,
				"success"
			);
			this.isPreviewOpen = false;
		} catch (error) {
			this.errorMessage = this.readError(error);
			this.toast("Error", this.errorMessage, "error");
		} finally {
			this.isSaving = false;
		}
	}

	handleOpenEmail() {
		this.emailTo = this.contactEmail;
		this.emailSubject = `Your K2 Insurance Quote ${this.quoteNumber}`.trim();
		this.emailBody =
			`<p>Hello${this.contactName ? " " + this.contactName : ""},</p>` +
			"<p>Please find your K2 Insurance quote attached. " +
			"Let us know if you have any questions.</p>" +
			"<p>Thank you,<br/>K2 Insurance</p>";
		this.isEmailOpen = true;
	}

	handleEmailToChange(event) {
		this.emailTo = event.target.value;
	}

	handleEmailSubjectChange(event) {
		this.emailSubject = event.target.value;
	}

	handleEmailBodyChange(event) {
		this.emailBody = event.detail.value;
	}

	async handleSendEmail() {
		this.errorMessage = null;
		if (!this.emailTo) {
			this.toast("Missing", "Recipient email is required.", "warning");
			return;
		}
		if (!this.emailSubject) {
			this.toast("Missing", "Subject is required.", "warning");
			return;
		}
		this.isSendingEmail = true;
		try {
			const result = await saveAndEmail({
				quoteId: this.recordId,
				toAddress: this.emailTo,
				subject: this.emailSubject,
				htmlBody: this.emailBody,
				orgWideEmailAddressId: null
			});
			this.toast(
				"Sent",
				`${result.fileName} sent to ${this.emailTo}.`,
				"success"
			);
			this.isEmailOpen = false;
			this.isPreviewOpen = false;
		} catch (error) {
			this.errorMessage = this.readError(error);
			this.toast("Error", this.errorMessage, "error");
		} finally {
			this.isSendingEmail = false;
		}
	}

	handleClosePreview() {
		this.isPreviewOpen = false;
		this.pdfDataUrl = null;
		this.revokeBlobUrl();
	}

	handleCloseEmail() {
		this.isEmailOpen = false;
	}

	// ─── Utilities ────────────────────────────────────────────────────────────

	readError(error) {
		if (error?.body?.message) return error.body.message;
		if (error?.message) return error.message;
		return "An unexpected error occurred.";
	}

	toast(title, message, variant) {
		this.dispatchEvent(
			new ShowToastEvent({ title, message, variant })
		);
	}
}

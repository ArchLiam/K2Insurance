/**
 * @description Modernized single-contact email composer for the Contact record page.
 * Lets the user pick a Lightning email template, edit the resolved subject and body,
 * and send directly to the contact — optionally saving it as an Activity.
 * @author Liam Jeong (liam.jeong@5sinfusion.com)
 * @date 2026-03-16
 */
import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import userId from "@salesforce/user/Id";

import CONTACT_NAME from "@salesforce/schema/Contact.Name";
import CONTACT_EMAIL from "@salesforce/schema/Contact.Email";
import CONTACT_PHONE from "@salesforce/schema/Contact.Phone";
import CONTACT_KOREAN_NAME from "@salesforce/schema/Contact.Korean_Name__c";
import LEAD_NAME from "@salesforce/schema/Lead.Name";
import LEAD_EMAIL from "@salesforce/schema/Lead.Email";
import LEAD_PHONE from "@salesforce/schema/Lead.Phone";
import USER_NAME from "@salesforce/schema/User.Name";
import USER_EMAIL from "@salesforce/schema/User.Email";

import getEmailTemplates from "@salesforce/apex/EmailComposerController.getEmailTemplates";
import getOrgWideEmailAddresses from "@salesforce/apex/EmailComposerController.getOrgWideEmailAddresses";
import getTemplateContent from "@salesforce/apex/EmailComposerController.getTemplateContent";
import sendEmail from "@salesforce/apex/EmailComposerController.sendEmail";

const RECORD_FIELDS = [
	CONTACT_NAME,
	CONTACT_EMAIL,
	CONTACT_PHONE,
	CONTACT_KOREAN_NAME,
	LEAD_NAME,
	LEAD_EMAIL,
	LEAD_PHONE,
];

export default class EmailComposer extends LightningElement {
	/** Current record Id — provided by the Lightning record page (Contact or Lead). */
	@api recordId;

	/** Wire: fetch record fields for the recipient info header (Contact or Lead). */
	@wire(getRecord, { recordId: "$recordId", optionalFields: RECORD_FIELDS })
	record;

	/** Wire: load all active email templates for the template picker. */
	@wire(getEmailTemplates)
	wiredTemplates({ error, data }) {
		if (data) {
			this.templateOptions = data.map((t) => ({
				label: t.label,
				value: t.templateId,
			}));
		} else if (error) {
			this.errorMessage = this.normalizeError(error);
		}
	}

	/** Wire: fetch current user name and email for the Send From default option. */
	@wire(getRecord, { recordId: userId, fields: [USER_NAME, USER_EMAIL] })
	wiredUser({ data }) {
		if (data) {
			this._currentUserLabel =
				getFieldValue(data, USER_NAME) +
				" <" +
				getFieldValue(data, USER_EMAIL) +
				">";
			this._rebuildSenderOptions();
		}
	}

	/** Wire: load org-wide email addresses for the Send From picker. */
	@wire(getOrgWideEmailAddresses)
	wiredSenders({ data, error }) {
		if (data) {
			this._owaOptions = data.map((s) => ({ label: s.label, value: s.id }));
		} else if (error) {
			this._owaOptions = [];
		}
		this._rebuildSenderOptions();
	}

	_currentUserLabel = "Current User";
	_owaOptions = [];

	_rebuildSenderOptions() {
		this.senderOptions = [
			{ label: this._currentUserLabel, value: "" },
			...this._owaOptions,
		];
	}

	@track templateOptions = [];
	@track senderOptions = [{ label: "Current User", value: "" }];

	selectedTemplateId = null;
	selectedSendFromId = "";
	editableSubject = "";
	editableBody = "";
	isTemplateLoading = false;
	isSending = false;
	errorMessage = null;
	successMessage = null;

	// ─── Record field getters (Contact or Lead) ───────────────────────────────

	get contactName() {
		return (
			getFieldValue(this.record.data, CONTACT_NAME) ||
			getFieldValue(this.record.data, LEAD_NAME) ||
			""
		);
	}

	get contactEmail() {
		return (
			getFieldValue(this.record.data, CONTACT_EMAIL) ||
			getFieldValue(this.record.data, LEAD_EMAIL) ||
			""
		);
	}

	get contactPhone() {
		return (
			getFieldValue(this.record.data, CONTACT_PHONE) ||
			getFieldValue(this.record.data, LEAD_PHONE) ||
			""
		);
	}

	get contactKoreanName() {
		return getFieldValue(this.record.data, CONTACT_KOREAN_NAME) || "";
	}

	get hasEmail() {
		return !!this.contactEmail;
	}

	get hasPhone() {
		return !!this.contactPhone;
	}

	get hasKoreanName() {
		return !!this.contactKoreanName;
	}

	// ─── UI state getters ─────────────────────────────────────────────────────

	/** Allowed rich-text formats for the body editor. */
	get richTextFormats() {
		return [
			"bold",
			"italic",
			"underline",
			"strike",
			"list",
			"indent",
			"align",
			"link",
			"clean",
		];
	}

	get rteClass() {
		return this.isTemplateLoading ? "rteHidden" : "";
	}

	get sendDisabled() {
		return (
			this.isSending ||
			!this.contactEmail ||
			!this.editableSubject.trim()
		);
	}

	get sendLabel() {
		return this.isSending ? "Sending..." : "Send Email";
	}

	// ─── Event handlers ───────────────────────────────────────────────────────

	/**
	 * Handles template picker change: loads the resolved template content from Apex
	 * and pre-populates the subject and body editors.
	 */
	async handleTemplateChange(event) {
		this.selectedTemplateId = event.detail.value;
		this.errorMessage = null;
		this.successMessage = null;

		if (!this.selectedTemplateId) {
			this.editableSubject = "";
			this.editableBody = "";
			return;
		}

		this.isTemplateLoading = true;
		try {
			const result = await getTemplateContent({
				templateId: this.selectedTemplateId,
				recordId: this.recordId,
			});

			if (result.success) {
				this.editableSubject = result.subject || "";
				this.editableBody =
					result.htmlBody ||
					this.plainToHtml(result.plainTextBody || "");
				// Quill defers visual rendering until it receives focus.
				// focus() + blur() after the finally block (isTemplateLoading=false)
				// forces Quill to paint without stealing the user's focus.
				// eslint-disable-next-line @lwc/lwc/no-async-operation
				setTimeout(() => {
					const rte = this.template.querySelector(
						"lightning-input-rich-text"
					);
					if (rte) {
						rte.focus();
						rte.blur();
					}
				}, 0);
			} else {
				this.errorMessage =
					result.message || "Failed to load template content.";
			}
		} catch (error) {
			this.errorMessage = this.normalizeError(error);
		} finally {
			this.isTemplateLoading = false;
		}
	}

	/** Keeps editableSubject in sync with the native <input> in real time. */
	handleSubjectInput(event) {
		this.editableSubject = event.target.value;
	}

	/** Keeps editableBody in sync when the rich-text editor changes. */
	handleBodyChange(event) {
		this.editableBody = event.detail.value;
	}

	/** Updates the selected Send From org-wide address. */
	handleSendFromChange(event) {
		this.selectedSendFromId = event.detail.value;
	}

	/** Validates and sends the email via Apex. Shows a toast on success. */
	async handleSend() {
		this.errorMessage = null;
		this.successMessage = null;

		if (!this.contactEmail) {
			this.errorMessage =
				"This record does not have an email address. Add one before sending.";
			return;
		}

		if (!this.editableSubject.trim()) {
			this.errorMessage = "Please enter a subject before sending.";
			return;
		}

		this.isSending = true;
		try {
			await sendEmail({
				recordId: this.recordId,
				toAddress: this.contactEmail,
				subject: this.editableSubject,
				htmlBody: this.editableBody,
				orgWideEmailAddressId: this.selectedSendFromId || null,
			});

			this.successMessage = `Email sent to ${this.contactEmail}.`;
			this.dispatchEvent(
				new ShowToastEvent({
					title: "Email Sent",
					message: `Email sent to ${this.contactEmail}.`,
					variant: "success",
				}),
			);

			// Reset composer after a successful send.
			this.editableSubject = "";
			this.editableBody = "";
			this.selectedTemplateId = null;
		} catch (error) {
			this.errorMessage = this.normalizeError(error);
		} finally {
			this.isSending = false;
		}
	}

	// ─── Lifecycle ────────────────────────────────────────────────────────────

	/**
	 * Injects a global style to override the internal editor height of
	 * lightning-input-rich-text, which cannot be controlled via external CSS
	 * due to Salesforce synthetic shadow DOM.
	 */
	renderedCallback() {
		// Inject RTE height styles once.
		const styleId = "email-composer-rte-height";
		if (!document.getElementById(styleId)) {
			const style = document.createElement("style");
			style.id = styleId;
			style.textContent = [
				".slds-rich-text-editor__textarea { height: 600px !important; min-height: 600px !important; }",
				".slds-rich-text-editor__textarea .ql-container { height: 100% !important; box-sizing: border-box; }",
				".slds-rich-text-editor__textarea .ql-editor { min-height: 560px !important; height: auto !important; box-sizing: border-box; }",
			].join(" ");
			document.head.appendChild(style);
		}

	}

	// ─── Utilities ────────────────────────────────────────────────────────────

	/** Converts a plain-text string to simple HTML paragraph elements. */
	plainToHtml(text) {
		if (!text) return "";
		return text
			.split("\n")
			.map((line) => `<p>${line || "&nbsp;"}</p>`)
			.join("");
	}

	/** Extracts a readable message from Apex or LWC error objects. */
	normalizeError(error) {
		if (error?.body?.message) return error.body.message;
		if (error?.message) return error.message;
		return "An unexpected error occurred.";
	}
}
import { LightningElement, api, track } from "lwc";
import getInitData from "@salesforce/apex/InsuranceMassEmailController.getInitData";
import getTemplatePreview from "@salesforce/apex/InsuranceMassEmailController.getTemplatePreview";
import enqueueSendEmails from "@salesforce/apex/InsuranceMassEmailController.enqueueSendEmails";

export default class InsuranceMassEmail extends LightningElement {
	@api selectedIds = [];

	@track recipients = [];
	@track templateOptions = [];

	selectedTemplateId;
	saveAsActivity = true;
	selectedCount = 0;
	validCount = 0;
	skippedCount = 0;
	isLoaded = false;
	errorMessage;
	successMessage;

	previewTemplateName;
	previewSubject;
	previewHtmlBody;
	previewPlainTextBody;
	previewMessage;
	isPreviewLoading = false;

	columns = [
		{ label: "Insurance", fieldName: "insuranceName" },
		{ label: "Policy Holder", fieldName: "contactName" },
		{ label: "Email", fieldName: "contactEmail" },
		{ label: "Status", fieldName: "status" },
	];

	connectedCallback() {
		this.loadData();
	}

	get sendDisabled() {
		return !this.selectedTemplateId || this.validCount === 0;
	}

	get showPreviewSection() {
		return !!this.selectedTemplateId;
	}

	get showPreviewContent() {
		return !!this.previewSubject || !!this.previewBodyToDisplay;
	}

	get previewBodyToDisplay() {
		return this.previewHtmlBody || this.previewPlainTextBody || "";
	}

	get hasPreviewHtml() {
		return !!this.previewHtmlBody;
	}

	get displayedRecipients() {
		return (this.recipients || []).slice(0, 20);
	}

	get displayedRecipientCount() {
		return this.displayedRecipients.length;
	}

	async loadData() {
		try {
			const response = await getInitData({
				insuranceIds: this.selectedIds,
			});
			this.selectedCount = response.selectedCount;
			this.validCount = response.validCount;
			this.skippedCount = response.skippedCount;
			this.recipients = response.recipients || [];
			this.templateOptions = (response.templates || []).map(
				(templateRecord) => ({
					label: templateRecord.label,
					value: templateRecord.templateId,
				}),
			);
			this.errorMessage = null;
		} catch (error) {
			this.errorMessage = this.normalizeError(error);
		} finally {
			this.isLoaded = true;
		}
	}

	async handleTemplateChange(event) {
		this.selectedTemplateId = event.detail.value;
		this.clearPreview();

		if (!this.selectedTemplateId) {
			return;
		}

		await this.loadPreview();
	}

	handleSaveAsActivityChange(event) {
		this.saveAsActivity = event.target.checked;
	}

	async loadPreview() {
		this.isPreviewLoading = true;
		this.previewMessage = null;

		try {
			const result = await getTemplatePreview({
				templateId: this.selectedTemplateId,
			});

			if (result && result.success) {
				this.previewTemplateName = result.templateName;
				this.previewSubject = result.subject;
				this.previewHtmlBody = result.htmlBody;
				this.previewPlainTextBody = result.plainTextBody;
				this.previewMessage = result.message;
			} else {
				this.previewTemplateName = null;
				this.previewSubject = null;
				this.previewHtmlBody = null;
				this.previewPlainTextBody = null;
				this.previewMessage = result ? result.message : null;
			}
		} catch (error) {
			this.previewTemplateName = null;
			this.previewSubject = null;
			this.previewHtmlBody = null;
			this.previewPlainTextBody = null;
			this.previewMessage = this.normalizeError(error);
		} finally {
			this.isPreviewLoading = false;
		}
	}

	clearPreview() {
		this.previewTemplateName = null;
		this.previewSubject = null;
		this.previewHtmlBody = null;
		this.previewPlainTextBody = null;
		this.previewMessage = null;
		this.isPreviewLoading = false;
	}

	async handleSend() {
		this.successMessage = null;
		this.errorMessage = null;

		try {
			const message = await enqueueSendEmails({
				insuranceIds: this.selectedIds,
				templateId: this.selectedTemplateId,
				saveAsActivity: this.saveAsActivity,
			});

			this.successMessage = message;
		} catch (error) {
			this.errorMessage = this.normalizeError(error);
		}
	}

	normalizeError(error) {
		if (error?.body?.message) {
			return error.body.message;
		}
		if (error?.message) {
			return error.message;
		}
		return "An unexpected error occurred.";
	}
}
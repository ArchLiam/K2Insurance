import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import sendContactEmail from "@salesforce/apex/PortfolioContactController.sendContactEmail";

const DEFAULT_SUBJECT = "Portfolio contact";

export default class PortfolioContact extends LightningElement {
	// =========================
	// Configurable properties
	// =========================
	@api pageTitle = "Contact";
	@api pageSubtitle =
		"Tell me about your Salesforce project, partnership idea, or team need.";
	@api recipientEmail = "dev.liam.jeong@gmail.com";
	@api linkedInProfileUrl =
		"https://www.linkedin.com/in/liam-jeong-b009b2189/";
	@api availabilityText =
		"Currently accepting new projects and collaborations.";
	@api responseTime = "Typically responds within 1 business day.";
	@api locationText = "United States · Remote friendly";
	@api statusLabel = "Open for new work";

	// =========================
	// Component state
	// =========================
	form = {
		name: "",
		email: "",
		subject: "",
		message: "",
	};

	errors = {};
	isSubmitting = false;
	statusMessage = "";
	statusVariant = "";

	get submitLabel() {
		return this.isSubmitting ? "Sending..." : "Send message";
	}

	get nameClass() {
		return this.errors.name ? "input-control has-error" : "input-control";
	}

	get emailClass() {
		return this.errors.email ? "input-control has-error" : "input-control";
	}

	get subjectClass() {
		return this.errors.subject
			? "input-control has-error"
			: "input-control";
	}

	get messageClass() {
		return this.errors.message
			? "input-control has-error"
			: "input-control";
	}

	get statusClass() {
		return this.statusVariant === "success"
			? "form-status form-status--success"
			: "form-status form-status--error";
	}

	handleInputChange(event) {
		const { name, value } = event.target;
		this.form = { ...this.form, [name]: value };
		this.errors = { ...this.errors, [name]: "" };
	}

	validate() {
		const nextErrors = {};
		const name = this.form.name?.trim();
		const email = this.form.email?.trim();
		const subject = this.form.subject?.trim();
		const message = this.form.message?.trim();

		if (!name) {
			nextErrors.name = "Please enter your name.";
		} else if (name.length > 120) {
			nextErrors.name = "Name must be 120 characters or fewer.";
		}

		if (!email) {
			nextErrors.email = "Please enter your email.";
		}

		if (!subject) {
			nextErrors.subject = "Please add a subject.";
		} else if (subject.length > 255) {
			nextErrors.subject = "Subject must be 255 characters or fewer.";
		}

		if (message && message.length > 3900) {
			nextErrors.message = "Message is too long. Please shorten it.";
		}

		this.errors = nextErrors;
		return Object.keys(nextErrors).length === 0;
	}

	async handleSubmit(event) {
		event.preventDefault();
		this.statusMessage = "";
		this.statusVariant = "";

		if (!this.validate()) {
			return;
		}

		this.isSubmitting = true;

		try {
			await sendContactEmail({
				name: this.form.name?.trim(),
				email: this.form.email?.trim(),
				subject: this.form.subject?.trim() || DEFAULT_SUBJECT,
				message: this.form.message?.trim(),
				toAddress: this.recipientEmail,
			});
			``;

			this.statusMessage =
				"Thanks for reaching out! I've received your message and will respond shortly.";
			this.statusVariant = "success";
			this.showToast("Message sent", this.statusMessage, "success");
			this.form = { name: "", email: "", subject: "", message: "" };
		} catch (error) {
			const serverMessage =
				error?.body?.message ||
				"Unable to send your message right now. Please try again soon.";

			this.statusMessage = serverMessage;
			this.statusVariant = "error";
			this.showToast("Message not sent", serverMessage, "error");
		} finally {
			this.isSubmitting = false;
		}
	}

	showToast(title, message, variant) {
		this.dispatchEvent(
			new ShowToastEvent({
				title,
				message,
				variant,
				mode: "dismissable",
			})
		);
	}
}
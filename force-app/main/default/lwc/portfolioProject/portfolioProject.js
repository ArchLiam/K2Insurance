import { LightningElement, api } from "lwc";
import templateFeatured from "./portfolioProject.html";
import templateSummary from "./portfolioProjectSummary.html";

const DEFAULT_PROJECT = {
	title: "Project Title",
	role: "Role / Capacity",
	meta: "Client • Year • Location",
	description: "Short description of the project and your impact.",
	highlights: [],
	tags: [],
	ctaLabel: null,
	ctaUrl: null,
};

export default class PortfolioProject extends LightningElement {
	/**
	 * Render variant. Accepts "featured" (default) or "summary".
	 * @type {"featured" | "summary"}
	 */
	@api status = "featured";

	/**
	 * Project content. Provide a shape similar to DEFAULT_PROJECT.
	 * @type {Object}
	 */
	@api project = DEFAULT_PROJECT;

	/**
	 * When true, the card is clickable and emits projectselect.
	 * @type {boolean}
	 */
	@api selectable = false;

	get projectClass() {
		return `project project--${this.status} ${
			this.selectable ? "project--clickable" : ""
		}`;
	}

	get computedTabIndex() {
		return this.selectable ? "0" : null;
	}

	get computedRole() {
		return this.selectable ? "button" : null;
	}

	get ariaLabel() {
		return this.selectable
			? `${this.project?.title || "Project"} – open details`
			: null;
	}

	get hasHighlights() {
		return Array.isArray(this.project?.highlights) && this.project.highlights.length > 0;
	}

	get hasTags() {
		return Array.isArray(this.project?.tags) && this.project.tags.length > 0;
	}

	get hasCta() {
		return Boolean(this.project?.ctaUrl && this.project?.ctaLabel);
	}

	get screenshotLabel() {
		return `${this.project?.title || "Project"} screenshot placeholder`;
	}

	handleSelect(event) {
		if (!this.selectable) return;
		event.preventDefault();
		this.dispatchEvent(
			new CustomEvent("projectselect", {
				detail: { project: this.project },
				bubbles: true,
				composed: true,
			})
		);
	}

	handleKeydown(event) {
		if (!this.selectable) return;
		const { key } = event;
		if (key === "Enter" || key === " ") {
			event.preventDefault();
			this.handleSelect(event);
		}
	}

	render() {
		return this.status === "summary" ? templateSummary : templateFeatured;
	}
}
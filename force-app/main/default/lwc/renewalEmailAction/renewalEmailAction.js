/**
 * @description Headless quick action for the Renewal (Opportunity). Opens the standard
 * Salesforce email composer with the policy holder already in the To field and the Renewal
 * set as Related To, so the {{{Opportunity.*}}} merge fields in the renewal templates resolve.
 *
 * The standard Email action does not prefill a recipient on Opportunity (there is no Contact
 * on the record), and predefined field values on an Email quick action only apply while the
 * record has no existing email thread — so the recipient is supplied here instead.
 *
 * @author Liam Jeong (liam.jeong@5sinfusion.com)
 * @date 2026-09-08
 */
import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import POLICY_HOLDER_EMAIL from "@salesforce/schema/Opportunity.Policy_Holder_Email__c";
import POLICY_HOLDER_NAME from "@salesforce/schema/Opportunity.Policy_Holder_Name__c";

const FIELDS = [POLICY_HOLDER_EMAIL, POLICY_HOLDER_NAME];

export default class RenewalEmailAction extends NavigationMixin(LightningElement) {
	/** Renewal Opportunity Id — supplied by the quick action. */
	@api recordId;

	_wireResult;
	_invoked = false;
	_opened = false;

	@wire(getRecord, { recordId: "$recordId", fields: FIELDS })
	wiredRecord(result) {
		this._wireResult = result;
		this.openComposerWhenReady();
	}

	/** Quick action entry point. Salesforce calls this when the button is clicked. */
	@api
	invoke() {
		this._invoked = true;
		this.openComposerWhenReady();
	}

	/**
	 * invoke() and the wire can settle in either order, so both call in here and the
	 * composer opens once — as soon as the click and the record data have both arrived.
	 */
	openComposerWhenReady() {
		if (this._opened || !this._invoked || !this._wireResult) {
			return;
		}
		const { data, error } = this._wireResult;
		if (!data && !error) {
			return; // wire still in flight
		}
		this._opened = true;

		if (error) {
			this.toast(
				"Couldn't read the Renewal",
				"The renewal record could not be loaded, so the recipient wasn't filled in.",
				"error",
			);
			this.openComposer(null);
			return;
		}

		const email = getFieldValue(data, POLICY_HOLDER_EMAIL);
		if (!email) {
			const name = getFieldValue(data, POLICY_HOLDER_NAME);
			this.toast(
				"No email on file",
				`${name || "The policy holder"} has no email address on their Contact record. Add one, or type the address in the composer.`,
				"warning",
			);
		}
		this.openComposer(email);
	}

	/** Opens the standard email composer, prefilled where possible. */
	openComposer(email) {
		const defaults = { RelatedToId: this.recordId };
		if (email) {
			defaults.ToAddress = email;
		}

		this[NavigationMixin.Navigate]({
			type: "standard__quickAction",
			attributes: { apiName: "Global.SendEmail" },
			state: {
				recordId: this.recordId,
				defaultFieldValues: encodeDefaultFieldValues(defaults),
			},
		});
	}

	toast(title, message, variant) {
		this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
	}
}

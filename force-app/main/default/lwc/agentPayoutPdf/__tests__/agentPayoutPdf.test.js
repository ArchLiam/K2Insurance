import { createElement } from 'lwc';
import AgentPayoutPdf from 'c/agentPayoutPdf';
import getState from '@salesforce/apex/AgentPayoutPdfController.getState';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import generatePdf from '@salesforce/apex/AgentPayoutPdfController.generatePdf';
import { refreshApex } from '@salesforce/apex';

jest.mock('@salesforce/apex/AgentPayoutPdfController.getState', () => {
    const { createApexTestWireAdapter } = require('@salesforce/wire-service-jest-util');
    return { __esModule: true, default: createApexTestWireAdapter(jest.fn()) };
}, { virtual: true });
jest.mock('@salesforce/apex/AgentPayoutPdfController.generatePdf', () => ({ __esModule: true, default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex', () => ({ refreshApex: jest.fn(() => Promise.resolve()) }), { virtual: true });

const saved = { documentId: '069000000000001AAA', versionId: '068000000000001AAA', versionNumber: '1', generatedAt: '2026-09-29T12:00:00.000Z', canGenerate: true, inlineAvailable: true, stale: false, voided: false };
const flush = () => Promise.resolve().then(() => Promise.resolve()).then(() => Promise.resolve());
function mount() {
    const element = createElement('c-agent-payout-pdf', { is: AgentPayoutPdf });
    element.recordId = 'a00000000000001AAA';
    document.body.appendChild(element);
    return element;
}

describe('c-agent-payout-pdf', () => {
    beforeEach(() => {
        generatePdf.mockResolvedValue(saved);
    });
    afterEach(() => {
        while (document.body.firstChild) { document.body.removeChild(document.body.firstChild); }
        jest.clearAllMocks();
    });

    it('does not generate or save a PDF on page load', async () => {
        const element = mount();
        getState.emit({ canGenerate: true, inlineAvailable: false });
        await flush();
        expect(generatePdf).not.toHaveBeenCalled();
        expect(element.shadowRoot.querySelector('iframe')).toBeNull();
        expect(element.shadowRoot.querySelector('[data-action="generate"]').disabled).toBe(false);
    });

    it('embeds the saved version and downloads that same version', async () => {
        const element = mount();
        getState.emit(saved);
        await flush();
        expect(element.shadowRoot.querySelector('iframe').src).toContain('/apex/K2AgentPayoutPdfPreview?view=stored&id=' + element.recordId + '&version=' + saved.versionId);
        expect(element.shadowRoot.querySelector('a').href).toContain(saved.versionId);
        expect(generatePdf).not.toHaveBeenCalled();
    });

    it('generates once on click and refreshes saved metadata', async () => {
        const element = mount();
        getState.emit({ canGenerate: true, inlineAvailable: false });
        await flush();
        const button = element.shadowRoot.querySelector('[data-action="generate"]');
        button.click();
        button.click();
        await flush();
        expect(generatePdf).toHaveBeenCalledTimes(1);
        expect(refreshApex).toHaveBeenCalled();
        expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([{ recordId: element.recordId }]);
        expect(button.disabled).toBe(false);
        expect(element.shadowRoot.querySelector('iframe').src).toContain('/apex/K2AgentPayoutPdfPreview?view=stored&id=' + element.recordId + '&version=' + saved.versionId);
    });

    it('switches the HTTPS viewer to the newly saved version', async () => {
        const element = mount();
        getState.emit(saved);
        await flush();
        getState.emit({ ...saved, versionId: '068000000000002AAA', versionNumber: '2' });
        await flush();
        expect(element.shadowRoot.querySelector('iframe').src).toContain('version=068000000000002AAA');
    });

    it('retains the archived preview but disables generation after voiding', async () => {
        const element = mount();
        getState.emit({ ...saved, voided: true, stale: true, canGenerate: false });
        await flush();
        expect(element.shadowRoot.querySelector('[data-action="generate"]').disabled).toBe(true);
        expect(element.shadowRoot.querySelectorAll('[role="status"]').length).toBe(2);
        expect(element.shadowRoot.querySelector('iframe')).not.toBeNull();
    });

    it('offers the expanded viewer for a file too large for inline transfer', async () => {
        const element = mount();
        getState.emit({ ...saved, inlineAvailable: false });
        await flush();
        expect(element.shadowRoot.querySelector('[data-action="open"]')).not.toBeNull();
    });

    it('surfaces generation failures and re-enables the button', async () => {
        const element = mount();
        getState.emit(saved);
        await flush();
        generatePdf.mockRejectedValue({ body: { message: 'Could not save' } });
        element.shadowRoot.querySelector('[data-action="generate"]').click();
        await flush();
        expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe('Could not save');
        expect(element.shadowRoot.querySelector('[data-action="generate"]').disabled).toBe(false);
    });

    it('shows a controlled error when metadata is inaccessible', async () => {
        const element = mount();
        getState.error({ message: 'Access denied' });
        await flush();
        expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toContain('Access denied');
        expect(element.shadowRoot.querySelector('iframe')).toBeNull();
    });
});

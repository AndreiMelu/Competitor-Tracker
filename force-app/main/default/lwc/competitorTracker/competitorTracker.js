import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';

import searchCompetitors from '@salesforce/apex/CompetitorTrackerController.searchCompetitors';
import linkCompetitor from '@salesforce/apex/CompetitorTrackerController.linkCompetitor';
import getLinkedCompetitors from '@salesforce/apex/CompetitorTrackerController.getLinkedCompetitors';
import updateLink from '@salesforce/apex/CompetitorTrackerController.updateLink';
import removeLink from '@salesforce/apex/CompetitorTrackerController.removeLink';
import getStats from '@salesforce/apex/CompetitorTrackerController.getStats';

const THREAT_LEVEL_OPTIONS = [
    { label: 'Low', value: 'Low' },
    { label: 'Medium', value: 'Medium' },
    { label: 'High', value: 'High' }
];

const LOSS_REASON_OPTIONS = [
    { label: '--None--', value: '' },
    { label: 'Price', value: 'Price' },
    { label: 'Features', value: 'Features' },
    { label: 'Relationship', value: 'Relationship' },
    { label: 'Other', value: 'Other' }
];

const SEARCH_DELAY = 300;
const SEARCH_MIN_LENGTH = 2;
const NOTES_TRUNCATE_LENGTH = 80;

export default class CompetitorTracker extends LightningElement {
    @api recordId;

    threatLevelOptions = THREAT_LEVEL_OPTIONS;
    lossReasonOptions = LOSS_REASON_OPTIONS;

    searchTerm = '';
    searchResults = [];
    selectedCompetitor;
    newThreatLevel = 'Medium';

    rows = [];
    isLoading = false;
    wiredLinksResult;

    searchTimeout;

    @wire(getLinkedCompetitors, { opportunityId: '$recordId' })
    wiredLinks(result) {
        this.wiredLinksResult = result;
        if (result.data) {
            this.rows = result.data.map((rec) => this.toRow(rec));
        } else if (result.error) {
            this.notifyError('Unable to load linked competitors', result.error);
        }
    }

    toRow(rec) {
        const notes = rec.Notes__c || '';
        return {
            id: rec.Id,
            competitorId: rec.Competitor__c,
            competitorName: rec.Competitor__r ? rec.Competitor__r.Name : '',
            threatLevel: rec.Threat_Level__c,
            lossReason: rec.Loss_Reason__c || '',
            notes,
            truncatedNotes:
                notes.length > NOTES_TRUNCATE_LENGTH
                    ? notes.substring(0, NOTES_TRUNCATE_LENGTH) + '…'
                    : notes,
            threatBadgeClass: this.threatClass(rec.Threat_Level__c),
            isEditing: false,
            isExpanded: false,
            expandIcon: 'utility:chevronright',
            stats: undefined
        };
    }

    threatClass(level) {
        if (level === 'High') return 'threat-badge threat-high';
        if (level === 'Medium') return 'threat-badge threat-medium';
        if (level === 'Low') return 'threat-badge threat-low';
        return 'threat-badge';
    }

    // Search method
    handleSearchInput(event) {
        const value = event.target.value;
        this.searchTerm = value;
        window.clearTimeout(this.searchTimeout);

        if (!value || value.trim().length < SEARCH_MIN_LENGTH) {
            this.searchResults = [];
            return;
        }

        this.searchTimeout = window.setTimeout(() => {
            this.runSearch(value);
        }, SEARCH_DELAY);
    }

    runSearch(term) {
        searchCompetitors({ searchTerm: term })
            .then((data) => {
                this.searchResults = data;
            })
            .catch((error) => {
                this.notifyError('Search failed', error);
            });
    }

    handleSelectCompetitor(event) {
        const id = event.currentTarget.dataset.id;
        const found = this.searchResults.find((c) => c.Id === id);
        if (found) {
            this.selectedCompetitor = { id: found.Id, name: found.Name };
            this.searchResults = [];
            this.searchTerm = found.Name;
        }
    }

    handleClearSelection() {
        this.selectedCompetitor = undefined;
        this.searchTerm = '';
        this.searchResults = [];
    }

    handleNewThreatLevelChange(event) {
        this.newThreatLevel = event.detail.value;
    }

    get isLinkDisabled() {
        return !this.selectedCompetitor || !this.newThreatLevel || this.isLoading;
    }

    get hasSearchResults() {
        return this.searchResults && this.searchResults.length > 0;
    }

    get hasRows() {
        return this.rows && this.rows.length > 0;
    }

    handleLink() {
        if (!this.selectedCompetitor) {
            return;
        }
        this.isLoading = true;
        linkCompetitor({
            opportunityId: this.recordId,
            competitorId: this.selectedCompetitor.id,
            threatLevel: this.newThreatLevel
        })
            .then(() => {
                this.notifySuccess('Competitor linked');
                this.handleClearSelection();
                this.newThreatLevel = 'Medium';
                return refreshApex(this.wiredLinksResult);
            })
            .catch((error) => {
                this.notifyError('Unable to link competitor', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleToggleExpand(event) {
        const id = event.currentTarget.dataset.id;
        const targetRow = this.rows.find((r) => r.id === id);
        if (!targetRow) {
            return;
        }
        const willExpand = !targetRow.isExpanded;

        this.rows = this.rows.map((row) => {
            if (row.id === id) {
                return {
                    ...row,
                    isExpanded: willExpand,
                    expandIcon: willExpand ? 'utility:chevrondown' : 'utility:chevronright'
                };
            }
            return row.isExpanded
                ? { ...row, isExpanded: false, expandIcon: 'utility:chevronright' }
                : row;
        });

        if (willExpand && !targetRow.stats) {
            this.loadStats(id, targetRow.competitorId);
        }
    }

    loadStats(rowId, competitorId) {
        getStats({ competitorId })
            .then((data) => {
                const formatted = this.formatStats(data);
                this.rows = this.rows.map((row) =>
                    row.id === rowId ? { ...row, stats: formatted } : row
                );
            })
            .catch((error) => {
                this.notifyError('Unable to load stats', error);
            });
    }

    formatStats(data) {
        return {
            totalOpportunities: data.totalOpportunities,
            winRate:
                data.winRate === null || data.winRate === undefined
                    ? 'N/A'
                    : `${(data.winRate * 100).toFixed(1)}%`,
            avgDealSizeWon:
                data.avgDealSizeWon === null || data.avgDealSizeWon === undefined
                    ? 'N/A'
                    : data.avgDealSizeWon,
            avgDealSizeLost:
                data.avgDealSizeLost === null || data.avgDealSizeLost === undefined
                    ? 'N/A'
                    : data.avgDealSizeLost
        };
    }

    handleEdit(event) {
        const id = event.currentTarget.dataset.id;
        this.rows = this.rows.map((row) => (row.id === id ? { ...row, isEditing: true } : row));
    }

    handleCancelEdit(event) {
        const id = event.currentTarget.dataset.id;
        if (this.wiredLinksResult && this.wiredLinksResult.data) {
            const original = this.wiredLinksResult.data.find((r) => r.Id === id);
            if (original) {
                const refreshedRow = this.toRow(original);
                this.rows = this.rows.map((row) =>
                    row.id === id ? { ...refreshedRow, isExpanded: row.isExpanded, stats: row.stats, expandIcon: row.expandIcon } : row
                );
                return;
            }
        }
        this.rows = this.rows.map((row) => (row.id === id ? { ...row, isEditing: false } : row));
    }

    handleEditThreatLevel(event) {
        const id = event.currentTarget.dataset.id;
        const value = event.detail.value;
        this.rows = this.rows.map((row) =>
            row.id === id ? { ...row, threatLevel: value, threatBadgeClass: this.threatClass(value) } : row
        );
    }

    handleEditLossReason(event) {
        const id = event.currentTarget.dataset.id;
        const value = event.detail.value;
        this.rows = this.rows.map((row) => (row.id === id ? { ...row, lossReason: value } : row));
    }

    handleEditNotes(event) {
        const id = event.currentTarget.dataset.id;
        const value = event.detail.value;
        this.rows = this.rows.map((row) => (row.id === id ? { ...row, notes: value } : row));
    }

    handleSave(event) {
        const id = event.currentTarget.dataset.id;
        const row = this.rows.find((r) => r.id === id);
        if (!row) {
            return;
        }
        this.isLoading = true;
        updateLink({
            linkId: row.id,
            threatLevel: row.threatLevel,
            lossReason: row.lossReason,
            notes: row.notes
        })
            .then(() => {
                this.notifySuccess('Changes saved');
                this.rows = this.rows.map((r) => (r.id === id ? { ...r, isEditing: false } : r));
                return refreshApex(this.wiredLinksResult);
            })
            .catch((error) => {
                this.notifyError('Unable to save changes', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    async handleRemove(event) {
        const id = event.currentTarget.dataset.id;
        const row = this.rows.find((r) => r.id === id);
        if (!row) {
            return;
        }

        const confirmed = await LightningConfirm.open({
            message: `Remove ${row.competitorName} from this opportunity?`,
            variant: 'destructive',
            label: 'Confirm Removal'
        });

        if (!confirmed) {
            return;
        }

        this.isLoading = true;
        removeLink({ linkId: row.id })
            .then(() => {
                this.notifySuccess('Competitor removed');
                return refreshApex(this.wiredLinksResult);
            })
            .catch((error) => {
                this.notifyError('Unable to remove competitor', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    notifySuccess(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message, variant: 'success' }));
    }

    notifyError(title, error) {
        const message =
            (error && error.body && error.body.message) ||
            (error && error.message) ||
            'Unknown error';
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant: 'error', mode: 'sticky' })
        );
    }
}

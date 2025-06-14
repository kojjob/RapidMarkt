import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "campaignCheckbox", "selectedCount", "actions", "sendButton", "scheduleButton"]

  connect() {
    this.updateUI()
  }

  toggleAll() {
    const isChecked = this.selectAllTarget.checked
    this.campaignCheckboxTargets.forEach(checkbox => {
      // Only check draft campaigns for bulk actions
      if (checkbox.dataset.campaignStatus === 'draft') {
        checkbox.checked = isChecked
      }
    })
    this.updateUI()
  }

  updateSelection() {
    this.updateUI()
  }

  updateUI() {
    const selectedCheckboxes = this.campaignCheckboxTargets.filter(cb => cb.checked)
    const selectedCount = selectedCheckboxes.length
    const draftCheckboxes = this.campaignCheckboxTargets.filter(cb => cb.dataset.campaignStatus === 'draft')
    const allDraftSelected = draftCheckboxes.length > 0 && draftCheckboxes.every(cb => cb.checked)

    // Update select all checkbox
    this.selectAllTarget.checked = allDraftSelected
    this.selectAllTarget.indeterminate = selectedCount > 0 && !allDraftSelected

    // Update selected count
    this.selectedCountTarget.textContent = `${selectedCount} selected`

    // Show/hide bulk actions
    if (selectedCount > 0) {
      this.actionsTarget.style.display = 'flex'
      this.updateButtonParams(selectedCheckboxes)
    } else {
      this.actionsTarget.style.display = 'none'
    }
  }

  updateButtonParams(selectedCheckboxes) {
    const selectedIds = selectedCheckboxes.map(cb => cb.dataset.campaignId)
    
    // Update send button params
    if (this.hasSendButtonTarget) {
      const sendForm = this.sendButtonTarget.closest('form')
      if (sendForm) {
        // Remove existing campaign_ids inputs
        sendForm.querySelectorAll('input[name="campaign_ids[]"]').forEach(input => input.remove())
        
        // Add new campaign_ids inputs
        selectedIds.forEach(id => {
          const input = document.createElement('input')
          input.type = 'hidden'
          input.name = 'campaign_ids[]'
          input.value = id
          sendForm.appendChild(input)
        })
      }
    }

    // Update schedule button params
    if (this.hasScheduleButtonTarget) {
      const scheduleForm = this.scheduleButtonTarget.closest('form')
      if (scheduleForm) {
        // Remove existing campaign_ids inputs
        scheduleForm.querySelectorAll('input[name="campaign_ids[]"]').forEach(input => input.remove())
        
        // Add new campaign_ids inputs
        selectedIds.forEach(id => {
          const input = document.createElement('input')
          input.type = 'hidden'
          input.name = 'campaign_ids[]'
          input.value = id
          scheduleForm.appendChild(input)
        })
      }
    }
  }
}
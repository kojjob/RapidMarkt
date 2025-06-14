import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="contact-modal"
export default class extends Controller {
  static targets = ["modal", "backdrop", "content", "contactName", "contactEmail", "contactStatus", "contactTags"]
  static values = {
    contactId: Number,
    contactName: String,
    contactEmail: String,
    contactStatus: String,
    contactTags: Array
  }

  connect() {
    this.close = this.close.bind(this)
  }

  open(event) {
    event.preventDefault()
    
    // Get contact data from the clicked element
    const contactElement = event.currentTarget.closest('[data-contact-id]')
    const contactId = contactElement.dataset.contactId
    const contactName = contactElement.dataset.contactName
    const contactEmail = contactElement.dataset.contactEmail
    const contactStatus = contactElement.dataset.contactStatus
    const contactTags = JSON.parse(contactElement.dataset.contactTags || '[]')
    
    // Update modal content
    this.contactIdValue = contactId
    this.contactNameValue = contactName
    this.contactEmailValue = contactEmail
    this.contactStatusValue = contactStatus
    this.contactTagsValue = contactTags
    
    this.updateModalContent()
    this.showModal()
  }

  updateModalContent() {
    // Update contact info
    this.contactNameTarget.textContent = this.contactNameValue
    this.contactEmailTarget.textContent = this.contactEmailValue
    
    // Update status badge
    const statusBadge = this.contactStatusTarget
    statusBadge.textContent = this.contactStatusValue.charAt(0).toUpperCase() + this.contactStatusValue.slice(1)
    statusBadge.className = `inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
      this.contactStatusValue === 'subscribed' 
        ? 'bg-green-100 text-green-800' 
        : 'bg-red-100 text-red-800'
    }`
    
    // Update tags
    this.contactTagsTarget.innerHTML = ''
    if (this.contactTagsValue.length > 0) {
      this.contactTagsValue.forEach(tag => {
        const tagElement = document.createElement('span')
        tagElement.className = 'inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800'
        tagElement.textContent = tag
        this.contactTagsTarget.appendChild(tagElement)
      })
    } else {
      this.contactTagsTarget.innerHTML = '<span class="text-sm text-gray-500">No tags</span>'
    }
    
    // Update action buttons with correct contact ID
    this.updateActionButtons()
  }

  updateActionButtons() {
    const editBtn = this.element.querySelector('[data-action="edit"]')
    const subscribeBtn = this.element.querySelector('[data-action="subscribe"]')
    const deleteBtn = this.element.querySelector('[data-action="delete"]')
    
    if (editBtn) {
      editBtn.href = `/contacts/${this.contactIdValue}/edit`
    }
    
    if (subscribeBtn) {
      const isSubscribed = this.contactStatusValue === 'subscribed'
      subscribeBtn.textContent = isSubscribed ? 'Unsubscribe' : 'Resubscribe'
      subscribeBtn.className = `w-full inline-flex items-center justify-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium ${
        isSubscribed 
          ? 'text-orange-700 bg-orange-100 hover:bg-orange-200 focus:ring-orange-500' 
          : 'text-green-700 bg-green-100 hover:bg-green-200 focus:ring-green-500'
      } focus:outline-none focus:ring-2 focus:ring-offset-2`
      
      // Update the icon
      const icon = subscribeBtn.querySelector('svg')
      if (icon) {
        icon.innerHTML = isSubscribed 
          ? '<path fill-rule="evenodd" d="M13.477 14.89A6 6 0 015.11 6.524l8.367 8.368zm1.414-1.414L6.524 5.11a6 6 0 018.367 8.367zM18 10a8 8 0 11-16 0 8 8 0 0116 0z" clip-rule="evenodd" />'
          : '<path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />'
      }
    }
    
    if (deleteBtn) {
      deleteBtn.href = `/contacts/${this.contactIdValue}`
    }
  }

  showModal() {
    this.modalTarget.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
    document.addEventListener('keydown', this.handleEscape.bind(this))
    
    // Animate in
    setTimeout(() => {
      this.backdropTarget.classList.remove('opacity-0')
      this.contentTarget.classList.remove('opacity-0', 'translate-y-4', 'sm:translate-y-0', 'sm:scale-95')
      this.contentTarget.classList.add('opacity-100', 'translate-y-0', 'sm:scale-100')
    }, 10)
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }
    
    // Animate out
    this.backdropTarget.classList.add('opacity-0')
    this.contentTarget.classList.add('opacity-0', 'translate-y-4', 'sm:translate-y-0', 'sm:scale-95')
    this.contentTarget.classList.remove('opacity-100', 'translate-y-0', 'sm:scale-100')
    
    setTimeout(() => {
      this.modalTarget.classList.add('hidden')
      document.body.classList.remove('overflow-hidden')
      document.removeEventListener('keydown', this.handleEscape.bind(this))
    }, 200)
  }

  handleEscape(event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }

  backdropClick(event) {
    if (event.target === this.backdropTarget) {
      this.close()
    }
  }

  handleSubscriptionToggle(event) {
    event.preventDefault()
    
    const isSubscribed = this.contactStatusValue === 'subscribed'
    const newStatus = isSubscribed ? 'unsubscribed' : 'subscribed'
    const confirmMessage = isSubscribed 
      ? 'Are you sure you want to unsubscribe this contact?' 
      : 'Are you sure you want to resubscribe this contact?'
    
    if (confirm(confirmMessage)) {
      // Create and submit form
      const form = document.createElement('form')
      form.method = 'POST'
      form.action = `/contacts/${this.contactIdValue}`
      
      const methodInput = document.createElement('input')
      methodInput.type = 'hidden'
      methodInput.name = '_method'
      methodInput.value = 'PATCH'
      
      const tokenInput = document.createElement('input')
      tokenInput.type = 'hidden'
      tokenInput.name = 'authenticity_token'
      tokenInput.value = document.querySelector('meta[name="csrf-token"]').content
      
      const statusInput = document.createElement('input')
      statusInput.type = 'hidden'
      statusInput.name = 'contact[status]'
      statusInput.value = newStatus
      
      form.appendChild(methodInput)
      form.appendChild(tokenInput)
      form.appendChild(statusInput)
      
      document.body.appendChild(form)
      form.submit()
    }
  }

  handleView(event) {
    event.preventDefault()
    window.location.href = `/contacts/${this.contactIdValue}`
  }

  handleEdit(event) {
    event.preventDefault()
    window.location.href = `/contacts/${this.contactIdValue}/edit`
  }

  handleDelete(event) {
    event.preventDefault()
    
    if (confirm('Are you sure you want to delete this contact? This action cannot be undone.')) {
      // Create and submit form
      const form = document.createElement('form')
      form.method = 'POST'
      form.action = `/contacts/${this.contactIdValue}`
      
      const methodInput = document.createElement('input')
      methodInput.type = 'hidden'
      methodInput.name = '_method'
      methodInput.value = 'DELETE'
      
      const tokenInput = document.createElement('input')
      tokenInput.type = 'hidden'
      tokenInput.name = 'authenticity_token'
      tokenInput.value = document.querySelector('meta[name="csrf-token"]').content
      
      form.appendChild(methodInput)
      form.appendChild(tokenInput)
      
      document.body.appendChild(form)
      form.submit()
    }
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleEscape.bind(this))
    document.body.classList.remove('overflow-hidden')
  }
}
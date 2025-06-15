import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="email-builder"
export default class extends Controller {
  static targets = [
    "palette", "canvas", "preview", "toolbar", "deviceToggle",
    "undoButton", "redoButton", "saveButton", "templateModal"
  ]
  static values = {
    autoSave: Boolean,
    autoSaveInterval: Number,
    maxHistorySteps: Number
  }

  connect() {
    this.autoSaveValue = this.autoSaveValue !== false
    this.autoSaveIntervalValue = this.autoSaveIntervalValue || 30000
    this.maxHistoryStepsValue = this.maxHistoryStepsValue || 50

    this.currentDevice = 'desktop'
    this.history = []
    this.historyIndex = -1
    this.draggedElement = null
    this.dropZones = []

    this.setupDragAndDrop()
    this.setupDevicePreview()
    this.setupAutoSave()
    this.saveState()
  }

  disconnect() {
    if (this.autoSaveTimer) {
      clearInterval(this.autoSaveTimer)
    }
    this.cleanup()
  }

  // Setup drag and drop functionality
  setupDragAndDrop() {
    // Make palette items draggable
    this.paletteTarget.querySelectorAll('[data-component-type]').forEach(item => {
      item.draggable = true
      item.addEventListener('dragstart', this.handleDragStart.bind(this))
      item.addEventListener('dragend', this.handleDragEnd.bind(this))
    })

    // Setup canvas as drop zone
    this.setupDropZone(this.canvasTarget)

    // Setup existing components for reordering
    this.updateCanvasComponents()
  }

  // Handle drag start
  handleDragStart(event) {
    this.draggedElement = event.target
    event.dataTransfer.effectAllowed = 'copy'
    event.dataTransfer.setData('text/html', event.target.outerHTML)

    // Add visual feedback
    event.target.classList.add('opacity-50')
    this.showDropZones()
  }

  // Handle drag end
  handleDragEnd(event) {
    event.target.classList.remove('opacity-50')
    this.hideDropZones()
    this.draggedElement = null
  }

  // Setup drop zone
  setupDropZone(element) {
    element.addEventListener('dragover', this.handleDragOver.bind(this))
    element.addEventListener('drop', this.handleDrop.bind(this))
    element.addEventListener('dragenter', this.handleDragEnter.bind(this))
    element.addEventListener('dragleave', this.handleDragLeave.bind(this))
  }

  // Handle drag over
  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'

    const dropZone = this.findDropZone(event.target)
    if (dropZone) {
      dropZone.classList.add('border-indigo-500', 'bg-indigo-50')
    }
  }

  // Handle drag enter
  handleDragEnter(event) {
    event.preventDefault()
    const dropZone = this.findDropZone(event.target)
    if (dropZone) {
      dropZone.classList.add('border-indigo-500', 'bg-indigo-50')
    }
  }

  // Handle drag leave
  handleDragLeave(event) {
    const dropZone = this.findDropZone(event.target)
    if (dropZone && !dropZone.contains(event.relatedTarget)) {
      dropZone.classList.remove('border-indigo-500', 'bg-indigo-50')
    }
  }

  // Handle drop
  handleDrop(event) {
    event.preventDefault()

    const dropZone = this.findDropZone(event.target)
    if (!dropZone) return

    dropZone.classList.remove('border-indigo-500', 'bg-indigo-50')

    const componentType = this.draggedElement?.dataset.componentType
    if (componentType) {
      this.addComponent(componentType, dropZone)
    }
  }

  // Find appropriate drop zone
  findDropZone(element) {
    return element.closest('[data-drop-zone]') ||
           element.closest('.email-canvas') ||
           (element.classList.contains('email-canvas') ? element : null)
  }

  // Add component to canvas
  addComponent(type, dropZone) {
    const component = this.createComponent(type)
    if (component) {
      dropZone.appendChild(component)
      this.updateCanvasComponents()
      this.saveState()
      this.triggerPreviewUpdate()
    }
  }

  // Create component based on type
  createComponent(type) {
    const templates = {
      text: this.createTextComponent(),
      image: this.createImageComponent(),
      button: this.createButtonComponent(),
      divider: this.createDividerComponent(),
      social: this.createSocialComponent(),
      html: this.createHtmlComponent()
    }

    return templates[type] || null
  }

  // Create text component
  createTextComponent() {
    const div = document.createElement('div')
    div.className = 'email-component text-component p-4 border-2 border-dashed border-gray-200 hover:border-indigo-300 transition-colors duration-200'
    div.dataset.componentType = 'text'
    div.innerHTML = `
      <div class="component-toolbar hidden absolute top-0 right-0 bg-white shadow-lg rounded-lg p-2 z-10">
        <button type="button" class="edit-btn p-1 text-gray-600 hover:text-indigo-600" title="Edit">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </button>
        <button type="button" class="delete-btn p-1 text-gray-600 hover:text-red-600" title="Delete">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </div>
      <div class="component-content" contenteditable="true">
        <p>Click to edit this text. You can add formatting, links, and personalization tokens.</p>
      </div>
    `

    this.setupComponentEvents(div)
    return div
  }

  // Create image component
  createImageComponent() {
    const div = document.createElement('div')
    div.className = 'email-component image-component p-4 border-2 border-dashed border-gray-200 hover:border-indigo-300 transition-colors duration-200'
    div.dataset.componentType = 'image'
    div.innerHTML = `
      <div class="component-toolbar hidden absolute top-0 right-0 bg-white shadow-lg rounded-lg p-2 z-10">
        <button type="button" class="edit-btn p-1 text-gray-600 hover:text-indigo-600" title="Edit">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </button>
        <button type="button" class="delete-btn p-1 text-gray-600 hover:text-red-600" title="Delete">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </div>
      <div class="component-content text-center">
        <div class="image-placeholder bg-gray-100 border-2 border-dashed border-gray-300 rounded-lg p-8 cursor-pointer hover:bg-gray-50">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
          <p class="mt-2 text-sm text-gray-600">Click to upload image</p>
        </div>
      </div>
    `

    this.setupComponentEvents(div)
    return div
  }

  // Create button component
  createButtonComponent() {
    const div = document.createElement('div')
    div.className = 'email-component button-component p-4 border-2 border-dashed border-gray-200 hover:border-indigo-300 transition-colors duration-200'
    div.dataset.componentType = 'button'
    div.innerHTML = `
      <div class="component-toolbar hidden absolute top-0 right-0 bg-white shadow-lg rounded-lg p-2 z-10">
        <button type="button" class="edit-btn p-1 text-gray-600 hover:text-indigo-600" title="Edit">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </button>
        <button type="button" class="delete-btn p-1 text-gray-600 hover:text-red-600" title="Delete">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </div>
      <div class="component-content text-center">
        <a href="#" class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-lg text-white bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 transition-all duration-200">
          Call to Action
        </a>
      </div>
    `

    this.setupComponentEvents(div)
    return div
  }

  // Create divider component
  createDividerComponent() {
    const div = document.createElement('div')
    div.className = 'email-component divider-component p-4 border-2 border-dashed border-gray-200 hover:border-indigo-300 transition-colors duration-200'
    div.dataset.componentType = 'divider'
    div.innerHTML = `
      <div class="component-toolbar hidden absolute top-0 right-0 bg-white shadow-lg rounded-lg p-2 z-10">
        <button type="button" class="edit-btn p-1 text-gray-600 hover:text-indigo-600" title="Edit">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </button>
        <button type="button" class="delete-btn p-1 text-gray-600 hover:text-red-600" title="Delete">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </div>
      <div class="component-content">
        <hr class="border-gray-300 my-4">
      </div>
    `

    this.setupComponentEvents(div)
    return div
  }

  // Create social component
  createSocialComponent() {
    const div = document.createElement('div')
    div.className = 'email-component social-component p-4 border-2 border-dashed border-gray-200 hover:border-indigo-300 transition-colors duration-200'
    div.dataset.componentType = 'social'
    div.innerHTML = `
      <div class="component-toolbar hidden absolute top-0 right-0 bg-white shadow-lg rounded-lg p-2 z-10">
        <button type="button" class="edit-btn p-1 text-gray-600 hover:text-indigo-600" title="Edit">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </button>
        <button type="button" class="delete-btn p-1 text-gray-600 hover:text-red-600" title="Delete">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </div>
      <div class="component-content text-center">
        <div class="flex justify-center space-x-4">
          <a href="#" class="text-blue-600 hover:text-blue-800 transition-colors duration-200">
            <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
              <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
            </svg>
          </a>
          <a href="#" class="text-blue-400 hover:text-blue-600 transition-colors duration-200">
            <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
              <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/>
            </svg>
          </a>
          <a href="#" class="text-pink-600 hover:text-pink-800 transition-colors duration-200">
            <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/>
            </svg>
          </a>
        </div>
      </div>
    `

    this.setupComponentEvents(div)
    return div
  }

  // Create HTML component
  createHtmlComponent() {
    const div = document.createElement('div')
    div.className = 'email-component html-component p-4 border-2 border-dashed border-gray-200 hover:border-indigo-300 transition-colors duration-200'
    div.dataset.componentType = 'html'
    div.innerHTML = `
      <div class="component-toolbar hidden absolute top-0 right-0 bg-white shadow-lg rounded-lg p-2 z-10">
        <button type="button" class="edit-btn p-1 text-gray-600 hover:text-indigo-600" title="Edit">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </button>
        <button type="button" class="delete-btn p-1 text-gray-600 hover:text-red-600" title="Delete">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </div>
      <div class="component-content">
        <div class="bg-gray-100 border border-gray-300 rounded-lg p-4 font-mono text-sm">
          <div class="text-gray-600 mb-2 font-semibold">Custom HTML Block</div>
          <code class="text-gray-800">&lt;div&gt;Your custom HTML here&lt;/div&gt;</code>
        </div>
      </div>
    `

    this.setupComponentEvents(div)
    return div
  }

  // Setup component events
  setupComponentEvents(component) {
    // Show/hide toolbar on hover
    component.addEventListener('mouseenter', () => {
      const toolbar = component.querySelector('.component-toolbar')
      if (toolbar) toolbar.classList.remove('hidden')
    })

    component.addEventListener('mouseleave', () => {
      const toolbar = component.querySelector('.component-toolbar')
      if (toolbar) toolbar.classList.add('hidden')
    })

    // Handle edit button
    const editBtn = component.querySelector('.edit-btn')
    if (editBtn) {
      editBtn.addEventListener('click', () => this.editComponent(component))
    }

    // Handle delete button
    const deleteBtn = component.querySelector('.delete-btn')
    if (deleteBtn) {
      deleteBtn.addEventListener('click', () => this.deleteComponent(component))
    }

    // Make component draggable for reordering
    component.draggable = true
    component.addEventListener('dragstart', this.handleComponentDragStart.bind(this))
  }

  // Handle component drag start for reordering
  handleComponentDragStart(event) {
    this.draggedElement = event.target
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/html', event.target.outerHTML)

    // Add visual feedback
    event.target.classList.add('opacity-50')
    this.showDropZones()
  }

  // Edit component
  editComponent(component) {
    // Implementation for component editing modal/panel
    console.log('Edit component:', component.dataset.componentType)
  }

  // Delete component
  deleteComponent(component) {
    if (confirm('Are you sure you want to delete this component?')) {
      component.remove()
      this.saveState()
      this.triggerPreviewUpdate()
    }
  }

  // Update canvas components
  updateCanvasComponents() {
    this.canvasTarget.querySelectorAll('.email-component').forEach(component => {
      if (!component.hasAttribute('data-events-setup')) {
        this.setupComponentEvents(component)
        component.setAttribute('data-events-setup', 'true')
      }
    })
  }

  // Show drop zones
  showDropZones() {
    this.canvasTarget.querySelectorAll('[data-drop-zone]').forEach(zone => {
      zone.classList.add('border-dashed', 'border-2', 'border-indigo-300', 'bg-indigo-50')
    })
  }

  // Hide drop zones
  hideDropZones() {
    this.canvasTarget.querySelectorAll('[data-drop-zone]').forEach(zone => {
      zone.classList.remove('border-dashed', 'border-2', 'border-indigo-300', 'bg-indigo-50')
    })
  }

  // Setup device preview
  setupDevicePreview() {
    this.deviceToggleTargets.forEach(toggle => {
      toggle.addEventListener('click', (event) => {
        const device = event.currentTarget.dataset.device
        this.switchDevice(device)
      })
    })
  }

  // Switch device preview
  switchDevice(device) {
    this.currentDevice = device

    // Update toggle buttons
    this.deviceToggleTargets.forEach(toggle => {
      if (toggle.dataset.device === device) {
        toggle.classList.add('bg-indigo-600', 'text-white')
        toggle.classList.remove('bg-gray-200', 'text-gray-700')
      } else {
        toggle.classList.remove('bg-indigo-600', 'text-white')
        toggle.classList.add('bg-gray-200', 'text-gray-700')
      }
    })

    // Update preview dimensions
    const dimensions = {
      desktop: { width: '100%', maxWidth: '1200px' },
      tablet: { width: '768px', maxWidth: '768px' },
      mobile: { width: '375px', maxWidth: '375px' }
    }

    if (this.hasPreviewTarget) {
      const dim = dimensions[device]
      this.previewTarget.style.width = dim.width
      this.previewTarget.style.maxWidth = dim.maxWidth
      this.previewTarget.style.margin = device === 'desktop' ? '0' : '0 auto'
    }
  }

  // Save state for undo/redo
  saveState() {
    const state = this.canvasTarget.innerHTML

    // Remove future states if we're not at the end
    if (this.historyIndex < this.history.length - 1) {
      this.history = this.history.slice(0, this.historyIndex + 1)
    }

    this.history.push(state)

    // Limit history size
    if (this.history.length > this.maxHistoryStepsValue) {
      this.history.shift()
    } else {
      this.historyIndex++
    }

    this.updateUndoRedoButtons()
  }

  // Undo
  undo() {
    if (this.historyIndex > 0) {
      this.historyIndex--
      this.canvasTarget.innerHTML = this.history[this.historyIndex]
      this.updateCanvasComponents()
      this.updateUndoRedoButtons()
      this.triggerPreviewUpdate()
    }
  }

  // Redo
  redo() {
    if (this.historyIndex < this.history.length - 1) {
      this.historyIndex++
      this.canvasTarget.innerHTML = this.history[this.historyIndex]
      this.updateCanvasComponents()
      this.updateUndoRedoButtons()
      this.triggerPreviewUpdate()
    }
  }

  // Update undo/redo buttons
  updateUndoRedoButtons() {
    if (this.hasUndoButtonTarget) {
      this.undoButtonTarget.disabled = this.historyIndex <= 0
    }

    if (this.hasRedoButtonTarget) {
      this.redoButtonTarget.disabled = this.historyIndex >= this.history.length - 1
    }
  }

  // Setup auto-save
  setupAutoSave() {
    if (this.autoSaveValue) {
      this.autoSaveTimer = setInterval(() => {
        this.save()
      }, this.autoSaveIntervalValue)
    }
  }

  // Save email content
  async save() {
    const content = this.canvasTarget.innerHTML

    try {
      const response = await fetch('/campaigns/auto_save_content', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
        body: JSON.stringify({ content })
      })

      if (response.ok) {
        this.showSaveIndicator()
      }
    } catch (error) {
      console.error('Auto-save failed:', error)
    }
  }

  // Show save indicator
  showSaveIndicator() {
    if (this.hasSaveButtonTarget) {
      const originalText = this.saveButtonTarget.textContent
      this.saveButtonTarget.textContent = 'Saved'
      this.saveButtonTarget.classList.add('bg-green-500')

      setTimeout(() => {
        this.saveButtonTarget.textContent = originalText
        this.saveButtonTarget.classList.remove('bg-green-500')
      }, 2000)
    }
  }

  // Trigger preview update
  triggerPreviewUpdate() {
    if (this.hasPreviewTarget) {
      // Update preview with current canvas content
      this.previewTarget.innerHTML = this.canvasTarget.innerHTML
    }
  }

  // Cleanup
  cleanup() {
    // Remove event listeners and clean up
  }
}
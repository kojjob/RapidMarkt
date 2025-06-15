import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="component-library"
export default class extends Controller {
  static targets = [
    "searchInput", "categoryFilter", "componentGrid", "previewModal",
    "previewContent", "favoritesList", "recentList"
  ]

  static values = {
    components: Array,
    categories: Array,
    favorites: Array
  }

  connect() {
    this.loadComponentLibrary()
    this.loadUserPreferences()
    this.setupSearch()
    this.renderComponents()
  }

  // Load component library data
  loadComponentLibrary() {
    this.componentsValue = this.componentsValue || this.getDefaultComponents()
    this.categoriesValue = this.categoriesValue || this.getDefaultCategories()
    this.favoritesValue = this.getFavorites()
  }

  // Get default component categories
  getDefaultCategories() {
    return [
      { id: 'all', name: 'All Components', icon: '📦' },
      { id: 'headers', name: 'Headers', icon: '📰' },
      { id: 'content', name: 'Content Blocks', icon: '📝' },
      { id: 'buttons', name: 'Buttons & CTAs', icon: '🔘' },
      { id: 'images', name: 'Images & Media', icon: '🖼️' },
      { id: 'social', name: 'Social Media', icon: '📱' },
      { id: 'footers', name: 'Footers', icon: '🦶' },
      { id: 'layouts', name: 'Layout Sections', icon: '📐' },
      { id: 'ecommerce', name: 'E-commerce', icon: '🛒' },
      { id: 'forms', name: 'Forms', icon: '📋' }
    ]
  }

  // Get default components
  getDefaultComponents() {
    return [
      // Headers
      {
        id: 'header-simple',
        name: 'Simple Header',
        category: 'headers',
        description: 'Clean header with logo and navigation',
        thumbnail: '/assets/components/header-simple.png',
        html: this.getHeaderSimpleHTML(),
        tags: ['header', 'navigation', 'logo', 'simple'],
        responsive: true,
        premium: false
      },
      {
        id: 'header-hero',
        name: 'Hero Header',
        category: 'headers',
        description: 'Large hero section with background image',
        thumbnail: '/assets/components/header-hero.png',
        html: this.getHeaderHeroHTML(),
        tags: ['header', 'hero', 'background', 'cta'],
        responsive: true,
        premium: false
      },

      // Content Blocks
      {
        id: 'text-block',
        name: 'Text Block',
        category: 'content',
        description: 'Formatted text content with typography',
        thumbnail: '/assets/components/text-block.png',
        html: this.getTextBlockHTML(),
        tags: ['text', 'content', 'typography'],
        responsive: true,
        premium: false
      },
      {
        id: 'two-column',
        name: 'Two Column Layout',
        category: 'content',
        description: 'Side-by-side content layout',
        thumbnail: '/assets/components/two-column.png',
        html: this.getTwoColumnHTML(),
        tags: ['layout', 'columns', 'content'],
        responsive: true,
        premium: false
      },

      // Buttons & CTAs
      {
        id: 'cta-button',
        name: 'Call-to-Action Button',
        category: 'buttons',
        description: 'Prominent action button with gradient',
        thumbnail: '/assets/components/cta-button.png',
        html: this.getCTAButtonHTML(),
        tags: ['button', 'cta', 'action', 'gradient'],
        responsive: true,
        premium: false
      },
      {
        id: 'button-group',
        name: 'Button Group',
        category: 'buttons',
        description: 'Multiple buttons in a row',
        thumbnail: '/assets/components/button-group.png',
        html: this.getButtonGroupHTML(),
        tags: ['buttons', 'group', 'multiple'],
        responsive: true,
        premium: false
      },

      // Images & Media
      {
        id: 'image-card',
        name: 'Image Card',
        category: 'images',
        description: 'Image with overlay text and button',
        thumbnail: '/assets/components/image-card.png',
        html: this.getImageCardHTML(),
        tags: ['image', 'card', 'overlay', 'button'],
        responsive: true,
        premium: false
      },
      {
        id: 'gallery-grid',
        name: 'Image Gallery',
        category: 'images',
        description: 'Grid of images with hover effects',
        thumbnail: '/assets/components/gallery-grid.png',
        html: this.getGalleryGridHTML(),
        tags: ['gallery', 'grid', 'images', 'hover'],
        responsive: true,
        premium: true
      },

      // Social Media
      {
        id: 'social-icons',
        name: 'Social Media Icons',
        category: 'social',
        description: 'Row of social media platform icons',
        thumbnail: '/assets/components/social-icons.png',
        html: this.getSocialIconsHTML(),
        tags: ['social', 'icons', 'media', 'links'],
        responsive: true,
        premium: false
      },

      // E-commerce
      {
        id: 'product-card',
        name: 'Product Card',
        category: 'ecommerce',
        description: 'Product showcase with price and button',
        thumbnail: '/assets/components/product-card.png',
        html: this.getProductCardHTML(),
        tags: ['product', 'ecommerce', 'price', 'shop'],
        responsive: true,
        premium: true
      }
    ]
  }

  // Setup search functionality
  setupSearch() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.addEventListener('input', this.debounce(() => {
        this.filterComponents()
      }, 300))
    }
  }

  // Filter components based on search and category
  filterComponents() {
    const searchTerm = this.hasSearchInputTarget ? this.searchInputTarget.value.toLowerCase() : ''
    const selectedCategory = this.hasCategoryFilterTarget ? this.categoryFilterTarget.value : 'all'

    const filteredComponents = this.componentsValue.filter(component => {
      const matchesSearch = !searchTerm || 
        component.name.toLowerCase().includes(searchTerm) ||
        component.description.toLowerCase().includes(searchTerm) ||
        component.tags.some(tag => tag.toLowerCase().includes(searchTerm))

      const matchesCategory = selectedCategory === 'all' || component.category === selectedCategory

      return matchesSearch && matchesCategory
    })

    this.renderFilteredComponents(filteredComponents)
  }

  // Render components in grid
  renderComponents() {
    this.renderFilteredComponents(this.componentsValue)
  }

  // Render filtered components
  renderFilteredComponents(components) {
    if (!this.hasComponentGridTarget) return

    const html = components.map(component => this.renderComponentCard(component)).join('')
    this.componentGridTarget.innerHTML = html

    // Setup component card events
    this.setupComponentCardEvents()
  }

  // Render individual component card
  renderComponentCard(component) {
    const isFavorite = this.favoritesValue.includes(component.id)
    
    return `
      <div class="component-card bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden hover:shadow-xl transition-all duration-300 transform hover:scale-105" 
           data-component-id="${component.id}">
        <div class="component-thumbnail relative">
          <div class="aspect-w-16 aspect-h-9 bg-gradient-to-br from-purple-100 to-pink-100 flex items-center justify-center">
            <div class="text-4xl">${this.getCategoryIcon(component.category)}</div>
          </div>
          
          <div class="absolute top-2 right-2 flex space-x-1">
            ${component.premium ? '<span class="px-2 py-1 bg-yellow-400 text-yellow-900 text-xs font-bold rounded-full">PRO</span>' : ''}
            <button class="favorite-btn p-1 bg-white/80 backdrop-blur-sm rounded-full hover:bg-white transition-colors duration-200" 
                    data-component-id="${component.id}"
                    data-action="click->component-library#toggleFavorite">
              <svg class="w-4 h-4 ${isFavorite ? 'text-red-500 fill-current' : 'text-gray-400'}" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
              </svg>
            </button>
          </div>
        </div>
        
        <div class="component-info p-4">
          <h3 class="font-bold text-gray-900 mb-1">${component.name}</h3>
          <p class="text-sm text-gray-600 mb-3">${component.description}</p>
          
          <div class="component-tags flex flex-wrap gap-1 mb-3">
            ${component.tags.slice(0, 3).map(tag => 
              `<span class="px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded-full">${tag}</span>`
            ).join('')}
          </div>
          
          <div class="component-actions flex space-x-2">
            <button class="preview-btn flex-1 px-3 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors duration-200"
                    data-component-id="${component.id}"
                    data-action="click->component-library#previewComponent">
              👁️ Preview
            </button>
            <button class="use-btn flex-1 px-3 py-2 text-sm font-medium text-white bg-gradient-to-r from-purple-600 to-pink-600 rounded-lg hover:from-purple-700 hover:to-pink-700 transition-all duration-200"
                    data-component-id="${component.id}"
                    data-action="click->component-library#useComponent">
              ✨ Use
            </button>
          </div>
        </div>
      </div>
    `
  }

  // Get category icon
  getCategoryIcon(category) {
    const icons = {
      headers: '📰',
      content: '📝',
      buttons: '🔘',
      images: '🖼️',
      social: '📱',
      footers: '🦶',
      layouts: '📐',
      ecommerce: '🛒',
      forms: '📋'
    }
    return icons[category] || '📦'
  }

  // Setup component card events
  setupComponentCardEvents() {
    // Events are handled by data-action attributes
  }

  // Toggle favorite status
  toggleFavorite(event) {
    const componentId = event.currentTarget.dataset.componentId
    const favorites = this.getFavorites()
    
    if (favorites.includes(componentId)) {
      this.favoritesValue = favorites.filter(id => id !== componentId)
    } else {
      this.favoritesValue = [...favorites, componentId]
    }
    
    this.saveFavorites()
    this.renderComponents() // Re-render to update favorite icons
  }

  // Preview component
  previewComponent(event) {
    const componentId = event.currentTarget.dataset.componentId
    const component = this.componentsValue.find(c => c.id === componentId)
    
    if (component && this.hasPreviewModalTarget) {
      this.showPreviewModal(component)
    }
  }

  // Use component
  useComponent(event) {
    const componentId = event.currentTarget.dataset.componentId
    const component = this.componentsValue.find(c => c.id === componentId)
    
    if (component) {
      // Add to recent list
      this.addToRecent(componentId)
      
      // Dispatch event to add component to builder
      const event = new CustomEvent('component:use', {
        detail: {
          component: component,
          source: 'library'
        },
        bubbles: true
      })
      
      this.element.dispatchEvent(event)
    }
  }

  // Show preview modal
  showPreviewModal(component) {
    if (this.hasPreviewContentTarget) {
      this.previewContentTarget.innerHTML = `
        <div class="preview-header mb-4">
          <h3 class="text-xl font-bold text-gray-900">${component.name}</h3>
          <p class="text-gray-600">${component.description}</p>
        </div>
        
        <div class="preview-content border border-gray-200 rounded-lg p-4 bg-gray-50 max-h-96 overflow-y-auto">
          ${component.html}
        </div>
        
        <div class="preview-actions mt-4 flex justify-end space-x-3">
          <button type="button" 
                  class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-200 rounded-lg hover:bg-gray-300 transition-colors duration-200"
                  data-action="click->component-library#closePreview">
            Cancel
          </button>
          <button type="button" 
                  class="px-6 py-2 text-sm font-medium text-white bg-gradient-to-r from-purple-600 to-pink-600 rounded-lg hover:from-purple-700 hover:to-pink-700 transition-all duration-200"
                  data-component-id="${component.id}"
                  data-action="click->component-library#useComponent">
            Use Component
          </button>
        </div>
      `
    }
    
    if (this.hasPreviewModalTarget) {
      this.previewModalTarget.classList.remove('hidden')
    }
  }

  // Close preview modal
  closePreview() {
    if (this.hasPreviewModalTarget) {
      this.previewModalTarget.classList.add('hidden')
    }
  }

  // Load user preferences
  loadUserPreferences() {
    // Load from localStorage or API
  }

  // Get favorites from localStorage
  getFavorites() {
    const stored = localStorage.getItem('rapidmarkt_component_favorites')
    return stored ? JSON.parse(stored) : []
  }

  // Save favorites to localStorage
  saveFavorites() {
    localStorage.setItem('rapidmarkt_component_favorites', JSON.stringify(this.favoritesValue))
  }

  // Add component to recent list
  addToRecent(componentId) {
    const recent = this.getRecent()
    const updated = [componentId, ...recent.filter(id => id !== componentId)].slice(0, 10)
    localStorage.setItem('rapidmarkt_component_recent', JSON.stringify(updated))
  }

  // Get recent components
  getRecent() {
    const stored = localStorage.getItem('rapidmarkt_component_recent')
    return stored ? JSON.parse(stored) : []
  }

  // Utility: debounce function
  debounce(func, wait) {
    let timeout
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout)
        func(...args)
      }
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
    }
  }

  // Component HTML templates (simplified versions)
  getHeaderSimpleHTML() {
    return `<div class="bg-white border-b border-gray-200 px-6 py-4"><div class="flex items-center justify-between"><div class="text-xl font-bold text-gray-900">Your Logo</div><nav class="hidden md:flex space-x-6"><a href="#" class="text-gray-600 hover:text-gray-900">Home</a><a href="#" class="text-gray-600 hover:text-gray-900">About</a><a href="#" class="text-gray-600 hover:text-gray-900">Contact</a></nav></div></div>`
  }

  getHeaderHeroHTML() {
    return `<div class="bg-gradient-to-r from-purple-600 to-pink-600 text-white py-20 px-6 text-center"><h1 class="text-4xl md:text-6xl font-bold mb-4">Welcome to Our Platform</h1><p class="text-xl mb-8 opacity-90">Create amazing experiences with our tools</p><button class="bg-white text-purple-600 px-8 py-3 rounded-lg font-semibold hover:bg-gray-100 transition-colors duration-200">Get Started</button></div>`
  }

  getTextBlockHTML() {
    return `<div class="prose max-w-none p-6"><h2 class="text-2xl font-bold text-gray-900 mb-4">Your Heading Here</h2><p class="text-gray-600 leading-relaxed">Your content goes here. This is a flexible text block that can contain paragraphs, lists, and other formatted content.</p></div>`
  }

  getTwoColumnHTML() {
    return `<div class="grid md:grid-cols-2 gap-8 p-6"><div><h3 class="text-xl font-bold text-gray-900 mb-3">Left Column</h3><p class="text-gray-600">Content for the left side goes here.</p></div><div><h3 class="text-xl font-bold text-gray-900 mb-3">Right Column</h3><p class="text-gray-600">Content for the right side goes here.</p></div></div>`
  }

  getCTAButtonHTML() {
    return `<div class="text-center p-6"><button class="bg-gradient-to-r from-purple-600 to-pink-600 text-white px-8 py-3 rounded-lg font-semibold hover:from-purple-700 hover:to-pink-700 transition-all duration-200 transform hover:scale-105">Call to Action</button></div>`
  }

  getButtonGroupHTML() {
    return `<div class="flex flex-wrap justify-center gap-4 p-6"><button class="bg-purple-600 text-white px-6 py-2 rounded-lg hover:bg-purple-700 transition-colors duration-200">Primary</button><button class="bg-gray-200 text-gray-800 px-6 py-2 rounded-lg hover:bg-gray-300 transition-colors duration-200">Secondary</button><button class="border border-purple-600 text-purple-600 px-6 py-2 rounded-lg hover:bg-purple-50 transition-colors duration-200">Outline</button></div>`
  }

  getImageCardHTML() {
    return `<div class="relative overflow-hidden rounded-lg shadow-lg"><div class="aspect-w-16 aspect-h-9 bg-gray-200"></div><div class="absolute inset-0 bg-black bg-opacity-40 flex items-center justify-center"><div class="text-center text-white"><h3 class="text-xl font-bold mb-2">Image Title</h3><p class="mb-4">Description text here</p><button class="bg-white text-gray-900 px-4 py-2 rounded-lg font-semibold">Learn More</button></div></div></div>`
  }

  getGalleryGridHTML() {
    return `<div class="grid grid-cols-2 md:grid-cols-3 gap-4 p-6">${Array(6).fill().map(() => '<div class="aspect-square bg-gray-200 rounded-lg hover:opacity-80 transition-opacity duration-200 cursor-pointer"></div>').join('')}</div>`
  }

  getSocialIconsHTML() {
    return `<div class="flex justify-center space-x-4 p-6"><a href="#" class="text-blue-600 hover:text-blue-800 transition-colors duration-200"><svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/></svg></a><a href="#" class="text-blue-400 hover:text-blue-600 transition-colors duration-200"><svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg></a><a href="#" class="text-pink-600 hover:text-pink-800 transition-colors duration-200"><svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/></svg></a></div>`
  }

  getProductCardHTML() {
    return `<div class="bg-white rounded-lg shadow-lg overflow-hidden"><div class="aspect-square bg-gray-200"></div><div class="p-4"><h3 class="font-bold text-gray-900 mb-2">Product Name</h3><p class="text-gray-600 text-sm mb-3">Product description goes here</p><div class="flex items-center justify-between"><span class="text-2xl font-bold text-purple-600">$99.99</span><button class="bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700 transition-colors duration-200">Add to Cart</button></div></div></div>`
  }
}

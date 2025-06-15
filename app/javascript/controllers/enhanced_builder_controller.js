import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="enhanced-builder"
export default class extends Controller {
  static targets = [
    "canvas", "dropZone", "componentGrid", "previewModal", "saveButton",
    "undoButton", "redoButton", "zoomLevel", "gridToggle"
  ]

  static values = {
    zoomLevel: Number,
    gridEnabled: Boolean,
    autoSave: Boolean
  }

  connect() {
    this.initializeBuilder()
    this.setupDragAndDrop()
    this.setupKeyboardShortcuts()
    this.setupAutoSave()
    this.history = []
    this.historyIndex = -1
    this.zoomLevelValue = 100
    this.gridEnabledValue = false
  }

  // Initialize the builder
  initializeBuilder() {
    console.log('🚀 Enhanced Template Builder initialized')
    this.components = this.getAvailableComponents()
    this.renderComponentGrid()
    this.updateCanvasStyles()
  }

  // Get available components including TikTok and social media
  getAvailableComponents() {
    return [
      // Email Components
      {
        id: 'email-header',
        name: 'Email Header',
        category: 'headers',
        platform: 'email',
        icon: '📧',
        description: 'Professional email header with logo',
        html: this.getEmailHeaderHTML(),
        responsive: true
      },
      {
        id: 'email-cta',
        name: 'Email CTA Button',
        category: 'buttons',
        platform: 'email',
        icon: '🔘',
        description: 'Call-to-action button for emails',
        html: this.getEmailCTAHTML(),
        responsive: true
      },

      // TikTok Components
      {
        id: 'tiktok-video',
        name: 'TikTok Video Template',
        category: 'tiktok',
        platform: 'tiktok',
        icon: '🎵',
        description: 'Vertical video template with trending effects',
        html: this.getTikTokVideoHTML(),
        aspectRatio: '9:16',
        responsive: true
      },
      {
        id: 'tiktok-text-overlay',
        name: 'TikTok Text Overlay',
        category: 'tiktok',
        platform: 'tiktok',
        icon: '💬',
        description: 'Animated text overlay for TikTok videos',
        html: this.getTikTokTextOverlayHTML(),
        animated: true
      },
      {
        id: 'tiktok-hashtag-challenge',
        name: 'TikTok Hashtag Challenge',
        category: 'tiktok',
        platform: 'tiktok',
        icon: '#️⃣',
        description: 'Hashtag challenge template with effects',
        html: this.getTikTokHashtagHTML(),
        trending: true
      },

      // Instagram Components
      {
        id: 'instagram-story',
        name: 'Instagram Story',
        category: 'instagram',
        platform: 'instagram',
        icon: '📸',
        description: 'Story template with interactive elements',
        html: this.getInstagramStoryHTML(),
        aspectRatio: '9:16'
      },
      {
        id: 'instagram-post',
        name: 'Instagram Post',
        category: 'instagram',
        platform: 'instagram',
        icon: '📷',
        description: 'Square post template for feed',
        html: this.getInstagramPostHTML(),
        aspectRatio: '1:1'
      },
      {
        id: 'instagram-reel',
        name: 'Instagram Reel',
        category: 'instagram',
        platform: 'instagram',
        icon: '🎬',
        description: 'Vertical video reel template',
        html: this.getInstagramReelHTML(),
        aspectRatio: '9:16'
      },

      // YouTube Components
      {
        id: 'youtube-shorts',
        name: 'YouTube Shorts',
        category: 'youtube',
        platform: 'youtube',
        icon: '📺',
        description: 'Short-form video content template',
        html: this.getYouTubeShortsHTML(),
        aspectRatio: '9:16'
      },
      {
        id: 'youtube-thumbnail',
        name: 'YouTube Thumbnail',
        category: 'youtube',
        platform: 'youtube',
        icon: '🖼️',
        description: 'Eye-catching video thumbnail',
        html: this.getYouTubeThumbnailHTML(),
        aspectRatio: '16:9'
      },

      // LinkedIn Components
      {
        id: 'linkedin-post',
        name: 'LinkedIn Post',
        category: 'social',
        platform: 'linkedin',
        icon: '💼',
        description: 'Professional content for business network',
        html: this.getLinkedInPostHTML(),
        professional: true
      },
      {
        id: 'linkedin-article',
        name: 'LinkedIn Article',
        category: 'content',
        platform: 'linkedin',
        icon: '📄',
        description: 'Long-form article template',
        html: this.getLinkedInArticleHTML(),
        longForm: true
      },

      // Universal Social Components
      {
        id: 'social-carousel',
        name: 'Social Media Carousel',
        category: 'social',
        platform: 'multi',
        icon: '🎠',
        description: 'Multi-slide carousel for all platforms',
        html: this.getSocialCarouselHTML(),
        multiSlide: true
      },
      {
        id: 'social-quote',
        name: 'Quote Post',
        category: 'social',
        platform: 'multi',
        icon: '💭',
        description: 'Inspirational quote template',
        html: this.getSocialQuoteHTML(),
        inspirational: true
      }
    ]
  }

  // Setup drag and drop functionality
  setupDragAndDrop() {
    // Make components draggable
    this.element.addEventListener('dragstart', (e) => {
      if (e.target.classList.contains('component-card')) {
        const componentId = e.target.dataset.componentId
        e.dataTransfer.setData('text/plain', componentId)
        e.target.style.opacity = '0.5'
      }
    })

    this.element.addEventListener('dragend', (e) => {
      if (e.target.classList.contains('component-card')) {
        e.target.style.opacity = '1'
      }
    })

    // Setup drop zone
    if (this.hasDropZoneTarget) {
      this.dropZoneTarget.addEventListener('dragover', (e) => {
        e.preventDefault()
        this.dropZoneTarget.classList.add('drag-over')
      })

      this.dropZoneTarget.addEventListener('dragleave', (e) => {
        if (!this.dropZoneTarget.contains(e.relatedTarget)) {
          this.dropZoneTarget.classList.remove('drag-over')
        }
      })

      this.dropZoneTarget.addEventListener('drop', (e) => {
        e.preventDefault()
        this.dropZoneTarget.classList.remove('drag-over')
        
        const componentId = e.dataTransfer.getData('text/plain')
        this.addComponentToCanvas(componentId, e.clientX, e.clientY)
      })
    }
  }

  // Add component to canvas
  addComponentToCanvas(componentId, x = 0, y = 0) {
    const component = this.components.find(c => c.id === componentId)
    if (!component) return

    // Save state for undo
    this.saveState()

    // Create component element
    const componentElement = document.createElement('div')
    componentElement.className = 'canvas-component'
    componentElement.dataset.componentId = componentId
    componentElement.innerHTML = component.html
    
    // Add platform-specific styling
    this.applyPlatformStyling(componentElement, component.platform)
    
    // Make component editable and moveable
    this.makeComponentInteractive(componentElement)

    // Add to canvas
    if (this.hasCanvasTarget) {
      this.canvasTarget.appendChild(componentElement)
    } else {
      // Replace drop zone content
      this.dropZoneTarget.innerHTML = ''
      this.dropZoneTarget.appendChild(componentElement)
    }

    // Show success notification
    this.showNotification(`${component.name} added to canvas!`, 'success')

    // Trigger auto-save
    if (this.autoSaveValue) {
      this.autoSave()
    }
  }

  // Apply platform-specific styling
  applyPlatformStyling(element, platform) {
    element.classList.add(`platform-${platform}`)
    
    switch (platform) {
      case 'tiktok':
        element.style.aspectRatio = '9/16'
        element.style.maxWidth = '300px'
        element.classList.add('tiktok-style')
        break
      case 'instagram':
        element.classList.add('instagram-style')
        break
      case 'youtube':
        element.classList.add('youtube-style')
        break
      case 'linkedin':
        element.classList.add('linkedin-style', 'professional')
        break
      case 'email':
        element.classList.add('email-style')
        break
    }
  }

  // Make component interactive
  makeComponentInteractive(element) {
    // Add selection functionality
    element.addEventListener('click', (e) => {
      e.stopPropagation()
      this.selectComponent(element)
    })

    // Add double-click to edit
    element.addEventListener('dblclick', (e) => {
      e.stopPropagation()
      this.editComponent(element)
    })

    // Add context menu
    element.addEventListener('contextmenu', (e) => {
      e.preventDefault()
      this.showContextMenu(element, e.clientX, e.clientY)
    })
  }

  // Setup keyboard shortcuts
  setupKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      if (e.ctrlKey || e.metaKey) {
        switch (e.key) {
          case 'z':
            e.preventDefault()
            if (e.shiftKey) {
              this.redo()
            } else {
              this.undo()
            }
            break
          case 's':
            e.preventDefault()
            this.save()
            break
          case 'c':
            if (this.selectedComponent) {
              e.preventDefault()
              this.copyComponent()
            }
            break
          case 'v':
            if (this.copiedComponent) {
              e.preventDefault()
              this.pasteComponent()
            }
            break
        }
      }
      
      if (e.key === 'Delete' && this.selectedComponent) {
        this.deleteComponent(this.selectedComponent)
      }
    })
  }

  // Setup auto-save
  setupAutoSave() {
    if (this.autoSaveValue) {
      setInterval(() => {
        this.autoSave()
      }, 30000) // Auto-save every 30 seconds
    }
  }

  // Save current state for undo/redo
  saveState() {
    const state = this.hasCanvasTarget ? 
      this.canvasTarget.innerHTML : 
      this.dropZoneTarget.innerHTML

    this.history = this.history.slice(0, this.historyIndex + 1)
    this.history.push(state)
    this.historyIndex++

    // Limit history size
    if (this.history.length > 50) {
      this.history.shift()
      this.historyIndex--
    }

    this.updateUndoRedoButtons()
  }

  // Undo action
  undo() {
    if (this.historyIndex > 0) {
      this.historyIndex--
      this.restoreState()
    }
  }

  // Redo action
  redo() {
    if (this.historyIndex < this.history.length - 1) {
      this.historyIndex++
      this.restoreState()
    }
  }

  // Restore state from history
  restoreState() {
    const state = this.history[this.historyIndex]
    if (this.hasCanvasTarget) {
      this.canvasTarget.innerHTML = state
    } else {
      this.dropZoneTarget.innerHTML = state
    }
    this.updateUndoRedoButtons()
    this.reattachEventListeners()
  }

  // Update undo/redo button states
  updateUndoRedoButtons() {
    if (this.hasUndoButtonTarget) {
      this.undoButtonTarget.disabled = this.historyIndex <= 0
    }
    if (this.hasRedoButtonTarget) {
      this.redoButtonTarget.disabled = this.historyIndex >= this.history.length - 1
    }
  }

  // Show notification
  showNotification(message, type = 'info') {
    const notification = document.createElement('div')
    notification.className = `notification ${type}`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    setTimeout(() => notification.classList.add('show'), 100)
    setTimeout(() => {
      notification.classList.remove('show')
      setTimeout(() => document.body.removeChild(notification), 300)
    }, 3000)
  }

  // Auto-save functionality
  async autoSave() {
    const content = this.hasCanvasTarget ? 
      this.canvasTarget.innerHTML : 
      this.dropZoneTarget.innerHTML

    try {
      const response = await fetch('/templates/auto_save', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ content })
      })

      if (response.ok) {
        this.showNotification('Auto-saved', 'success')
      }
    } catch (error) {
      console.error('Auto-save failed:', error)
    }
  }

  // Component HTML templates
  getTikTokVideoHTML() {
    return `
      <div class="tiktok-video-container">
        <div class="tiktok-video-frame">
          <div class="tiktok-overlay">
            <h2 class="tiktok-title">Your TikTok Title</h2>
            <p class="tiktok-description">Add your engaging description here #trending #viral</p>
          </div>
          <div class="tiktok-effects">
            <div class="effect-sparkle">✨</div>
            <div class="effect-heart">❤️</div>
          </div>
        </div>
      </div>
    `
  }

  getTikTokTextOverlayHTML() {
    return `
      <div class="tiktok-text-overlay">
        <div class="animated-text">
          <span class="text-line">Your</span>
          <span class="text-line">Amazing</span>
          <span class="text-line">Content</span>
        </div>
      </div>
    `
  }

  getTikTokHashtagHTML() {
    return `
      <div class="tiktok-hashtag-challenge">
        <h3 class="challenge-title">#YourChallenge</h3>
        <p class="challenge-description">Join the trend and show us your creativity!</p>
        <div class="hashtag-list">
          <span class="hashtag">#trending</span>
          <span class="hashtag">#viral</span>
          <span class="hashtag">#challenge</span>
        </div>
      </div>
    `
  }

  getInstagramStoryHTML() {
    return `
      <div class="instagram-story">
        <div class="story-header">
          <div class="profile-pic"></div>
          <span class="username">@yourbrand</span>
        </div>
        <div class="story-content">
          <h2>Your Story Content</h2>
          <p>Engage with your audience</p>
        </div>
        <div class="story-cta">
          <button class="story-button">Swipe Up</button>
        </div>
      </div>
    `
  }

  getInstagramPostHTML() {
    return `
      <div class="instagram-post">
        <div class="post-image"></div>
        <div class="post-content">
          <p>Your engaging caption goes here... #instagram #content</p>
        </div>
      </div>
    `
  }

  getInstagramReelHTML() {
    return `
      <div class="instagram-reel">
        <div class="reel-video"></div>
        <div class="reel-overlay">
          <h3>Your Reel Title</h3>
          <p>Quick, engaging content</p>
        </div>
      </div>
    `
  }

  getYouTubeShortsHTML() {
    return `
      <div class="youtube-shorts">
        <div class="shorts-video"></div>
        <div class="shorts-info">
          <h3>Your YouTube Short</h3>
          <p>Captivating short-form content</p>
        </div>
      </div>
    `
  }

  getYouTubeThumbnailHTML() {
    return `
      <div class="youtube-thumbnail">
        <div class="thumbnail-image"></div>
        <div class="thumbnail-overlay">
          <h2>CLICK-WORTHY TITLE</h2>
          <div class="play-button">▶️</div>
        </div>
      </div>
    `
  }

  getLinkedInPostHTML() {
    return `
      <div class="linkedin-post">
        <div class="post-header">
          <div class="profile-info">
            <div class="profile-pic"></div>
            <div class="profile-details">
              <h4>Your Name</h4>
              <p>Your Professional Title</p>
            </div>
          </div>
        </div>
        <div class="post-content">
          <p>Share your professional insights and industry knowledge...</p>
        </div>
      </div>
    `
  }

  getLinkedInArticleHTML() {
    return `
      <div class="linkedin-article">
        <h1>Your Article Title</h1>
        <div class="article-meta">
          <span>Published by Your Name</span>
          <span>Industry Insights</span>
        </div>
        <div class="article-content">
          <p>Your in-depth professional content goes here...</p>
        </div>
      </div>
    `
  }

  getSocialCarouselHTML() {
    return `
      <div class="social-carousel">
        <div class="carousel-slide active">
          <h3>Slide 1</h3>
          <p>Your first slide content</p>
        </div>
        <div class="carousel-slide">
          <h3>Slide 2</h3>
          <p>Your second slide content</p>
        </div>
        <div class="carousel-indicators">
          <span class="indicator active"></span>
          <span class="indicator"></span>
        </div>
      </div>
    `
  }

  getSocialQuoteHTML() {
    return `
      <div class="social-quote">
        <blockquote>
          "Your inspirational quote goes here"
        </blockquote>
        <cite>- Author Name</cite>
      </div>
    `
  }

  getEmailHeaderHTML() {
    return `
      <div class="email-header">
        <div class="logo">Your Logo</div>
        <nav class="email-nav">
          <a href="#">Home</a>
          <a href="#">Products</a>
          <a href="#">Contact</a>
        </nav>
      </div>
    `
  }

  getEmailCTAHTML() {
    return `
      <div class="email-cta">
        <button class="cta-button">Call to Action</button>
      </div>
    `
  }
}

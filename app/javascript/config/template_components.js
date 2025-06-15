// Dynamic Template Component Configuration
// This file defines all template types, their components, and properties
// No hardcoded values - everything is configurable

export const TEMPLATE_TYPES = {
  email: {
    id: 'email',
    name: 'Email Templates',
    description: 'Newsletters, promotions, transactional',
    icon: 'M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z',
    gradient: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    categories: {
      layout: {
        name: 'Layout',
        components: ['header', 'footer', 'section', 'divider']
      },
      content: {
        name: 'Content', 
        components: ['text', 'image', 'button', 'spacer']
      },
      interactive: {
        name: 'Interactive',
        components: ['link', 'social-links']
      }
    }
  },
  
  website: {
    id: 'website',
    name: 'Website Pages',
    description: 'Landing pages, product pages, blogs',
    icon: 'M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zM4 6h16v2H4V6zm0 4h4v8H4v-8zm6 0h10v8H10v-8z',
    gradient: 'linear-gradient(135deg, #11998e 0%, #38ef7d 100%)',
    categories: {
      layout: {
        name: 'Layout',
        components: ['navbar', 'hero', 'grid', 'sidebar', 'container']
      },
      content: {
        name: 'Content',
        components: ['text', 'image', 'video', 'gallery', 'testimonial', 'pricing-table']
      },
      interactive: {
        name: 'Interactive',
        components: ['form', 'button', 'accordion', 'tabs', 'modal']
      }
    }
  },
  
  facebook: {
    id: 'facebook',
    name: 'Facebook',
    description: 'Posts, ads, cover photos, stories',
    icon: 'M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z',
    gradient: 'linear-gradient(135deg, #1877f2 0%, #42a5f5 100%)',
    categories: {
      'post-elements': {
        name: 'Post Elements',
        components: ['fb-post-header', 'fb-text', 'fb-image', 'fb-video', 'fb-link']
      },
      'advertising': {
        name: 'Advertising',
        components: ['fb-ad-headline', 'fb-cta-button', 'fb-carousel', 'fb-lead-form']
      },
      'engagement': {
        name: 'Engagement',
        components: ['fb-poll', 'fb-event', 'fb-live-video']
      }
    }
  },
  
  instagram: {
    id: 'instagram',
    name: 'Instagram',
    description: 'Posts, stories, reels, IGTV',
    icon: 'M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z',
    gradient: 'linear-gradient(135deg, #833ab4 0%, #fd1d1d 50%, #fcb045 100%)',
    categories: {
      'content-types': {
        name: 'Content Types',
        components: ['ig-square-post', 'ig-story', 'ig-reel', 'ig-carousel', 'ig-igtv']
      },
      'overlays': {
        name: 'Overlays & Text',
        components: ['ig-text-overlay', 'ig-sticker', 'ig-filter']
      },
      'social': {
        name: 'Social Elements',
        components: ['ig-hashtags', 'ig-location', 'ig-user-tag', 'ig-mention']
      }
    }
  },
  
  seo: {
    id: 'seo',
    name: 'SEO Content',
    description: 'Meta descriptions, titles, schemas',
    icon: 'M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z',
    gradient: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    categories: {
      'meta-data': {
        name: 'Meta Data',
        components: ['meta-title', 'meta-description', 'meta-keywords']
      },
      'structured-data': {
        name: 'Structured Data',
        components: ['schema-article', 'schema-product', 'schema-organization', 'schema-faq']
      },
      'optimization': {
        name: 'Optimization',
        components: ['heading-structure', 'alt-text', 'canonical-url']
      }
    }
  }
}

export const COMPONENT_DEFINITIONS = {
  // Email Components
  header: {
    name: 'Header',
    icon: '📄',
    color: '#3b82f6',
    defaultContent: {
      title: 'Header Title',
      subtitle: 'Header subtitle',
      alignment: 'center'
    },
    properties: {
      title: { type: 'text', label: 'Title', required: true },
      subtitle: { type: 'text', label: 'Subtitle' },
      alignment: { type: 'select', label: 'Alignment', options: ['left', 'center', 'right'] }
    },
    styles: {
      backgroundColor: '#ffffff',
      padding: '20px',
      textAlign: 'center'
    }
  },
  
  footer: {
    name: 'Footer',
    icon: '🦶',
    color: '#10b981',
    defaultContent: {
      content: 'Footer content',
      copyright: '© 2024 Your Company',
      links: []
    },
    properties: {
      content: { type: 'textarea', label: 'Content' },
      copyright: { type: 'text', label: 'Copyright' },
      links: { type: 'array', label: 'Links', itemType: 'link' }
    },
    styles: {
      backgroundColor: '#f3f4f6',
      padding: '20px',
      textAlign: 'center'
    }
  },
  
  text: {
    name: 'Text Block',
    icon: '📝',
    color: '#6b7280',
    defaultContent: {
      content: 'Your text content here...',
      fontSize: '16px',
      fontWeight: 'normal'
    },
    properties: {
      content: { type: 'textarea', label: 'Content', required: true },
      fontSize: { type: 'select', label: 'Font Size', options: ['12px', '14px', '16px', '18px', '20px', '24px'] },
      fontWeight: { type: 'select', label: 'Font Weight', options: ['normal', 'bold', '600', '700'] }
    },
    styles: {
      padding: '10px',
      lineHeight: '1.5'
    }
  },
  
  image: {
    name: 'Image',
    icon: '🖼️',
    color: '#f59e0b',
    defaultContent: {
      src: '',
      alt: 'Image placeholder',
      caption: '',
      width: '100%'
    },
    properties: {
      src: { type: 'url', label: 'Image URL' },
      alt: { type: 'text', label: 'Alt Text', required: true },
      caption: { type: 'text', label: 'Caption' },
      width: { type: 'select', label: 'Width', options: ['25%', '50%', '75%', '100%'] }
    },
    styles: {
      display: 'block',
      margin: '0 auto'
    }
  },
  
  button: {
    name: 'Button',
    icon: '🔘',
    color: '#ef4444',
    defaultContent: {
      text: 'Click Me',
      url: '#',
      style: 'primary'
    },
    properties: {
      text: { type: 'text', label: 'Button Text', required: true },
      url: { type: 'url', label: 'Link URL' },
      style: { type: 'select', label: 'Style', options: ['primary', 'secondary', 'outline'] }
    },
    styles: {
      backgroundColor: '#3b82f6',
      color: '#ffffff',
      padding: '12px 24px',
      borderRadius: '6px',
      textDecoration: 'none',
      display: 'inline-block'
    }
  },
  
  // Website Components
  navbar: {
    name: 'Navigation',
    icon: '🧭',
    color: '#1e40af',
    defaultContent: {
      brand: 'Brand',
      links: [
        { text: 'Home', url: '#' },
        { text: 'About', url: '#' },
        { text: 'Contact', url: '#' }
      ]
    },
    properties: {
      brand: { type: 'text', label: 'Brand Name' },
      links: { type: 'array', label: 'Navigation Links', itemType: 'link' }
    },
    styles: {
      backgroundColor: '#1e40af',
      color: '#ffffff',
      padding: '1rem'
    }
  },
  
  hero: {
    name: 'Hero Section',
    icon: '🦸',
    color: '#7c3aed',
    defaultContent: {
      title: 'Hero Title',
      subtitle: 'Hero subtitle',
      cta: 'Get Started',
      ctaUrl: '#'
    },
    properties: {
      title: { type: 'text', label: 'Title', required: true },
      subtitle: { type: 'textarea', label: 'Subtitle' },
      cta: { type: 'text', label: 'CTA Text' },
      ctaUrl: { type: 'url', label: 'CTA URL' }
    },
    styles: {
      backgroundColor: '#7c3aed',
      color: '#ffffff',
      padding: '4rem 2rem',
      textAlign: 'center'
    }
  },
  
  // Facebook Components
  'fb-post-header': {
    name: 'Post Header',
    icon: '👤',
    color: '#1877f2',
    defaultContent: {
      name: 'Page Name',
      time: '2 hours ago',
      verified: false
    },
    properties: {
      name: { type: 'text', label: 'Page Name', required: true },
      time: { type: 'text', label: 'Time' },
      verified: { type: 'checkbox', label: 'Verified' }
    },
    styles: {
      padding: '12px',
      backgroundColor: '#ffffff',
      borderRadius: '8px'
    }
  },
  
  'fb-text': {
    name: 'Post Text',
    icon: '💬',
    color: '#374151',
    defaultContent: {
      content: "What's on your mind?"
    },
    properties: {
      content: { type: 'textarea', label: 'Post Content', required: true }
    },
    styles: {
      padding: '16px',
      backgroundColor: '#ffffff'
    }
  },
  
  'fb-cta-button': {
    name: 'CTA Button',
    icon: '🎯',
    color: '#1877f2',
    defaultContent: {
      text: 'Learn More',
      action: 'learn_more'
    },
    properties: {
      text: { type: 'text', label: 'Button Text', required: true },
      action: { type: 'select', label: 'Action', options: ['learn_more', 'shop_now', 'sign_up', 'download'] }
    },
    styles: {
      backgroundColor: '#1877f2',
      color: '#ffffff',
      padding: '8px 16px',
      borderRadius: '6px'
    }
  },
  
  // Instagram Components
  'ig-square-post': {
    name: 'Square Post',
    icon: '📷',
    color: '#e1306c',
    defaultContent: {
      content: 'Instagram Post',
      caption: 'Your caption here...',
      aspectRatio: '1:1'
    },
    properties: {
      content: { type: 'text', label: 'Post Content' },
      caption: { type: 'textarea', label: 'Caption' },
      aspectRatio: { type: 'select', label: 'Aspect Ratio', options: ['1:1', '4:5', '16:9'] }
    },
    styles: {
      aspectRatio: '1',
      backgroundColor: '#f3f4f6',
      borderRadius: '8px'
    }
  },
  
  'ig-story': {
    name: 'Story',
    icon: '📱',
    color: '#833ab4',
    defaultContent: {
      content: 'Story',
      duration: 15
    },
    properties: {
      content: { type: 'text', label: 'Story Content' },
      duration: { type: 'number', label: 'Duration (seconds)', min: 1, max: 60 }
    },
    styles: {
      aspectRatio: '9/16',
      backgroundColor: '#833ab4',
      borderRadius: '12px'
    }
  },
  
  'ig-hashtags': {
    name: 'Hashtags',
    icon: '#️⃣',
    color: '#0ea5e9',
    defaultContent: {
      hashtags: '#instagram #social #marketing'
    },
    properties: {
      hashtags: { type: 'textarea', label: 'Hashtags', placeholder: '#hashtag1 #hashtag2' }
    },
    styles: {
      color: '#0ea5e9',
      padding: '8px'
    }
  }
}

// Helper functions
export function getTemplateTypes() {
  return Object.keys(TEMPLATE_TYPES)
}

export function getTemplateConfig(type) {
  return TEMPLATE_TYPES[type] || null
}

export function getComponentsForTemplate(type) {
  const config = getTemplateConfig(type)
  if (!config) return []
  
  const components = []
  Object.values(config.categories).forEach(category => {
    components.push(...category.components)
  })
  
  return [...new Set(components)] // Remove duplicates
}

export function getComponentDefinition(componentType) {
  return COMPONENT_DEFINITIONS[componentType] || null
}

export function getCategoriesForTemplate(type) {
  const config = getTemplateConfig(type)
  return config ? config.categories : {}
}

export function validateComponent(componentType, data) {
  const definition = getComponentDefinition(componentType)
  if (!definition) return { valid: false, errors: ['Unknown component type'] }
  
  const errors = []
  
  Object.entries(definition.properties).forEach(([key, prop]) => {
    if (prop.required && (!data[key] || data[key].trim() === '')) {
      errors.push(`${prop.label} is required`)
    }
  })
  
  return { valid: errors.length === 0, errors }
}
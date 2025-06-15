class TemplatesController < ApplicationController
  before_action :set_template, only: [ :show, :edit, :update, :destroy, :duplicate, :preview ]

  def index
    @templates = @current_account.templates
                                .order(created_at: :desc)
                                .page(params[:page])

    # Filter by category
    if params[:category].present?
      @templates = @templates.where(template_type: params[:category])
    end

    # Filter by status
    if params[:status].present?
      @templates = @templates.where(status: params[:status])
    end

    @categories = Template.categories.keys
  end

  def show
    @usage_count = @template.campaigns.count
  end

  def new
    @template = @current_account.templates.build
    @template.template_type = params[:category] if params[:category].present?
  end

  def create
    @template = @current_account.templates.build(template_params)
    @template.user = current_user

    if @template.save
      redirect_to @template, notice: "Template was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @template.update(template_params)
      redirect_to @template, notice: "Template was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @template.campaigns.exists?
      redirect_to @template, alert: "Cannot delete template that is being used by campaigns."
    else
      @template.destroy
      redirect_to templates_url, notice: "Template was successfully deleted."
    end
  end

  def duplicate
    @new_template = @template.dup
    @new_template.name = "#{@template.name} (Copy)"
    @new_template.user = current_user

    if @new_template.save
      redirect_to edit_template_path(@new_template), notice: "Template was successfully duplicated."
    else
      redirect_to @template, alert: "Failed to duplicate template."
    end
  end

  def preview
    @contact = Contact.new(first_name: "John", last_name: "Doe", email: "john@example.com")
    @rendered_content = TemplateRenderer.new(@template, @contact).render
    render layout: false
  end

  def test_dropdowns
    render layout: false
  end

  def ui_diagnostic
    render layout: false
  end

  def enhanced_builder
    @template = Template.new
    render layout: false
  end

  def auto_save
    template_id = params[:template_id]
    content = params[:content]

    if template_id.present? && template_id != 'new'
      template = current_user.templates.find_by(id: template_id)
      if template
        template.update(content: content, updated_at: Time.current)
        render json: { success: true, message: 'Auto-saved successfully', last_saved: template.updated_at.strftime('%H:%M') }
      else
        render json: { success: false, message: 'Template not found' }, status: :not_found
      end
    else
      # Store in session for new templates
      session[:template_draft] = { content: content, updated_at: Time.current }
      render json: { success: true, message: 'Draft saved to session', last_saved: Time.current.strftime('%H:%M') }
    end
  end

  def components
    # Return available components for the builder
    components = [
      {
        id: 'email-header',
        name: 'Email Header',
        category: 'headers',
        platform: 'email',
        description: 'Professional email header with logo and navigation',
        thumbnail: asset_path('components/email-header.svg'),
        html: email_header_html,
        css: email_header_css,
        responsive: true
      },
      {
        id: 'tiktok-video',
        name: 'TikTok Video Template',
        category: 'tiktok',
        platform: 'tiktok',
        description: 'Vertical video template with trending effects',
        thumbnail: asset_path('components/tiktok-video.svg'),
        html: tiktok_video_html,
        css: tiktok_video_css,
        aspect_ratio: '9:16'
      },
      {
        id: 'instagram-story',
        name: 'Instagram Story',
        category: 'instagram',
        platform: 'instagram',
        description: 'Story template with interactive elements',
        thumbnail: asset_path('components/instagram-story.svg'),
        html: instagram_story_html,
        css: instagram_story_css,
        aspect_ratio: '9:16'
      },
      {
        id: 'youtube-short',
        name: 'YouTube Short',
        category: 'youtube',
        platform: 'youtube',
        description: 'Short-form video content template',
        thumbnail: asset_path('components/youtube-short.svg'),
        html: youtube_short_html,
        css: youtube_short_css,
        aspect_ratio: '9:16'
      },
      {
        id: 'linkedin-post',
        name: 'LinkedIn Post',
        category: 'social',
        platform: 'linkedin',
        description: 'Professional content for business network',
        thumbnail: asset_path('components/linkedin-post.svg'),
        html: linkedin_post_html,
        css: linkedin_post_css,
        professional: true
      },
      {
        id: 'cta-button',
        name: 'Call-to-Action Button',
        category: 'buttons',
        platform: 'universal',
        description: 'Prominent action button with customizable styling',
        thumbnail: asset_path('components/cta-button.svg'),
        html: cta_button_html,
        css: cta_button_css,
        customizable: true
      },
      {
        id: 'image-gallery',
        name: 'Image Gallery',
        category: 'images',
        platform: 'universal',
        description: 'Responsive image gallery with lightbox',
        thumbnail: asset_path('components/image-gallery.svg'),
        html: image_gallery_html,
        css: image_gallery_css,
        responsive: true
      },
      {
        id: 'contact-form',
        name: 'Contact Form',
        category: 'forms',
        platform: 'universal',
        description: 'Professional contact form with validation',
        thumbnail: asset_path('components/contact-form.svg'),
        html: contact_form_html,
        css: contact_form_css,
        interactive: true
      }
    ]

    render json: components
  end

  def generate
    template_data = params[:template]

    # Simulate AI generation (replace with actual AI service)
    generated_content = generate_ai_template(
      prompt: template_data[:prompt],
      platform: template_data[:platform],
      content_type: template_data[:content_type],
      industry: template_data[:industry],
      tone: template_data[:tone]
    )

    render json: {
      success: true,
      html: generated_content[:html],
      css: generated_content[:css],
      metadata: generated_content[:metadata]
    }
  rescue => e
    render json: {
      success: false,
      message: 'AI generation failed. Please try again.',
      error: e.message
    }, status: :unprocessable_entity
  end

  private

  def set_template
    @template = @current_account.templates.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to templates_path, alert: "Template not found or you do not have permission to access it."
  end

  def template_params
    params.require(:template).permit(:name, :subject, :body, :template_type, :status, :content, :description)
  end

  # AI Template Generation
  def generate_ai_template(prompt:, platform:, content_type:, industry:, tone:)
    # This is a simplified AI generation simulation
    # In production, you would integrate with OpenAI, Claude, or another AI service

    base_templates = {
      'tiktok' => {
        html: tiktok_ai_template(prompt, content_type, industry, tone),
        css: tiktok_video_css,
        metadata: { platform: 'tiktok', type: content_type, industry: industry, tone: tone }
      },
      'instagram' => {
        html: instagram_ai_template(prompt, content_type, industry, tone),
        css: instagram_story_css,
        metadata: { platform: 'instagram', type: content_type, industry: industry, tone: tone }
      },
      'email' => {
        html: email_ai_template(prompt, content_type, industry, tone),
        css: email_header_css,
        metadata: { platform: 'email', type: content_type, industry: industry, tone: tone }
      },
      'linkedin' => {
        html: linkedin_ai_template(prompt, content_type, industry, tone),
        css: linkedin_post_css,
        metadata: { platform: 'linkedin', type: content_type, industry: industry, tone: tone }
      }
    }

    base_templates[platform] || base_templates['email']
  end

  def tiktok_ai_template(prompt, content_type, industry, tone)
    title = generate_tiktok_title(prompt, content_type, industry, tone)
    description = generate_tiktok_description(prompt, content_type, industry, tone)
    hashtags = generate_tiktok_hashtags(content_type, industry)

    <<~HTML
      <div class="tiktok-video ai-generated" style="aspect-ratio: 9/16; background: #000; color: white; position: relative; max-width: 300px; border-radius: 12px; overflow: hidden;">
        <div class="video-background" style="position: absolute; inset: 0; background: linear-gradient(45deg, #ff0050, #25f4ee, #000);">
        </div>
        <div class="video-overlay" style="position: absolute; bottom: 80px; left: 20px; right: 20px; z-index: 2;">
          <h2 style="font-size: 18px; font-weight: bold; margin-bottom: 8px; text-shadow: 2px 2px 4px rgba(0,0,0,0.8);">#{title}</h2>
          <p style="font-size: 14px; line-height: 1.4; text-shadow: 1px 1px 2px rgba(0,0,0,0.8);">#{description}</p>
          <div class="hashtags" style="margin-top: 10px; font-size: 12px; opacity: 0.9;">#{hashtags}</div>
        </div>
        <div class="tiktok-effects" style="position: absolute; right: 15px; bottom: 100px; display: flex; flex-direction: column; gap: 15px;">
          <div style="font-size: 24px; animation: pulse 2s infinite;">✨</div>
          <div style="font-size: 24px; animation: pulse 2s infinite;">❤️</div>
          <div style="font-size: 24px; animation: pulse 2s infinite;">🔥</div>
        </div>
      </div>
    HTML
  end

  def instagram_ai_template(prompt, content_type, industry, tone)
    title = generate_instagram_title(prompt, content_type, industry, tone)
    description = generate_instagram_description(prompt, content_type, industry, tone)

    <<~HTML
      <div class="instagram-story ai-generated" style="aspect-ratio: 9/16; background: linear-gradient(45deg, #f09433, #e6683c, #dc2743, #cc2366, #bc1888); color: white; padding: 20px; display: flex; flex-direction: column; max-width: 300px; border-radius: 12px;">
        <div class="story-header" style="display: flex; align-items: center; gap: 10px; margin-bottom: 20px;">
          <div class="profile-pic" style="width: 40px; height: 40px; border-radius: 50%; background: white; border: 2px solid rgba(255,255,255,0.8);"></div>
          <span style="font-weight: 600; font-size: 14px;">@yourbrand</span>
        </div>
        <div class="story-content" style="flex: 1; display: flex; flex-direction: column; justify-content: center; text-align: center;">
          <h2 style="font-size: 24px; margin-bottom: 10px; text-shadow: 2px 2px 4px rgba(0,0,0,0.3);">#{title}</h2>
          <p style="font-size: 16px; line-height: 1.4;">#{description}</p>
        </div>
        <div class="story-cta" style="text-align: center;">
          <button style="background: rgba(255,255,255,0.9); color: #333; border: none; padding: 12px 24px; border-radius: 25px; font-weight: 600;">Learn More</button>
        </div>
      </div>
    HTML
  end

  def email_ai_template(prompt, content_type, industry, tone)
    subject = generate_email_subject(prompt, content_type, industry, tone)
    content = generate_email_content(prompt, content_type, industry, tone)

    <<~HTML
      <div class="email-template ai-generated" style="max-width: 600px; margin: 0 auto; background: white; font-family: Arial, sans-serif;">
        #{email_header_html}
        <div class="email-body" style="padding: 30px 20px;">
          <h1 style="color: #333; font-size: 28px; margin-bottom: 20px; text-align: center;">#{subject}</h1>
          <div class="email-content" style="color: #555; line-height: 1.6; font-size: 16px;">
            #{content}
          </div>
          <div style="text-align: center; margin-top: 30px;">
            #{cta_button_html}
          </div>
        </div>
        <div class="email-footer" style="background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 14px;">
          <p>© 2024 Your Brand. All rights reserved.</p>
        </div>
      </div>
    HTML
  end

  def linkedin_ai_template(prompt, content_type, industry, tone)
    title = generate_linkedin_title(prompt, content_type, industry, tone)
    content = generate_linkedin_content(prompt, content_type, industry, tone)

    <<~HTML
      <div class="linkedin-post ai-generated" style="background: white; border: 1px solid #e1e5e9; border-radius: 8px; padding: 20px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px;">
        <div class="post-header" style="margin-bottom: 15px;">
          <div class="profile-info" style="display: flex; align-items: center; gap: 12px;">
            <div class="profile-pic" style="width: 48px; height: 48px; border-radius: 50%; background: #0077b5;"></div>
            <div class="profile-details">
              <h4 style="margin: 0; font-size: 16px; font-weight: 600; color: #000;">Your Name</h4>
              <p style="margin: 2px 0 0 0; font-size: 14px; color: #666;">#{industry.humanize} Professional</p>
            </div>
          </div>
        </div>
        <div class="post-content" style="font-size: 14px; line-height: 1.5; color: #000;">
          <h3 style="margin: 0 0 10px 0; font-size: 16px; font-weight: 600;">#{title}</h3>
          <p>#{content}</p>
        </div>
      </div>
    HTML
  end

  # Content generators
  def generate_tiktok_title(prompt, content_type, industry, tone)
    titles = {
      'promotional' => ["🔥 Don't Miss This!", "Limited Time Only!", "You NEED This!"],
      'educational' => ["Learn This Quick Tip!", "Did You Know?", "Pro Tip Alert!"],
      'entertaining' => ["This Will Make You Laugh", "Plot Twist!", "Wait for It..."],
      'trending' => ["Everyone's Doing This", "New Trend Alert!", "Going Viral!"]
    }
    titles[content_type]&.sample || "Amazing Content!"
  end

  def generate_tiktok_description(prompt, content_type, industry, tone)
    "#{prompt.truncate(100)} Perfect for #{industry} content!"
  end

  def generate_tiktok_hashtags(content_type, industry)
    base_tags = ['#fyp', '#viral', '#trending']
    content_tags = {
      'promotional' => ['#sale', '#deal', '#offer'],
      'educational' => ['#learn', '#tips', '#howto'],
      'entertaining' => ['#funny', '#comedy', '#entertainment'],
      'trending' => ['#trend', '#challenge', '#popular']
    }
    industry_tags = {
      'tech' => ['#tech', '#innovation', '#digital'],
      'fitness' => ['#fitness', '#health', '#workout'],
      'food' => ['#food', '#recipe', '#cooking'],
      'fashion' => ['#fashion', '#style', '#outfit']
    }

    all_tags = base_tags + (content_tags[content_type] || []) + (industry_tags[industry] || [])
    all_tags.first(8).join(' ')
  end

  def generate_instagram_title(prompt, content_type, industry, tone)
    case tone
    when 'professional' then "Professional #{industry.humanize} Insights"
    when 'friendly' then "Hey there! Let's talk #{industry}"
    when 'trendy' then "The Latest in #{industry.humanize}"
    else "Discover #{industry.humanize}"
    end
  end

  def generate_instagram_description(prompt, content_type, industry, tone)
    "#{prompt.truncate(80)} Swipe up to learn more!"
  end

  def generate_email_subject(prompt, content_type, industry, tone)
    case content_type
    when 'promotional' then "Special Offer: #{prompt.truncate(30)}"
    when 'educational' then "Learn: #{prompt.truncate(40)}"
    when 'trending' then "Trending Now: #{prompt.truncate(35)}"
    else prompt.truncate(50)
    end
  end

  def generate_email_content(prompt, content_type, industry, tone)
    <<~CONTENT
      <p>#{prompt}</p>
      <p>We're excited to share this #{content_type} content specifically designed for the #{industry} industry.</p>
      <p>With a #{tone} approach, we believe this will resonate perfectly with your audience.</p>
      <p>Ready to take the next step?</p>
    CONTENT
  end

  def generate_linkedin_title(prompt, content_type, industry, tone)
    "#{content_type.humanize} Insights for #{industry.humanize} Professionals"
  end

  def generate_linkedin_content(prompt, content_type, industry, tone)
    "#{prompt} This is particularly relevant for professionals in the #{industry} space. What are your thoughts on this approach?"
  end

  # Component HTML generators (keeping existing ones)
  def email_header_html
    <<~HTML
      <div class="email-header" style="background: #f8f9fa; padding: 20px; text-align: center; border-bottom: 1px solid #e9ecef;">
        <div class="header-content" style="max-width: 600px; margin: 0 auto;">
          <h1 style="margin: 0; font-size: 24px; color: #333; font-family: Arial, sans-serif;">Your Brand</h1>
          <nav style="margin-top: 10px;">
            <a href="#" style="color: #007bff; text-decoration: none; margin: 0 15px;">Home</a>
            <a href="#" style="color: #007bff; text-decoration: none; margin: 0 15px;">Products</a>
            <a href="#" style="color: #007bff; text-decoration: none; margin: 0 15px;">Contact</a>
          </nav>
        </div>
      </div>
    HTML
  end

  def email_header_css
    <<~CSS
      .email-header {
        background: #f8f9fa;
        padding: 20px;
        text-align: center;
        border-bottom: 1px solid #e9ecef;
      }
    CSS
  end

  def tiktok_video_html
    <<~HTML
      <div class="tiktok-video" style="aspect-ratio: 9/16; background: #000; color: white; position: relative; max-width: 300px; border-radius: 12px; overflow: hidden;">
        <div class="video-background" style="position: absolute; inset: 0; background: linear-gradient(45deg, #ff0050, #000);"></div>
        <div class="video-overlay" style="position: absolute; bottom: 80px; left: 20px; right: 20px; z-index: 2;">
          <h2 style="font-size: 18px; font-weight: bold; margin-bottom: 8px; text-shadow: 2px 2px 4px rgba(0,0,0,0.8);">Your TikTok Content</h2>
          <p style="font-size: 14px; line-height: 1.4; text-shadow: 1px 1px 2px rgba(0,0,0,0.8);">Add your engaging description here #trending #viral</p>
        </div>
      </div>
    HTML
  end

  def tiktok_video_css
    <<~CSS
      .tiktok-video { aspect-ratio: 9/16; background: #000; color: white; position: relative; max-width: 300px; border-radius: 12px; overflow: hidden; }
      @keyframes pulse { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.1); } }
    CSS
  end

  def instagram_story_html
    <<~HTML
      <div class="instagram-story" style="aspect-ratio: 9/16; background: linear-gradient(45deg, #f09433, #e6683c, #dc2743, #cc2366, #bc1888); color: white; padding: 20px; display: flex; flex-direction: column; max-width: 300px; border-radius: 12px;">
        <div class="story-content" style="flex: 1; display: flex; flex-direction: column; justify-content: center; text-align: center;">
          <h2 style="font-size: 24px; margin-bottom: 10px; text-shadow: 2px 2px 4px rgba(0,0,0,0.3);">Your Story Content</h2>
        </div>
      </div>
    HTML
  end

  def instagram_story_css
    <<~CSS
      .instagram-story { aspect-ratio: 9/16; background: linear-gradient(45deg, #f09433, #e6683c, #dc2743, #cc2366, #bc1888); color: white; }
    CSS
  end

  def youtube_short_html
    <<~HTML
      <div class="youtube-short" style="aspect-ratio: 9/16; background: #000; color: white; position: relative; max-width: 300px; border-radius: 12px;">
        <div class="shorts-info" style="position: absolute; bottom: 20px; left: 20px; right: 20px;">
          <h3>Your YouTube Short</h3>
        </div>
      </div>
    HTML
  end

  def youtube_short_css
    <<~CSS
      .youtube-short { aspect-ratio: 9/16; background: #000; color: white; }
    CSS
  end

  def linkedin_post_html
    <<~HTML
      <div class="linkedin-post" style="background: white; border: 1px solid #e1e5e9; border-radius: 8px; padding: 20px;">
        <p>Share your professional insights and industry knowledge.</p>
      </div>
    HTML
  end

  def linkedin_post_css
    <<~CSS
      .linkedin-post { background: white; border: 1px solid #e1e5e9; border-radius: 8px; padding: 20px; }
    CSS
  end

  def cta_button_html
    <<~HTML
      <div class="cta-container" style="text-align: center; padding: 30px;">
        <button class="cta-button" style="background: linear-gradient(135deg, #007bff, #0056b3); color: white; border: none; padding: 15px 30px; border-radius: 8px; font-size: 16px; font-weight: 600;">Call to Action</button>
      </div>
    HTML
  end

  def cta_button_css
    <<~CSS
      .cta-button { background: linear-gradient(135deg, #007bff, #0056b3); color: white; border: none; padding: 15px 30px; border-radius: 8px; }
    CSS
  end

  def image_gallery_html
    <<~HTML
      <div class="image-gallery" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; padding: 20px;">
        <div class="gallery-item" style="aspect-ratio: 1; background: #f8f9fa; border-radius: 8px;">Image 1</div>
      </div>
    HTML
  end

  def image_gallery_css
    <<~CSS
      .image-gallery { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; }
    CSS
  end

  def contact_form_html
    <<~HTML
      <div class="contact-form" style="max-width: 500px; margin: 0 auto; padding: 30px; background: white; border-radius: 12px;">
        <h3>Get In Touch</h3>
        <form>
          <input type="text" placeholder="Your Name" style="width: 100%; padding: 12px; margin-bottom: 15px; border: 1px solid #ddd; border-radius: 6px;">
          <input type="email" placeholder="your@email.com" style="width: 100%; padding: 12px; margin-bottom: 15px; border: 1px solid #ddd; border-radius: 6px;">
          <textarea placeholder="Your message..." style="width: 100%; padding: 12px; margin-bottom: 15px; border: 1px solid #ddd; border-radius: 6px; min-height: 100px;"></textarea>
          <button type="submit" style="width: 100%; background: #007bff; color: white; border: none; padding: 12px; border-radius: 6px;">Send Message</button>
        </form>
      </div>
    HTML
  end

  def contact_form_css
    <<~CSS
      .contact-form { max-width: 500px; margin: 0 auto; padding: 30px; background: white; border-radius: 12px; }
    CSS
  end
end

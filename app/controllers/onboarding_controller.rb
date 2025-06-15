class OnboardingController < ApplicationController
  before_action :authenticate_user!
  before_action :set_onboarding_progress
  before_action :check_already_completed, except: [:show, :restart]
  
  # GET /onboarding
  def show
    if @progress.completed?
      redirect_to dashboard_path, notice: "Welcome back! You've completed onboarding."
      return
    end
    
    @current_step = @progress.current_step_info
    @progress_summary = @progress.progress_summary
    
    # Redirect to specific step
    redirect_to onboarding_step_path(@progress.current_step)
  end
  
  # GET /onboarding/welcome
  def welcome
    redirect_unless_current_step('welcome')
    
    @user_name = current_user.first_name || current_user.email.split('@').first.titleize
    @account_name = current_user.account.name
  end
  
  # POST /onboarding/welcome
  def complete_welcome
    @progress.complete_step!('welcome')
    
    redirect_to onboarding_step_path('business_info'), 
                notice: "Great! Let's set up your business profile."
  end
  
  # GET /onboarding/business_info
  def business_info
    redirect_unless_current_step('business_info')
    
    @account = current_user.account
    @business_types = [
      'E-commerce Store',
      'Local Business', 
      'Consulting/Services',
      'SaaS/Tech Startup',
      'Agency/Marketing',
      'Non-profit',
      'Creator/Influencer',
      'Other'
    ]
  end
  
  # POST /onboarding/business_info
  def complete_business_info
    account_params = params.require(:account).permit(:name, :business_type, :website, :industry)
    
    if current_user.account.update(account_params)
      @progress.complete_step!('business_info', {
        business_type: account_params[:business_type],
        industry: account_params[:industry]
      })
      
      redirect_to onboarding_step_path('first_contacts'),
                  notice: "Perfect! Now let's add your contacts."
    else
      @account = current_user.account
      @business_types = business_types_list
      render :business_info, status: :unprocessable_entity
    end
  end
  
  # GET /onboarding/first_contacts
  def first_contacts
    redirect_unless_current_step('first_contacts')
    
    @contacts_count = current_user.account.contacts.count
    @plan_limit = current_user.account.plan_limits[:contacts]
    @can_import = @contacts_count < @plan_limit
  end
  
  # POST /onboarding/first_contacts
  def complete_first_contacts
    method = params[:method] # 'manual', 'import', or 'skip'
    
    case method
    when 'manual'
      # Quick manual contact addition
      contact_params = params.require(:contact).permit(:first_name, :last_name, :email)
      
      contact = current_user.account.contacts.build(contact_params)
      contact.status = 'subscribed'
      contact.subscribed_at = Time.current
      
      if contact.save
        @progress.complete_step!('first_contacts', { method: 'manual', contacts_added: 1 })
        redirect_to onboarding_step_path('choose_template'),
                    notice: "Great! Contact added. Let's pick a template."
      else
        @contacts_count = current_user.account.contacts.count
        @plan_limit = current_user.account.plan_limits[:contacts]
        @contact = contact
        render :first_contacts, status: :unprocessable_entity
      end
      
    when 'import'
      # Handle CSV import (simplified)
      if params[:csv_file].present?
        result = ContactImportService.new(current_user.account).import_csv(params[:csv_file])
        
        if result[:success]
          @progress.complete_step!('first_contacts', { 
            method: 'import', 
            contacts_added: result[:imported_count] 
          })
          redirect_to onboarding_step_path('choose_template'),
                      notice: "#{result[:imported_count]} contacts imported! Let's create your first campaign."
        else
          redirect_to onboarding_step_path('first_contacts'),
                      alert: "Import failed: #{result[:error]}"
        end
      else
        redirect_to onboarding_step_path('first_contacts'),
                    alert: "Please select a CSV file to import."
      end
      
    when 'skip'
      # Create a sample contact for demo
      sample_contact = current_user.account.contacts.create!(
        first_name: 'Sample',
        last_name: 'Contact',
        email: 'sample@example.com',
        status: 'subscribed',
        subscribed_at: Time.current
      )
      
      @progress.complete_step!('first_contacts', { method: 'demo', contacts_added: 1 })
      redirect_to onboarding_step_path('choose_template'),
                  notice: "We've added a sample contact. You can add real contacts later!"
    end
  end
  
  # GET /onboarding/choose_template
  def choose_template
    redirect_unless_current_step('choose_template')
    
    @templates = Template.public_templates.active.free
                        .where(template_type: 'email')
                        .limit(6)
    @can_create_custom = current_user.account.plan != 'free'
  end
  
  # POST /onboarding/choose_template
  def complete_choose_template
    template_choice = params[:choice] # 'existing' or 'custom'
    
    case template_choice
    when 'existing'
      template_id = params[:template_id]
      source_template = Template.public_templates.find(template_id)
      
      # Copy template to user's account
      user_template = source_template.duplicate
      user_template.account = current_user.account
      user_template.user = current_user
      user_template.name = "My #{source_template.name}"
      
      if user_template.save
        @progress.complete_step!('choose_template', { 
          method: 'existing', 
          template_id: user_template.id,
          source_template: source_template.name
        })
        
        session[:onboarding_template_id] = user_template.id
        redirect_to onboarding_step_path('first_campaign'),
                    notice: "Template ready! Let's create your first campaign."
      else
        redirect_to onboarding_step_path('choose_template'),
                    alert: "Error copying template. Please try again."
      end
      
    when 'custom'
      # Redirect to simple template creator
      redirect_to new_template_path(onboarding: true)
      
    when 'skip'
      # Use a default template
      default_template = Template.public_templates.active.free.first
      
      @progress.complete_step!('choose_template', { method: 'default' })
      session[:onboarding_template_id] = default_template.id
      redirect_to onboarding_step_path('first_campaign'),
                  notice: "We'll use a default template. You can customize it later!"
    end
  end
  
  # GET /onboarding/first_campaign  
  def first_campaign
    redirect_unless_current_step('first_campaign')
    
    @template_id = session[:onboarding_template_id] || current_user.account.templates.first&.id
    @contacts_count = current_user.account.contacts.count
    @template = Template.find(@template_id) if @template_id
    
    @campaign = current_user.account.campaigns.build(
      name: "My First Campaign",
      subject: "Hello from #{current_user.account.name}!",
      template_id: @template_id,
      from_name: current_user.full_name,
      from_email: current_user.email
    )
  end
  
  # POST /onboarding/first_campaign
  def complete_first_campaign
    campaign_params = params.require(:campaign).permit(:name, :subject, :from_name, :from_email, :template_id)
    
    @campaign = current_user.account.campaigns.build(campaign_params)
    @campaign.user = current_user
    @campaign.status = 'draft'
    
    if @campaign.save
      # Add all contacts to the campaign
      current_user.account.contacts.active.find_each do |contact|
        @campaign.campaign_contacts.create!(contact: contact)
      end
      
      action = params[:action_type] # 'send_now' or 'save_draft'
      
      if action == 'send_now' && @campaign.can_be_sent?
        # Send immediately
        CampaignSenderJob.perform_later(@campaign.id)
        @campaign.update!(status: 'sending')
        
        @progress.complete_step!('first_campaign', { 
          campaign_id: @campaign.id,
          action: 'sent',
          recipients: @campaign.campaign_contacts.count
        })
        
        redirect_to onboarding_step_path('explore_features'),
                    notice: "🎉 Your first campaign is being sent! Check the dashboard to see results."
      else
        # Save as draft
        @progress.complete_step!('first_campaign', { 
          campaign_id: @campaign.id,
          action: 'saved_draft'
        })
        
        redirect_to onboarding_step_path('explore_features'),
                    notice: "Campaign saved! You can send it from your dashboard when ready."
      end
    else
      @template_id = campaign_params[:template_id]
      @template = Template.find(@template_id) if @template_id
      @contacts_count = current_user.account.contacts.count
      render :first_campaign, status: :unprocessable_entity
    end
  end
  
  # GET /onboarding/explore_features
  def explore_features
    @progress.complete_step!('explore_features') unless @progress.step_completed?('explore_features')
    
    @features = [
      {
        title: 'Email Automation',
        description: 'Set up drip campaigns and automated sequences',
        icon: '🤖',
        link: campaigns_path,
        available: true
      },
      {
        title: 'Advanced Analytics', 
        description: 'Track opens, clicks, and campaign performance',
        icon: '📊',
        link: analytics_path,
        available: true
      },
      {
        title: 'Team Collaboration',
        description: 'Invite team members to help with marketing',
        icon: '👥',
        link: account_path,
        available: current_user.account.can_have_team_members?
      },
      {
        title: 'Template Marketplace',
        description: 'Browse professional email templates',
        icon: '🎨',
        link: marketplace_templates_path,
        available: true
      }
    ]
    
    @next_steps = [
      'Import more contacts',
      'Create automated email sequences', 
      'Set up your brand colors and logo',
      'Invite team members',
      'Explore the template marketplace'
    ]
  end
  
  # POST /onboarding/complete
  def complete
    @progress.complete_onboarding!
    
    redirect_to dashboard_path, 
                notice: "🎉 Welcome to RapidMarkt! You're all set up and ready to grow your business."
  end
  
  # POST /onboarding/skip_step
  def skip_step
    step = params[:step]
    next_step_info = @progress.next_step
    
    if next_step_info
      @progress.skip_to_step!(next_step_info[:key])
      redirect_to onboarding_step_path(next_step_info[:key]),
                  notice: "Step skipped. You can always come back to complete it later."
    else
      @progress.complete_onboarding!
      redirect_to dashboard_path,
                  notice: "Onboarding completed! Welcome to RapidMarkt."
    end
  end
  
  # POST /onboarding/restart
  def restart
    @progress.restart!
    redirect_to onboarding_path,
                notice: "Onboarding restarted. Let's go through the setup again!"
  end
  
  private
  
  def set_onboarding_progress
    @progress = OnboardingProgress.for_user(current_user)
  end
  
  def check_already_completed
    if @progress.completed?
      redirect_to dashboard_path, 
                  notice: "You've already completed onboarding! Welcome back."
    end
  end
  
  def redirect_unless_current_step(expected_step)
    unless @progress.current_step == expected_step
      redirect_to onboarding_step_path(@progress.current_step)
    end
  end
  
  def onboarding_step_path(step)
    "/onboarding/#{step}"
  end
  
  def business_types_list
    [
      'E-commerce Store',
      'Local Business', 
      'Consulting/Services',
      'SaaS/Tech Startup',
      'Agency/Marketing',
      'Non-profit',
      'Creator/Influencer',
      'Other'
    ]
  end
end
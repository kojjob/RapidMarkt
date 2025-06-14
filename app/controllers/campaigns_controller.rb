class CampaignsController < ApplicationController
  before_action :set_campaign, only: [:show, :edit, :update, :destroy, :send_campaign, :send_test, :preview]

  def index
    @campaigns = @current_account.campaigns.includes(:template)
                                .order(created_at: :desc)
                                .page(params[:page])
  end

  def show
    @campaign_stats = calculate_campaign_stats(@campaign)
    @recent_activities = @campaign.campaign_contacts
                                  .includes(:contact)
                                  .where.not(sent_at: nil)
                                  .order(sent_at: :desc)
                                  .limit(10)
  end

  def new
    @campaign = @current_account.campaigns.build
    @templates = @current_account.templates.active
  end

  def create
    @campaign = @current_account.campaigns.build(campaign_params)
    @campaign.user = current_user

    if @campaign.save
      redirect_to @campaign, notice: 'Campaign was successfully created.'
    else
      @templates = @current_account.templates.active
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @templates = @current_account.templates.active
  end

  def update
    if @campaign.update(campaign_params)
      redirect_to @campaign, notice: 'Campaign was successfully updated.'
    else
      @templates = @current_account.templates.active
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @campaign.destroy
    redirect_to campaigns_url, notice: 'Campaign was successfully deleted.'
  end

  def preview
    @contact = @current_account.contacts.first || Contact.new(first_name: 'John', last_name: 'Doe', email: 'john@example.com')
    render layout: false
  end

  def send_campaign
    if @campaign.can_be_sent?
      # Queue the campaign for sending via background job
      CampaignSenderJob.perform_later(@campaign.id)
      
      redirect_to @campaign, notice: 'Campaign is being sent! You will be notified when complete.'
    else
      redirect_to @campaign, alert: 'Campaign cannot be sent in its current state.'
    end
  end

  def send_test
    if @campaign.draft?
      # Send test email to current user
      test_contact = Contact.new(
        first_name: current_user.first_name || 'Test',
        last_name: current_user.last_name || 'User',
        email: current_user.email
      )
      
      begin
        CampaignMailer.send_campaign(
          campaign: @campaign,
          contact: test_contact,
          subject: @campaign.subject,
          content: @campaign.template&.body || "Test content"
        ).deliver_now
        
        redirect_to @campaign, notice: 'Test email sent successfully!'
      rescue => e
        redirect_to @campaign, alert: "Failed to send test email: #{e.message}"
      end
    else
      redirect_to @campaign, alert: 'Test emails can only be sent for draft campaigns.'
    end
  end

  def bulk_send
    campaign_ids = params[:campaign_ids] || []
    
    if campaign_ids.empty?
      redirect_to campaigns_path, alert: 'No campaigns selected.'
      return
    end

    campaigns = @current_account.campaigns.where(id: campaign_ids, status: 'draft')
    
    if campaigns.empty?
      redirect_to campaigns_path, alert: 'No valid campaigns found to send.'
      return
    end

    sent_count = 0
    failed_campaigns = []

    campaigns.each do |campaign|
      if campaign.can_be_sent?
        CampaignSenderJob.perform_later(campaign.id)
        sent_count += 1
      else
        failed_campaigns << campaign.name
      end
    end

    if sent_count > 0
      notice = "#{sent_count} campaign#{'s' if sent_count != 1} queued for sending!"
      notice += " Failed: #{failed_campaigns.join(', ')}" if failed_campaigns.any?
      redirect_to campaigns_path, notice: notice
    else
      redirect_to campaigns_path, alert: "Failed to send campaigns: #{failed_campaigns.join(', ')}"
    end
  end

  def bulk_schedule
    campaign_ids = params[:campaign_ids] || []
    
    if campaign_ids.empty?
      redirect_to campaigns_path, alert: 'No campaigns selected.'
      return
    end

    # For now, redirect to a scheduling interface
    # In a full implementation, you'd show a modal or form to select the schedule time
    redirect_to campaigns_path, notice: 'Bulk scheduling feature coming soon! Please schedule campaigns individually for now.'
  end

  private

  def set_campaign
    @campaign = @current_account.campaigns.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to campaigns_path, alert: 'Campaign not found or you do not have permission to access it.'
  end

  def campaign_params
    params.require(:campaign).permit(
      :name, :subject, :template_id, :scheduled_at, :status, :from_name, :from_email, :reply_to, 
      :recipient_type, :send_type, :media_type, :media_urls, :design_theme, :background_color, 
      :text_color, :font_family, :header_image_url, :logo_url, :call_to_action_text, 
      :call_to_action_url, :social_sharing_enabled, :social_platforms,
      tag_ids: [], media_urls_array: [], social_platforms_array: []
    )
  end

  def calculate_campaign_stats(campaign)
    campaign_contacts = campaign.campaign_contacts
    total_sent = campaign_contacts.where.not(sent_at: nil).count
    total_opened = campaign_contacts.where.not(opened_at: nil).count
    total_clicked = campaign_contacts.where.not(clicked_at: nil).count
    total_unsubscribed = campaign_contacts.where.not(unsubscribed_at: nil).count

    {
      total_sent: total_sent,
      total_opened: total_opened,
      total_clicked: total_clicked,
      total_unsubscribed: total_unsubscribed,
      open_rate: total_sent > 0 ? (total_opened.to_f / total_sent * 100).round(2) : 0,
      click_rate: total_sent > 0 ? (total_clicked.to_f / total_sent * 100).round(2) : 0
    }
  end
end
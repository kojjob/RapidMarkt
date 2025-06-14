class CampaignsController < ApplicationController
  before_action :set_campaign, only: [ :show, :edit, :update, :destroy, :send_campaign, :send_test, :preview, :pause, :resume, :stop, :duplicate ]

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
      redirect_to @campaign, notice: "Campaign was successfully created."
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
      redirect_to @campaign, notice: "Campaign was successfully updated."
    else
      @templates = @current_account.templates.active
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @campaign.destroy
    redirect_to campaigns_url, notice: "Campaign was successfully deleted."
  end

  def preview
    @contact = @current_account.contacts.first || Contact.new(first_name: "John", last_name: "Doe", email: "john@example.com")
    render layout: false
  end

  def send_campaign
    if @campaign.can_be_sent?
      # Queue the campaign for sending via background job
      CampaignSenderJob.perform_later(@campaign.id)

      redirect_to @campaign, notice: "Campaign is being sent! You will be notified when complete."
    else
      redirect_to @campaign, alert: "Campaign cannot be sent in its current state."
    end
  end

  def send_test
    if @campaign.draft?
      # Send test email to current user
      test_contact = Contact.new(
        first_name: current_user.first_name || "Test",
        last_name: current_user.last_name || "User",
        email: current_user.email
      )

      begin
        CampaignMailer.send_campaign(
          campaign: @campaign,
          contact: test_contact,
          subject: @campaign.subject,
          content: @campaign.template&.body || "Test content"
        ).deliver_now

        redirect_to @campaign, notice: "Test email sent successfully!"
      rescue => e
        redirect_to @campaign, alert: "Failed to send test email: #{e.message}"
      end
    else
      redirect_to @campaign, alert: "Test emails can only be sent for draft campaigns."
    end
  end

  def bulk_send
    campaign_ids = params[:campaign_ids] || []

    if campaign_ids.empty?
      respond_to do |format|
        format.html { redirect_to campaigns_path, alert: "No campaigns selected." }
        format.json { render json: { success: false, message: "No campaigns selected." }, status: :bad_request }
      end
      return
    end

    campaigns = @current_account.campaigns.where(id: campaign_ids, status: ["draft", "scheduled"])

    if campaigns.empty?
      respond_to do |format|
        format.html { redirect_to campaigns_path, alert: "No valid campaigns found to send." }
        format.json { render json: { success: false, message: "No valid campaigns found to send." }, status: :bad_request }
      end
      return
    end

    sent_count = 0
    failed_campaigns = []

    campaigns.each do |campaign|
      if campaign.can_be_sent?
        begin
          campaign.update!(status: "sending")
          CampaignSenderJob.perform_later(campaign.id)
          sent_count += 1
        rescue => e
          failed_campaigns << { name: campaign.name, error: e.message }
        end
      else
        failed_campaigns << { name: campaign.name, error: "Campaign not ready to send" }
      end
    end

    if sent_count > 0
      message = "#{sent_count} campaign#{'s' if sent_count != 1} queued for sending!"
      if failed_campaigns.any?
        message += " Failed: #{failed_campaigns.map { |f| f[:name] }.join(', ')}"
      end
      
      respond_to do |format|
        format.html { redirect_to campaigns_path, notice: message }
        format.json { render json: { success: true, message: message, sent_count: sent_count, failed_campaigns: failed_campaigns } }
      end
    else
      error_message = "Failed to send campaigns: #{failed_campaigns.map { |f| "#{f[:name]} (#{f[:error]})" }.join(', ')}"
      
      respond_to do |format|
        format.html { redirect_to campaigns_path, alert: error_message }
        format.json { render json: { success: false, message: error_message, failed_campaigns: failed_campaigns }, status: :unprocessable_entity }
      end
    end
  end

  def bulk_schedule
    campaign_ids = params[:campaign_ids] || []
    scheduled_at = params[:scheduled_at]
    
    if campaign_ids.empty?
      render json: { success: false, message: "No campaigns selected." }, status: :bad_request
      return
    end
    
    if scheduled_at.blank?
      render json: { success: false, message: "Schedule time is required." }, status: :bad_request
      return
    end
    
    begin
      schedule_time = Time.parse(scheduled_at)
      
      if schedule_time <= Time.current
        render json: { success: false, message: "Schedule time must be in the future." }, status: :bad_request
        return
      end
      
      campaigns = @current_account.campaigns.where(id: campaign_ids, status: "draft")
      
      if campaigns.empty?
        render json: { success: false, message: "No valid campaigns found to schedule." }, status: :bad_request
        return
      end
      
      scheduled_count = 0
      failed_campaigns = []
      
      campaigns.each do |campaign|
        if campaign.can_be_scheduled?
          campaign.update!(
            status: "scheduled",
            scheduled_at: schedule_time
          )
          
          # Queue the campaign for sending at the scheduled time
          ScheduledCampaignProcessorJob.perform_at(schedule_time, campaign.id)
          scheduled_count += 1
        else
          failed_campaigns << campaign.name
        end
      end
      
      if scheduled_count > 0
        message = "#{scheduled_count} campaign#{'s' if scheduled_count != 1} scheduled for #{schedule_time.strftime('%B %d, %Y at %I:%M %p')}!"
        message += " Failed: #{failed_campaigns.join(', ')}" if failed_campaigns.any?
        render json: { success: true, message: message, scheduled_count: scheduled_count }
      else
        render json: { success: false, message: "Failed to schedule campaigns: #{failed_campaigns.join(', ')}" }, status: :unprocessable_entity
      end
      
    rescue ArgumentError => e
      render json: { success: false, message: "Invalid date format." }, status: :bad_request
    rescue => e
      render json: { success: false, message: "Error scheduling campaigns: #{e.message}" }, status: :internal_server_error
    end
  end

  def dashboard
    @campaigns = @current_account.campaigns.includes(:template, :campaign_contacts)
    @campaign_stats = calculate_dashboard_stats
    
    # Set instance variables for template compatibility
    @total_campaigns = @campaign_stats[:total_campaigns]
    @active_campaigns = @campaign_stats[:active_campaigns]
    @sent_campaigns = @campaign_stats[:sent_campaigns]
    @paused_campaigns = @campaign_stats[:paused_campaigns]
    @recent_campaigns = @campaigns.recent.limit(5)
    
    respond_to do |format|
      format.html
      format.json do
        render json: @campaign_stats.merge(
          performance_data: {
            daily_sends: [],
            weekly_opens: [],
            monthly_clicks: []
          },
          status_distribution: {
            draft: @current_account.campaigns.where(status: 'draft').count,
            scheduled: @current_account.campaigns.where(status: 'scheduled').count,
            sending: @current_account.campaigns.where(status: 'sending').count,
            sent: @current_account.campaigns.where(status: 'sent').count,
            paused: @current_account.campaigns.where(status: 'paused').count,
            cancelled: @current_account.campaigns.where(status: 'cancelled').count
          }
        )
      end
    end
  end

  def pause
    if @campaign.sending?
      @campaign.pause!
      render json: { success: true, message: 'Campaign paused successfully' }
    else
      render json: { success: false, message: 'Campaign cannot be paused in its current state' }, status: :unprocessable_entity
    end
  end

  def resume
    if @campaign.paused?
      @campaign.update!(status: 'sending')
      render json: { success: true, message: 'Campaign resumed successfully' }
    else
      render json: { success: false, message: 'Campaign cannot be resumed in its current state' }, status: :unprocessable_entity
    end
  end

  def stop
    if @campaign.sending?
      @campaign.update!(status: 'cancelled')
      render json: { success: true, message: 'Campaign stopped successfully' }
    else
      render json: { success: false, message: 'Campaign cannot be stopped in its current state' }, status: :unprocessable_entity
    end
  end

  def duplicate
    new_campaign = @campaign.dup
    new_campaign.name = "#{@campaign.name} (Copy)"
    new_campaign.status = 'draft'
    new_campaign.sent_at = nil
    new_campaign.scheduled_at = nil
    new_campaign.user = current_user
    
    if new_campaign.save
      render json: { 
        success: true, 
        message: 'Campaign duplicated successfully',
        campaign: {
          id: new_campaign.id,
          name: new_campaign.name,
          status: new_campaign.status
        }
      }
    else
      render json: { 
        success: false, 
        message: 'Failed to duplicate campaign',
        errors: new_campaign.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def set_campaign
    @campaign = @current_account.campaigns.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    if request.format.json? || params[:format] == 'json'
      raise ActiveRecord::RecordNotFound
    else
      redirect_to campaigns_path, alert: "Campaign not found or you do not have permission to access it."
    end
  end

  def campaign_params
    params.require(:campaign).permit(
      :name, :subject, :preview_text, :template_id, :scheduled_at, :status, :from_name, :from_email, :reply_to,
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

  def calculate_dashboard_stats
    campaigns = @current_account.campaigns
    
    {
      total_campaigns: campaigns.count,
      active_campaigns: campaigns.where(status: ['draft', 'scheduled', 'sending']).count,
      sent_campaigns: campaigns.where(status: 'sent').count,
      paused_campaigns: campaigns.where(status: 'paused').count,
      recent_campaigns: campaigns.recent.limit(5).map do |campaign|
        {
          id: campaign.id,
          name: campaign.name,
          status: campaign.status,
          created_at: campaign.created_at,
          sent_at: campaign.sent_at
        }
      end
    }
  end
end

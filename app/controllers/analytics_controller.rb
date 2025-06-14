class AnalyticsController < ApplicationController
  def index
    @date_range = params[:date_range] || "last_30_days"
    @analytics_service = AnalyticsService.new(@current_account)

    # Overview statistics
    @overview_stats = @analytics_service.overview_stats(@date_range)

    # Recent campaign performance
    @campaign_performance = @analytics_service.campaign_performance(@date_range).first(10) || []

    # Contact growth
    @contact_growth = @analytics_service.contact_growth(@date_range)

    # Engagement trends
    @engagement_trends = @analytics_service.engagement_trends(@date_range)
    
    # Top performing campaigns
    @top_campaigns = @analytics_service.top_performing_campaigns(5, @date_range)
    
    # Contact segments
    @contact_segments = @analytics_service.contact_segments
    
    # Real-time stats
    @real_time_stats = @analytics_service.real_time_stats
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          overview: @overview_stats,
          campaigns: @campaign_performance,
          contact_growth: @contact_growth,
          engagement_trends: @engagement_trends,
          top_campaigns: @top_campaigns,
          contact_segments: @contact_segments,
          real_time: @real_time_stats
        }
      end
    end
  end

  def campaigns
    @campaigns = @current_account.campaigns
                                .includes(:campaign_contacts)
                                .where(created_at: parse_date_range)
                                .order(created_at: :desc)

    @campaigns_with_stats = @campaigns.map do |campaign|
      {
        campaign: campaign,
        stats: calculate_campaign_stats(campaign)
      }
    end
  end

  def contacts
    @date_range = parse_date_range
    @contact_growth = calculate_contact_growth
    @engagement_by_contact = calculate_contact_engagement
    @top_engaged_contacts = top_engaged_contacts
  end

  def export
    @date_range = params[:date_range] || "last_30_days"
    format = params[:format] || "csv"
    @analytics_service = AnalyticsService.new(@current_account)

    begin
      export_data = @analytics_service.export_data(format, @date_range)

      case format.downcase
      when "csv"
        send_data export_data,
                  filename: "analytics_#{@date_range}_#{Date.current}.csv",
                  type: "text/csv"
      when "pdf"
        send_data export_data,
                  filename: "analytics_#{@date_range}_#{Date.current}.pdf",
                  type: "application/pdf"
      else
        redirect_to analytics_path, alert: "Invalid export format"
      end
    rescue => e
      redirect_to analytics_path, alert: "Export failed: #{e.message}"
    end
  end
  
  def real_time
    @analytics_service = AnalyticsService.new(@current_account)
    
    render json: @analytics_service.real_time_stats
  end
  
  def chart_data
    @date_range = params[:date_range] || "last_30_days"
    chart_type = params[:chart_type] || "engagement"
    @analytics_service = AnalyticsService.new(@current_account)
    
    data = case chart_type
    when "engagement"
      @analytics_service.engagement_trends(@date_range)
    when "contact_growth"
      @analytics_service.contact_growth(@date_range)[:daily_growth]
    when "campaign_performance"
      @analytics_service.top_performing_campaigns(10, @date_range)
    else
      []
    end
    
    render json: {
      chart_type: chart_type,
      date_range: @date_range,
      data: data
    }
  end
  
  def dashboard_summary
    @analytics_service = AnalyticsService.new(@current_account)
    
    render json: {
      overview: @analytics_service.overview_stats("last_30_days"),
      real_time: @analytics_service.real_time_stats,
      contact_segments: @analytics_service.contact_segments,
      top_campaigns: @analytics_service.top_performing_campaigns(3, "last_7_days")
    }
  end

  private

  def parse_date_range
    case params[:period]
    when "week"
      1.week.ago..Time.current
    when "month"
      1.month.ago..Time.current
    when "3months"
      3.months.ago..Time.current
    when "year"
      1.year.ago..Time.current
    when "custom"
      if params[:start_date].present? && params[:end_date].present?
        Date.parse(params[:start_date])..Date.parse(params[:end_date])
      else
        30.days.ago..Time.current
      end
    else
      30.days.ago..Time.current
    end
  end

  def calculate_overview_stats
    campaigns = @current_account.campaigns.where(created_at: @date_range)
    campaign_contacts = CampaignContact.joins(:campaign)
                                      .where(campaigns: { account: @current_account })
                                      .where(created_at: @date_range)

    {
      total_campaigns: campaigns.count,
      total_sent: campaign_contacts.where.not(sent_at: nil).count,
      total_opened: campaign_contacts.where.not(opened_at: nil).count,
      total_clicked: campaign_contacts.where.not(clicked_at: nil).count,
      total_unsubscribed: campaign_contacts.where.not(unsubscribed_at: nil).count
    }
  end

  def calculate_campaign_performance
    stats = @overview_stats
    return {} if stats[:total_sent] == 0

    {
      open_rate: (stats[:total_opened].to_f / stats[:total_sent] * 100).round(2),
      click_rate: (stats[:total_clicked].to_f / stats[:total_sent] * 100).round(2),
      unsubscribe_rate: (stats[:total_unsubscribed].to_f / stats[:total_sent] * 100).round(2)
    }
  end

  def calculate_engagement_trends
    # Group by day for the last 30 days
    campaign_contacts = CampaignContact.joins(:campaign)
                                      .where(campaigns: { account: @current_account })
                                      .where(sent_at: @date_range)

    trends = {}
    (@date_range.begin.to_date..@date_range.end.to_date).each do |date|
      day_contacts = campaign_contacts.where(sent_at: date.beginning_of_day..date.end_of_day)

      trends[date.strftime("%Y-%m-%d")] = {
        sent: day_contacts.count,
        opened: day_contacts.where.not(opened_at: nil).count,
        clicked: day_contacts.where.not(clicked_at: nil).count
      }
    end

    trends
  end

  def top_performing_campaigns
    campaigns_with_stats = @current_account.campaigns
                                          .joins(:campaign_contacts)
                                          .where(created_at: @date_range)
                                          .group(:id, :name)
                                          .having("COUNT(campaign_contacts.id) > 0")
                                          .select(
                                            "campaigns.*",
                                            "COUNT(campaign_contacts.id) as sent_count",
                                            "COUNT(CASE WHEN campaign_contacts.opened_at IS NOT NULL THEN 1 END) as opened_count",
                                            "(COUNT(CASE WHEN campaign_contacts.opened_at IS NOT NULL THEN 1 END)::float / COUNT(campaign_contacts.id)) as open_rate_calc"
                                          )
                                          .order("open_rate_calc DESC")
                                          .limit(5)

    campaigns_with_stats.map do |campaign|
      sent = campaign.sent_count
      opened = campaign.opened_count

      {
        name: campaign.name,
        sent: sent,
        opened: opened,
        open_rate: sent > 0 ? (opened.to_f / sent * 100).round(2) : 0
      }
    end
  end

  def calculate_contact_growth
    # Get contacts within the date range
    contacts = @current_account.contacts.where(created_at: @date_range)

    # Group contacts by day manually
    contacts_by_day = contacts.group("DATE(created_at)").count

    # Get basic stats for the period
    new_contacts = contacts.count
    total_contacts = @current_account.contacts.count
    subscribed = @current_account.contacts.where(status: "subscribed").count
    unsubscribed = @current_account.contacts.where(status: "unsubscribed").count
    total_unsubscribed = @current_account.contacts.where(status: "unsubscribed").count

    {
      new_contacts: new_contacts,
      total_contacts: total_contacts,
      subscribed: subscribed,
      unsubscribed: unsubscribed,
      total_unsubscribed: total_unsubscribed,
      daily_growth: contacts_by_day
    }
  end

  def calculate_contact_engagement
    contacts_with_stats = @current_account.contacts
                                         .joins(:campaign_contacts)
                                         .where(campaign_contacts: { created_at: @date_range })
                                         .group(:id, :first_name, :last_name, :email)
                                         .select(
                                           "contacts.*",
                                           "COUNT(campaign_contacts.id) as sent_count",
                                           "COUNT(CASE WHEN campaign_contacts.opened_at IS NOT NULL THEN 1 END) as opened_count",
                                           "COUNT(CASE WHEN campaign_contacts.clicked_at IS NOT NULL THEN 1 END) as clicked_count"
                                         )
                                         .order("opened_count DESC")
                                         .limit(10)

    contacts_with_stats.map do |contact|
      sent = contact.sent_count
      opened = contact.opened_count
      clicked = contact.clicked_count

      {
        name: "#{contact.first_name} #{contact.last_name}",
        email: contact.email,
        sent: sent,
        opened: opened,
        clicked: clicked,
        engagement_score: sent > 0 ? ((opened + clicked * 2).to_f / sent * 100).round(2) : 0
      }
    end
  end

  def top_engaged_contacts
    calculate_contact_engagement.first(5)
  end

  def calculate_campaign_stats(campaign)
    campaign_contacts = campaign.campaign_contacts
    total_sent = campaign_contacts.where.not(sent_at: nil).count
    total_opened = campaign_contacts.where.not(opened_at: nil).count
    total_clicked = campaign_contacts.where.not(clicked_at: nil).count

    {
      total_sent: total_sent,
      total_opened: total_opened,
      total_clicked: total_clicked,
      open_rate: total_sent > 0 ? (total_opened.to_f / total_sent * 100).round(2) : 0,
      click_rate: total_sent > 0 ? (total_clicked.to_f / total_sent * 100).round(2) : 0
    }
  end
end

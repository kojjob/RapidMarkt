class AnalyticsController < ApplicationController
  def index
    @date_range = params[:date_range] || 'last_30_days'
    @analytics_service = AnalyticsService.new(@current_account)
    
    # Overview statistics
    @overview_stats = @analytics_service.overview_stats(@date_range)
    
    # Recent campaign performance
    @recent_campaigns = @analytics_service.campaign_performance(@date_range).first(10)
    
    # Contact growth
    @contact_growth = @analytics_service.contact_growth(@date_range)
    
    # Engagement trends
    @engagement_trends = @analytics_service.engagement_trends(@date_range)
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
    @date_range = params[:date_range] || 'last_30_days'
    format = params[:format] || 'csv'
    @analytics_service = AnalyticsService.new(@current_account)
    
    begin
      export_data = @analytics_service.export_data(format, @date_range)
      
      case format.downcase
      when 'csv'
        send_data export_data, 
                  filename: "analytics_#{@date_range}_#{Date.current}.csv",
                  type: 'text/csv'
      when 'pdf'
        send_data export_data,
                  filename: "analytics_#{@date_range}_#{Date.current}.pdf",
                  type: 'application/pdf'
      else
        redirect_to analytics_path, alert: 'Invalid export format'
      end
    rescue => e
      redirect_to analytics_path, alert: "Export failed: #{e.message}"
    end
  end

  private

  def parse_date_range
    case params[:period]
    when 'week'
      1.week.ago..Time.current
    when 'month'
      1.month.ago..Time.current
    when '3months'
      3.months.ago..Time.current
    when 'year'
      1.year.ago..Time.current
    when 'custom'
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
      
      trends[date.strftime('%Y-%m-%d')] = {
        sent: day_contacts.count,
        opened: day_contacts.where.not(opened_at: nil).count,
        clicked: day_contacts.where.not(clicked_at: nil).count
      }
    end

    trends
  end

  def top_performing_campaigns
    @current_account.campaigns
                   .joins(:campaign_contacts)
                   .where(created_at: @date_range)
                   .group('campaigns.id, campaigns.name')
                   .having('COUNT(campaign_contacts.id) > 0')
                   .order('(COUNT(CASE WHEN campaign_contacts.opened_at IS NOT NULL THEN 1 END)::float / COUNT(campaign_contacts.id)) DESC')
                   .limit(5)
                   .pluck('campaigns.name, COUNT(campaign_contacts.id), COUNT(CASE WHEN campaign_contacts.opened_at IS NOT NULL THEN 1 END)')
                   .map do |name, sent, opened|
      {
        name: name,
        sent: sent,
        opened: opened,
        open_rate: sent > 0 ? (opened.to_f / sent * 100).round(2) : 0
      }
    end
  end

  def calculate_contact_growth
    contacts_by_day = @current_account.contacts
                                     .where(created_at: @date_range)
                                     .group_by_day(:created_at)
                                     .count

    # Calculate cumulative growth
    cumulative_count = @current_account.contacts.where('created_at < ?', @date_range.begin).count
    
    contacts_by_day.transform_values do |daily_count|
      cumulative_count += daily_count
    end
  end

  def calculate_contact_engagement
    @current_account.contacts
                   .joins(:campaign_contacts)
                   .where(campaign_contacts: { created_at: @date_range })
                   .group('contacts.id, contacts.first_name, contacts.last_name, contacts.email')
                   .order('COUNT(CASE WHEN campaign_contacts.opened_at IS NOT NULL THEN 1 END) DESC')
                   .limit(10)
                   .pluck('contacts.first_name, contacts.last_name, contacts.email, COUNT(campaign_contacts.id), COUNT(CASE WHEN campaign_contacts.opened_at IS NOT NULL THEN 1 END), COUNT(CASE WHEN campaign_contacts.clicked_at IS NOT NULL THEN 1 END)')
                   .map do |first_name, last_name, email, sent, opened, clicked|
      {
        name: "#{first_name} #{last_name}",
        email: email,
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
class AnalyticsService
  def initialize(account)
    @account = account
  end

  def overview_stats(date_range = nil)
    campaigns = filter_by_date_range(@account.campaigns, date_range)
    contacts = filter_by_date_range(@account.contacts, date_range)
    
    # Get campaign contacts for detailed analysis
    campaign_contacts = CampaignContact.joins(:campaign)
                                      .where(campaigns: { account: @account })
    
    if date_range
      start_date, end_date = parse_date_range(date_range)
      campaign_contacts = campaign_contacts.where(sent_at: start_date..end_date)
    end

    total_sent = campaign_contacts.where.not(sent_at: nil).count
    total_opened = campaign_contacts.where.not(opened_at: nil).count
    total_clicked = campaign_contacts.where.not(clicked_at: nil).count
    total_bounced = campaign_contacts.where.not(bounced_at: nil).count
    total_unsubscribed = campaign_contacts.where.not(unsubscribed_at: nil).count

    {
      total_campaigns: campaigns.count,
      draft_campaigns: campaigns.where(status: "draft").count,
      scheduled_campaigns: campaigns.where(status: "scheduled").count,
      sent_campaigns: campaigns.where(status: "sent").count,
      emails_sent: total_sent,
      emails_opened: total_opened,
      emails_clicked: total_clicked,
      emails_bounced: total_bounced,
      emails_unsubscribed: total_unsubscribed,
      open_rate: total_sent > 0 ? (total_opened.to_f / total_sent * 100).round(2) : 0,
      click_rate: total_sent > 0 ? (total_clicked.to_f / total_sent * 100).round(2) : 0,
      bounce_rate: total_sent > 0 ? (total_bounced.to_f / total_sent * 100).round(2) : 0,
      unsubscribe_rate: total_sent > 0 ? (total_unsubscribed.to_f / total_sent * 100).round(2) : 0,
      total_contacts: contacts.count,
      active_contacts: @account.contacts.where(status: "subscribed").count,
      inactive_contacts: @account.contacts.where(status: "unsubscribed").count
    }
  end

  def campaign_performance(date_range = nil)
    campaigns = filter_by_date_range(@account.campaigns.sent, date_range)

    campaigns.map do |campaign|
      {
        id: campaign.id,
        name: campaign.name,
        subject: campaign.subject,
        sent_at: campaign.sent_at,
        emails_sent: campaign.campaign_contacts.count,
        opens: campaign.campaign_contacts.where.not(opened_at: nil).count,
        clicks: campaign.campaign_contacts.where.not(clicked_at: nil).count,
        open_rate: campaign.open_rate || 0,
        click_rate: campaign.click_rate || 0
      }
    end
  end

  def contact_growth(date_range = nil)
    start_date, end_date = parse_date_range(date_range || "last_30_days")
    
    # Daily contact growth data for charts
    daily_growth = []
    cumulative_total = @account.contacts.where("created_at < ?", start_date).count
    
    (start_date.to_date..end_date.to_date).each do |date|
      day_contacts = @account.contacts.where(created_at: date.beginning_of_day..date.end_of_day)
      new_today = day_contacts.count
      subscribed_today = day_contacts.where(status: "subscribed").count
      unsubscribed_today = @account.contacts.where(updated_at: date.beginning_of_day..date.end_of_day, status: "unsubscribed").count
      
      cumulative_total += new_today
      
      daily_growth << {
        date: date.strftime("%Y-%m-%d"),
        new_contacts: new_today,
        subscribed: subscribed_today,
        unsubscribed: unsubscribed_today,
        cumulative_total: cumulative_total
      }
    end
    
    # Summary stats
    total_new = @account.contacts.where(created_at: start_date..end_date).count
    total_subscribed = @account.contacts.where(status: "subscribed").count
    total_unsubscribed = @account.contacts.where(status: "unsubscribed").count
    
    {
      daily_growth: daily_growth,
      summary: {
        new_contacts: total_new,
        total_contacts: @account.contacts.count,
        subscribed: total_subscribed,
        unsubscribed: total_unsubscribed,
        growth_rate: calculate_growth_rate(start_date, end_date)
      }
    }
  end
  
  def real_time_stats
    # Get stats for the last hour for real-time dashboard
    one_hour_ago = 1.hour.ago
    
    recent_campaign_contacts = CampaignContact.joins(:campaign)
                                             .where(campaigns: { account: @account })
                                             .where(sent_at: one_hour_ago..Time.current)
    
    {
      recent_sends: recent_campaign_contacts.count,
      recent_opens: recent_campaign_contacts.where(opened_at: one_hour_ago..Time.current).count,
      recent_clicks: recent_campaign_contacts.where(clicked_at: one_hour_ago..Time.current).count,
      active_campaigns: @account.campaigns.where(status: "sending").count
    }
  end
  
  def top_performing_campaigns(limit = 10, date_range = nil)
    campaigns = filter_by_date_range(@account.campaigns.where(status: "sent"), date_range)
    
    campaigns.joins(:campaign_contacts)
            .group("campaigns.id, campaigns.name, campaigns.subject, campaigns.sent_at")
            .select(
              "campaigns.*,
               COUNT(campaign_contacts.id) as total_sent,
               COUNT(CASE WHEN campaign_contacts.opened_at IS NOT NULL THEN 1 END) as total_opened,
               COUNT(CASE WHEN campaign_contacts.clicked_at IS NOT NULL THEN 1 END) as total_clicked,
               ROUND(COUNT(CASE WHEN campaign_contacts.opened_at IS NOT NULL THEN 1 END)::numeric / COUNT(campaign_contacts.id) * 100, 2) as calculated_open_rate"
            )
            .having("COUNT(campaign_contacts.id) > 0")
            .order("calculated_open_rate DESC, total_sent DESC")
            .limit(limit)
            .map do |campaign|
              {
                id: campaign.id,
                name: campaign.name,
                subject: campaign.subject,
                sent_at: campaign.sent_at,
                total_sent: campaign.total_sent,
                total_opened: campaign.total_opened,
                total_clicked: campaign.total_clicked,
                open_rate: campaign.calculated_open_rate.to_f,
                click_rate: campaign.total_sent > 0 ? (campaign.total_clicked.to_f / campaign.total_sent * 100).round(2) : 0
              }
            end
  end
  
  def contact_segments
    total_contacts = @account.contacts.count
    
    {
      total: total_contacts,
      subscribed: @account.contacts.where(status: "subscribed").count,
      unsubscribed: @account.contacts.where(status: "unsubscribed").count,
      bounced: @account.contacts.where(status: "bounced").count,
      recent_signups: @account.contacts.where(created_at: 7.days.ago..Time.current).count,
      growth_this_month: @account.contacts.where(created_at: Time.current.beginning_of_month..Time.current).count
    }
  end
  
  def revenue_metrics(date_range = nil)
    # This would connect to payment/subscription data
    # For now, return placeholder data
    {
      mrr: 0, # Monthly Recurring Revenue
      arr: 0, # Annual Recurring Revenue  
      churn_rate: 0,
      ltv: 0, # Customer Lifetime Value
      revenue_per_contact: 0
    }
  end
  
  def engagement_trends(date_range = nil)
    start_date, end_date = parse_date_range(date_range || "last_30_days")
    
    # Get daily data for charts
    daily_stats = []
    
    (start_date.to_date..end_date.to_date).each do |date|
      day_start = date.beginning_of_day
      day_end = date.end_of_day
      
      campaign_contacts = CampaignContact.joins(:campaign)
                                        .where(campaigns: { account: @account })
                                        .where(sent_at: day_start..day_end)
      
      sent_count = campaign_contacts.count
      opened_count = campaign_contacts.where.not(opened_at: nil).count
      clicked_count = campaign_contacts.where.not(clicked_at: nil).count
      
      daily_stats << {
        date: date.strftime("%Y-%m-%d"),
        sent: sent_count,
        opened: opened_count,
        clicked: clicked_count,
        open_rate: sent_count > 0 ? (opened_count.to_f / sent_count * 100).round(2) : 0,
        click_rate: sent_count > 0 ? (clicked_count.to_f / sent_count * 100).round(2) : 0
      }
    end
    
    daily_stats
  end

  def export_data(format = "csv", date_range = nil)
    case format.downcase
    when "csv"
      export_csv(date_range)
    when "pdf"
      export_pdf(date_range)
    else
      raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  private
  
  def calculate_growth_rate(start_date, end_date)
    contacts_at_start = @account.contacts.where("created_at < ?", start_date).count
    contacts_at_end = @account.contacts.where("created_at <= ?", end_date).count
    
    return 0 if contacts_at_start == 0
    
    ((contacts_at_end.to_f - contacts_at_start) / contacts_at_start * 100).round(2)
  end

  def filter_by_date_range(relation, date_range)
    return relation unless date_range

    start_date, end_date = parse_date_range(date_range)
    relation.where(created_at: start_date..end_date)
  end

  def parse_date_range(date_range)
    case date_range
    when "last_7_days"
      [ 7.days.ago.beginning_of_day, Time.current.end_of_day ]
    when "last_30_days"
      [ 30.days.ago.beginning_of_day, Time.current.end_of_day ]
    when "last_90_days"
      [ 90.days.ago.beginning_of_day, Time.current.end_of_day ]
    when "this_month"
      [ Time.current.beginning_of_month, Time.current.end_of_month ]
    when "last_month"
      [ 1.month.ago.beginning_of_month, 1.month.ago.end_of_month ]
    when Hash
      [ Date.parse(date_range[:start_date]), Date.parse(date_range[:end_date]) ]
    else
      [ 1.year.ago.beginning_of_day, Time.current.end_of_day ]
    end
  end

  def calculate_emails_sent(campaigns)
    campaigns.joins(:campaign_contacts).count
  end

  def calculate_average_open_rate(campaigns)
    sent_campaigns = campaigns.where(status: "sent")
    return 0 if sent_campaigns.empty?

    total_rate = sent_campaigns.sum(:open_rate)
    (total_rate / sent_campaigns.count).round(2)
  end

  def export_csv(date_range)
    require "csv"

    campaigns = filter_by_date_range(@account.campaigns.sent, date_range)

    CSV.generate(headers: true) do |csv|
      csv << [ "Campaign Name", "Subject", "Sent At", "Emails Sent", "Opens", "Clicks", "Open Rate", "Click Rate" ]

      campaigns.each do |campaign|
        csv << [
          campaign.name,
          campaign.subject,
          campaign.sent_at,
          campaign.campaign_contacts.count,
          campaign.campaign_contacts.where.not(opened_at: nil).count,
          campaign.campaign_contacts.where.not(clicked_at: nil).count,
          "#{campaign.open_rate}%",
          "#{campaign.click_rate}%"
        ]
      end
    end
  end

  def export_pdf(date_range)
    # This would require a PDF generation library like Prawn
    # For now, return a placeholder
    "PDF export functionality requires additional setup"
  end
end

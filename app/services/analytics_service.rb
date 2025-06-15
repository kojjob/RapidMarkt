class AnalyticsService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_reader :account, :errors

  def initialize(account)
    @account = account
    @errors = ActiveModel::Errors.new(self)
  end

  def overview_stats(date_range = nil)
    campaigns = filter_by_date_range(@account.campaigns, date_range)
    contacts = filter_by_date_range(@account.contacts, date_range)

    {
      total_campaigns: campaigns.count,
      emails_sent: calculate_emails_sent(campaigns),
      average_open_rate: calculate_average_open_rate(campaigns),
      total_contacts: contacts.count
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
    contacts = @account.contacts

    if date_range
      start_date, end_date = parse_date_range(date_range)
      contacts = contacts.where(created_at: start_date..end_date)
    end

    {
      new_contacts: contacts.count,
      subscribed: contacts.where(status: "subscribed").count,
      unsubscribed: contacts.where(status: "unsubscribed").count,
      total_unsubscribed: @account.contacts.where(status: "unsubscribed").count
    }
  end

  def engagement_trends(date_range = nil)
    campaigns = filter_by_date_range(@account.campaigns.sent, date_range)

    # Group by week for trend analysis
    trends = campaigns.group_by { |c| c.sent_at&.beginning_of_week }
                     .transform_values do |week_campaigns|
                       {
                         campaigns_sent: week_campaigns.count,
                         avg_open_rate: week_campaigns.sum(&:open_rate) / week_campaigns.count.to_f,
                         avg_click_rate: week_campaigns.sum(&:click_rate) / week_campaigns.count.to_f
                       }
                     end

    trends.sort_by { |date, _| date || Time.current }.to_h
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
    # Generate PDF report with charts and analytics
    require "prawn"

    campaigns = filter_by_date_range(@account.campaigns.sent, date_range)

    Prawn::Document.generate do |pdf|
      pdf.text "Analytics Report - #{@account.name}", size: 20, style: :bold
      pdf.move_down 20

      # Overview stats
      stats = overview_stats(date_range)
      pdf.text "Overview", size: 16, style: :bold
      pdf.move_down 10

      pdf.text "Total Campaigns: #{stats[:total_campaigns]}"
      pdf.text "Emails Sent: #{stats[:emails_sent]}"
      pdf.text "Average Open Rate: #{stats[:average_open_rate]}%"
      pdf.text "Total Contacts: #{stats[:total_contacts]}"

      pdf.move_down 20

      # Campaign performance table
      pdf.text "Campaign Performance", size: 16, style: :bold
      pdf.move_down 10

      performance_data = campaign_performance(date_range)
      if performance_data.any?
        table_data = [ [ "Campaign", "Subject", "Sent", "Opens", "Clicks", "Open Rate", "Click Rate" ] ]
        performance_data.each do |campaign|
          table_data << [
            campaign[:name].truncate(20),
            campaign[:subject].truncate(25),
            campaign[:emails_sent],
            campaign[:opens],
            campaign[:clicks],
            "#{campaign[:open_rate]}%",
            "#{campaign[:click_rate]}%"
          ]
        end

        pdf.table(table_data, header: true, width: pdf.bounds.width) do
          style(row(0), background_color: "DDDDDD", font_style: :bold)
        end
      end
    end.render
  rescue => e
    Rails.logger.error "PDF export failed: #{e.message}"
    "PDF export failed: #{e.message}"
  end

  # Advanced analytics methods
  def funnel_analysis(date_range = nil)
    campaigns = filter_by_date_range(@account.campaigns.sent, date_range)

    total_sent = campaigns.joins(:campaign_contacts).count
    total_delivered = campaigns.joins(:campaign_contacts).where(campaign_contacts: { status: "delivered" }).count
    total_opened = campaigns.joins(:campaign_contacts).where.not(campaign_contacts: { opened_at: nil }).count
    total_clicked = campaigns.joins(:campaign_contacts).where.not(campaign_contacts: { clicked_at: nil }).count

    {
      sent: { count: total_sent, percentage: 100.0 },
      delivered: {
        count: total_delivered,
        percentage: total_sent > 0 ? (total_delivered.to_f / total_sent * 100).round(2) : 0
      },
      opened: {
        count: total_opened,
        percentage: total_delivered > 0 ? (total_opened.to_f / total_delivered * 100).round(2) : 0
      },
      clicked: {
        count: total_clicked,
        percentage: total_opened > 0 ? (total_clicked.to_f / total_opened * 100).round(2) : 0
      }
    }
  end

  def cohort_analysis(period = "month")
    # Analyze contact engagement over time cohorts
    cohorts = {}

    case period
    when "month"
      @account.contacts.group_by { |c| c.created_at.beginning_of_month }
    when "week"
      @account.contacts.group_by { |c| c.created_at.beginning_of_week }
    else
      @account.contacts.group_by { |c| c.created_at.beginning_of_month }
    end.each do |cohort_date, contacts|
      cohort_data = {
        cohort_date: cohort_date,
        total_contacts: contacts.count,
        retention_data: {}
      }

      # Calculate retention for each period after cohort
      (0..11).each do |period_offset|
        analysis_date = cohort_date + period_offset.send(period.pluralize)
        active_contacts = contacts.select do |contact|
          contact.campaign_contacts.joins(:campaign)
                 .where(campaigns: { sent_at: analysis_date..(analysis_date + 1.send(period)) })
                 .where.not(opened_at: nil)
                 .exists?
        end

        retention_rate = contacts.count > 0 ? (active_contacts.count.to_f / contacts.count * 100).round(2) : 0
        cohort_data[:retention_data][period_offset] = {
          active_contacts: active_contacts.count,
          retention_rate: retention_rate
        }
      end

      cohorts[cohort_date] = cohort_data
    end

    cohorts
  end

  def predictive_analytics
    # Predict future campaign performance based on historical data
    campaigns = @account.campaigns.sent.where("sent_at >= ?", 6.months.ago)

    return { error: "Insufficient data for predictions" } if campaigns.count < 10

    # Calculate trends
    monthly_data = campaigns.group_by { |c| c.sent_at.beginning_of_month }
                           .transform_values do |month_campaigns|
                             {
                               count: month_campaigns.count,
                               avg_open_rate: month_campaigns.average(:open_rate) || 0,
                               avg_click_rate: month_campaigns.average(:click_rate) || 0
                             }
                           end

    # Simple linear regression for predictions
    sorted_months = monthly_data.keys.sort

    if sorted_months.length >= 3
      # Predict next month's performance
      open_rate_trend = calculate_trend(sorted_months.map { |m| monthly_data[m][:avg_open_rate] })
      click_rate_trend = calculate_trend(sorted_months.map { |m| monthly_data[m][:avg_click_rate] })

      next_month = sorted_months.last + 1.month

      {
        predictions: {
          next_month: next_month,
          predicted_open_rate: [ open_rate_trend[:next_value], 0 ].max.round(2),
          predicted_click_rate: [ click_rate_trend[:next_value], 0 ].max.round(2),
          confidence: calculate_prediction_confidence(monthly_data)
        },
        historical_trend: {
          open_rate: open_rate_trend,
          click_rate: click_rate_trend
        }
      }
    else
      { error: "Need at least 3 months of data for reliable predictions" }
    end
  end

  def engagement_scoring
    # Score contacts based on engagement patterns
    contacts_with_scores = @account.contacts.includes(:campaign_contacts).map do |contact|
      score = ContactEngagementScorer.new(contact).calculate_score

      {
        contact_id: contact.id,
        email: contact.email,
        name: contact.full_name,
        engagement_score: score,
        engagement_level: categorize_engagement_score(score),
        last_activity: contact.last_opened_at || contact.created_at
      }
    end

    # Sort by engagement score
    contacts_with_scores.sort_by { |c| -c[:engagement_score] }
  end

  def campaign_optimization_suggestions
    recent_campaigns = @account.campaigns.sent.where("sent_at >= ?", 3.months.ago)

    suggestions = []

    # Analyze send times
    send_time_analysis = analyze_optimal_send_times(recent_campaigns)
    if send_time_analysis[:suggestion].present?
      suggestions << {
        type: "send_time",
        priority: "high",
        suggestion: send_time_analysis[:suggestion],
        data: send_time_analysis[:data]
      }
    end

    # Analyze subject line performance
    subject_analysis = analyze_subject_line_performance(recent_campaigns)
    if subject_analysis[:suggestions].any?
      suggestions.concat(subject_analysis[:suggestions])
    end

    # Analyze content performance
    content_analysis = analyze_content_performance(recent_campaigns)
    if content_analysis[:suggestions].any?
      suggestions.concat(content_analysis[:suggestions])
    end

    # Analyze frequency optimization
    frequency_analysis = analyze_send_frequency(recent_campaigns)
    if frequency_analysis[:suggestion].present?
      suggestions << frequency_analysis
    end

    suggestions
  end

  def benchmark_comparison
    # Compare account performance against industry benchmarks
    account_stats = overview_stats("last_90_days")

    # Industry benchmarks (these would come from a database or external service)
    industry_benchmarks = {
      average_open_rate: 21.33,
      average_click_rate: 2.62,
      average_bounce_rate: 0.58,
      average_unsubscribe_rate: 0.05
    }

    {
      account_performance: account_stats,
      industry_benchmarks: industry_benchmarks,
      comparison: {
        open_rate_vs_industry: calculate_benchmark_comparison(account_stats[:average_open_rate], industry_benchmarks[:average_open_rate]),
        click_rate_vs_industry: calculate_benchmark_comparison(account_stats[:average_click_rate] || 0, industry_benchmarks[:average_click_rate])
      },
      recommendations: generate_benchmark_recommendations(account_stats, industry_benchmarks)
    }
  end

  def advanced_segmentation_analysis
    # Analyze performance across different contact segments
    segments = {}

    # Analyze by engagement level
    %w[high medium low].each do |level|
      contacts = get_contacts_by_engagement_level(level)
      next if contacts.empty?

      segments[level] = analyze_segment_performance(contacts)
    end

    # Analyze by lifecycle stage
    %w[lead prospect customer advocate].each do |stage|
      contacts = @account.contacts.where(lifecycle_stage: stage)
      next if contacts.empty?

      segments["lifecycle_#{stage}"] = analyze_segment_performance(contacts)
    end

    # Analyze by recency
    segments["new_subscribers"] = analyze_segment_performance(@account.contacts.where("created_at >= ?", 30.days.ago))
    segments["long_term_subscribers"] = analyze_segment_performance(@account.contacts.where("created_at <= ?", 1.year.ago))

    segments
  end

  private

  def calculate_trend(values)
    return { trend: "insufficient_data", next_value: 0 } if values.length < 2

    n = values.length
    sum_x = (1..n).sum
    sum_y = values.sum
    sum_xy = values.each_with_index.sum { |y, i| y * (i + 1) }
    sum_x_squared = (1..n).sum { |x| x * x }

    # Calculate slope (trend)
    slope = (n * sum_xy - sum_x * sum_y).to_f / (n * sum_x_squared - sum_x * sum_x)
    intercept = (sum_y - slope * sum_x).to_f / n

    next_value = slope * (n + 1) + intercept

    {
      trend: slope > 0 ? "increasing" : (slope < 0 ? "decreasing" : "stable"),
      slope: slope.round(4),
      next_value: next_value.round(2),
      r_squared: calculate_r_squared(values, slope, intercept)
    }
  end

  def calculate_r_squared(values, slope, intercept)
    n = values.length
    y_mean = values.sum.to_f / n

    ss_tot = values.sum { |y| (y - y_mean) ** 2 }
    ss_res = values.each_with_index.sum { |y, i| (y - (slope * (i + 1) + intercept)) ** 2 }

    return 0 if ss_tot == 0

    (1 - ss_res / ss_tot).round(4)
  end

  def calculate_prediction_confidence(monthly_data)
    # Simple confidence calculation based on data consistency
    values = monthly_data.values.map { |v| v[:avg_open_rate] }
    return "low" if values.length < 3

    coefficient_of_variation = (values.standard_deviation / values.mean) * 100

    case coefficient_of_variation
    when 0..15
      "high"
    when 15..25
      "medium"
    else
      "low"
    end
  end

  def categorize_engagement_score(score)
    case score
    when 80..100
      "highly_engaged"
    when 60..79
      "moderately_engaged"
    when 40..59
      "somewhat_engaged"
    when 20..39
      "barely_engaged"
    else
      "not_engaged"
    end
  end

  def analyze_optimal_send_times(campaigns)
    # Group campaigns by send time and analyze performance
    send_time_data = campaigns.group_by { |c| c.sent_at.hour }.transform_values do |hour_campaigns|
      {
        count: hour_campaigns.count,
        avg_open_rate: hour_campaigns.average(:open_rate) || 0,
        avg_click_rate: hour_campaigns.average(:click_rate) || 0
      }
    end

    best_hour = send_time_data.max_by { |_, data| data[:avg_open_rate] }

    if best_hour && send_time_data.size > 1
      {
        suggestion: "Consider sending campaigns around #{best_hour[0]}:00 for better open rates",
        data: send_time_data
      }
    else
      { suggestion: nil, data: send_time_data }
    end
  end

  def analyze_subject_line_performance(campaigns)
    suggestions = []

    # Analyze subject line length
    length_analysis = campaigns.group_by { |c| c.subject.length / 10 * 10 }.transform_values do |group|
      { count: group.count, avg_open_rate: group.average(:open_rate) || 0 }
    end

    best_length = length_analysis.max_by { |_, data| data[:avg_open_rate] }
    if best_length
      suggestions << {
        type: "subject_length",
        priority: "medium",
        suggestion: "Subject lines around #{best_length[0]}-#{best_length[0] + 10} characters perform best",
        data: length_analysis
      }
    end

    # Analyze personalization
    personalized = campaigns.select { |c| c.subject.include?("{{") }
    non_personalized = campaigns.reject { |c| c.subject.include?("{{") }

    if personalized.any? && non_personalized.any?
      pers_avg = personalized.average(:open_rate) || 0
      non_pers_avg = non_personalized.average(:open_rate) || 0

      if pers_avg > non_pers_avg
        suggestions << {
          type: "personalization",
          priority: "high",
          suggestion: "Personalized subject lines perform #{((pers_avg - non_pers_avg) / non_pers_avg * 100).round(1)}% better",
          data: { personalized: pers_avg, non_personalized: non_pers_avg }
        }
      end
    end

    { suggestions: suggestions }
  end

  def analyze_content_performance(campaigns)
    suggestions = []

    # Analyze content length
    campaigns_with_length = campaigns.map do |c|
      { campaign: c, word_count: ActionView::Base.full_sanitizer.sanitize(c.template&.body || "").split.length }
    end

    length_groups = campaigns_with_length.group_by { |c| (c[:word_count] / 100) * 100 }
    length_performance = length_groups.transform_values do |group|
      campaigns_in_group = group.map { |c| c[:campaign] }
      {
        count: campaigns_in_group.count,
        avg_open_rate: campaigns_in_group.average(:open_rate) || 0,
        avg_click_rate: campaigns_in_group.average(:click_rate) || 0
      }
    end

    best_length = length_performance.max_by { |_, data| data[:avg_click_rate] }
    if best_length && length_performance.size > 1
      suggestions << {
        type: "content_length",
        priority: "medium",
        suggestion: "Content with #{best_length[0]}-#{best_length[0] + 100} words tends to perform better",
        data: length_performance
      }
    end

    { suggestions: suggestions }
  end

  def analyze_send_frequency(campaigns)
    # Analyze time between campaigns and performance
    sorted_campaigns = campaigns.order(:sent_at)

    frequency_data = []
    sorted_campaigns.each_cons(2) do |prev_campaign, current_campaign|
      days_between = (current_campaign.sent_at.to_date - prev_campaign.sent_at.to_date).to_i
      frequency_data << {
        days_between: days_between,
        open_rate: current_campaign.open_rate || 0,
        click_rate: current_campaign.click_rate || 0
      }
    end

    return { suggestion: nil } if frequency_data.empty?

    # Group by frequency ranges
    frequency_groups = frequency_data.group_by do |data|
      case data[:days_between]
      when 0..3
        "very_frequent"
      when 4..7
        "weekly"
      when 8..14
        "bi_weekly"
      when 15..30
        "monthly"
      else
        "infrequent"
      end
    end

    best_frequency = frequency_groups.max_by { |_, group| group.sum { |d| d[:open_rate] } / group.size }

    {
      type: "send_frequency",
      priority: "medium",
      suggestion: "#{best_frequency[0]} sending frequency shows the best engagement",
      data: frequency_groups.transform_values { |group| group.sum { |d| d[:open_rate] } / group.size }
    }
  end

  def calculate_benchmark_comparison(account_value, benchmark_value)
    return 0 if benchmark_value == 0

    percentage_diff = ((account_value - benchmark_value) / benchmark_value * 100).round(2)

    {
      difference: percentage_diff,
      status: percentage_diff > 0 ? "above_benchmark" : "below_benchmark",
      performance_level: case percentage_diff.abs
                         when 0..5
                          "similar"
                         when 5..15
                          "noticeable_difference"
                         else
                          "significant_difference"
                         end
    }
  end

  def generate_benchmark_recommendations(account_stats, benchmarks)
    recommendations = []

    if account_stats[:average_open_rate] < benchmarks[:average_open_rate]
      recommendations << {
        type: "open_rate",
        priority: "high",
        message: "Your open rate is below industry average. Consider improving subject lines and send times.",
        target_improvement: (benchmarks[:average_open_rate] - account_stats[:average_open_rate]).round(2)
      }
    end

    if (account_stats[:average_click_rate] || 0) < benchmarks[:average_click_rate]
      recommendations << {
        type: "click_rate",
        priority: "high",
        message: "Your click rate is below industry average. Focus on improving call-to-action and content relevance.",
        target_improvement: (benchmarks[:average_click_rate] - (account_stats[:average_click_rate] || 0)).round(2)
      }
    end

    recommendations
  end

  def get_contacts_by_engagement_level(level)
    case level
    when "high"
      @account.contacts.where("engagement_score >= ?", 80)
    when "medium"
      @account.contacts.where(engagement_score: 40..79)
    when "low"
      @account.contacts.where("engagement_score < ?", 40)
    else
      @account.contacts.none
    end
  end

  def analyze_segment_performance(contacts)
    return {} if contacts.empty?

    # Get campaigns that were sent to these contacts
    campaign_contacts = CampaignContact.joins(:campaign)
                                     .where(contact: contacts, campaigns: { status: "sent" })

    total_sent = campaign_contacts.count
    return { total_sent: 0 } if total_sent == 0

    {
      total_contacts: contacts.count,
      total_sent: total_sent,
      total_opened: campaign_contacts.where.not(opened_at: nil).count,
      total_clicked: campaign_contacts.where.not(clicked_at: nil).count,
      open_rate: (campaign_contacts.where.not(opened_at: nil).count.to_f / total_sent * 100).round(2),
      click_rate: (campaign_contacts.where.not(clicked_at: nil).count.to_f / total_sent * 100).round(2),
      avg_engagement_score: contacts.average(:engagement_score) || 0
    }
  end

  # Contact Engagement Scorer
  class ContactEngagementScorer
    def initialize(contact)
      @contact = contact
    end

    def calculate_score
      score = 0

      # Base score for subscription status
      score += case @contact.status
      when "subscribed" then 20
      when "unsubscribed" then 0
      when "bounced" then 0
      else 10
      end

      # Recent activity bonus
      if @contact.last_opened_at.present?
        days_since_open = (Date.current - @contact.last_opened_at.to_date).to_i
        score += case days_since_open
        when 0..7 then 30
        when 8..30 then 20
        when 31..90 then 10
        else 0
        end
      end

      # Click activity bonus
      if @contact.last_clicked_at.present?
        days_since_click = (Date.current - @contact.last_clicked_at.to_date).to_i
        score += case days_since_click
        when 0..7 then 25
        when 8..30 then 15
        when 31..90 then 5
        else 0
        end
      end

      # Frequency of engagement
      campaign_contacts = @contact.campaign_contacts.where("sent_at >= ?", 90.days.ago)
      if campaign_contacts.any?
        engagement_rate = campaign_contacts.where.not(opened_at: nil).count.to_f / campaign_contacts.count
        score += (engagement_rate * 25).round
      end

      # Profile completeness
      score += 5 if @contact.first_name.present?
      score += 5 if @contact.last_name.present?

      # Cap at 100
      [ score, 100 ].min
    end
  end

  def export_pdf(date_range)
    # This would be implemented based on actual tracking data
    # For now, we'll keep the existing values
  end
end

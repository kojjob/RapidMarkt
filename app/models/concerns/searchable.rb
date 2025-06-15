# frozen_string_literal: true

# Concern for models that can be searched and filtered
module Searchable
  extend ActiveSupport::Concern

  included do
    scope :search, ->(query) { where(build_search_query(query)) if query.present? }
    scope :with_status, ->(status) { where(status: status) if status.present? }
    scope :created_between, ->(start_date, end_date) { where(created_at: start_date..end_date) }
    scope :updated_since, ->(date) { where('updated_at >= ?', date) }
  end

  class_methods do
    # Define searchable fields for each model
    def searchable_fields
      # Override in including models
      %w[name title]
    end

    def build_search_query(query)
      return nil if query.blank?
      
      # Clean and prepare the search query
      clean_query = query.strip
      
      # Handle quoted phrases
      if clean_query.match?(/\A".*"\z/)
        phrase_search(clean_query.gsub(/\A"|"\z/, ''))
      else
        # Handle multiple words
        terms = clean_query.split(/\s+/)
        if terms.length == 1
          single_term_search(terms.first)
        else
          multi_term_search(terms)
        end
      end
    end

    def phrase_search(phrase)
      conditions = searchable_fields.map do |field|
        "#{field} ILIKE ?"
      end.join(' OR ')
      
      [conditions] + Array.new(searchable_fields.length, "%#{phrase}%")
    end

    def single_term_search(term)
      conditions = searchable_fields.map do |field|
        "#{field} ILIKE ?"
      end.join(' OR ')
      
      [conditions] + Array.new(searchable_fields.length, "%#{term}%")
    end

    def multi_term_search(terms)
      # Each term must match at least one field
      term_conditions = terms.map do |term|
        field_conditions = searchable_fields.map do |field|
          "#{field} ILIKE ?"
        end.join(' OR ')
        
        "(#{field_conditions})"
      end.join(' AND ')
      
      params = terms.flat_map do |term|
        Array.new(searchable_fields.length, "%#{term}%")
      end
      
      [term_conditions] + params
    end

    # Advanced filtering
    def filter_by_date_range(field, range)
      case range
      when 'today'
        where("#{field} >= ?", Date.current.beginning_of_day)
      when 'yesterday'
        where("#{field} >= ? AND #{field} < ?", 1.day.ago.beginning_of_day, Date.current.beginning_of_day)
      when 'this_week'
        where("#{field} >= ?", Date.current.beginning_of_week)
      when 'last_week'
        where("#{field} >= ? AND #{field} < ?", 1.week.ago.beginning_of_week, Date.current.beginning_of_week)
      when 'this_month'
        where("#{field} >= ?", Date.current.beginning_of_month)
      when 'last_month'
        where("#{field} >= ? AND #{field} < ?", 1.month.ago.beginning_of_month, Date.current.beginning_of_month)
      when 'this_year'
        where("#{field} >= ?", Date.current.beginning_of_year)
      when Hash
        if range[:start_date] && range[:end_date]
          where("#{field} >= ? AND #{field} <= ?", range[:start_date], range[:end_date])
        elsif range[:start_date]
          where("#{field} >= ?", range[:start_date])
        elsif range[:end_date]
          where("#{field} <= ?", range[:end_date])
        else
          all
        end
      else
        all
      end
    end

    # Sort by various criteria
    def sorted_by(sort_option)
      case sort_option
      when 'name_asc'
        order(:name)
      when 'name_desc'
        order(name: :desc)
      when 'created_asc'
        order(:created_at)
      when 'created_desc'
        order(created_at: :desc)
      when 'updated_asc'
        order(:updated_at)
      when 'updated_desc'
        order(updated_at: :desc)
      when 'status'
        order(:status, :name)
      else
        order(:created_at)
      end
    end

    # Pagination with search
    def paginated_search(params = {})
      query = params[:query]
      page = params[:page] || 1
      per_page = params[:per_page] || 25
      sort = params[:sort] || 'created_desc'
      filters = params[:filters] || {}

      results = all
      
      # Apply search
      results = results.search(query) if query.present?
      
      # Apply filters
      filters.each do |key, value|
        next if value.blank?
        
        case key.to_s
        when 'status'
          results = results.with_status(value)
        when 'date_range'
          results = results.filter_by_date_range('created_at', value)
        when 'updated_since'
          results = results.updated_since(value)
        end
      end
      
      # Apply sorting
      results = results.sorted_by(sort)
      
      # Apply pagination
      results.page(page).per(per_page)
    end
  end

  # Instance methods
  def matches_search?(query)
    return true if query.blank?
    
    searchable_content = self.class.searchable_fields.map do |field|
      send(field).to_s.downcase
    end.join(' ')
    
    query.downcase.split(/\s+/).all? do |term|
      searchable_content.include?(term)
    end
  end

  def highlight_search_matches(query, field)
    return send(field) if query.blank?
    
    content = send(field).to_s
    terms = query.split(/\s+/)
    
    terms.each do |term|
      content = content.gsub(/(#{Regexp.escape(term)})/i, '<mark>\1</mark>')
    end
    
    content.html_safe
  end
end

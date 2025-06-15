module ApplicationHelper
  # Generate user avatar with fallback to initials
  def user_avatar(user, size: 'w-10 h-10', text_size: 'text-sm', additional_classes: '')
    initials = if user.first_name.present? && user.last_name.present?
                 "#{user.first_name.first.upcase}#{user.last_name.first.upcase}"
               elsif user.first_name.present?
                 user.first_name.first.upcase
               else
                 user.email.first.upcase
               end

    gradient_class = user_avatar_gradient(user)

    content_tag :div,
                class: "#{size} #{gradient_class} rounded-xl flex items-center justify-center shadow-md #{additional_classes}" do
      content_tag :span, initials, class: "#{text_size} font-bold text-white"
    end
  end

  # Generate consistent gradient based on user ID for visual consistency
  def user_avatar_gradient(user)
    gradients = [
      'bg-gradient-to-r from-purple-500 to-pink-500',
      'bg-gradient-to-r from-blue-500 to-indigo-500',
      'bg-gradient-to-r from-green-500 to-emerald-500',
      'bg-gradient-to-r from-orange-500 to-red-500',
      'bg-gradient-to-r from-teal-500 to-cyan-500',
      'bg-gradient-to-r from-violet-500 to-purple-500',
      'bg-gradient-to-r from-rose-500 to-pink-500',
      'bg-gradient-to-r from-amber-500 to-orange-500'
    ]

    gradients[user.id % gradients.length]
  end

  # Format user status with appropriate styling
  def user_status_badge(user)
    case user.status
    when 'active'
      content_tag :span, 'Active',
                  class: 'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800'
    when 'inactive'
      content_tag :span, 'Inactive',
                  class: 'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800'
    when 'suspended'
      content_tag :span, 'Suspended',
                  class: 'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800'
    else
      content_tag :span, user.status.humanize,
                  class: 'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800'
    end
  end

  # Format user role with appropriate styling
  def user_role_badge(user)
    case user.role
    when 'owner'
      content_tag :span, 'Owner',
                  class: 'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800'
    when 'admin'
      content_tag :span, 'Admin',
                  class: 'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800'
    when 'member'
      content_tag :span, 'Member',
                  class: 'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800'
    when 'viewer'
      content_tag :span, 'Viewer',
                  class: 'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800'
    else
      content_tag :span, user.role.humanize,
                  class: 'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800'
    end
  end

  # Online status indicator
  def online_status_indicator(user)
    if user.online?
      content_tag :div, '',
                  class: 'w-3 h-3 bg-green-400 border-2 border-white rounded-full animate-pulse'
    else
      content_tag :div, '',
                  class: 'w-3 h-3 bg-gray-300 border-2 border-white rounded-full'
    end
  end

  # Format last active time
  def last_active_text(user)
    if user.online?
      'Online now'
    elsif user.last_active_at
      "Last seen #{time_ago_in_words(user.last_active_at)} ago"
    else
      'Never logged in'
    end
  end

  # Enhanced Toast/Flash helpers
  def toast(type, message, options = {})
    render 'shared/enhanced_toast', {
      type: type.to_s,
      message: message,
      title: options[:title],
      auto_dismiss: options.fetch(:auto_dismiss, true),
      duration: options.fetch(:duration, 5000),
      position: options.fetch(:position, 'top-right'),
      show_progress: options.fetch(:show_progress, true),
      actions: options[:actions]
    }
  end

  def success_toast(message, options = {})
    toast(:success, message, options)
  end

  def error_toast(message, options = {})
    toast(:error, message, options)
  end

  def warning_toast(message, options = {})
    toast(:warning, message, options)
  end

  def info_toast(message, options = {})
    toast(:info, message, options)
  end

  def loading_toast(message, options = {})
    toast(:loading, message, options.merge(auto_dismiss: false))
  end

  # Flash message type detection
  def flash_type_for(key)
    case key.to_s
    when 'notice', 'success'
      'success'
    when 'alert', 'error'
      'error'
    when 'warning'
      'warning'
    else
      'info'
    end
  end

  # Render flash messages as enhanced toasts
  def render_flash_toasts
    content = []

    flash.each do |key, message|
      next if message.blank?

      type = flash_type_for(key)
      content << toast(type, message, {
        title: type.humanize,
        position: 'top-right'
      })
    end

    safe_join(content)
  end
end

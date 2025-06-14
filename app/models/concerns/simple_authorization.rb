module SimpleAuthorization
  extend ActiveSupport::Concern
  
  # Simplified permissions for indie solopreneurs and SMEs
  # Focus: Easy to understand, minimal complexity
  
  SIMPLE_PERMISSIONS = {
    # Owner: Full access to everything (most indie users)
    owner: {
      can_do_everything: true,
      description: "Full access - perfect for business owners"
    },
    
    # Team Member: Can work but not manage billing/settings
    member: {
      campaigns: [:create, :read, :update, :send, :duplicate],
      contacts: [:create, :read, :update, :import],
      templates: [:create, :read, :update, :duplicate, :use],
      analytics: [:read],
      description: "Can create and manage marketing - perfect for team members"
    },
    
    # Viewer: Read-only access (for clients, stakeholders)
    viewer: {
      campaigns: [:read],
      contacts: [:read], 
      templates: [:read],
      analytics: [:read],
      description: "View-only access - perfect for clients or stakeholders"
    }
  }.freeze
  
  included do
    # Simple permission check - easy for indie users to understand
    def can?(action, resource = nil)
      return true if owner? # Owners can do everything
      return false unless active? # Only active users have permissions
      
      permissions = SIMPLE_PERMISSIONS[role.to_sym]
      return false unless permissions
      
      # If it's a simple viewer/member, check specific permissions
      resource_permissions = permissions[resource.to_sym]
      return false unless resource_permissions
      
      resource_permissions.include?(action.to_sym)
    end
    
    def cannot?(action, resource)
      !can?(action, resource)
    end
    
    # Simplified role checks for indie users
    def can_manage_team?
      owner? # Only owners manage team in small businesses
    end
    
    def can_access_billing?
      owner? # Only owners handle billing in SMEs
    end
    
    def can_invite_users?
      owner? && account.can_have_team_members?
    end
    
    def can_delete_things?
      owner? # Only owners can delete in small teams
    end
    
    # Simple role descriptions for indie users
    def role_description
      SIMPLE_PERMISSIONS[role.to_sym][:description] || "Unknown role"
    end
    
    # What this user can do (for onboarding/help)
    def capabilities
      return ["Everything! You're the owner 🎉"] if owner?
      
      permissions = SIMPLE_PERMISSIONS[role.to_sym]
      return ["View marketing campaigns and data"] if viewer?
      
      [
        "Create and send email campaigns",
        "Manage contacts and lists", 
        "Create and use templates",
        "View analytics and reports"
      ]
    end
  end
end
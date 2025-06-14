module Authorization
  extend ActiveSupport::Concern
  
  # Define permissions for each resource and action
  PERMISSIONS = {
    campaigns: {
      owner: [:create, :read, :update, :delete, :send, :schedule, :analytics],
      admin: [:create, :read, :update, :delete, :send, :schedule, :analytics],
      member: [:create, :read, :update, :send],
      viewer: [:read]
    },
    
    contacts: {
      owner: [:create, :read, :update, :delete, :import, :export, :segment],
      admin: [:create, :read, :update, :delete, :import, :export, :segment],
      member: [:create, :read, :update, :import],
      viewer: [:read]
    },
    
    templates: {
      owner: [:create, :read, :update, :delete, :duplicate, :publish],
      admin: [:create, :read, :update, :delete, :duplicate, :publish],
      member: [:create, :read, :update, :duplicate],
      viewer: [:read]
    },
    
    analytics: {
      owner: [:read, :export, :advanced],
      admin: [:read, :export, :advanced],
      member: [:read],
      viewer: [:read]
    },
    
    account: {
      owner: [:read, :update, :billing, :team_management, :settings],
      admin: [:read, :team_management, :settings],
      member: [:read],
      viewer: [:read]
    },
    
    users: {
      owner: [:create, :read, :update, :delete, :invite, :change_roles],
      admin: [:create, :read, :update, :invite],
      member: [:read],
      viewer: [:read]
    }
  }.freeze
  
  included do
    def can?(action, resource)
      return false unless role.present?
      
      resource_permissions = PERMISSIONS[resource.to_sym]
      return false unless resource_permissions
      
      role_permissions = resource_permissions[role.to_sym]
      return false unless role_permissions
      
      role_permissions.include?(action.to_sym)
    end
    
    def cannot?(action, resource)
      !can?(action, resource)
    end
    
    # Convenience methods for common checks
    def can_manage?(resource)
      can?(:create, resource) && can?(:update, resource) && can?(:delete, resource)
    end
    
    def can_read_only?(resource)
      can?(:read, resource) && cannot?(:update, resource)
    end
    
    # Role hierarchy checks
    def higher_role_than?(other_user)
      role_hierarchy[role.to_sym] > role_hierarchy[other_user.role.to_sym]
    end
    
    def same_or_higher_role_than?(other_user)
      role_hierarchy[role.to_sym] >= role_hierarchy[other_user.role.to_sym]
    end
    
    private
    
    def role_hierarchy
      {
        viewer: 0,
        member: 1,
        admin: 2,
        owner: 3
      }
    end
  end
end
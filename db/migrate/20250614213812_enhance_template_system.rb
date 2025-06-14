class EnhanceTemplateSystem < ActiveRecord::Migration[8.0]
  def change
    add_column :templates, :description, :text
    add_column :templates, :thumbnail_url, :string
    add_column :templates, :design_system, :string, default: 'modern'
    add_column :templates, :color_scheme, :jsonb, default: {}
    add_column :templates, :content_blocks, :jsonb, default: []
    add_column :templates, :variables, :jsonb, default: {}
    add_column :templates, :is_premium, :boolean, default: false
    add_column :templates, :is_public, :boolean, default: false
    add_column :templates, :usage_count, :integer, default: 0
    add_column :templates, :rating, :decimal, precision: 3, scale: 2, default: 0.0
    add_column :templates, :tags, :text, array: true, default: []
    
    add_index :templates, :design_system
    add_index :templates, :is_public
    add_index :templates, :tags, using: 'gin'
    add_index :templates, :color_scheme, using: 'gin'
  end
end

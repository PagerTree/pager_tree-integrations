class CreatePagerTreeIntegrationsIntegrations < ActiveRecord::Migration[7.0]
  def change
    create_table :pager_tree_integrations_integrations do |t|
      t.string :type, null: false
      t.text :options

      t.timestamps
    end
  end
end

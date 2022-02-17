class CreatePagerTreeIntegrationsOutgoingWebhookDeliveries < ActiveRecord::Migration[7.0]
  def change
    create_table :pager_tree_integrations_outgoing_webhook_deliveries do |t|
      t.string :type, null: false
      t.string :thirdparty_id
      t.integer :status, null: false, default: 0
      t.text :data
      t.timestamps
    end
  end
end

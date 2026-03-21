class AddVerificationFieldsToHeartbeats < ActiveRecord::Migration[8.1]
  def change
    add_column :heartbeats, :verified, :boolean, default: true, null: false
    add_column :heartbeats, :trust_score, :float, default: 1.0, null: false
    add_column :heartbeats, :trust_reasons, :string, array: true, default: [], null: false

    add_index :heartbeats, [ :user_id, :verified, :time ],
      where: "(deleted_at IS NULL)",
      name: "idx_heartbeats_user_verified_time"
  end
end
class AddLastSeenAtToCollaborators < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:collaborators)
      create_table :collaborators do |t|
        t.bigint :document_id, null: false
        t.bigint :user_id, null: false
        t.string :role
        t.timestamps
      end
      add_index :collaborators, :document_id
      add_index :collaborators, :user_id
    end

    add_column :collaborators, :last_seen_at, :datetime
    add_index :collaborators, :last_seen_at
  end
end

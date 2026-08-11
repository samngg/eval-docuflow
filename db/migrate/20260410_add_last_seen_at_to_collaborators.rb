class AddLastSeenAtToCollaborators < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:collaborators)
      create_table :collaborators do |t|
        t.bigint :document_id, null: false
        t.references :user, null: false, foreign_key: true
        t.datetime :last_seen_at
        t.string :role
        t.timestamps
      end
    end

    unless column_exists?(:collaborators, :last_seen_at)
      add_column :collaborators, :last_seen_at, :datetime
    end

    unless index_exists?(:collaborators, :last_seen_at)
      add_index :collaborators, :last_seen_at
    end
  end
end

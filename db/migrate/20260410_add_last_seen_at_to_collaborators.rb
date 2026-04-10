class AddLastSeenAtToCollaborators < ActiveRecord::Migration[7.1]
  def change
    add_column :collaborators, :last_seen_at, :datetime
    add_index :collaborators, :last_seen_at
  end
end

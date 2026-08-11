# frozen_string_literal: true

module CollaboratorPresence
  extend ActiveSupport::Concern

  PRESENCE_TIMEOUT = 5.minutes

  included do
    scope :with_active_presence, -> {
      joins(:collaborators)
        .where("collaborators.last_seen_at > ?", PRESENCE_TIMEOUT.ago)
    }
  end

  def self.with_presence_data(documents)
    documents.map do |doc|
      collaborators = Collaborator.where(document_id: doc.id)
        .where("last_seen_at > ?", PRESENCE_TIMEOUT.ago)
        .includes(:user)

      {
        document: doc,
        active_collaborators: collaborators.map do |c|
          {
            user_id: c.user_id,
            name: c.user.name,
            avatar_url: c.user.avatar_url,
            last_seen_at: c.last_seen_at,
            role: c.role
          }
        end
      }
    end
  end
end

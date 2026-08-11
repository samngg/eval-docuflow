# frozen_string_literal: true

class Collaborator < ApplicationRecord
  # 🚅 add concerns above.

  # 🚅 add belongs_to associations above.
  belongs_to :user

  # 🚅 add has_many associations above.

  # 🚅 add oauth providers above.

  # 🚅 add has_one associations above.

  # 🚅 add scopes above.

  # 🚅 add validations above.
  validates :document_id, presence: true
  validates :role, presence: true

  # 🚅 add callbacks above.

  # 🚅 add delegations above.

  # 🚅 add methods above.
end

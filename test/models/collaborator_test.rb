require "test_helper"

class CollaboratorTest < ActiveSupport::TestCase
  setup do
    @user = FactoryBot.create(:user)
    @collaborator = Collaborator.new(
      user: @user,
      document_id: 1,
      role: "editor",
      last_seen_at: Time.current
    )
  end

  test "should be valid with valid attributes" do
    assert @collaborator.valid?
  end

  test "should require user" do
    @collaborator.user = nil
    assert_not @collaborator.valid?
  end

  test "should require document_id" do
    @collaborator.document_id = nil
    assert_not @collaborator.valid?
  end

  test "should require role" do
    @collaborator.role = nil
    assert_not @collaborator.valid?
  end

  test "with_presence_data should return formatted presence data" do
    # Create mock document struct
    doc = Struct.new(:id).new(123)
    @collaborator.document_id = doc.id
    @collaborator.save!

    presence_data = CollaboratorPresence.with_presence_data([doc])
    assert_equal 1, presence_data.length

    data = presence_data.first
    assert_equal doc, data[:document]
    assert_equal 1, data[:active_collaborators].length

    active_collab = data[:active_collaborators].first
    assert_equal @user.id, active_collab[:user_id]
    assert_equal @user.name, active_collab[:name]
    assert_equal @user.avatar_url, active_collab[:avatar_url]
    assert_equal "editor", active_collab[:role]
  end
end

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

  test "should require document_id" do
    @collaborator.document_id = nil
    assert_not @collaborator.valid?
    assert_includes @collaborator.errors[:document_id], "can't be blank"
  end

  test "should require role" do
    @collaborator.role = nil
    assert_not @collaborator.valid?
    assert_includes @collaborator.errors[:role], "can't be blank"
  end

  test "should require user" do
    @collaborator.user = nil
    assert_not @collaborator.valid?
  end
end

require 'rails_helper'

include Features::SubmissionHelpers
include Features::CommentHelpers

feature 'Comment', js: true do
  before do
    @submission = FactoryGirl.create(:submission)
    @submission_api = TestSubmission.new
    @admin = FactoryGirl.create(:admin)
    @user = FactoryGirl.create(:user)
    @comment_api = TestComment.new(@submission)
  end

  feature 'edit' do
    before do
      @comment = FactoryGirl.create(:comment, commentable: @submission)
    end

    scenario "admin should update comment" do
      login_as @admin
      visit submission_page_path(id: @submission.id, camel_caption: @submission.camel_caption)

      @comment_api.open_edit_field(@comment)
      fill_in :edit_raw_content, with: 'Edit test comment'

      @comment_api.click_update_button(@comment)

      expect(page).to have_content('Edit test comment')
    end

    scenario "should not show control buttons" do
      login_as @user
      visit submission_page_path(id: @submission.id, camel_caption: @submission.camel_caption)

      expect(page).to_not have_css("#test_comment_edit_#{@comment.id}")
    end
  end

end

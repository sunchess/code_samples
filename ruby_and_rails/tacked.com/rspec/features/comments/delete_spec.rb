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

    scenario "admin should delete comment" do
      login_as @admin
      visit submission_page_path(id: @submission.id, camel_caption: @submission.camel_caption)

      @comment_api.click_delete_icon(@comment)

      click_button 'YES'

      expect(page).to_not have_content(@comment.raw_content)
    end
  end
end

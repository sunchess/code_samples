require 'rails_helper'

include Features::SubmissionHelpers
include Features::CommentHelpers

feature 'Comment', js: true do
  before do
    @submission = FactoryGirl.create(:submission)
    @submission_api = TestSubmission.new
    @user = FactoryGirl.create(:user)
    @comment_api = TestComment.new(@submission)
  end

  feature 'flagging' do
    before do
      @comment = FactoryGirl.create(:comment, commentable: @submission)
    end

    scenario 'send reason' do
      login_as @user
      visit page_path(page: 'newest')

      @submission_api.open_from_feed(@submission)
      @comment_api.open_reason(@comment)

      @comment_api.fill_reason('test reason comment')
      @comment_api.submit_reason

      expect(page).to have_content('Thank you for your response')
    end
  end
end

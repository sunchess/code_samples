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

  scenario 'create' do
    login_as @user
    visit page_path(page: 'newest')

    @submission_api.open_from_feed(@submission)
    sleep(2)
    @comment_api.fill_comment('test comment submission')
    @comment_api.submit

    sleep(2)
    expect(page).to have_content 'test comment submission'
  end

  feature 'user names' do
    before do
      @user_in_comment = FactoryGirl.create(:user, name: 'John Doe')
    end

    scenario "should add link by @userName" do
      login_as @user
      visit page_path(page: 'newest')

      @submission_api.open_from_feed(@submission)
      @comment_api.fill_comment('@JohnDoe test comment submission')
      @comment_api.submit

      within("#test_show_submission_#{@submission.id}") do
        expect(page).to have_css("a[href='#{user_page_path(user: @user_in_comment.name)}']")
      end
    end
  end
end

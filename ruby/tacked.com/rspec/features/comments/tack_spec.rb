require 'rails_helper'

include Features::SubmissionHelpers
include Features::CommentHelpers

feature 'Comment', js: true do
  before do
    @user = FactoryGirl.create(:user)
    @submission = FactoryGirl.create(:submission, tacks: 1)
    @comment = FactoryGirl.create(:comment, commentable: @submission)

    @submission_api = TestSubmission.new
    @comment_api = TestComment.new(@submission)
  end

  feature 'Tack' do

    scenario 'should tack successfully' do
      login_as @user
      visit root_path


      @submission_api.open_from_feed(@submission)
      @comment_api.tack!(@comment)

      within("#test_comment_#{@comment.id}") do
        expect(page).to have_css("#tack_comment_button_#{@comment.id}.active")
      end

      expect(@comment.reload.tacks).to be(1)
    end

  end
end

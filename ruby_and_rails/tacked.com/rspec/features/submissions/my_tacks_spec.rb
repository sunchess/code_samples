require 'rails_helper'

include Features::SidebarHelpers

feature 'Submissions feed', js: true do
  feature 'my tacks' do
    before do
      @submissions = FactoryGirl.create_list(:submission, 5)
      @user = FactoryGirl.create(:user)
      @sidebar = TestSidebar.new

      @submissions.each do |submission|
        submission.increment!(:tacks)
        @user.store_tack_for(submission)
      end
    end

    scenario 'should show submissions which I tacked' do

      login_as @user
      visit root_path

      @sidebar.open
      @sidebar.open_my_tack_page

      @submissions.each do |submission|
        expect(page).to have_css("#test_submission_#{submission.id}")
      end
    end

    scenario 'should show anonymus submissions' do
      submissions = FactoryGirl.create_list(:submission, 3, user: nil)

      submissions.each do |submission|
        submission.increment!(:tacks)
        @user.store_tack_for(submission)
      end

      login_as @user
      visit root_path

      @sidebar.open
      @sidebar.open_my_tack_page

      submissions.each do |submission|
        expect(page).to have_css("#test_submission_#{submission.id}")
      end
    end

  end
end

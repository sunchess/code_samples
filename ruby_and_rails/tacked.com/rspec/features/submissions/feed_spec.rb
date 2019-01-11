require 'rails_helper'

include Features::FeedHelpers
include Features::SubmissionHelpers

feature 'Submissions feed', js: true do
  before do
    @feed_api = TestFeed.new
    @submission_api = TestSubmission.new
  end

  after do
    page.execute_script("window.localStorage.clear()")
  end

  feature 'recommended' do
    before do
      @user = FactoryGirl.create(:user)
      @submissions = FactoryGirl.create_list(:submission, 5, {pic: nil, tag_list: ['tag-1']})
      @first = FactoryGirl.create(:submission, {pic: nil, tag_list: ['tag-1']})
    end

    scenario "should shows recommended feed" do
      @admin = FactoryGirl.create(:admin)
      login_as @admin
      visit page_path(page: :recommended)

      sleep(2)
      #recommended submissions are empty
      @submissions.each do |submission|
        expect(page).to_not have_content(submission.description)
      end

      @first.increment!(:tacks) and @admin.store_tack_for(@first)

      @feed_api.reload_feed(:recommended)
      sleep(2)

      #check with additional submission
      @submissions.each do |submission|
        expect(page).to have_content(submission.description)
      end
    end
  end

  feature 'newest' do
    before do
      @submissions = FactoryGirl.create_list(:submission, 5, {pic: nil})
    end

    scenario 'Should reload newest feed by click' do
      visit page_path(page: :newest)

      sleep(2)
      @submissions.each do |submission|
        expect(page).to have_content(submission.description)
      end

      @submissions << FactoryGirl.create(:submission)

      @feed_api.reload_feed(:newest)

      #check with additional submission
      @submissions.each do |submission|
        expect(page).to have_content(submission.description)
      end
    end
  end


  feature 'best' do
    before do
      @submissions = FactoryGirl.create_list(:submission, 5, {pic: nil, tacks: (5..20).to_a.sample})
    end

    scenario 'Should reload best feed by click' do
      visit page_path(page: :best)

      sleep(2)
      @submissions.each do |submission|
        expect(page).to have_content(submission.description)
      end

      @submissions << FactoryGirl.create(:submission, {tacks: (5..20).to_a.sample})

      @feed_api.reload_feed(:best)

      #check with additional submission
      @submissions.each do |submission|
        expect(page).to have_content(submission.description)
      end
    end
  end


  feature '/' do
    before do
      @submissions = FactoryGirl.create_list(:submission, 5, {pic: nil, tacks: (5..20).to_a.sample})
    end

    scenario 'Should reload logo feed by click' do
      visit root_path

      sleep(2)
      @submissions.each do |submission|
        expect(page).to have_content(submission.description)
      end

      @submissions << FactoryGirl.create(:submission, {tacks: (5..20).to_a.sample})

      @feed_api.reload_feed(:logo)

      #check with additional submission
      @submissions.each do |submission|
        expect(page).to have_content(submission.description)
      end
    end
  end


  feature 'following' do
    before do
      @user = FactoryGirl.create(:user)
      @follower = FactoryGirl.create(:user)

      # @user.followers << @follower
      @submissions = FactoryGirl.create_list(:submission, 5, {pic: nil, tacks: (5..20).to_a.sample, user: @user})
    end

    scenario 'Should open the sign in page when user not logged in' do
      visit root_path
      sleep(2)
      @feed_api.load_feed(:following)
      sleep(2)

      expect(page).to have_content 'SIGN IN TO TACKED.'
      expect(page).to have_field 'Email'
      expect(page).to have_field 'Password'
    end

    scenario 'Should reload following feed by click' do
      login_as @follower
      visit page_path(page: :following)

      sleep(2)
      @submissions.each do |submission|
        expect(page).to have_content(submission.description)
      end

      @submissions << FactoryGirl.create(:submission, {tacks: (5..20).to_a.sample, user: @user})

      @feed_api.reload_feed(:following)
      Rails.cache.clear #- for me it fails with "Directory not empty @ dir_s_rmdir"

      #check with additional submission
      @submissions.each do |submission|
        expect(page).to have_content(submission.description)
      end
    end
  end


  feature "description limit" do
    before do
      @submission = FactoryGirl.create(:submission, {description: Faker::Lorem.sentence * 50})
      @text_submission = FactoryGirl.create(:text_submission, {description: Faker::Lorem.sentence * 50})
    end

    scenario "should show 200 limit of image category description of submission at feed" do
      visit page_path(page: :newest)

      sleep(2)
      within("#test_submission_#{@submission.id}") do
        expect(page).to have_content(@submission.description.truncate(200))
      end

      within("#test_submission_#{@text_submission.id}") do
        expect(page).to have_content(@text_submission.description.truncate(200))
      end
    end
  end


  feature '4th spot' do
    before do
      @submissions = FactoryGirl.create_list(:best_submission, 10)
      spot = @submissions.first.update_attributes( spot: true, caption: 'spot spot spot' )
      Submission.set_scores!
    end

    scenario 'advert spot should be on 4th place' do
      visit root_path

      sleep(2)
      expect(page).to have_selector('.test-submissions-list .test-submission-item-wrapper:nth-child(4).spot')
    end

    scenario 'spot should not have tack button tags and controll elements' do
      visit root_path

      sleep(2)
      within('.test-submissions-list .test-submission-item-wrapper:nth-child(4)') do
        expect(page).to_not have_css('.submission-item__tacks')
        expect(page).to_not have_css('.submission-item__comments')
        expect(page).to_not have_css('.submission-item__user')
        expect(page).to_not have_css('.submission-item__share')
        expect(page).to_not have_css('submission-menu')
      end
    end
  end

  feature 'Tack' do
    before do
      @submission = FactoryGirl.create(:submission_without_owner_after_tacks, {pic: nil, tacks: 1})
    end

    scenario "Should tack submission successfully" do
      visit root_path
      sleep(2)
      @feed_api.tack! @submission
      sleep(2)

      within("#test_submission_#{@submission.id}") do
        expect(page).to have_css('.test-tack-button.test-active')
        expect(page).to have_selector('div.submission-item__tacks-count', text: '2')
      end

    end

  end

  feature 'user name' do
    before do
      @user = FactoryGirl.create(:user)
      @submission = FactoryGirl.create(:submission, {pic: nil, tacks: 1, user: @user})
    end

    scenario 'should shows user page url in submission item' do
      visit root_path

      within("#test_submission_#{@submission.id}") do
        expect(page).to have_css('a[href="' + user_page_path(user: @user.normalized_name) + '"]')
      end

    end

    scenario 'should shows user page url on submission popout' do
      visit root_path

      @submission_api.open_from_feed(@submission, 'caption')
      sleep(2)

      within("#test_show_submission_#{@submission.id}") do
        expect(page).to have_css('a[href="' + user_page_path(user: @user.normalized_name) + '"]')
      end
    end

    scenario 'should shows user page url on submission page' do
      visit submission_page_path(id: @submission.id, camel_caption: @submission.camel_caption)

      expect(page).to have_css('a[href="' + user_page_path(user: @user.normalized_name) + '"]')
    end
  end

end

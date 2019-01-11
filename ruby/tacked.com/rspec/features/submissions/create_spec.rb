require 'rails_helper'

include Features::SubmissionHelpers
include Features::FeedHelpers

feature 'Submissions', js: true do
  before do
    @user = FactoryGirl.create(:user)
    @recommended_tags = generate_recommended_tags(times: 10)
    @feed_api = TestFeed.new

    login_as(@user)
  end

  after do
    page.execute_script("window.localStorage.clear()")
  end

  scenario 'new submission should allow to tack' do
    @submission = FactoryGirl.create(:submission)
    visit page_path(page: :newest)
    find('.test-tack-button').click
    expect(find('.test-tack-button')[:class].include?("test-active")).to be true

    visit page_path(page: :newest)
    expect(find('.test-tack-button')[:class].include?("test-active")).to be true
  end

  scenario 'success create text' do
    visit root_path
    create_text_submission(text: 'tested submission', tags: @recommended_tags)
    expect(page).to have_content("LET'S REALLY SEAL THE DEAL. SPREAD THE LOVE. SHARE YOUR POST.")

    @feed_api.load_feed(:newest)
    expect(page).to have_content('tested submission')
  end

  scenario 'success create link' do
    visit root_path
    test_submission = TestSubmission.new(tags: @recommended_tags)
    test_submission.fill_multifield(link: 'https://www.yandex.ru/')
    test_submission.fill_tags_and_submit
    expect(page).to have_content("LET'S REALLY SEAL THE DEAL. SPREAD THE LOVE. SHARE YOUR POST.")

    @feed_api.load_feed(:newest)
    expect(page).to have_link 'www.yandex.ru', href: 'https://www.yandex.ru/'
  end

  scenario 'success create image' do
    visit root_path
    test_submission = TestSubmission.new(tags: @recommended_tags)
    test_submission.fill_multifield(image: Rails.root.join('spec', 'support', 'files', 'images.jpeg'))
    test_submission.fill_caption_and_description(caption: 'test caption', description: 'test decription')
    test_submission.fill_tags_and_submit

    @feed_api.load_feed(:newest)
    expect(page).to have_content 'test caption'
    expect(page).to have_content 'test decription'
  end

  scenario 'should clear form after create' do
    visit root_path
    test_submission = TestSubmission.new(tags: @recommended_tags)
    test_submission.fill_multifield(image: Rails.root.join('spec', 'support', 'files', 'images.jpeg'))
    test_submission.fill_caption_and_description(caption: 'test caption', description: 'test decription')
    test_submission.fill_tags_and_submit

    test_submission.fill_multifield(image: Rails.root.join('spec', 'support', 'files', 'images.jpeg'))

    within('form#new_submission') do
      expect(page).to_not have_css('.upload-tag.btn-primary')
      expect(page).to_not have_css('ul.tag-list li.tag-item')
      expect(page).to_not have_field('js-submission-title', with: 'test caption')
      expect(page).to_not have_field('js-submission-description', with: 'test decription')
    end
  end

  feature 'errors' do
    scenario 'get error on tags' do
      visit root_path
      test_submission = TestSubmission.new
      test_submission.fill_multifield(text: 'new submission')
      test_submission.submit

      expect(page).to have_content 'List of topics should have at least one Topic'
    end
  end


  feature 'Cached Submissions', js: true do
    before do
      ActionController::Base.perform_caching = true
      Rails.cache.clear

      @user = FactoryGirl.create(:user)
      @recommended_tags = generate_recommended_tags(times: 10)
      login_as(@user)
    end

    after do
      Rails.cache.clear
      ActionController::Base.perform_caching = false
    end

    scenario 'cached submission should allow to tack' do
      @submission = FactoryGirl.create(:submission)
      @user.store_tack_for(@submission)
      @user.reload
      visit page_path(page: :newest)
      expect(find('.test-tack-button')[:class].include?("test-active")).to be true
      Capybara.reset_sessions!
      visit page_path(page: :newest)
      expect(find('.test-tack-button')[:class].include?("test-active")).to be false
    end
  end

  feature 'Clear Form' do

    scenario 'should clear the text submission counter' do
      visit root_path
      test_submission = TestSubmission.new(tags: @recommended_tags)
      test_submission.fill_multifield(text: 'new submission')

      #check counter should have the remaining characters
      within('#new_submission') do
        expect(page).to have_css('.counter', text: '186')
      end

      test_submission.fill_tags_and_submit

      sleep(3)

      test_submission.open_new_submission_popup

      #check counter should not have remaining chars
      within('#new_submission') do
        expect(page).to_not have_css('.counter', text: '186')
      end
    end

    scenario 'should clear form after creating' do
      visit root_path
      test_submission = TestSubmission.new(tags: @recommended_tags)
      test_submission.fill_multifield(image: Rails.root.join('spec', 'support', 'files', 'images.jpeg'))
      test_submission.fill_caption_and_description(caption: 'test caption', description: 'test decription')
      test_submission.fill_custom_tag
      test_submission.fill_tags_and_submit

      sleep(3)

      test_submission.fill_multifield(image: Rails.root.join('spec', 'support', 'files', 'images.jpeg'))

      within('#new_submission') do
        #caption
        expect(page).to_not have_field('js-submission-title', with: 'test caption')
        #description
        expect(page).to_not have_field('js-submission-description', with: 'test caption')

        #tags
        within('#js-submission-extra') do
          expect(page).to_not have_css('.upload-tag.btn-primary')
          expect(page).to_not have_css('li.tag-item')
        end
      end
    end

    scenario 'should clear form after canceling' do
      visit root_path
      test_submission = TestSubmission.new(tags: @recommended_tags)
      test_submission.fill_multifield(image: Rails.root.join('spec', 'support', 'files', 'images.jpeg'))
      test_submission.fill_caption_and_description(caption: 'test caption', description: 'test decription')
      test_submission.fill_custom_tag
      test_submission.select_popular_tag

      test_submission.cancel_creation
      sleep(4)

      test_submission.fill_multifield(image: Rails.root.join('spec', 'support', 'files', 'images.jpeg'), open: false)

      sleep(4)

      within('#new_submission') do
        #caption
        expect(page).to_not have_field('js-submission-title', with: 'test caption')

        #description
        expect(page).to_not have_field('js-submission-description', with: 'test caption')

       #TODO: meybe need later
       # within('#js-submission-extra') do
       #   expect(page).to_not have_css('.upload-tag.btn-primary')
       #   expect(page).to_not have_css('li.tag-item')
       # end
      end
    end

  end
end

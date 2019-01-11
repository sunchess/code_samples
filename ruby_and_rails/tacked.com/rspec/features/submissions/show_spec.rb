require 'rails_helper'

include Features::SubmissionHelpers

feature 'Submission', js: true do
  before do
    @submission = FactoryGirl.create(:best_submission)
    @submission_api = TestSubmission.new
  end

  scenario 'should show submission from feed by image link' do
    visit root_path

    @submission_api.open_from_feed(@submission)

    expect(page).to have_content(@submission.caption.upcase)
    expect(page).to have_content(@submission.description)
  end

  scenario 'should show submission from feed by caption link' do
    visit root_path

    @submission_api.open_from_feed(@submission, 'caption')

    expect(page).to have_content(@submission.caption.upcase)
    expect(page).to have_content(@submission.description)
  end

  scenario 'should show submission from feed by description link' do
    visit root_path

    @submission_api.open_from_feed(@submission, 'description')
    sleep(2)

    expect(page).to have_content(@submission.caption.upcase)
    expect(page).to have_content(@submission.description)
  end

  scenario 'should open direct submission path' do
    visit submission_path(@submission)
    sleep(2)

    expect(page).to have_content(@submission.caption.upcase)
    expect(page).to have_content(@submission.description)
  end


  feature "description limit" do
    let(:submission){FactoryGirl.create(:submission, {description: "test description" * 100, tacks: 1})}
    let(:text_submission){FactoryGirl.create(:text_submission, {description: "test description" * 100, tacks: 1})}

    scenario "should show full description of image category submission" do
      submission = submission()
      visit root_path

      @submission_api.open_from_feed(submission)
      sleep(3)

      expect(page).to have_content(submission.description)
    end

    scenario "should show full description of text category submission" do
      submission = text_submission()
      visit root_path

      @submission_api.open_from_feed(submission, 'description')
      sleep(3)

      expect(page).to have_content(submission.description)
    end


    scenario "should show full description of text category submission in direct submission suite" do
      submission = submission()

      visit submission_path(submission)
      sleep(2)

      expect(page).to have_content(submission.description)
    end
  end

  feature 'Tack' do
    before do
      @submission = FactoryGirl.create(:submission_without_owner_after_tacks, {pic: nil, tacks: 1})
    end

    scenario 'should tack successfully' do
      visit submission_page_path(id: @submission.id, camel_caption: @submission.camel_caption)
      @submission_api.tack!(@submission)

      within("#test_show_submission_#{@submission.id}") do
        expect(page).to have_css('.test-tack-button.test-active')
        expect(page).to have_selector('div.submission-item__tacks-count', text: '2')
      end
    end
  end

end

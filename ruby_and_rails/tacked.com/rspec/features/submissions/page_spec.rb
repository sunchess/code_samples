require 'rails_helper'
include Features::FeedHelpers

feature 'Submissions page', js: true do
  before do
    @feed_api = TestFeed.new

    @user = FactoryGirl.create(:user)
    @sender = FactoryGirl.create(:user)
    @submission = FactoryGirl.create(:submission, { tag_list: 'TestTag', user: @sender, tacks: 1 })
  end

  scenario "should show tag's submission with new, trending and top feed" do
    login_as @user
    visit tag_page_path(tag: 'TestTag')
    expect(page).to have_content(@submission.description)
    expect(page).to have_content(@submission.caption)

    @feed_api.select_order_feed('New')

    expect(page).to have_content(@submission.description)
    expect(page).to have_content(@submission.caption)

    @feed_api.select_order_feed('Top')

    expect(page).to have_content(@submission.description)
    expect(page).to have_content(@submission.caption)

    @feed_api.select_order_feed('Trending')

    expect(page).to have_content(@submission.description)
    expect(page).to have_content(@submission.caption)
  end

  scenario "should show user's submission with new, trending and top feed" do
    login_as @user
    visit  user_page_path(user: @sender.name)
    expect(page).to have_content(@submission.description)
    expect(page).to have_content(@submission.caption)

    @feed_api.select_order_feed('New')

    expect(page).to have_content(@submission.description)
    expect(page).to have_content(@submission.caption)

    @feed_api.select_order_feed('Top')

    expect(page).to have_content(@submission.description)
    expect(page).to have_content(@submission.caption)

    @feed_api.select_order_feed('Trending')

    expect(page).to have_content(@submission.description)
    expect(page).to have_content(@submission.caption)
  end


  scenario "should scroll page removing duplicate submissions" do
    @submission = FactoryGirl.create_list(:submission, 10)
    Submission.all.each{|s| s.update_attribute :tacks, s.id}
    visit page_path(page: :best)
    Submission.best.last.update_attribute :tacks, 10
    page.execute_script "window.scrollTo(0,document.body.scrollHeight);"
    dupe = Submission.best.last
    sleep 1
    expect(page).to have_selector("#submission_#{dupe.id}", maximum: 1)
  end
end

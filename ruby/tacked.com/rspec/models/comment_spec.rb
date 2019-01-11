require 'rails_helper'

RSpec.describe Comment, type: :model do
  it{should respond_to(:user)}
  it{should respond_to(:raw_content)}
  it{should respond_to(:score)}
  it{should respond_to(:save_user_counters)}
  it{should respond_to(:save_commentable_counters)}

  it "should generate auto link with http" do
    comment = FactoryGirl.create(:comment, raw_content: 'its test http://google.com')

    expect(comment.content =~ /<a.+>http:\/\/google.com<\/a>/).to_not eq nil
  end

  it "should not generate link" do
    comment = FactoryGirl.create(:comment, raw_content: 'its test google')

    expect(comment.content =~ /<a.+>http:\/\/google.com<\/a>/).to eq nil
  end

  it "should send notification after create" do
    user = FactoryGirl.create(:user, name: 'Alex')
    comment = FactoryGirl.build(:comment, raw_content: '@Alex is cool!')
    comment.save!
    expect(user.notifications.main.count).to eq(1)
  end

  it "should save notices to all users which will be mentiones in comment" do
    actor = FactoryGirl.create(:user, name: 'Actor')
    user1 = FactoryGirl.create(:user, name: 'Alex')
    user2 = FactoryGirl.create(:user, name: 'John')

    comment = FactoryGirl.build(:comment, raw_content: '@Alex is cool! @John is cool, too!', user: actor)
    comment.save!

    expect(user1.notifications.main.count).to eq(1)
    expect(user1.notifications.main.first.description).to eq("#{actor.name} mentioned you in a comment")
    expect(user2.notifications.main.count).to eq(1)
    expect(user2.notifications.main.first.description).to eq("#{actor.name} mentioned you in a comment")
  end

  it "should add user links to content" do
    user = FactoryGirl.create(:user, name: 'Alex')
    comment = FactoryGirl.build(:comment, user: user, raw_content: 'Hey, @Alex it is cool!')
    comment.save!
    expect(comment.content).to eq('<p>Hey, <a href="/user/Alex">@Alex</a> it is cool!</p>')
  end

  it "should update user published counter" do
    user = FactoryGirl.create(:user)
    comment = FactoryGirl.build(:comment, user: user)
    comment.save!
    expect(user.published_comments_count).to eq(1)
  end

  it "should update submission comment published counter" do
    submission = FactoryGirl.create(:submission)
    comment = FactoryGirl.build(:comment, commentable: submission)
    comment.save!
    expect(submission.published_comments_count).to eq(1)
  end

end

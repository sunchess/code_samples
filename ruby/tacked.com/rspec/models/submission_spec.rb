require 'rails_helper'
require 'vcr_helper'

RSpec.describe Submission, type: :model do
  it{should respond_to :pic_uuid}
  it{should respond_to :pic_url}
  it{should respond_to :custom_tag}
  it{should respond_to :content}

  it{should respond_to :set_spot_score!}
  it{should respond_to :update_score!}

  describe 'methods' do
    let(:submission){ FactoryGirl.create(:submission) }

    it "should truncate too long picture names" do
      skip 'Not implemented yet'
    end

    it "should truncate caption and description" do
      submission = FactoryGirl.create(:submission, {caption: Faker::Lorem.sentence * 100, description: Faker::Lorem.sentence * 100})
      expect(submission.caption.size <= 200).to be(true)
      expect(submission.description.size <= 4096).to be(true)
    end

    describe "scopes" do
      before do
        @submissions = Array.new
        10.times do |t|
          @submissions << FactoryGirl.create(:submission, {tacks: t})
        end
      end

      it "should return right order at top" do
        expect(Submission.top.first).to eq(Submission.order(tacks: :desc).first)
      end

      it "should return right order at best scope" do
        expect(Submission.best.first).to eq(Submission.order({score: :desc}).first)
      end

      it "should return right order at newest scope" do
        expect(Submission.newest.first).to eq(Submission.order(created_at: :desc).where(spot: false).first)
      end

      it "newest should not have spot submission" do
        expect(Submission.newest).to_not include(Submission.spot)
      end
    end

    describe 'class methods' do
      before do
        @user = FactoryGirl.create(:user)
        @tag1 = FactoryGirl.create(:tag, {name: 'test-tag1'})
        @tag2 = FactoryGirl.create(:tag, {name: 'test-tag2'})
        @submission1 = FactoryGirl.create(:submission, {tag_list: ['test-tag1']})
        @submission2 = FactoryGirl.create(:submission, {tag_list: ['test-tag2']})
      end

      it "should return followed submissions by user [self.followed_for(user)]" do
        @user.follow!(@tag1)
        @user.follow!(@tag2)
        expect(Submission.followed_for(@user)).to include(@submission1)
        expect(Submission.followed_for(@user)).to include(@submission2)
      end
    end

    describe 'pusher' do
      before do
        @user = FactoryGirl.create(:user, {tacks_count: 20})
        @submission = FactoryGirl.build(:submission, {user: @user, score: 4.003, tacks: 12})
      end

      it "should return hash for pusher score [pusher_hash]" do
        id = @submission.id
        expect(@submission.pusher_hash).to eq({id => [4.003, 12]})
      end

      it "should return pusher hash for user recount [pusher_user_tacks]" do
        expect(@submission.pusher_user_tacks).to eq({ user_id: @user.id, tacks_count: @user.tacks_count, pluralize_tacks: "20 Tacks" })
      end
    end

    context "image attachment corner cases", vcr: {cassette_name: 'image_requests', record: :none, allow_playback_repeats: true} do
      describe "image from a 3rd party server gets returned with content-type application/octet-stream" do
        it "'s ok" do
          Submission.any_instance.stub(:update_score!)
          submission = FactoryGirl.create(:submission)
          submission.pic = URI.parse('http://example.com/octetstream-image.jpg')
          submission.save!
        end
      end
    end
  end

  describe 'rankin' do

    it 'should be compatible with the paranoia gem' do
      s = FactoryGirl.create(:submission)
      expect{ s.really_destroy! }.to_not raise_error
    end

    describe 'spot' do
      describe 'not eq scores ' do
        before do
          5.times do |time|
            FactoryGirl.create(:submission, tacks: time + 1)
          end
          @spot_submission = FactoryGirl.create(:spot_submission, {spot: true, tacks: 1})

          Submission.best.each do |submission|
            submission.update_attribute(:tacks, submission.tacks + 1)
          end
        end

        it "should return spot on 4th plase" do
          spot = Submission.best.limit(4).last
          expect(spot).to eq(@spot_submission)
        end
      end

      describe 'eq scores' do
        before do
          5.times do |time|
            FactoryGirl.create(:submission, tacks: 4)
          end
          @spot_submission = FactoryGirl.create(:spot_submission, {spot: true, tacks: 1})
        end

        it "should return spot on 4th plase" do
          Submission.best.first.increment!(:tacks)
          spot = Submission.best.limit(4).last
          expect(spot).to eq(@spot_submission)
        end

      end
    end

  end
end

require 'rails_helper'

RSpec.describe WebhookService do
  subject(:webhook) { described_class.new(WebhookCodes::USER_CREATED, url, user.id) }

  let(:url) { 'https://webhook.site' }
  let(:user) { Oleg.create(:user) }

  describe 'http headers' do
    before do
      stub_request(:post, 'https://webhook.site')
        .with(body: {
          id: user.id,
          name: user.name,
          email: user.email,
          custom_fields: Zapier::CustomFieldsPresenter.new(user).to_h,
          event: 'user_created'
        }.to_json,
              headers: { 'Accept' => 'application/json', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
        .to_return(status: 200, body: '', headers: {})
    end

    it 'send webhook with correct json header' do
      expect(subject.send.request.options).to include(headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' })
    end
  end

  describe 'user_updated webhook' do
    let!(:user) { Oleg.create(:user) }

    it 'returns correct json' do
      expect(
        described_class.new(WebhookCodes::USER_UPDATED, user.store_id, user.id).body
      ).to eq({
        id: user.id,
        changes: {
          name: user.name,
          email: user.email,
          subscription_status: user.subscription_status,
          lifetime_spent: Money.new(user.lifetime_spent, user.store.currency).format,
          bounced_email: user.bounced_email
        }.merge(Zapier::CustomFieldsPresenter.new(user).to_h),
        event: 'user_updated'
      })
    end
  end
end

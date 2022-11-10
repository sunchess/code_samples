require 'rails_helper'

describe Videos::ExplicitContentWorker do
  subject(:worker) { described_class.new }

  let(:owner) { Oleg.create(:user_owner) }
  let(:store) { owner.store }
  let(:video) { Oleg.create(:video, :with_duration, store: store) }

  before do
    allow_any_instance_of(Video).to receive(:check_for_explicit_content).and_return(false)
  end

  it 'invokes checking' do
    expect_any_instance_of(Video).to receive(:check_for_explicit_content)
    worker.perform(video.id)
  end

  context 'when DO_NOT_RUN_EXPLICIT_CONTENT_CHECKING is present' do
    before do
      stub_const('ENV', ENV.to_hash.merge('DO_NOT_RUN_EXPLICIT_CONTENT_CHECKING' => 'true'))
    end

    it 'skips the checking' do
      expect_any_instance_of(Video).to_not receive(:check_for_explicit_content)
      worker.perform(video.id)
    end
  end
end

require 'rails_helper'

describe Videos::Frame do
  subject(:frame) { described_class.new(video) }

  let(:video) { Oleg.create(:video, :with_duration) }
  let(:frames) { frame.where(seconds: [10, 20]) }

  describe '#where' do
    let(:urls) { frames.urls }

    it 'assignees @urls' do
      expect(urls[0]).to match(%r{https://image\.mux\.com/[^/]+/thumbnail\.png\?time=10})
      expect(urls[1]).to match(%r{https://image\.mux\.com/[^/]+/thumbnail\.png\?time=20})
    end

    context 'when video source_type is not :upload' do
      let(:video) { Oleg.create(:video, source_type: :stream) }

      it 'raises an error' do
        expect { frame.where }.to raise_error('Frames are not available')
      end
    end
  end

  describe '#load' do
    before do
      allow_any_instance_of(described_class).to receive(:open_image).and_return(Tempfile.new('foo'))
    end

    it 'loads images' do
      expect_any_instance_of(described_class).to receive(:open_image).twice
      frames.load
    end

    it 'returns value by seconds' do
      expect(frames.load.count).to eq(2)
    end
  end
end

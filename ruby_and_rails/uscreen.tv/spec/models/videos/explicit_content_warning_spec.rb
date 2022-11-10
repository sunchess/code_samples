require 'rails_helper'
require 'google/cloud/vision/v1'

describe Videos::ExplicitContentWarning do
  subject(:checker) { described_class.new(content) }

  let(:content) { Oleg.create(:video, :with_duration) }

  include_examples 'stub google vision api'

  describe '#detect' do
    before do
      allow_any_instance_of(Google::Cloud::Vision::V1::ImageAnnotator::Client).to receive(:safe_search_detection).and_return(
        batch_annotate_image_response
      )
    end

    context 'when content duration is not present' do
      let(:content) { Oleg.create(:video) }

      it 'returns false' do
        expect(checker.detect).to be_falsy
      end
    end

    context 'when content is not video' do
      let(:content) { Oleg.create(:content_collection) }

      it 'returns false' do
        expect(checker.detect).to be_falsy
      end
    end

    context 'when explicit content is NOT detected' do
      let(:adult_sign) { :VERY_UNLIKELY }

      it 'returns true' do
        expect(checker.detect).to be_falsy
      end
    end

    context 'when explicit content is detected' do
      let(:adult_sign) { :VERY_LIKELY }

      it 'returns true' do
        expect(checker.detect).to be_truthy
      end
    end
  end

  describe '#notify!' do
    it 'invokes ExplicitContentSlackNotifierWorker' do
      expect { checker.notify! }
        .to enqueue_sidekiq_job(Videos::ExplicitContentSlackNotifierWorker)
        .with(content.id, anything)
    end
  end
end

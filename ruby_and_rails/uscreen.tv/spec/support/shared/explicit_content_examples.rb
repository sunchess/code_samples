require 'google/cloud/vision/v1'

RSpec.shared_context 'stub google vision api' do
  let(:adult_sign) { :UNLIKELY }

  let(:safe_search_annotation) {
    Google::Cloud::Vision::V1::SafeSearchAnnotation
      .new(adult: adult_sign,
           spoof: :VERY_UNLIKELY,
           medical: :VERY_UNLIKELY,
           violence: :VERY_UNLIKELY,
           racy: :UNLIKELY,
           adult_confidence: 0.0,
           spoof_confidence: 0.0,
           medical_confidence: 0.0,
           violence_confidence: 0.0,
           racy_confidence: 0.0,
           nsfw_confidence: 0.0)
  }

  let(:image_response) {
    Google::Cloud::Vision::V1::AnnotateImageResponse.new(
      safe_search_annotation: safe_search_annotation
    )
  }

  let(:batch_annotate_image_response) {
    Google::Cloud::Vision::V1::BatchAnnotateImagesResponse.new(
      responses: [image_response]
    )
  }

  before do
    allow_any_instance_of(Videos::Frame).to receive(:open_image).and_return(Tempfile.new('foo'))
  end
end

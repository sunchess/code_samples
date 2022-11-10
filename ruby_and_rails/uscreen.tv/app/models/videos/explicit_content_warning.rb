require 'google/cloud/vision'
require 'open-uri'

module Videos
  class ExplicitContentWarning
    DETECTION_ATTEMPTS = 3

    def initialize(video)
      @video = video
      @client = Google::Cloud::Vision.image_annotator do |config|
        config.credentials = Rails.configuration.google_api_key
      end
    end

    def detect
      return false unless @video.duration
      detection_results.include?(:VERY_LIKELY)
    end

    def notify!
      Videos::ExplicitContentSlackNotifierWorker.perform_async(@video.id, frames.urls)
    end

    private

    def detection_results
      @detection_results ||= begin
        detection = @client.safe_search_detection(images: frames.load)
        detection.responses.map do |r|
          r.safe_search_annotation.adult
        end.uniq
      end
    end

    def frames
      @video.frames.where(seconds: seconds)
    end

    def seconds
      (1..DETECTION_ATTEMPTS).to_a.map { |attempt| averaged_timeframe * attempt }
    end

    # + 1 means to get frames from the middle of a video timing
    def averaged_timeframe
      @video.duration / (DETECTION_ATTEMPTS + 1)
    end
  end
end

module Videos
  class Frame
    attr_reader :urls

    def initialize(video)
      @video = video
    end

    def where(seconds: [])
      raise 'Frames are not available' unless available?
      return if seconds.empty?

      @urls = seconds.map { |sec| url(sec) }

      self
    end

    def load
      @urls.map { |frame_url| open_image(frame_url) }
    end

    def available?
      @video.source_upload? && @video.sources['playback_id']
    end

    private

    # There is an ability to pass image urls to google client
    # but after a few tests I faced that mux has a limitation on
    # asynchronous requests from one IP, it returns error
    # pretty often, so I decided to add that functionality to avoid the case
    # rubocop:disable Security/Open
    def open_image(url)
      retries ||= 0
      URI.open(url, read_timeout: 30)
    rescue
      retry if (retries += 1) < 3
    end
    # rubocop:enable Security/Open

    def url(time)
      "https://image.mux.com/#{@video.sources['playback_id']}/thumbnail.png?time=#{time}"
    end
  end
end

module Videos
  class ExplicitContentWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'low', retry: 5

    def perform(id)
      # use the ENV variable to skip the checking and keep google query units e.g. on the staging server
      return if ENV['DO_NOT_RUN_EXPLICIT_CONTENT_CHECKING'].presence
      video = Video.find(id)
      video.check_for_explicit_content
    end
  end
end

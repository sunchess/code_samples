class Video < Content
  after_commit :check_for_explicit_content, on: :create

  # `has` is internal lib that just adds code like below
  #
  # def entity
  #   @entity ||= Models::Entity.new(self)
  # end
  has :frames, class_name: 'Videos::Frame'
  has :explicit_content_warning

  private

  def check_for_explicit_content
    return if store.skip_checking_for_explicit_content? || !frames.available?
    explicit_content_warning.notify! if explicit_content_warning.detect
  end

  def perform_async_checking_for_explicit_content
    Videos::ExplicitContentWorker.perform_async(id)
  end
end

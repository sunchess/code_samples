require Rails.root.join "lib/paperclip_long_filename_patch.rb"

class Submission < ActiveRecord::Base
  include Concerns::RankingConcerns
  include ActionView::Helpers::NumberHelper
  include Concerns::PusherConcerns

  HOURS_TRESHOLD = 168
  COUNT_TRESHOLD = 50

  attr_accessor :pic_uuid
  attr_accessor :pic_url
  attr_accessor :custom_tag
  attr_accessor :content #for errors

  before_create :set_image_url
  before_create :set_avatar_url

  has_many :notifications, dependent: :destroy
  has_many :comments, as: :commentable

  store_methods :pic_aspect_ratio, :orientation, :category

  make_flaggable
  acts_as_paranoid
  acts_as_taggable

  alias_method :topic_list, :tag_list
  validates :topic_list, length: {
    minimum: 1, too_short: "should have at least one Topic",
    maximum: 5, too_long: "should have at most 5 Topics"
  }


  validate :url, :not_banned, if: :url?

  validate :content_present

  def content_present
    if url.blank? and description.blank? and pic.blank? and youtube_local_name.blank?
      errors.add(:content, 'should be present')
    end
  end

  belongs_to :user

  has_attached_file :pic,
    #styles: { large: "700>", thumb: "280>", large_jpg: ["700>", :jpg], thumb_jpg: ["280>", :jpg]},
    styles: {
      large: {geometry: "700>", animated: false},
      thumb: {geometry: "280>", animated: false},
      #large_jpg: {geometry: "700>", format: :jpg, animated: false},
      #thumb_jpg: {geometry: "280>", format: :jpg, animated: false}
    },
    default_url: -> (pic) { pic.instance.youtube_id? ? pic.instance.youtube_video.likely_image_url : ''},
    escape_url: false,
    convert_options: { all: "-strip"}
  process_in_background :pic, processing_image_url: :processing_image_fallback unless Rails.env.test?

  validates_attachment_content_type :pic, content_type: [/\Aimage\/.*\Z/, 'application/octet-stream']  # octet-stream is needed to load previews from some servers

  validates_attachment_size :pic, less_than: 30.megabytes

  after_save :add_to_submission_recommender!, if: :url_changed?
  after_destroy :remove_from_submission_recommender!

  after_save   :set_spot_score!, if: :spot?
  after_create :update_score!, unless: :spot?
  after_update :update_score!, if: :tacks_changed?
  after_destroy :update_score!

  after_create :remove_follows_cache
  after_update :remove_follows_cache, if: :tacks_changed?
  after_destroy :remove_follows_cache

  #TODO we don't need this, delete later
  # after_update :update_weighted_score!, if: :tacks_changed?
  after_update :notification_after_10_or_50_tacks, if: :tacks_changed?
  before_save :normalize_fields
  after_save :after_pic_updated, if: :pic_updated_at_changed?  # no, after_ and before_update won't work
  after_create :owner_tack, :delete_cache_by_sort

  after_update  :delete_tags_name_cache
  after_destroy :delete_cache_by_sort, :delete_tags_name_cache

  after_save :set_cache_store
  after_touch :set_cache_store


  before_save :clean_tags

  def clean_tags
    self.tag_list = self.tag_list.map{|tag| tag.gsub(/[^-a-zA-Z0-9\']/, ' ').gsub('_', ' ').gsub(/\s+/, ' ')}
  end

  scope :top, ->{order(tacks: :desc)}
  #scope :best, ->{where("submissions.tacks >= ? OR spot=true", TACKS_TRESHOLD).order({score: :desc})}
  scope :best, ->{where("submissions.flaggings_count < submissions.tacks").order({score: :desc, created_at: :desc})}
  #scope :ordered_new, ->{order(created_at: :desc, id: :desc).where(spot: false)}
  scope :ordered_new, ->{order(created_at: :desc)}
  scope :not_spot, ->{where(spot: false)}
  #scope :hourly, ->{where(["submissions.created_at > ?", Time.now - HOURS_TRESHOLD.hours])}

  #The scope for submissions newer than HOURS_TRESHOLD but at least COUNT_TRESHOLD submissions
  scope :newest, ->{ordered_new.not_spot}
  scope :flagged, -> { where("flaggings_count > 0 AND deleted_at IS NULL") }

  def notification_after_10_or_50_tacks
    NotificationAfterTacksJob.perform_later(self) if self.tacks == 10 or self.tacks == 50
  end

  def add_to_submission_recommender!
    SubmissionRecommender.instance.add_to_matrix!(:domains, source_hostname, id) if source_hostname
  end

  def remove_from_submission_recommender!
    SubmissionRecommender.instance.delete_item!(id)
  end

  def self.followed_for(user)
    tagged_with(user.following_tags, any: true)
  end

  def self.spot
    where(spot: true).take
  end

  def self.look_for query, params = {}
    if query.present?
      query = [query].flatten.join("* ")
      submission_ids = Submission.search_for_ids(query, params)
      Submission.where(id: submission_ids)
    else
      Submission
    end
  end

  def self.pluck_fields params = {}
    self.includes(:user).page(params[:page])
        .per(params[:per_page])
        .pluck(:tacks, :published_comments_count, :cache_store, "users.avatar_url", "users.normalized_name")
  end

  def pusher_hash
    {id => [score, tacks]}
  end

  def pusher_user_tacks
    { user_id: self.user_id, tacks_count: self.user.tacks_count, pluralize_tacks: "#{number_with_delimiter(self.user.tacks_count)} #{ 'Tack'.pluralize(self.user.tacks_count) }" }
  end

  def orientation
    return nil unless pic.present?
    Paperclip::Geometry.from_file(pic.path).orientation
  end

  def pic_aspect_ratio
    return nil unless pic.present?
    geometry = Paperclip::Geometry.from_file(pic.path)
    geometry.auto_orient
    geometry.aspect
  end

  def pic_height_percentage
    return nil unless pic.present?

    min = 10
    default = 66.7

    return default  unless pic.present? && File.exist?(pic.path)

    real = 100.0 / pic_aspect_ratio

    return real < min ? min : real
  end

  def source_url
    if youtube_id?
      youtube_video.watch_url
    elsif url?
      url
    else
      pic.url
    end
  end

  def video?
    youtube_id? || video_embed_url?
  end

  def facebook_video?
    url['//www.facebook.com/'] && (url['/videos/'] || url['/video.php?v=']) != nil
  end

  def media_category
    return 'video'  if video?
    return 'image'  if pic.present?
    return 'text'
  end

  def embed_url
    return  unless video?

    url = Addressable::URI.parse(video_embed_url.presence || youtube_video.embed_url)
    url.query_values = (url.query_values || {}).merge("autoplay" => 0)
    url.to_s
  end

  def source_hostname
    Addressable::URI.parse(source_url).host
  rescue Addressable::URI::InvalidURIError
    nil
  end

  def caption_or_hostname
    caption.presence || source_hostname
  end

  # (among other things) using this to share in fb / twitter / etc
  def to_s
    caption.presence || description.presence || "#{media_category.capitalize} from #{source_hostname || Rails.application.secrets.host}"
  end

  def image_url(style = :thumb)
    return pic.url if pic_content_type.in?(%w[image/gif])
    return pic.url(style)
  end

  def avatar_url
    user ? user.avatar_url : "anonymous.png"
  end

  def tacked_by?(tacker, possibly_anonymous_avatar_url = nil)
    # return avatar_url == possibly_anonymous_avatar_url  if possibly_anonymous_avatar_url
    return tacker.tacked?(self)  if tacker
    return false
  end

  # Commentable methods
  def commentable_title
    caption.presence || description.to_s[0..64].presence || "Untitled submission ##{id}"
  end

  def commentable_url
    "/submissions/#{id}"
  end

  def commentable_state
    "published"
  end

  # Callbacks for OurYoutube {

  def youtube_video
    @youtube_video ||= OurYoutube::Video.new(self)
  end

  def youtube_tmp_file
    '/tmp/tacked_uploads/' + youtube_local_name  if youtube_local_name?
  end

  def youtube_orig_name
    Upload.orig_name_of(youtube_local_name)  if youtube_local_name?
  end

  def update_youtube_image!
    self.pic = youtube_video.image
  end

  def params_for_youtube
    {
      title: caption,
      description: "Tacked",
      keywords: "",
      category: 'Film',
      list: 'denied'
    }
  end

  #cache methods below
  #cache comments
  #delete cache in app/models/comment.rb update_submission_comments_cache
  def published_comments_cache(reload: false)
    #when reload
    Rails.cache.fetch("/submissions/comments/#{self.id}-#{self.updated_at.to_i}", force: reload) do
      self.comments.published_root.order(:id).to_a
    end
  end

  #cache tags name
  def tag_names_cache(reload: false)
    Rails.cache.fetch("/submissions/tag_name/#{self.id}-#{self.updated_at.to_i}", force: reload) do
      self.tags.pluck(:name)
    end
  end

  #cache for all user followings submissions
  def self.following_for_user(user, page, per_page)
    Rails.cache.fetch("/user/#{user.id}-#{user.updated_at.to_i}/following_for_user/#{page}/#{per_page}") do
      tags_submissions = self.followed_for(user)
      user_submissions = self.where(user: user.followings_cache.map(&:id))
      self.order("score DESC NULLS LAST").where.any_of(tags_submissions, user_submissions).uniq.page(page).per(per_page).includes(:user, :tags).to_a
    end
  end

  #delete cache tag names
  def delete_tags_name_cache
    Rails.cache.delete_matched("/submissions/tag_name/#{self.id}-*")
  end

  #cache submissions by sorting
  def self.cache_by_sort(sort, page, per_page)
    #make actual cache
    Rails.cache.fetch("/submissions/sort/#{sort}/#{page}/#{per_page}") do
      self.send(sort).page(page).per(per_page).to_a
    end
  end

  #clear cache for scope
  def delete_cache_by_sort
    Rails.cache.delete_matched("/submissions/sort/*")
    Rails.cache.delete_matched("controller/submissions/*")
  end

  #remove cache for users which followed the submission user or tags
  def remove_follows_cache
    Rails.logger.debug('Delete follow cache')
    FollowCacheCleanerJob.perform_later(self.user, self.topic_list)
  end

  def caption_or_subdescription
    return caption if caption.presents
    description.truncate(100, omission: '')
  end

  def camel_caption
    to_s.truncate(100, omission: '').try(:gsub, /[^\w\d]/, "-")
  end

  def recalculate_comments_counters!
    self.update_column(:published_comments_count, self.comments.published.count)
  end

  protected
  def owner_tack
    self.user.store_tack_for(self, increment: false) if self.user
  end

  def not_banned
    host = URI.parse(url.strip).host
    errors.add(:base, "#{host} domain is banned") if BannedSite.pluck(:domain).select{|banned| host =~ /#{banned.gsub(".", '\.')}$/}.any?
  end

  def normalize_fields
    self.description = description.strip.truncate(4096)  if description?
    self.caption = caption.strip.truncate(200)  if caption?
    self.url.strip!  if url?
  end

  def after_pic_updated
    return  if new_record? || pic.blank?
    refresh_pic_aspect_ratio  # defined in the store_method gem
  end

  def set_image_url
    self.image_url = "/images/default_backgrounds/#{rand(4)+1}.png" if !self.image_url && self.category != "text"
  end

  def processing_image_fallback
    options = pic.options
    options[:interpolator].interpolate(options[:url], pic, :original)
  end

  def set_avatar_url
    self.avatar_url = self.user.avatar_url unless self.avatar_url
  end

  def set_cache_store
    if (!self.tacks_changed? && !self.published_comments_count_changed?) || self.just_created?
      cache_store = SubmissionSerializer.new(self, root: false).as_json
      self.update_column(:cache_store, cache_store)
    end
  end

  def just_created?
    self.created_at == self.updated_at
  end
end

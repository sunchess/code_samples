class Comment < ActiveRecord::Base
  include AASM

  #for angular show in mobile comment when is added
  attr_accessor :focused

  JSON_PER_PAGE = 5

  include ActionView::Helpers::TextHelper

  store_method :avatar_url
  make_flaggable

  belongs_to :user
  belongs_to :commentable, polymorphic: true


  after_update :update_score!, :if => :needs_new_score?
  # after_create :add_to_submission_recommender

  after_create :update_submission_comments_cache
  after_destroy :update_submission_comments_cache

  after_create :send_notification
  before_save   :prepare_content
  after_save :save_user_counters
  after_save :save_commentable_counters

  scope :flagged, -> { where("flaggings_count > 0  AND state != 'deleted'") }
  scope :published_root, ->{where(parent_id: nil, state: 'published')}

  validates_presence_of :raw_content

  aasm :column => :state do
    state :published, :initial => true
    state :spamed
    state :deleted

    event :delete do
      transitions :from => [:spamed, :published], :to => :deleted
    end

    event :spam do
      transitions :from => :published, :to => :spamed
    end

    event :publish do
      transitions :from => [ :deleted, :spamed ], :to => :published
    end
  end

  def save_user_counters
    return unless user
    user.update_column(:published_comments_count, user.comments.published.count)
  end

  def save_commentable_counters
    commentable.recalculate_comments_counters!
  end

  # def add_to_submission_recommender
  #   SubmissionRecommender.instance.add_to_matrix!(:comments, "user-#{user.id}", commentable_id)
  # end

  def needs_new_score?
    tacks_changed? || flaggings_count_changed?
  end

  def send_notification
    #TODO: think how to make one query for this below
    NormalizeService.get_names(raw_content).each do |name|
      if user = User.find_by(normalized_name: NormalizeService.normalize_name(name))
        Notification.mention!(user, self)
      end
    end

    Notification.commented!(self)
    #Notification.replied!(@comment)
  end


  # calculate lower bound of Wilson score confidence interval for a Bernoulli parameter
  # http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
  def score
    pos = tacks
    n = tacks + flaggings_count
    return 0 if n == 0
    z = 1.96 # confidence level of 0.95
    phat = 1.0*pos/n
    (phat + z*z/(2*n) - z * Math.sqrt((phat*(1-phat)+z*z/(4*n))/n))/(1+z*z/n)
  end

  # calculate score only for the top level comments
  def update_score!
    update_column(:score, score) #if parent.nil?
    self.user.save_tacks_count! if self.user
  end

  #clear old cache
  def update_submission_comments_cache
    Rails.cache.delete_matched("/submissions/comments/#{self.commentable.id}-*") if self.commentable.is_a?(Submission)
  end

  public
  # ---------------------------------------------------
  # Define comment's avatar url
  # Usually we use Comment#user (owner of comment) to define avatar
  # @blog.comments.includes(:user) <= use includes(:user) to decrease queries count
  # comment#user.avatar_url
  # ---------------------------------------------------
  def avatar_url
    user ? user.avatar_url : "anonymous.png"
  end

  def prepare_content
    text = self.raw_content
    text = RedCloth.new(text).to_html
    text = Sanitize.clean(text, Sanitize::Config::RELAXED)
    self.content = auto_link(text, html: {rel: "nofollow", target: '_blank'})

    #TODO: think how to make one query for this below
    NormalizeService.get_names(raw_content).each do |name|
      if user = User.find_by(normalized_name: NormalizeService.normalize_name(name))
        self.content = self.content.gsub!(name, ActionController::Base.helpers.link_to(name, Rails.application.routes.url_helpers.user_page_path(user: user.name)))
      end
    end
  end
end

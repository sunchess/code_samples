class SubmissionsController < ApplicationController
  include UserSubmissionConcern
  include SubmissionsFilterConcern

  before_action :set_search_params, only: [:index, :user, :tag]
  before_action :check_order, only: [:index, :users, :tags]
  before_action :set_user_and_tag, only: [:follow, :unfollow]
  before_action :set_submission, only: [:show, :upload, :comments, :edit, :update, :tack, :thumb, :flag, :destroy, :get_customs]
  before_action :check_user, only: [:edit, :update, :destroy]
  before_action :check_admin, only: [:edit, :update]

  def index
    @sort_submissions = params[:page]

    respond_to do |format|
      format.html{
        if params[:page] and Filter.check_scope(params[:page])
          not_found unless current_user
        end
      }
      format.json{
        @submissions = Submission.look_for(params[:query])
        @submissions = Filter.new(@submissions).with(current_user).select_for(params[:sort])
        not_found if @submissions.nil?
        @submissions = @submissions.tagged_with(params[:tag]) if params[:tag]

        render json: dump(@submissions.pluck_fields(params))
      }
    end
  end

  def tag
    @tag = ActsAsTaggableOn::Tag.find_by("lower(?) = lower(name)", params[:tag].gsub("_", " "))
    respond_to do |format|
      format.html
      format.json{
        @submissions = Submission
        @submissions = Filter.new(@submissions).with(current_user).select_for(params[:sort])
        @submissions = @submissions.tagged_with(params[:tag].gsub("_", " "))

        render json: dump(@submissions.pluck_fields(params))
      }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json {
        Notification.seen_submission!(@submission, looker: current_user)  if signed_in?
        render json: @submission
      }
    end
  end

  def comments
    respond_to do |format|
      format.html
      format.json {
        @comments = @submission.comments.published.order(:id)
        render json: @comments
      }
    end
  end

  def new
  end

  def spot
    redirect_to root_path and return unless user_signed_in? && current_user.admin?
    redirect_to edit_submission_path(Submission.spot) and return if Submission.spot
    @submission = Submission.new(spot: true)
    respond_to do |format|
      format.html
      format.json {
        render json: @submission
      }
    end
  end

  def edit
    respond_to do |format|
      format.html
      format.json {
        render json: @submission
      }
    end
  end

  def tack
    if signed_in?
      current_user.store_tack_for(@submission) unless @submission.try(:user) == current_user
    else
      @submission.increment!(:tacks)
    end

    respond_to do |format|
      format.json {
        render json: @submission.reload.as_json(only: [:tacks])
      }
    end
  end

  def create
    @submission = Submission.new(submission_params)
    @submission.spot = false unless user_signed_in? && current_user.admin? # ensure that only admins can create Spot
    @submission.tacks = 1
    @submission.user = current_user

    @submission.ip = request.ip
    @submission.user_agent = request.user_agent
    attacher = attach_upload(@submission, :pic, youtubeable: true)
    @submission.pic = URI.parse(@submission.pic_url.strip)  if @submission.pic_url.present?

    # TODO: We must reconsider our approach
    if !params[:submission][:suggested_tags] && params[:submission][:tags]
      params[:submission][:suggested_tags] ||= params[:submission][:tags].map {|tag| tag[:id].to_s || tag[:name]}
    end

    @submission.tag_list = TagService.extract(params)

    session[:amnotbot] ||= verify_recaptcha(model: @submission, attribute: 'ReCaptcha', message: 'validation is failed')

    if signed_in? or session[:amnotbot]
      if @submission.save
        @submission.youtube_video.upload!  if attacher.youtubeable?

        render json: {submission: @submission}
      else
        render json: {msg: @submission.errors.full_messages.join(", ")}, status: 422
      end
    else
      render json: {msg: "ReCaptcha validation is failed"}, status: 422
    end
  end

  def update
    respond_to do |format|
      format.json {

        @submission.attributes = submission_params

        attacher = attach_upload(@submission, :pic, youtubeable: true)
        @submission.pic = open(@submission.pic_url.strip)  if @submission.pic_url.present?
        @submission.tag_list = params[:submission][:suggested_tags] if params[:submission][:suggested_tags]
        @submission.tag_list = [] if @submission.spot? and !params[:submission][:suggested_tags]

        if @submission.save(validate: !@submission.spot?)
          if current_user.admin?
            @submission.youtube_video.upload!  if attacher.youtubeable?
          end
          render json: {msg: "Submission successfully updated", redirect_to: "submission_path", redirect_options: {id: @submission.id}}
        else
          render json: {msg: @submission.errors.full_messages.join(', ')}, status: 422
        end

      }
    end

  end

  def flag
    respond_to do |format|
      format.json {
        signed_in? ? current_user.flag(@submission, params[:reason]) : MakeFlaggable::Flagging.create!(flaggable: @submission, reason: params[:reason])
        render json: {msg: "Thank you for your response"}
      }
    end
  end

  def destroy
    if (current_user.admin? and params[:permanently] == 'true') or current_user == @submission.user
      @submission.destroy
    else
      current_user.block_submission!(@submission)
    end

    render json: {msg: "Submission successfully deleted"}
  end

  def upload
    respond_to do |format|
      format.json {
        @submission.update(pic: params[:attachments][0])
        render json: [@submission.pic.url]
      }
    end
  end

  def created
    respond_to do |format|
      format.html
    end
  end

  def similar
    respond_to do |format|
      format.html
      format.json{
        ids = SubmissionRecommender.instance.similarities_for(params[:id])
        @submissions = Submission.where(id: ids).order("POSITION(' ' || submissions.id::TEXT || ' ' IN ' #{ids.map{|id| " #{id} "}.join} ')")  # where(id: ids) doesn't preserve order, see http://stackoverflow.com/questions/1680627
        render json: dump(@submissions.pluck_fields(params))
      }
    end
  end

  def tacks_count
    respond_to do |format|
      format.json {
        @tacks = Submission.where(id: params[:id]).pluck(:id, :tacks)
        @tacks = @tacks.map{|tack| {id: tack[0], tacks: tack[1]}}.index_by{|tack| tack[:id]}
        render json: @tacks
      }
    end
  end

  private
    def set_search_params
      if request.format == 'json'
        params[:page] = params[:page].to_i
        params[:per_page] ||= 20
      end

      params[:sort] ||= "best"
    end

    def set_user_and_tag
      @tag = ActsAsTaggableOn::Tag.find_by(name: params[:tag])  if params[:tag]
      @user = User.find_by(normalized_name: params[:user])      if params[:user]
    end

    def submission_params
      params.require(:submission).permit(:caption, :description, :category, :session_id, :ip, :url, :video_embed_url, :pic_uuid, :pic_url, :custom_tag, :spot, :pic)
        .merge({
          url: (params[:submission][:url].match(/https?:\/\//).present? ? params[:submission][:url] : "http://#{params[:submission][:url]}" rescue nil)
        })
    end

    def set_submission
      @submission = Submission.find(params[:id])
    end

    def check_order
      return not_found unless Filter.agree?(params[:sort])
      render json: {redirect_to: "new_user_session_path"} and return if !signed_in? && params[:sort] == "following"
    end

    def check_admin
      redirect_to(root_path, notice: 'Not authorized') and return unless current_user.try(:admin?)
    end
end

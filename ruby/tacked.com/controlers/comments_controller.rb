class CommentsController < ApplicationController
  layout 'admin'

  # Define your restrict methods and use them like this:
  before_action :check_user,  except: %w[index flag tack get_more create_by_json]
  before_action :require_admin, except: %w[index create flag tack get_more create_by_json]


  # preparation
  before_action :define_commentable, only: [:create, :create_by_json]
  before_action :set_comment, only: [:tack, :flag, :destroy, :get_more, :update]

  def flag
    respond_to do |format|
      format.json {
        signed_in? ? current_user.flag(@comment, params[:reason]) : MakeFlaggable::Flagging.create!(flaggable: @comment, reason: params[:reason])
        render json: {msg: "Thank you for your response"}
      }
    end
  end

  def flagged
    @comments = ::Comment.flagged.with_users.order("flaggings_count DESC").page(params[:page])
    render comment_template(:manage)
  end

  def tack
    respond_to do |format|
      format.json {
        if signed_in?
          current_user.store_tack_for(@comment)
        else
          @comment.increment!(:tacks)
        end

        render json: {}
      }
    end
  end

  def destroy
    respond_to do |format|
      format.json {
        @commentable = @comment.commentable
        @comment.destroy if current_user.admin?
        @commentable.recalculate_comments_counters!

        render json: {}
      }
    end
  end

  def create
    respond_to do |format|
      format.json {
        @comment = @commentable.comments.new comment_params
        if @comment.save
          @comment.focused = true
          render json: @comment
        else
          render json: { msg: @comment.errors.full_messages.join(', ') }, status: 422
        end
      }
    end
  end

  def get_more
    respond_to do |format|
      format.json {
        submission = Submission.find(params[:submission_id])
        comments = Kaminari.paginate_array(submission.published_comments_cache).page(params[:page]).per(Comment::JSON_PER_PAGE)
        render json: comments
      }
    end
  end

  def update
    if @comment.update_attribute(:raw_content, params[:raw_content])
      render json: @comment.reload
    else
      render json: { msg: @comment.reload.errors.full_messages.join(', ') }, status: 422
    end
  end

  def destroy
    @commentable = @comment.commentable
    @comment.delete! if current_user.admin?
    if @comment.deleted?
      render json: @comment.reload
    else
      render json: { msg: @comment.reload.errors.full_messages.join(', ') }, status: 422
    end
  end

  private

  def require_admin
    unless current_user.try(:admin?)
      flash[:error] = 'Access denied'
      redirect_to( root_path )
    end
  end

  def set_comment
    @comment = Comment.find(params[:id])
  end

  def define_commentable
    comment = params[:comment]
    commentable_class = comment[:commentable_type].constantize
    @commentable = commentable_class.find(comment[:commentable_id])
  end

  def comment_params
    params
    .require(:comment)
    .permit(:raw_content)
    .merge(user: current_user, commentable: @commentable)
  end

end

class CommentSerializer < ActiveModel::Serializer
  attributes *(Comment.attribute_names - []), :avatar_url, :can_flag, :focused, :is_tacked, :tacks, :h_date, :raw_content

  #has_many :children, serializer: CommentSerializer
  has_one :user

  def content
    object.content.html_safe
  end

  def can_flag
    scope.try(:current_user).nil? || !scope.try(:current_user).flagged_comment?(object)
  end

  def is_tacked
    if scope.current_user
      scope.current_user.tacked?(object) or scope.current_user.id == object.user.try(:id)
    else
      (scope.cookies["tacks.comment"] || []).index(object.id.to_s)
    end
  end

  def h_date
    I18n.l(object.created_at)
  end

  def children
    object.children.where(state: :published).order(:id)
  end
end

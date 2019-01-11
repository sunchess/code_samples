class SubmissionSerializer < ActiveModel::Serializer
  attributes :id, :created_at, :spot, :caption, :to_s, :tacks, :description, :url, :avatar_url, :category, :pic, :video, :pic_height_percentage, :large_image_url, :thumb_image_url, :source_hostname, :source_url, :mode, :tag_list, :class_name, :large_static_gif_url, :thumb_static_gif_url, :gif, :user_id, :user, :tags, :camel_caption, :total_height, :type, :published_comments_count

  # has_one :user, serializer: UserSerializer
  def type
    if object.spot?
      "spot"
    else
      "submission"
    end
  end

  def class_name
    object.class.to_s
  end

  def to_s
    object.to_s
  end

  def video
    object.video?
  end

  def gif
    object.pic_content_type.in?(%w[image/gif])
  end

  def large_image_url
    object.image_url(:large)
  end

  def thumb_image_url
    object.image_url(:thumb)
  end

  def large_static_gif_url
    object.pic.url(:large)
  end

  def thumb_static_gif_url
    object.pic.url(:thumb)
  end

  def mode
    object.class.name.underscore.dasherize
  end

  def tag_list
    object.tag_names_cache
  end

  def tags
    object.tags.map {|tag| {name: tag.name, type: "tag", normalized_name: tag.name.downcase.gsub(" ", "_")}}
  end

  def user
    object.user.attributes.slice("id", "name", "normalized_name") rescue "anonim"
  end

  def total_height
    total = if object.pic_height_percentage
      object.pic_height_percentage/100
    else
      0.75
    end

    # total = 0.75 if total == 1

    total * 258
  end
end

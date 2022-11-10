class WebhookService
  def initialize(code, link, item_id, options = {})
    @code, @link, @item_id, @options = code, link, item_id, options
  end

  def send
    HTTParty.post(@link, body: body.to_json, timeout: 5,
                         headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' })
  rescue HTTParty::Error => e
    ExceptionLogger.log(e)
    nil
  end

  def body
    case @code
    when WebhookCodes::USER_CREATED, WebhookCodes::USER_SIGNED_IN, WebhookCodes::PAYMENT_METHOD_UPDATED
      user_body
    when ::WebhookCodes::USER_UPDATED
      user_updated
    when ::WebhookCodes::ORDER_PAID
      order_body
    when ::WebhookCodes::SUBSCRIPTION_CANCELED
      subscription_body
    when ::WebhookCodes::SUCCESS_RECURRING
      subscription_body
    when WebhookCodes::VIDEO_PLAY
      video_body
    when WebhookCodes::ADDED_TO_FAVORITES
      added_to_favorites_body
    when WebhookCodes::INVOICE_OVERDUE
      overdue_invoice_body
    when WebhookCodes::OWNERSHIP_CREATED
      subscription_body.merge(event_date: Time.zone.today)
    else
      {}
    end.merge(event: @code)
  end

  private

  def user_body
    user = User.find(@item_id)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      custom_fields: Zapier::CustomFieldsPresenter.new(user).to_h
    }
  end

  def user_updated
    user = User.find(@item_id)

    {
      id: user.id,
      changes: {
        name: user.name,
        email: user.email,
        subscription_status: user.subscription_status,
        lifetime_spent: Money.new(user.lifetime_spent, user.store.currency).format,
        bounced_email: user.bounced_email
      }.merge(Zapier::CustomFieldsPresenter.new(user).to_h)
    }
  end

  def order_body
    order = Invoice.find(@item_id)
    { id: order.id, title: order.ownership.offer.title,
      total: Money.new(order.original_price, order.currency).to_s, amount: Money.new(order.final_price, order.currency).to_s,
      discount: Money.new(order.discount, order.currency).to_s,
      offer_id: order.ownership.offer.id_param,
      customer_name: order.ownership.user.name, customer_email: order.ownership.user.email }
  end

  def subscription_body
    ownership = Ownership.find(@item_id)
    { id: ownership.id,
      name: ownership.user.name,
      email: ownership.user.email,
      offer_id: ownership.offer.id_param,
      offer_title: ownership.offer.title }
  end

  def video_body
    options = @item_id.with_indifferent_access

    video = Video.find(options[:video_id])
    chapter = Chapter.find(options[:chapter_id])
    user = User.find(options[:user_id])

    { title: chapter.title, id: video.id,
      name: user.name, email: user.email,
      chapter_id: chapter.id }
  end

  def added_to_favorites_body
    options = @item_id.with_indifferent_access

    record = if options[:chapter_id]
      Chapter.find(options[:chapter_id])
    elsif options[:content_id]
      Content.find(options[:content_id])
    end

    user = User.find(options[:user_id])

    {
      title: record.title,
      id: record.id,
      name: user.name,
      email: user.email
    }
  end

  def overdue_invoice_body
    invoice = Invoice.find(@item_id)
    user = invoice.user

    { invoice_id: @item_id, user_id: invoice.user.id,
      name: user.try(:name), email: user.try(:email),
      title: invoice&.product&.title, final_price: Money.new(invoice.final_price, invoice.currency).to_f,
      offer_id: invoice.offer&.id }
  end
end

defmodule Tuskarr.Mailer do
  use Mailgun.Client,
      domain: "https://api.mailgun.net/v3/ml.dev.bz",
      key:    "key-d1c9fff7d21ddfeb245098e799cd489f",
      mode: Mix.env, # Alternatively use Mix.env while in the test environment.
      test_file_path: "/tmp/mailgun.json"

  @from "vpetrenko@gmail.com"

  def recovery_password(user) do
    send_email to: user.email,
               from: @from,
               subject: "Recovery password on Tuskarr",
               text: recovery_text(user)
               #html: welcome_html(user)
  end

  def welcome_email(user) do
    send_email to: user.email,
               from: @from,
               subject: "Welcome to Tuskarr",
               text: welcome_text(user)
               #html: welcome_html(user)
  end


  def confirm_email(user) do
    send_email to: user.email,
               from: @from,
               subject: "Confirmation email on Tuskarr",
               text: confirm_text(user)
               #html: welcome_html(user)
  end

  defp recovery_text(user) do
    """
    Recovery password token: #{user.recovery_password_token}
    """
  end

  defp welcome_text(user) do
    """
    Welcome to Tuskarr #{user.name}! #{confirm_text(user)}
    """
  end

  def confirm_text(user) do
    """
    You can confirm your email by this link: #{TuskarrWeb.Router.Helpers.confirm_user_url(TuskarrWeb.Endpoint, :confirm, token: user.confirmation_token )}
    """
  end

end

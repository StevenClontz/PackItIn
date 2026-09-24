module ApplicationHelper
  # A Money amount, e.g. $12.50, with negatives (money owed) in red.
  def money(amount)
    # Money formats a negative as "$-5.00"; write it the usual way, "-$5.00".
    text = "#{'-' if amount.negative?}#{amount.abs.format}"
    tag.span(text, class: ("text-red-600" if amount.negative?))
  end

  def format_ledger_time(time)
    time.strftime("%b %-d, %Y %-I:%M %p %Z")
  end

  # The app's display name, e.g. in the nav and page title. Override per deployment with APP_NAME.
  def app_name
    ENV.fetch("APP_NAME", "Pack It In")
  end
end

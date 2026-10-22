module ApplicationHelper
  VERDICT_LABELS = {
    "ac" => "AC",
    "wa" => "WA",
    "tle" => "TLE",
    "mle" => "MLE",
    "re" => "RE",
    "ce" => "CE",
    "ie" => "IE",
    "queued" => "Queued",
    "judging" => "Judging",
    "running" => "Judging"
  }.freeze

  def verdict_badge(verdict)
    key = verdict.to_s.downcase
    label = VERDICT_LABELS.fetch(key, key.upcase)
    content_tag(:span, label, class: "badge badge--#{key}")
  end

  def contest_status_label(status)
    status.to_s.tr("_", " ").capitalize
  end

  def nav_link_to(name, path, **options)
    active = current_page?(path)
    css = [ "site-nav__link", (active ? "site-nav__link--active" : nil) ].compact.join(" ")
    link_to name, path, class: css, **options
  end
end


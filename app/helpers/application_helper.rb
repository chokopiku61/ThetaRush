# frozen_string_literal: true

module ApplicationHelper
  KNOWN_VERDICTS = %w[ac wa tle mle re ce ie queued judging running].freeze

  LANGUAGE_LABELS = {
    "python" => "Python",
    "cpp" => "C++"
  }.freeze

  # Sidebar entries in display order. `path` is a route helper name, `auth`
  # hides the entry from guests and `admin` limits it to admin users.
  SIDEBAR_SECTIONS = [
    { key: :home, path: :root_path, icon: "home" },
    { key: :problems, path: :problems_path, icon: "problems" },
    { key: :contests, path: :contests_path, icon: "contests" },
    { key: :submissions, path: :submissions_path, icon: "submissions" },
    { key: :favorites, path: :favorites_path, icon: "favorites" },
    { key: :groups, path: :groups_path, icon: "groups" },
    { key: :profile, path: :profile_path, icon: "profile", auth: true },
    { key: :ui_kit, path: :ui_kit_path, icon: "ui_kit" },
    { key: :admin, path: :admin_root_path, icon: "admin", auth: true, admin: true }
  ].freeze

  # Stroke paths for 24x24 icons (currentColor).
  SIDEBAR_ICON_PATHS = {
    "home" => "M4 11l8-7 8 7v8a1 1 0 0 1-1 1h-5v-5H10v5H5a1 1 0 0 1-1-1v-8z",
    "problems" => "M7 4h10v16l-5-2.5L7 20V4z",
    "contests" => "M8 21h8M12 17v4M7 4h10v3l-2 2v5a3 3 0 0 1-6 0V9L7 7V4z",
    "submissions" => "M8 7h8M8 11h8M8 15h5M6 3h12v18H6V3z",
    "favorites" => "M12 4l2.2 4.5 5 .7-3.6 3.5.9 5L12 15.4 7.5 17.7l.9-5L4.8 9.2l5-.7L12 4z",
    "groups" => "M16 19v-1a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v1M17 11a3 3 0 1 0 0-6M21 19v-1a3.5 3.5 0 0 0-2.5-3.3M9.5 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6z",
    "profile" => "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM5 20a7 7 0 0 1 14 0",
    "ui_kit" => "M4 6h6v6H4V6zM14 6h6v4h-6V6zM14 14h6v4h-6v-4zM4 14h6v4H4v-4z",
    "admin" => "M12 3l8 3.5v5.5c0 4.5-3.2 7.8-8 9-4.8-1.2-8-4.5-8-9V6.5L12 3zM12 9v4M12 16h.01",
    "logout" => "M10 5H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h4M15 15l4-3-4-3M19 12H10",
    "login" => "M14 5h4a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2h-4M9 15l-4-3 4-3M5 12h9"
  }.freeze

  def verdict_badge(verdict)
    key = verdict.to_s.downcase
    label = t("verdicts.#{key}", default: key.upcase)
    content_tag(:span, label, class: "badge badge--#{key}")
  end

  def contest_status_label(status)
    key = status.to_s
    t("contests.status.#{key}", default: key.tr("_", " ").capitalize)
  end

  def nav_link_to(name, path, **options)
    css = [ "site-nav__link", (current_page?(path) ? "site-nav__link--active" : nil) ].compact.join(" ")
    link_to name, path, class: css, **options
  end

  def sidebar_link_to(label, path, icon: nil, **options)
    active = sidebar_active?(path)
    css = [ "sidebar__link", (active ? "sidebar__link--active" : nil), options.delete(:class) ].compact.join(" ")
    body = safe_join([
      content_tag(:span, sidebar_icon(icon), class: "sidebar__icon", aria: { hidden: true }),
      content_tag(:span, label, class: "sidebar__label")
    ])
    link_to body, path, class: css, aria: { current: (active ? "page" : nil), label: label }, title: label, **options
  end

  def sidebar_icon(name)
    path = SIDEBAR_ICON_PATHS[name.to_s]
    return "".html_safe if path.blank?

    tag.svg(
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": "1.75",
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      class: "sidebar__icon-svg",
      "aria-hidden": true
    ) do
      tag.path(d: path)
    end
  end

  # Entries of SIDEBAR_SECTIONS visible to the current viewer.
  def visible_sidebar_sections
    SIDEBAR_SECTIONS.select do |section|
      next false if section[:auth] && !user_signed_in?
      next false if section[:admin] && !(user_signed_in? && current_user.admin?)

      true
    end
  end

  def rating_pill_class(rating)
    tier =
      case rating.to_i
      when 0...1200 then "newbie"
      when 1200...1600 then "pupil"
      when 1600...2000 then "expert"
      when 2000...2400 then "master"
      else "grandmaster"
      end
    "rating-pill rating-pill--#{tier}"
  end

  def language_label(language)
    LANGUAGE_LABELS.fetch(language.to_s, language.to_s.upcase)
  end

  def format_memory(kb)
    return "-" if kb.nil?

    kb = kb.to_i
    if kb < 1024
      "#{kb} KB"
    else
      "#{number_with_precision(kb / 1024.0, precision: 1, strip_insignificant_zeros: true)} MB"
    end
  end

  # Compact relative age for the workspace package menu (e.g. "7m", "2h").
  def compact_ago(time)
    return "—" if time.blank?

    seconds = (Time.current - time).to_i
    return t("time.compact.now") if seconds < 60

    minutes = seconds / 60
    return t("time.compact.minutes", count: minutes) if minutes < 60

    hours = minutes / 60
    return t("time.compact.hours", count: hours) if hours < 48

    t("time.compact.days", count: hours / 24)
  end

  # Localized "13 minutes ago" / "13 минут назад" for tables.
  def time_ago_label(time)
    return "—" if time.blank?

    t("time.ago", time: time_ago_in_words(time))
  end

  def favorited?(record)
    return false unless user_signed_in?

    current_user.favorites.exists?(favoritable: record)
  end

  private

  def sidebar_active?(path)
    return current_page?(path) if path == root_path

    request.path == path || request.path.start_with?("#{path}/")
  end
end

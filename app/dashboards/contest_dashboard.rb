require "administrate/base_dashboard"

class ContestDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    contest_participations: Field::HasMany,
    contest_problems: Field::HasMany,
    description: Field::Text,
    ends_at: Field::DateTime,
    participants: Field::HasMany,
    problems: Field::HasMany,
    rating_histories: Field::HasMany,
    starts_at: Field::DateTime,
    status: Field::String,
    submissions: Field::HasMany,
    title: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    title
    status
    starts_at
    ends_at
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    contest_participations
    contest_problems
    description
    ends_at
    participants
    problems
    rating_histories
    starts_at
    status
    submissions
    title
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    title
    description
    starts_at
    ends_at
    status
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  #
  # For example to add an option to search for open resources by typing "open:"
  # in the search field:
  #
  #   COLLECTION_FILTERS = {
  #     open: ->(resources) { resources.where(open: true) }
  #   }.freeze
  COLLECTION_FILTERS = {}.freeze

  # Overwrite this method to customize how contests are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(contest)
    contest.title
  end
end

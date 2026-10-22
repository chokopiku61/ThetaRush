require "administrate/base_dashboard"

class SubmissionDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    compile_output: Field::Text,
    contest: Field::BelongsTo,
    judge0_token: Field::String,
    language: Field::String,
    memory_kb: Field::Number,
    problem: Field::BelongsTo,
    source_code: Field::Text,
    status: Field::String,
    stderr: Field::Text,
    stdout: Field::Text,
    submitted_at: Field::DateTime,
    time_ms: Field::Number,
    user: Field::BelongsTo,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    compile_output
    contest
    judge0_token
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    compile_output
    contest
    judge0_token
    language
    memory_kb
    problem
    source_code
    status
    stderr
    stdout
    submitted_at
    time_ms
    user
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    compile_output
    contest
    judge0_token
    language
    memory_kb
    problem
    source_code
    status
    stderr
    stdout
    submitted_at
    time_ms
    user
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

  # Overwrite this method to customize how submissions are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(submission)
  #   "Submission ##{submission.id}"
  # end
end

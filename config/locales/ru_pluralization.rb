# frozen_string_literal: true

# Russian pluralization for I18n (one / few / many / other).
{
  ru: {
    i18n: {
      plural: {
        keys: [ :one, :few, :many, :other ],
        rule: lambda do |n|
          n = n.to_i
          mod10 = n % 10
          mod100 = n % 100

          if mod10 == 1 && mod100 != 11
            :one
          elsif (2..4).include?(mod10) && !(12..14).include?(mod100)
            :few
          else
            :many
          end
        end
      }
    }
  }
}

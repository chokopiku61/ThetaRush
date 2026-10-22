# frozen_string_literal: true

# Enable locale-specific plural rules (needed for Russian one/few/many).
require "i18n/backend/pluralization"

I18n::Backend::Simple.include(I18n::Backend::Pluralization)

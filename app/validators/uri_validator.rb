# frozen_string_literal: true

class UriValidator < ActiveModel::EachValidator
  DEFAULT_ACCEPTED_SCHEMES = /^https?$/
  DEFAULT_OPTIONAL_PARTS = %i[port].freeze
  DEFAULT_FORBIDDEN_PARTS = %i[userinfo registry path opaque query fragment].freeze

  def validate_each(record, attribute, value)
    uri = URI.parse(value)
    raise URI::InvalidURIError if !valid_scheme?(uri.scheme) || uri.host.blank? || forbidden_part?(uri)
    true
  rescue URI::InvalidURIError
    record.errors.add(attribute, options[:message] || :invalid)
    false
  end

  def valid_scheme?(scheme)
    accepted_scheme = options.fetch(:scheme, DEFAULT_ACCEPTED_SCHEMES)
    case accepted_scheme
    when Regexp
      scheme =~ accepted_scheme
    else
      [*accepted_scheme].include? scheme
    end
  end

  def forbidden_part?(uri)
    forbidden_parts = DEFAULT_FORBIDDEN_PARTS.reject { |part| options[part].presence }
    forbidden_parts += DEFAULT_OPTIONAL_PARTS.select { |part| options.key?(part) && !options[part] }
    forbidden_parts.any? { |forbidden_attr| uri.public_send(forbidden_attr).present? }
  end
end

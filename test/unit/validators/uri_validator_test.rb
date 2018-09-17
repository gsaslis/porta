# frozen_string_literal: true

require 'test_helper'

class UriValidatorTest < ActiveSupport::TestCase
  test 'invalid uri' do
    klass = Class.new(base_record_class) { validates :uri, uri: true }
    record = klass.new

    %w[missing.scheme:9 fdsfas not_&_valid &/(\\'].each do |invalid_uri|
      record.uri = invalid_uri
      refute record.valid?
    end
  end

  test 'default format http(s)://host(:port)' do
    klass = Class.new(base_record_class) { validates :uri, uri: true }
    record = klass.new

    %w[http https].each do |scheme|
      record.uri = "#{scheme}://domain.test"
      assert record.valid?

      record.uri = "#{scheme}://domain.test:123"
      assert record.valid?
    end
  end

  test '/path' do
    klass = Class.new(base_record_class) { validates :uri, uri: true }
    record = klass.new
    record.uri = "http://domain.test/path"
    refute record.valid?

    klass = Class.new(base_record_class) { validates :uri, uri: { path: true } }
    record = klass.new
    record.uri = "http://domain.test/path"
    assert record.valid?
  end

  test 'custom scheme' do
    klass = Class.new(base_record_class) { validates :uri, uri: true }
    record = klass.new
    record.uri = "ssh://domain.test"
    refute record.valid?

    klass = Class.new(base_record_class) { validates :uri, uri: { scheme: 'ssh' } }
    record = klass.new
    record.uri = "ssh://domain.test"
    assert record.valid?

    klass = Class.new(base_record_class) { validates :uri, uri: { scheme: %w[pop imap] } }
    record = klass.new
    record.uri = "pop://domain.test"
    assert record.valid?
    record.uri = "imap://domain.test"
    assert record.valid?

    klass = Class.new(base_record_class) { validates :uri, uri: { scheme: /^s?ftp$/ } }
    record = klass.new
    record.uri = "ftp://domain.test"
    assert record.valid?
    record.uri = "sftp://domain.test"
    assert record.valid?
    record.uri = "tftp://domain.test"
    refute record.valid?
  end

  test 'forbid optional parts' do
    klass = Class.new(base_record_class) { validates :uri, uri: true }
    record = klass.new
    record.uri = "http://domain.test:123"
    assert record.valid?

    klass = Class.new(base_record_class) { validates :uri, uri: { port: false } }
    record = klass.new
    record.uri = "http://domain.test:123"
    refute record.valid?
  end

  private

  def base_record_class
    @base_record_class ||= Class.new do
      include ActiveModel::Validations

      def self.model_name
        ActiveModel::Name.new(self, nil, "uri_validator_test__base_klass")
      end

      attr_accessor :uri
    end
  end
end

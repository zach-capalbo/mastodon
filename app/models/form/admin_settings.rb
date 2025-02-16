# frozen_string_literal: true

class Form::AdminSettings
  include ActiveModel::Model

  KEYS = %i(
    site_contact_username
    site_contact_email
    site_title
    site_short_description
    site_extended_description
    site_terms
    registrations_mode
    closed_registrations_message
    timeline_preview
    bootstrap_timeline_accounts
    theme
    activity_api_enabled
    peers_api_enabled
    preview_sensitive_media
    custom_css
    profile_directory
    thumbnail
    mascot
    trends
    trendable_by_default
    show_domain_blocks
    show_domain_blocks_rationale
    noindex
    require_invite_text
    media_cache_retention_period
    content_cache_retention_period
    backups_retention_period
    download_media_enabled
  ).freeze

  INTEGER_KEYS = %i(
    media_cache_retention_period
    content_cache_retention_period
    backups_retention_period
  ).freeze

  BOOLEAN_KEYS = %i(
    timeline_preview
    activity_api_enabled
    peers_api_enabled
    preview_sensitive_media
    profile_directory
    trends
    trendable_by_default
    noindex
    require_invite_text
    download_media_enabled
  ).freeze

  UPLOAD_KEYS = %i(
    thumbnail
    mascot
  ).freeze

  attr_accessor(*KEYS)

  validates :registrations_mode, inclusion: { in: %w(open approved none) }, if: -> { defined?(@registrations_mode) }
  validates :site_contact_email, :site_contact_username, presence: true, if: -> { defined?(@site_contact_username) || defined?(@site_contact_email) }
  validates :site_contact_username, existing_username: true, if: -> { defined?(@site_contact_username) }
  validates :bootstrap_timeline_accounts, existing_username: { multiple: true }, if: -> { defined?(@bootstrap_timeline_accounts) }
  validates :show_domain_blocks, inclusion: { in: %w(disabled users all) }, if: -> { defined?(@show_domain_blocks) }
  validates :show_domain_blocks_rationale, inclusion: { in: %w(disabled users all) }, if: -> { defined?(@show_domain_blocks_rationale) }
  validates :media_cache_retention_period, :content_cache_retention_period, :backups_retention_period, numericality: { only_integer: true }, allow_blank: true, if: -> { defined?(@media_cache_retention_period) || defined?(@content_cache_retention_period) || defined?(@backups_retention_period) }
  validates :site_short_description, length: { maximum: 200 }, if: -> { defined?(@site_short_description) }

  KEYS.each do |key|
    define_method(key) do
      return instance_variable_get("@#{key}") if instance_variable_defined?("@#{key}")

      stored_value = begin
        if UPLOAD_KEYS.include?(key)
          SiteUpload.where(var: key).first_or_initialize(var: key)
        else
          Setting.public_send(key)
        end
      end

      instance_variable_set("@#{key}", stored_value)
    end
  end

  UPLOAD_KEYS.each do |key|
    define_method("#{key}=") do |file|
      value = public_send(key)
      value.file = file
    end
  end

  def save
    return false unless valid?

    KEYS.each do |key|
      next unless instance_variable_defined?("@#{key}")

      if UPLOAD_KEYS.include?(key)
        public_send(key).save
      else
        setting = Setting.where(var: key).first_or_initialize(var: key)
        setting.update(value: typecast_value(key, instance_variable_get("@#{key}")))
      end
    end
  end

  private

  def typecast_value(key, value)
    if BOOLEAN_KEYS.include?(key)
      value == '1'
    elsif INTEGER_KEYS.include?(key)
      value.blank? ? value : Integer(value)
    else
      value
    end
  end
end

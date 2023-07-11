# frozen_string_literal: true

class RedownloadMediaWorker
  include Sidekiq::Worker
  include ExponentialBackoff
  include JsonLdHelper

  sidekiq_options queue: 'pull', retry: 3

  def perform(id)
    media_attachment = MediaAttachment.find(id)

    return if media_attachment.remote_url.blank?
    # return unless Setting.download_media_enabled

    # Rails.logger.warn "Going to download Media!!! redownload.rb, #{Setting.download_media_enabled}"

    media_attachment.download_file!
    media_attachment.download_thumbnail!
    media_attachment.save
  rescue ActiveRecord::RecordNotFound
    # Do nothing
  rescue Mastodon::UnexpectedResponseError => e
    response = e.response

    if response_error_unsalvageable?(response)
      # Give up
    else
      raise e
    end
  end
end

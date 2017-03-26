require "models/email_alert"
require "models/message"

class MessageProcessor
  def initialize(channel, logger)
    @channel = channel
    @logger = logger
  end

  def process(document_json, properties, delivery_info)
    message = Message.new(document_json, properties, delivery_info)

    process_message(message)

    acknowledge(message)
  rescue InvalidDocumentError, MalformedDocumentError => e
    Airbrake.notify_or_ignore(e)
    discard(delivery_info.delivery_tag)
  end

private

  def process_message(message)
    return if message.heartbeat?

    document = message.parsed_document

    unless has_title?(document)
      @logger.info "not triggering email alert for document with no title: #{document}"
      return
    end

    unless has_public_updated_at?(document)
      @logger.info "not triggering email alert for document with no public_updated_at: #{document}"
      return
    end

    unless is_english?(document)
      @logger.info "not triggering email alert for non-english document #{document["title"]}: locale #{document["locale"]}"
      return
    end

    message.validate!

    if email_alerts_supported?(document)
      @logger.info "triggering email alert for document #{document["title"]}"
      trigger_email_alert(document)
    end
  end

  attr_reader :channel

  def trigger_email_alert(document)
    EmailAlert.new(document, @logger).trigger
  end

  def email_alerts_supported?(document)
    return false if blacklisted_publishing_app?(document["publishing_app"])

    document_tags = document.fetch("details", {}).fetch("tags", {})
    document_links = document.fetch("links", {})
    document_type = document.fetch("document_type")

    contains_supported_attribute?(document_links) \
      || contains_supported_attribute?(document_tags) \
      || whitelisted_document_type?(document_type) \
      || has_relevant_document_supertype?(document)
  end

  def contains_supported_attribute?(tags_hash)
    supported_attributes = ["topics", "policies", "service_manual_topics", "taxons"]
    supported_attributes.any? do |tag_name|
      tags_hash[tag_name] && tags_hash[tag_name].any?
    end
  end

  def blacklisted_publishing_app?(publishing_app)
    # These publishing apps make direct calls to email-alert-api to send their
    # emails, so we need to avoid sending duplicate emails when they come
    # through on the queue:
    ['travel-advice-publisher', 'specialist-publisher'].include?(publishing_app)
  end

  def whitelisted_document_type?(document_type)
    document_type == "service_manual_guide"
  end

  def has_relevant_document_supertype?(document)
    def relevant_supertype?(supertype)
      !(['other', '', nil].include?(supertype))
    end

    # These supertypes were added to Whitehall content to aid the migration of
    # Whitehall subscriptions to email-alert-api. We'd like to get to the point
    # where email subscriptions cover all content on the site rather than
    # perpetuating the Whitehall/everything else divide, but don't have time to
    # work through all the ramifications of that while also doing that migration
    # so are limiting the scope of emails to approximately what Whitehall did.
    relevant_supertype?(document["government_document_supertype"]) ||
      relevant_supertype?(document["email_document_supertype"])
  end

  def is_english?(document)
    # a missing locale is assumed to be English, but a "null" locale
    # is not
    return true unless document.key?("locale")

    document["locale"] == "en"
  end

  def has_title?(document)
    has_non_blank_value_for_key?(document: document, key: "title")
  end

  def has_public_updated_at?(document)
    has_non_blank_value_for_key?(document: document, key: "public_updated_at")
  end

  def acknowledge(message)
    channel.acknowledge(message.delivery_tag, false)
  end

  def discard(delivery_tag)
    channel.reject(delivery_tag, false)
  end

  private
  def has_non_blank_value_for_key?(document:, key:)
    # a key can be present but the value is nil, so fetch won't
    # protect us here
    return false unless document.key?(key)
    (document[key] || "") != ""
  end
end

require_relative("./message_processor")

class UnpublishingMessageProcessor < MessageProcessor
protected

  def process_message(message)
    document = message.payload
    Services.email_api_client.send_unpublish_message(document)
  end
end

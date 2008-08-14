# Modify TMail to properly handle attachments posing as multipart elements
module TMail
  class Mail
    def attachments
      if multipart?
        parts.collect { |part|
          if part.multipart?
            part.attachments
          elsif attachment?(part)
            content   = part.body # unquoted automatically by TMail#body
            file_name = (part['content-location'] &&
                          part['content-location'].body) ||
                        part.sub_header("content-type", "name") ||
                        part.sub_header("content-disposition", "filename")
         
            next if file_name.blank? || content.blank?
         
            attachment = Attachment.new(content)
            attachment.original_filename = file_name.strip
            attachment.content_type = part.content_type
            attachment
          end
        }.flatten.compact
      end     
    end
  end
end
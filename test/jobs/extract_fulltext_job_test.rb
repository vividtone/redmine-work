require 'test_helper'

class ExtractFulltextJobTest < ActiveJob::TestCase

  def test_should_extract_fulltext
    att = nil
    Redmine::Configuration.with 'enable_fulltext_search' => false do
      att = Attachment.create(
        :container => Issue.find(1),
        :file => uploaded_test_file("testfile.txt", "text/plain"),
        :author => User.find(1),
        :content_type => 'text/plain')
    end
    att.reload
    assert_nil att.fulltext

    ExtractFulltextJob.perform_now(att.id)

    att.reload
    assert att.fulltext.include?("this is a text file for upload tests\r\nwith multiple lines")
  end

end

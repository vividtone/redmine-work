require_relative '../../../test_helper'

class Redmine::TextExtractorTest < ActiveSupport::TestCase
  fixtures :projects, :users, :attachments

  setup do
    @project = Project.find_by_identifier 'ecookbook'
    set_fixtures_attachments_directory
    @dlopper = User.find_by_login 'dlopper'
  end

  def attachment_for(filename, content_type = nil)
    Attachment.new(container: @project,
                   file: uploaded_test_file(filename, content_type),
                   filename: filename,
                   author: @dlopper).tap do |a|
      a.content_type = content_type if content_type
      a.save!
    end
  end

  if Redmine::TextExtractor::PdfHandler.available?
    test "should extract text from pdf" do
      a = attachment_for "text.pdf"
      te = Redmine::TextExtractor.new a
      assert text = te.text
      assert_match /lorem ipsum fulltext find me!/, text
    end
  end

  if Redmine::TextExtractor::RtfHandler.available?
    test "should extract text from rtf" do
      a = attachment_for "text.rtf"
      te = Redmine::TextExtractor.new a
      assert text = te.text
      assert_match /lorem ipsum fulltext find me!/, text
    end
  end

  if Redmine::TextExtractor::DocHandler.available?
    test "should extract text from doc" do
      a = attachment_for "text.doc"
      te = Redmine::TextExtractor.new a
      assert text = te.text
      assert_match /lorem ipsum fulltext find me!/, text
    end
  end

  if Redmine::TextExtractor::XlsHandler.available?
    test "should extract text from xls" do
      a = attachment_for "spreadsheet.xls"
      te = Redmine::TextExtractor.new a
      assert text = te.text
      assert_match /lorem ipsum fulltext find me!/, text
    end
  end


  %w(txt docx odt ott).each do |type|
    test "should extract text from #{type}" do
      a = attachment_for "text.#{type}"
      te = Redmine::TextExtractor.new a
      assert text = te.text
      assert_match /lorem ipsum fulltext find me!/, text
    end
  end


  %w(xlsx ods ots).each do |type|
    test "should extract text from #{type}" do
      a = attachment_for "spreadsheet.#{type}"
      te = Redmine::TextExtractor.new a
      assert text = te.text
      assert_match /lorem ipsum fulltext find me!/, text
    end
  end


  %w(pptx ppsx potm odp otp).each do |type|
    test "should extract text from #{type}" do
      a = attachment_for "presentation.#{type}"
      te = Redmine::TextExtractor.new a
      assert text = te.text
      assert_equal 'The Title find me Slide two Click To Add Text', text
    end
  end


  test "should extract text from csv" do
    a = attachment_for "spreadsheet.csv"
    te = Redmine::TextExtractor.new a
    assert text = te.text
    assert_match /lorem ipsum fulltext find me!/, text.gsub(/(,+|\n+\s*)/m, ' ').squeeze(' ')
  end

end







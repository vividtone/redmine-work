module Redmine
  class TextExtractor

    MAX_FULLTEXT_LENGTH = 4.megabytes
    TEXT_EXTRACTORS = Redmine::Configuration['text_extractors'] || {}

    def initialize(attachment)
      @attachment = attachment
    end

    # returns the extracted fulltext or nil if no matching handler was found
    # for the file type.
    def text
      if handler = find_handler and text = handler.text(@attachment)
        text.gsub! /\s+/m, ' '
        text.strip!
        text.mb_chars.compose.limit(MAX_FULLTEXT_LENGTH).to_s
      end
    rescue Exception => e
      Rails.logger.error "error in fulltext extraction: #{e}"
      raise e unless e.is_a? StandardError # re-raise Signals / SyntaxErrors etc
    end

    private

    def find_handler
      @@file_handlers.detect{|h| h.accept? @attachment }
    end


    class FileHandler
      def accept?(attachment)
        if @content_type
          attachment.content_type == @content_type
        elsif @content_types
          @content_types.include? attachment.content_type
        else
          false
        end
      end
    end

    class ExternalCommandHandler < FileHandler
      include Redmine::Utils::Shell

      FILE_PLACEHOLDER = '__FILE__'.freeze

      def text(attachment)
        cmd = @command.dup
        cmd[cmd.index(FILE_PLACEHOLDER)] = attachment.diskfile
        shellout(cmd){ |io| io.read }.to_s
      end

      def accept?(attachment)
        super and available?
      end

      def available?
        @command.present? and File.executable?(@command[0])
      end

      def self.available?
        new.available?
      end
    end


    class PdfHandler < ExternalCommandHandler
      DEFAULT = [
        '/usr/bin/pdftotext', '-enc', 'UTF-8', '__FILE__', '-'
      ].freeze
      def initialize
        @content_type = 'application/pdf'
        @command = TEXT_EXTRACTORS['pdftotext'] || DEFAULT
      end
    end


    class RtfHandler < ExternalCommandHandler
      DEFAULT = [
        '/usr/bin/unrtf', '--text', '__FILE__'
      ].freeze
      def initialize
        @content_type = 'application/rtf'
        @command = TEXT_EXTRACTORS['unrtf'] || DEFAULT
      end
    end


    # Handler base class for XML based (MS / Open / Libre) office documents.
    class ZippedXmlHandler < FileHandler

      class SaxDocument < Nokogiri::XML::SAX::Document
        attr_reader :text

        def initialize(text_element, text_namespace)
          @element = text_element
          @namespace_uri = text_namespace
          @text = ''.dup
          @is_text = false
        end

        # Handle each element, expecting the name and any attributes
        def start_element_namespace(name, attrs = [], prefix = nil, uri = nil, ns = [])
          if name == @element and uri == @namespace_uri
            @is_text = true
          end
        end

        # Any characters between the start and end element expected as a string
        def characters(string)
          @text << string if @is_text
        end

        # Given the name of an element once its closing tag is reached
        def end_element_namespace(name, prefix = nil, uri = nil)
          if name == @element and uri == @namespace_uri
            @text << ' '
            @is_text = false
          end
        end
      end

      def text(attachment)
        Zip::File.open(attachment.diskfile) do |zip_file|
          zip_file.each do |entry|
            if entry.name == @file
              return xml_to_text entry.get_input_stream
            end
          end
        end
      end

      private

      def xml_to_text(io)
        sax_doc = SaxDocument.new @element, @namespace_uri
        Nokogiri::XML::SAX::Parser.new(sax_doc).parse(io)
        sax_doc.text
      end
    end


    # Base class for extractors for MS Office formats
    class OfficeDocumentHandler < ZippedXmlHandler
      def initialize
        super
        @element = 't'
      end
    end


    class DocxHandler < OfficeDocumentHandler
      def initialize
        super
        @content_type = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        @file = 'word/document.xml'
        @namespace_uri = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
      end
    end


    class XlsxHandler < OfficeDocumentHandler
      def initialize
        super
        @content_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        @file = 'xl/sharedStrings.xml'
        @namespace_uri = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
      end
    end



    class PptxHandler < OfficeDocumentHandler
      CONTENT_TYPES = [
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'application/vnd.openxmlformats-officedocument.presentationml.slideshow',
        'application/vnd.ms-powerpoint.template.macroEnabled.12',
      ]

      def initialize
        super
        @content_types = CONTENT_TYPES
        @namespace_uri = 'http://schemas.openxmlformats.org/drawingml/2006/main'
      end

      def text(attachment)
        slides = []
        Zip::File.open(attachment.diskfile) do |zip_file|
          zip_file.each do |entry|
            if entry.name =~ /slide(\d+)\.xml/
              slides << [$1, xml_to_text(entry.get_input_stream)]
            end
          end
        end
        slides.sort!{|a, b| a.first <=> b.first}
        slides.map(&:last).join ' '
      end
    end


    # Extractor for Open / Libre Office formats
    class OpendocumentHandler < ZippedXmlHandler
      CONTENT_TYPES = [
        'application/vnd.oasis.opendocument.presentation',
        'application/vnd.oasis.opendocument.presentation-template',
        'application/vnd.oasis.opendocument.text',
        'application/vnd.oasis.opendocument.text-template',
        'application/vnd.oasis.opendocument.spreadsheet',
        'application/vnd.oasis.opendocument.spreadsheet-template'
      ]
      def initialize
        super
        @file = 'content.xml'
        @content_types = CONTENT_TYPES
        @element = 'p'
        @namespace_uri = 'urn:oasis:names:tc:opendocument:xmlns:text:1.0'
      end
    end



    class DocHandler < ExternalCommandHandler
      CONTENT_TYPES = [
        'application/vnd.ms-word',
        'application/msword',
      ]
      DEFAULT = [
        '/usr/bin/catdoc', '-dutf-8', '__FILE__'
      ]
      def initialize
        @content_types = CONTENT_TYPES
        @command = TEXT_EXTRACTORS['catdoc'] || DEFAULT
      end
    end

    class XlsHandler < ExternalCommandHandler
      CONTENT_TYPES = [
        'application/vnd.ms-excel',
        'application/excel',
      ]
      DEFAULT = [
        '/usr/bin/xls2csv', '-dutf-8', '__FILE__'
      ]
      def initialize
        @content_types = CONTENT_TYPES
        @command = TEXT_EXTRACTORS['xls2csv'] || DEFAULT
      end
      def text(*_)
        if str = super
          str.delete('"').gsub /,+/, ' '
        end
      end
    end

    class PptHandler < ExternalCommandHandler
      CONTENT_TYPES = [
        'application/vnd.ms-powerpoint',
        'application/powerpoint',
      ]
      DEFAULT = [
        '/usr/bin/catppt', '-dutf-8', '__FILE__'
      ]
      def initialize
        @content_types = CONTENT_TYPES
        @command = TEXT_EXTRACTORS['catppt'] || DEFAULT
      end
    end


    class PlaintextHandler < FileHandler
      CONTENT_TYPES = %w(text/csv text/plain)
      def initialize
        @content_types = CONTENT_TYPES
      end
      def text(attachment)
        Redmine::CodesetUtil.to_utf8 IO.read(attachment.diskfile), 'UTF-8'
      end
    end

    # the handler chain. List most specific handlers first and more general
    # (fallback) handlers later.
    @@file_handlers = [
      PdfHandler,
      OpendocumentHandler,
      DocxHandler, XlsxHandler, PptxHandler,
      DocHandler, XlsHandler, PptHandler,
      RtfHandler,
      PlaintextHandler,
    ].map(&:new)

  end

end


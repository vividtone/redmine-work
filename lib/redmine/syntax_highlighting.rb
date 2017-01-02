# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module Redmine
  module SyntaxHighlighting

    BUILTIN_HIGHLIGHTERS = %w(CodeRay Rouge)

    class << self
      def highlighter
        if @highlighter
          @highlighter
        else
          begin
            const_get(Setting.syntax_highlighter, false)
          rescue NameError
            CodeRay
          end
        end
      end

      def highlighter=(name)
        if name.is_a?(Module)
          @highlighter = name
        else
          @highlighter = const_get(name)
        end
      end

      # Highlights +text+ as the content of +filename+
      # Should not return line numbers nor outer pre tag
      def highlight_by_filename(text, filename)
        highlighter.highlight_by_filename(text, filename)
      rescue
        ERB::Util.h(text)
      end

      # Highlights +text+ using +language+ syntax
      # Should not return outer pre tag
      def highlight_by_language(text, language)
        highlighter.highlight_by_language(text, language)
      rescue
        ERB::Util.h(text)
      end
    end

    module CodeRay
      require 'coderay'

      class << self
        def highlight_by_filename(text, filename)
          language = ::CodeRay::FileType[filename]
          language ? ::CodeRay.scan(text, language).html(:break_lines => true) : ERB::Util.h(text)
        end

        def highlight_by_language(text, language)
          ::CodeRay.scan(text, language).html(:wrap => :span)
        end
      end
    end

    module Rouge
      require 'rouge'

      # Customized formatter based on Rouge::Formatters::HTMLLinewise
      # Syntax highlighting is completed within each line.
      class CustomHTMLLinewise < ::Rouge::Formatter
        def initialize(formatter)
          @formatter = formatter
        end

        def stream(tokens, &b)
          token_lines(tokens) do |line|
            line.each do |tok, val|
              yield @formatter.span(tok, val)
            end
            yield "\n"
          end
        end
      end

      class << self
        def highlight_by_filename(text, filename)
          lexer =::Rouge::Lexer.guess_by_filename(filename)
          html_formatter = ::Rouge::Formatters::HTML.new
          ::Rouge.highlight(text, lexer, CustomHTMLLinewise.new(html_formatter))
        end

        def highlight_by_language(text, language)
          lexer = ::Rouge::Lexer.find(language.downcase)
          if lexer == ::Rouge::Lexers::PHP
            start_inline = text !~ /<\?(php|=)/ ? true : false
            lexer = ::Rouge::Lexers::PHP.new(:start_inline => start_inline)
          end
          lexer ||= ::Rouge::Lexers::PlainText
          ::Rouge.highlight(text, lexer, ::Rouge::Formatters::HTML)
        end
      end
    end
  end
end

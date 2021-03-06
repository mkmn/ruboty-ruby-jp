require 'open3'

module Ruboty
  module Handlers
    class ParseRuby < Base
      KNOWN_RUBY_VERSIONS = 18..27
      KNOWN_PARSERS = %w[ripper sexp tokenize lex rubyvm] + KNOWN_RUBY_VERSIONS.map {|v| "parser#{v}"}

      KNOWN_RUBY_VERSIONS.each do |v|
        require "parser/ruby#{v}"
      end
      require 'ripper'
      require 'pp'

      on(
         /(?<with_parse>parse\s)?(?:(?<parser>#{Regexp.union(*KNOWN_PARSERS)})\s)?(?<code>.+)/im,
         name: 'parse',
         description: "Parse Ruby code and response AST",
      )

      on(
        /syntax-check (?<code>.+)/im,
        name: 'syntax_check',
        description: 'Check the syntax of the given Ruby code with parser gem',
      )

      on(
        /-?cwe? (?<code>.+)/im,
        name: 'cw',
        description: 'Run ruby -cw',
      )

      def parse(message)
        m = message.match_data
        parser = m['parser']
        code = m['code']
        with_parse = m['with_parse']
        return if !with_parse && !parser

        obj = parse_code(parser, code)
        message.reply wrap_codeblock(obj.pretty_inspect)
      end

      def syntax_check(message)
        code = message.match_data['code']
        result = KNOWN_RUBY_VERSIONS.map do |v|
          err_or_ast = parse_code("parser#{v}", code)
          ok = !err_or_ast.is_a?(Exception)
          "#{v}: #{ok ? 'ok' : err_or_ast}"
        end
        message.reply result.join "\n"
      end

      def cw(message)
        code = message.match_data['code']
        out, _status = Open3.capture2e("ruby", '-cwve', code)
        message.reply wrap_codeblock(out)
      end

      private def parse_code(parser, code)
        case parser
        when 'ripper', 'sexp', nil
          Ripper.sexp(code)
        when 'tokenize'
          Ripper.tokenize(code)
        when 'lex'
          Ripper.lex(code)
        when /parser(?<version>\d+)/
          v = Regexp.last_match['version']
          Parser.const_get(:"Ruby#{v}").parse(code)
        when 'rubyvm'
          RubyVM::AbstractSyntaxTree.parse(code)
        else
          raise 'unreachable'
        end
      rescue SyntaxError, Parser::SyntaxError => ex
        ex
      end

      private def wrap_codeblock(str)
        "```\n#{str.chomp}\n```"
      end
    end
  end
end

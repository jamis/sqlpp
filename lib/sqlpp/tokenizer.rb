require 'strscan'

module SQLPP
  class Tokenizer
    class Exception < SQLPP::Exception; end
    class UnexpectedCharacter < Exception; end
    class EOFError < Exception; end

    class Token < Struct.new(:type, :text, :pos)
    end

    KEYWORDS = %w(
      and
      as
      asc
      between
      by
      case
      cross
      desc
      distinct
      else
      end
      first
      from
      full
      group
      having
      ilike
      in
      inner
      is
      join
      last
      left
      like
      limit
      not
      null
      nulls
      offset
      on
      or
      order
      outer
      right
      select
      then
      when
      where
    )

    KEYWORDS_REGEX = Regexp.new('\b(' + KEYWORDS.join('|') + ')\b', Regexp::IGNORECASE)

    def initialize(string)
      @scanner = StringScanner.new(string)
      @buffer = []
    end

    def next
      if @buffer.any?
        @buffer.pop
      else
        _scan
      end
    end

    def peek
      push(self.next)
    end

    def push(token)
      @buffer.push(token)
      token
    end

    def _scan
      pos = @scanner.pos

      if @scanner.eos?
        Token.new(:eof, nil, pos)
      elsif (key = @scanner.scan(KEYWORDS_REGEX))
        Token.new(:key, key.downcase.to_sym, pos)
      elsif (num = @scanner.scan(/\d+(?:\.\d+)?/))
        Token.new(:lit, num, pos)
      elsif (id = @scanner.scan(/\w+/))
        Token.new(:id, id, pos)
      elsif (punct = @scanner.scan(/<=|<>|!=|>=|::/))
        Token.new(:punct, punct, pos)
      elsif (punct = @scanner.scan(/[<>=\(\).*,\/+\-\[\]]/))
        Token.new(:punct, punct, pos)
      elsif (delim = @scanner.scan(/["`]/))
        contents = _scan_to_delim(delim, pos)
        Token.new(:id, "#{delim}#{contents}#{delim}", pos)
      elsif @scanner.scan(/'/)
        contents = _scan_to_delim("'", pos)
        Token.new(:lit, "'#{contents}'", pos)
      elsif (space = @scanner.scan(/\s+/))
        Token.new(:space, space, pos)
      else
        raise UnexpectedCharacter, @scanner.rest
      end
    end

    def _scan_to_delim(delim, pos)
      escape, if_peek = case delim
        when '"', '`' then ["\\", nil]
        when "'" then ["'", "'"]
      end

      string = ""
      loop do
        ch = @scanner.getch

        if ch == escape && (if_peek.nil? || @scanner.peek(1) == if_peek)
          ch << @scanner.getch
        end

        case ch
        when nil then
          raise EOFError, "end of input reached in string started at #{pos} with #{delim.inspect}"
        when delim then
          return string
        else
          string << ch
        end
      end
    end
  end
end

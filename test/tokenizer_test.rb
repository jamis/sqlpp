require 'test_helper'

class TokenizerTest < Minitest::Test
  def setup
    @tokenizer = nil
  end

  def test_next_should_return_next_token_in_stream
    _setup_tokenizer("select * from table")

    assert_equal :key, tokenizer.next.type
    assert_equal :space, tokenizer.next.type
    assert_equal :punct, tokenizer.next.type
    assert_equal :space, tokenizer.next.type
    assert_equal :key, tokenizer.next.type
    assert_equal :space, tokenizer.next.type
    assert_equal :id, tokenizer.next.type
  end

  def test_peek_should_not_advance_token_pointer
    _setup_tokenizer("select * from table")

    assert_equal :key, tokenizer.peek.type
    assert_equal :key, tokenizer.peek.type
  end

  def test_push_should_put_token_into_stream
    _setup_tokenizer("select * from table")

    tok = tokenizer.next
    tokenizer.push tok

    assert_equal :key, tokenizer.next.type
  end

  def test_it_should_recognize_keywords
    SQLPP::Tokenizer::KEYWORDS.each do |word|
      tok = _setup_tokenizer(word).next
      assert_token tok, type: :key, text: word.downcase.to_sym
    end
  end

  def test_it_should_recognize_identifiers
    _setup_tokenizer "word word123 \"quoted word\" \"with \\\"escape\\\" word\" `mysql word` `mysql \\`escape\\` word`"

    assert_token _next, type: :id, text: "word"
    _skip :space
    assert_token _next, type: :id, text: "word123"
    _skip :space
    assert_token _next, type: :id, text: '"quoted word"'
    _skip :space
    assert_token _next, type: :id, text: '"with \"escape\" word"'
    _skip :space
    assert_token _next, type: :id, text: '`mysql word`'
    _skip :space
    assert_token _next, type: :id, text: '`mysql \`escape\` word`'
  end

  def test_it_should_recognize_number_literals
    _setup_tokenizer "1 123 0.5 123.456"

    assert_token _next, type: :lit, text: "1"; _skip :space
    assert_token _next, type: :lit, text: "123"; _skip :space
    assert_token _next, type: :lit, text: "0.5"; _skip :space
    assert_token _next, type: :lit, text: "123.456"
  end

  def test_it_should_recognize_string_literals
    _setup_tokenizer "'hello' 'quoted ''string'' here'"

    assert_token _next, type: :lit, text: "'hello'"; _skip :space
    assert_token _next, type: :lit, text: "'quoted ''string'' here'"
  end

  def test_it_should_recognize_whitespace
    _setup_tokenizer "     space\n  "

    assert_token _next, type: :space, text: "     "; _skip :id
    assert_token _next, type: :space, text: "\n  "
  end

  def test_it_should_recognize_multichar_punctuation
    _setup_tokenizer "<= <> != >="

    assert_token _next, type: :punct, text: "<="; _skip :space
    assert_token _next, type: :punct, text: "<>"; _skip :space
    assert_token _next, type: :punct, text: "!="; _skip :space
    assert_token _next, type: :punct, text: ">="
  end

  def test_it_should_recognize_punctuation
    _setup_tokenizer "< > = ( ) . * , / + -"

    assert_token _next, type: :punct, text: "<"; _skip :space
    assert_token _next, type: :punct, text: ">"; _skip :space
    assert_token _next, type: :punct, text: "="; _skip :space
    assert_token _next, type: :punct, text: "("; _skip :space
    assert_token _next, type: :punct, text: ")"; _skip :space
    assert_token _next, type: :punct, text: "."; _skip :space
    assert_token _next, type: :punct, text: "*"; _skip :space
    assert_token _next, type: :punct, text: ","; _skip :space
    assert_token _next, type: :punct, text: "/"; _skip :space
    assert_token _next, type: :punct, text: "+"; _skip :space
    assert_token _next, type: :punct, text: "-"
  end

  def test_it_should_recognize_end_of_file
    _setup_tokenizer "done"

    _skip :id
    assert_token _next, type: :eof
    assert_token _next, type: :eof
  end

  attr_reader :tokenizer

  def _setup_tokenizer(string)
    @tokenizer = SQLPP::Tokenizer.new(string)
  end

  def _next
    tokenizer.next
  end

  def _skip(type)
    assert_token _next, type: type
  end

  def assert_token(token, type: nil, text: nil, pos: nil)
    assert_equal type, token.type if type
    assert_equal text, token.text if text
    assert_equal pos, token.pos if pos
  end
end

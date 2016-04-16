require 'sqlpp/ast'

# select := 'SELECT' optional_distinct
#             optional_projections
#             optional_froms
#             optional_wheres
#             optional_groups
#             optional_orders
#             optional_limit
#             optional_offset
#
# optional_distinct := ''
#                    | 'DISTINCT'
#
# optional_projections := ''
#                       | list
#
# optional_froms := ''
#                 | 'FROM' froms
#
# optional_wheres := ''
#                  | 'WHERE' expr1
#
# optional_groups := ''
#                  | 'GROUP' 'BY' list
#
# optional_orders := ''
#                  | 'ORDER' 'BY' sort_keys
#
# optional_limit := ''
#                 | 'LIMIT' expr4
#
# optional_offset := ''
#                  | 'OFFSET' expr4
#
# sort_keys := sort_key
#            | sort_key ',' sort_keys
#
# sort_key := expr1
#           | expr1 sort_options
#
# sort_options := sort_option
#               | sort_option ' ' sort_options
#
# sort_option := 'ASC' | 'DESC' | 'NULLS FIRST' | 'NULLS LAST'
#
# froms := from
#        | from ',' froms
#
# from := entity
#       | entity optional_join_expr
#
# optional_join_expr := ''
#                     | 'LEFT' 'JOIN' from 'ON' expr
#                     | 'INNER' 'JOIN' from 'ON' expr
#                     | 'OUTER' 'JOIN' from 'ON' expr
#                     | 'FULL' 'OUTER' 'JOIN' from 'ON' expr
#
# entity := '(' from ')'
#         | id
#         | select_stmt
#
# expr1 := expr2
#        | expr2 op expr1
#
# op := 'AND' | 'OR' | 'IS' | 'IS NOT'
#
# expr2 := expr3 optional_op
#
# optional_op := ''
#              | 'NOT' optional_op
#              | 'BETWEEN' expr3 AND expr3
#              | 'NOT IN' '(' list ')'
#              | 'IN' '(' list ')'
#              | bop expr3
#
# bop := '<' | '<=' | '<>' | '=' | '>=' | '>'
#
# expr3 := expr4
#        | expr4 op2 expr3
#        | unary expr3
#
# op2 := '+' | '-' | '*' | '/'
#
# unary := '+' | '-' | 'NOT' | 'DISTINCT'
#
# expr4 := lit
#        | id
#        | id '.' id
#        | id '(' args ')'
#        | 'CASE' case_stmt 'END'
#        | '(' expr1 ')'
#        | expr4 '[' expr1 ']'
#        | expr4 '::' expr4
#
# list := expr1
#       | expr1 ',' list

module SQLPP
  class Parser
    class Exception < SQLPP::Exception; end
    class UnexpectedToken < Exception; end
    class TrailingTokens < Exception; end

    def self.parse(string)
      parser = new(string)
      parser.parse
    end

    def initialize(string)
      @tokenizer = SQLPP::Tokenizer.new(string)
    end

    def parse
      _eat :space

      token = _peek(:key)
      raise UnexpectedToken, token.inspect unless token

      case token.text
        when :select then parse_select
        else raise UnexpectedToken, token.inspect
      end
    end

    # --- exposed for testing purposes ---

    def parse_expression
      _parse_expr1
    ensure
      _ensure_stream_empty!
    end

    def parse_from
      _parse_from
    ensure
      _ensure_stream_empty!
    end

    def parse_select
      _parse_select
    ensure
      _ensure_stream_empty!
    end

    # --- internal use ---

    def _parse_select
      _expect :key, :select
      select = AST::Select.new

      _eat :space
      if _eat(:key, :distinct)
        select.distinct = true
        _eat :space
      end

      if !_peek(:key, /^(from|where)$/) && !_peek(:eof)
        list = []

        loop do
          expr = _parse_expr1
          _eat :space
          if _peek(:key, :as)
            _next
            _eat :space
            name = _expect(:id)
            expr = AST::As.new(name.text, expr)
          end
          list.push expr
          break unless _eat(:punct, ",")
        end
        _eat :space

        select.projections = list
      end

      if _eat(:key, :from)
        list = []

        loop do
          _eat :space
          list << _parse_from
          _eat :space
          break unless _eat(:punct, ',')
        end
        _eat :space

        select.froms = list
      end

      if _eat(:key, :where)
        select.wheres = _parse_expr1
        _eat :space
      end

      if _eat(:key, :group)
        _eat :space
        _expect :key, :by
        _eat :space
        select.groups = _parse_list
      end

      if _eat(:key, :order)
        _eat :space
        _expect :key, :by
        _eat :space

        list = []
        loop do
          key = AST::SortKey.new(_parse_expr1, [])
          list << key

          _eat :space

          if (dir = _eat(:key, /^(asc|desc)$/))
            _eat :space
            key.options << dir.text
          end

          if (opt = _eat(:key, :nulls))
            opt = opt.text.to_s
            _eat :space
            sort = _eat(:key, /^(first|last)$/)
            opt << " " << sort.text.to_s if sort
            key.options << opt
          end

          _eat :space
          break unless _eat(:punct, ",")
        end

        select.orders = list
      end

      if _eat(:key, :limit)
        _eat :space
        atom = _parse_atom
        _eat :space

        select.limit = AST::Limit.new(atom)
      end

      if _eat(:key, :offset)
        _eat :space
        atom = _parse_atom
        _eat :space

        select.offset = AST::Offset.new(atom)
      end

      select
    end

    def _parse_from
      entity = _parse_entity

      loop do
        _eat :space

        if (which = _eat(:key, /^(inner|cross|left|right|full|outer)$/))
          type = which.text.to_s

          if type == "full" || type == "left" || type == "right"
            _eat :space
            _expect :key, :outer
            type << " outer"
          end

          _eat :space
          _expect :key, :join

          entity = AST::Join.new(type.downcase, entity, _parse_from)

          _eat :space
          if _eat(:key, :on)
            _eat :space
            entity.on = _parse_expr1
          end

        else
          break
        end
      end

      entity
    end

    def _parse_entity
      _eat :space

      entity = if _eat(:punct, '(')
          from = _parse_from
          _eat :space
          _expect :punct, ')'
          AST::Parens.new(from)

        elsif _peek(:key, :select)
          _parse_select

        else
          id = _expect(:id)
          AST::Atom.new(:attr, id.text)
        end

      _eat :space
      if _eat(:key, :as)
        _eat :space
        id = _expect(:id)
        AST::As.new(id.text, entity)
      elsif (id = _eat(:id))
        AST::Alias.new(id.text, entity)
      else
        entity
      end
    end

    def _parse_expr1
      _eat :space

      left = _parse_expr2
      _eat :space

      if (op = _eat(:key, /^(and|or|is)$/i))
        op = op.text

        if op == :is
          _eat :space
          op2 = _eat(:key, :not)
          op = "#{op} #{op2.text}" if op2
        end

        right = _parse_expr1

        AST::Expr.new(left, op, right)
      else
        left
      end
    end

    def _parse_expr2
      _eat :space

      left = _parse_expr3
      _eat :space

      not_kw = _eat(:key, :not)
      _eat :space if not_kw

      if (op = _eat(:key, :between))
        op = op.text

        _eat :space
        lo = _parse_expr3

        _eat :space
        _expect :key, :and

        _eat :space
        hi = _parse_expr3

        right = AST::Atom.new(:range, lo, hi)

      elsif (op = _eat(:key, :in))
        op = op.text

        _eat :space
        _expect :punct, "("

        right = AST::Atom.new(:list, _parse_list)
        _eat :space
        _expect :punct, ")"

      elsif (op = _eat(:punct, /<=|<>|>=|=|<|>/) || _eat(:key, /^i?like$/))
        op = op.text
        right = _parse_expr3
      end

      if right
        AST::Expr.new(left, op, right, not_kw != nil)
      elsif not_kw
        raise UnexpectedToken, "got #{not_kw.inspect}"
      else
        left
      end
    end

    def _parse_expr3
      _eat :space

      if (op = (_eat(:punct, /[-+]/) || _eat(:key, /^(not|distinct)$/)))
        _eat :space
        AST::Unary.new(op.text, _parse_expr3)

      else
        atom = _parse_atom
        _eat :space

        if _eat(:punct, "[")
          subscript = _parse_expr1
          _eat :space
          _expect(:punct, "]")
          _eat :space

          atom = AST::Subscript.new(atom, subscript)
        end

        if _eat(:punct, "::")
          _eat :space
          type = _parse_atom
          _eat :space

          atom = AST::TypeCast.new(atom, type)
        end

        if (op = _eat(:punct, /[-+*\/]/))
          _eat :space
          AST::Expr.new(atom, op.text, _parse_expr3)
        else
          atom
        end
      end
    end

    def _parse_atom
      if (lit = _eat(:lit))
        AST::Atom.new(:lit, lit.text)

      elsif _eat(:key, :case)
        _parse_case

      elsif _eat(:punct, "(")
        expr = _parse_expr1
        _eat :space
        _expect(:punct, ")")
        AST::Parens.new(expr)

      elsif _eat(:key, :null)
        AST::Atom.new(:lit, "NULL")

      elsif _eat(:punct, "*")
        AST::Atom.new(:lit, "*")

      else
        id = _expect(:id)

        if _eat(:punct, "(")
          args = _parse_list
          _expect(:punct, ")")
          AST::Atom.new(:func, id.text, args)
        elsif _eat(:punct, '.')
          id2 = _eat(:id) || _eat(:punct, '*')

          if !id2
            raise UnexpectedToken, "expected id or *, got #{_peek.inspect}"
          end

          AST::Atom.new(:attr, id.text, id2.text)
        else
          AST::Atom.new(:attr, id.text)
        end
      end
    end

    def _parse_case
      _expect :space

      kase = AST::Atom.new(:case)
      unless _peek(:key, :when)
        kase.left = _parse_expr1
        _eat :space
      end

      cases = []
      while _eat(:key, :when)
        condition = _parse_expr1
        _eat :space
        _expect :key, :then
        result = _parse_expr1
        cases << [condition, result]
        _eat :space
      end

      if _eat(:key, :else)
        cases << _parse_expr1
        _eat :space
      end

      _expect :key, :end

      kase.right = cases
      kase
    end

    # list := ''
    #       | expr
    #       | expr ',' args
    def _parse_list
      _eat :space
      args = []

      loop do
        args << _parse_expr1

        _eat :space
        if _eat(:punct, ",")
          _eat :space
        else
          break
        end
      end

      args
    end

    def _eat(type_or_types, pattern=nil)
      _next if _peek(type_or_types, pattern)
    end

    def _peek(type_or_types, pattern=nil)
      token = _next
      _match(token, type_or_types, pattern)
    ensure
      @tokenizer.push(token)
    end

    def _match(token, type_or_types, pattern=nil)
      types = type_or_types.is_a?(Array) ? type_or_types : [ type_or_types ]

      if types.include?(token.type) && (pattern.nil? || pattern === token.text)
        token
      else
        nil
      end
    end

    def _expect(type_or_types, pattern=nil)
      token = _next

      if !_match(token, type_or_types, pattern)
        raise UnexpectedToken, "expected #{type_or_types.inspect}(#{pattern.inspect}), got #{token.inspect}"
      end

      token
    end

    def _next
      @tokenizer.next
    end

    def _ensure_stream_empty!
      unless _peek(:eof)
        raise TrailingTokens, _next.inspect
      end
    end

  end
end

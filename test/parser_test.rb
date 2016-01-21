require 'test_helper'

class ParserTest < Minitest::Test
  def test_it_should_parse_number_as_expression
    expr = _parser("5").parse_expression
    assert_instance_of SQLPP::AST::Atom, expr
    assert_equal :lit, expr.type
    assert_equal "5", expr.left
  end

  def test_it_should_parse_string_as_expression
    expr = _parser("'hello'").parse_expression
    assert_instance_of SQLPP::AST::Atom, expr
    assert_equal :lit, expr.type
    assert_equal "'hello'", expr.left
  end

  def test_it_should_parse_id_as_expression
    expr = _parser("hello").parse_expression
    assert_instance_of SQLPP::AST::Atom, expr
    assert_equal :attr, expr.type
    assert_equal "hello", expr.left
  end

  def test_it_should_parse_star_as_expression
    expr = _parser("*").parse_expression
    assert_instance_of SQLPP::AST::Atom, expr
    assert_equal :lit, expr.type
    assert_equal "*", expr.left
  end

  def test_it_should_parse_function_as_expression
    expr = _parser("sum(donuts)").parse_expression
    assert_instance_of SQLPP::AST::Atom, expr
    assert_equal :func, expr.type
    assert_equal "sum", expr.left
    assert_equal 1, expr.right.count

    assert_instance_of SQLPP::AST::Atom, expr.right[0]
    assert_equal :attr, expr.right[0].type
    assert_equal "donuts", expr.right[0].left
  end

  def test_it_should_parse_parenthesized_expression
    expr = _parser("(donuts)").parse_expression
    assert_instance_of SQLPP::AST::Parens, expr
    assert_instance_of SQLPP::AST::Atom, expr.value
    assert_equal :attr, expr.value.type
    assert_equal "donuts", expr.value.left
  end

  def test_it_should_parse_qualified_references
    expr = _parser("foo.bar").parse_expression
    assert_instance_of SQLPP::AST::Atom, expr
    assert_equal :attr, expr.type
    assert_equal "foo", expr.left
    assert_equal "bar", expr.right
  end

  def test_it_should_treat_null_as_literal
    expr = _parser("NULL").parse_expression
    assert_instance_of SQLPP::AST::Atom, expr
    assert_equal :lit, expr.type
    assert_equal "NULL", expr.left
  end

  def test_it_should_parse_case_with_root_expression
    expr = _parser("case x when 5 then 1 end").parse_expression
    assert_instance_of SQLPP::AST::Atom, expr
    assert_equal :case, expr.type
    assert_equal "x", expr.left.left
    assert_equal 1, expr.right.length
    assert_equal 2, expr.right[0].length
    assert_equal "5", expr.right[0][0].left
    assert_equal "1", expr.right[0][1].left
  end

  def test_it_should_parse_case_without_root_expression
    expr = _parser("case when 5 then 1 end").parse_expression
    assert_instance_of SQLPP::AST::Atom, expr
    assert_equal :case, expr.type
    assert_nil expr.left
    assert_equal 1, expr.right.length
    assert_equal 2, expr.right[0].length
    assert_equal "5", expr.right[0][0].left
    assert_equal "1", expr.right[0][1].left
  end

  def test_it_should_parse_case_with_else_expression
    expr = _parser("case when 5 then 1 else 3 end").parse_expression
    assert_instance_of SQLPP::AST::Atom, expr
    assert_equal :case, expr.type
    assert_nil expr.left
    assert_equal 2, expr.right.length
    assert_equal 2, expr.right[0].length
    assert_equal "5", expr.right[0][0].left
    assert_equal "1", expr.right[0][1].left
    assert_equal "3", expr.right[1].left
  end

  def test_it_should_parse_unary_plus
    expr = _parser("+x").parse_expression
    assert_instance_of SQLPP::AST::Unary, expr
    assert_equal "+", expr.op
    assert_equal "x", expr.expr.left
  end

  def test_it_should_parse_unary_minus
    expr = _parser("-x").parse_expression
    assert_instance_of SQLPP::AST::Unary, expr
    assert_equal "-", expr.op
    assert_equal "x", expr.expr.left
  end

  def test_it_should_parse_arithmatic
    %w(+ - * /).each do |op|
      expr = _parser("x #{op} y").parse_expression
      assert_instance_of SQLPP::AST::Expr, expr
      assert_instance_of SQLPP::AST::Atom, expr.left
      assert_equal op, expr.op
      assert_instance_of SQLPP::AST::Atom, expr.right
    end
  end

  def test_it_should_parse_between
    expr = _parser("x between y and z").parse_expression
    assert_instance_of SQLPP::AST::Expr, expr
    assert_instance_of SQLPP::AST::Atom, expr.left
    assert_equal :between, expr.op
    assert_instance_of SQLPP::AST::Atom, expr.right
    assert_equal :range, expr.right.type
    assert_instance_of SQLPP::AST::Atom, expr.right.left
    assert_instance_of SQLPP::AST::Atom, expr.right.right
  end

  def test_it_should_parse_like
    expr = _parser("x like y").parse_expression
    assert_instance_of SQLPP::AST::Expr, expr
    assert_instance_of SQLPP::AST::Atom, expr.left
    assert_equal :like, expr.op
    assert_instance_of SQLPP::AST::Atom, expr.right
  end

  def test_it_should_parse_ilike
    expr = _parser("x ilike y").parse_expression
    assert_instance_of SQLPP::AST::Expr, expr
    assert_instance_of SQLPP::AST::Atom, expr.left
    assert_equal :ilike, expr.op
    assert_instance_of SQLPP::AST::Atom, expr.right
  end

  def test_it_should_parse_in
    expr = _parser("x in (1,2,3,4,5)").parse_expression
    assert_instance_of SQLPP::AST::Expr, expr
    assert_instance_of SQLPP::AST::Atom, expr.left
    assert_equal :in, expr.op
    assert_instance_of SQLPP::AST::Atom, expr.right
    assert_equal :list, expr.right.type
    assert_equal 5, expr.right.left.length
  end

  def test_it_should_parse_boolean_operations
    %w(< <= <> != = >= >).each do |op|
      expr = _parser("x #{op} y").parse_expression
      assert_instance_of SQLPP::AST::Expr, expr
      assert_instance_of SQLPP::AST::Atom, expr.left
      assert_equal op, expr.op
      assert_instance_of SQLPP::AST::Atom, expr.right
    end
  end

  def test_it_should_parse_expr_operations
    [:is, "is not", :and, :or].each do |op|
      expr = _parser("x #{op} y").parse_expression
      assert_instance_of SQLPP::AST::Expr, expr
      assert_instance_of SQLPP::AST::Atom, expr.left
      assert_equal op, expr.op
      assert_instance_of SQLPP::AST::Atom, expr.right
    end
  end

  def test_it_should_parse_distinct_expression
    expr = _parser("count(distinct id)").parse_expression
    assert_instance_of SQLPP::AST::Atom, expr
    assert_equal :func, expr.type
    assert_equal 1, expr.right.count

    assert_instance_of SQLPP::AST::Unary, expr.right[0]
    assert_equal :distinct, expr.right[0].op
    assert_instance_of SQLPP::AST::Atom, expr.right[0].expr
    assert_equal :attr, expr.right[0].expr.type
    assert_equal "id", expr.right[0].expr.left
  end

  def test_from_should_recognize_single_attr
    from = _parser("x").parse_from
    assert_instance_of SQLPP::AST::Atom, from
  end

  def test_from_should_recognize_alias
    from = _parser("x y").parse_from
    assert_instance_of SQLPP::AST::Alias, from
    assert_equal "y", from.name
    assert_instance_of SQLPP::AST::Atom, from.expr
  end

  def test_from_should_recognize_as
    from = _parser("x AS y").parse_from
    assert_instance_of SQLPP::AST::As, from
    assert_equal "y", from.name
    assert_instance_of SQLPP::AST::Atom, from.expr
  end

  def test_from_may_be_parenthesized
    from = _parser("( x ) AS y").parse_from
    assert_instance_of SQLPP::AST::As, from
    assert_equal "y", from.name
    assert_instance_of SQLPP::AST::Parens, from.expr
    assert_instance_of SQLPP::AST::Atom, from.expr.value
  end

  def test_from_may_be_a_subselect
    from = _parser("(select * from x) as y").parse_from
    assert_instance_of SQLPP::AST::As, from
    assert_instance_of SQLPP::AST::Parens, from.expr
    assert_instance_of SQLPP::AST::Select, from.expr.value
  end

  def test_from_may_join_to_another_entity
    [ "inner",
      "left outer",
      "right outer",
      "full outer",
      "cross"
    ].each do |type|
      from = _parser("x #{type} join y AS z ON x.id = z.id").parse_from
      assert_instance_of SQLPP::AST::Join, from
      assert_instance_of SQLPP::AST::Atom, from.left
      assert_equal type, from.type
      assert_instance_of SQLPP::AST::As, from.right
      assert_instance_of SQLPP::AST::Expr, from.on
    end
  end

  def test_chained_join_will_build_tree
    from = _parser("x inner join y on x.id = y.id inner join z on x.id = z.id").parse_from
    assert_instance_of SQLPP::AST::Join, from
    assert_instance_of SQLPP::AST::Join, from.left
  end

  def test_accepts_select_with_projections
    s = _parser("select x, y").parse_select
    assert_instance_of SQLPP::AST::Select, s
    assert_equal 2, s.projections.length
  end

  def test_accepts_select_with_froms
    s = _parser("select from x, y").parse_select
    assert_instance_of SQLPP::AST::Select, s
    assert_equal 2, s.froms.length
  end

  def test_accepts_select_with_where
    s = _parser("select from x where x > 5 and z < 2").parse_select
    assert_instance_of SQLPP::AST::Select, s
    assert_instance_of SQLPP::AST::Expr, s.wheres
  end

  def test_accepts_select_with_group_by
    s = _parser("select * from x group by a, b").parse_select
    assert_instance_of SQLPP::AST::Select, s
    assert_equal 2, s.groups.length
  end

  def test_accepts_select_with_order_by
    s = _parser("select * from x order by a ASC, b DESC NULLS LAST").parse_select
    assert_instance_of SQLPP::AST::Select, s
    assert_equal 2, s.orders.length
    assert_instance_of SQLPP::AST::SortKey, s.orders[0]
    assert_equal [:asc], s.orders[0].options
    assert_instance_of SQLPP::AST::SortKey, s.orders[1]
    assert_equal [:desc, "nulls last"], s.orders[1].options
  end

  def test_accepts_select_distinct
    s = _parser("select distinct * from x").parse_select
    assert_instance_of SQLPP::AST::Select, s
    assert_equal s.distinct, true
  end

  def test_parse_should_recognize_select
    s = _parser("select * from x").parse
    assert_instance_of SQLPP::AST::Select, s
  end

  def _parser(string)
    SQLPP::Parser.new(string)
  end
end

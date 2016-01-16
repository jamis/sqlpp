require 'test_helper'

class FormatterTest < Minitest::Test
  def test_format_select
    ast = _parser("select a, b, c from table where x > 5 and z between 1 and 2 or (y IS NULL) group by a, b order by z ASC").parse

    assert_equal <<-SQL, _format(ast)
SELECT a, b, c
FROM table
WHERE x > 5
AND z BETWEEN 1 AND 2
OR (y IS NULL)
GROUP BY a, b
ORDER BY z ASC
SQL
  end

  def test_format_subselect
    ast = _parser("select a, b, c from (select d,e,f from table where table.id in (1,2,3)) subselect where x > 5 group by a, b order by z ASC").parse

    assert_equal <<-SQL, _format(ast)
SELECT a, b, c
FROM (
  SELECT d, e, f
  FROM table
  WHERE table.id IN (1, 2, 3)
) subselect
WHERE x > 5
GROUP BY a, b
ORDER BY z ASC
SQL
  end

  def _parser(string)
    SQLPP::Parser.new(string)
  end

  def _format(ast)
    SQLPP::Formatter.new.format(ast)
  end
end

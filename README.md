# SQLPP

SQLPP is a simplistic SQL parser and pretty-printer.

## Usage

```ruby
require 'sqlpp'

sql = "..."
ast = SQLPP::Parser.parse(sql)

puts SQLPP::Formatter.new.format(ast)
```

Or, you can use the included `bin/sqlpp` script to format SQL via STDIN:

```sh
$ sqlpp < query.sql
```

## Output

The formatter is not particularly sophisticated, and is optimized primarily for displaying queries with deeply nested subselects. The major query components (`FROM`, `WHERE`, `GROUP BY`, and `ORDER BY`) are printed on separate lines, with subselects indented.

```sql
SELECT a, b, sum(c)
FROM (
  SELECT d, e, f
  FROM (
    SELECT g, h, i
    FROM table
    WHERE id IN (1, 2, 3)
  ) a
  WHERE a.e = 5
  OR a.e = 7
) b
WHERE b.c > 5
GROUP BY a, b
ORDER BY a ASC, b DESC
```

## Caveats

This implementation is far, far, far from complete. It currently accepts only `SELECT` statements, and even then will only recognize a subset of the valid SQL syntax. That said, it should be a pretty big subset. It's done well enough for what I've needed it for.

If, however, you find that it doesn't recognize some syntax that you need, pull requests would be appreciated!

## License

MIT. See `MIT-LICENSE`.

## Author

Jamis Buck (jamis@jamisbuck.org)

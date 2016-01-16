module SQLPP
  module AST
    class Select < Struct.new(:projections, :froms, :wheres, :groups, :orders)
    end

    class Expr < Struct.new(:left, :op, :right)
    end

    class Unary < Struct.new(:op, :expr)
    end

    class Atom < Struct.new(:type, :left, :right)
    end

    class Parens < Struct.new(:value)
    end

    class As < Struct.new(:name, :expr)
    end

    class Alias < Struct.new(:name, :expr)
    end

    class Join < Struct.new(:type, :left, :right, :on)
    end

    class SortKey < Struct.new(:key, :options)
    end
  end
end

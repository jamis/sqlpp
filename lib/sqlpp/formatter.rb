module SQLPP
  class Formatter
    def initialize(projections: nil)
      @indent = nil
      @state = nil

      @projections = projections
    end

    def format(node)
      name = node.class.to_s.split(/::/).last
      send(:"_format_#{name}", node)
    end

    def _format_Select(node)
      output = ""

      if @indent.nil?
        @indent = 0
      else
        @indent += 2
        output << "\n"
      end

      output << (select = "#{_indent}SELECT ")
      output << "DISTINCT " if node.distinct
      link = ","
      link << ((@projections == :wrap) ? "\n#{" " * select.length}" : " ")
      output << node.projections.map { |c| format(c) }.join(link)
      output << "\n"

      if node.froms
        output << "#{_indent}FROM "
        output << node.froms.map { |c| format(c) }.join(", ")
        output << "\n"
      end

      if node.wheres
        save, @state = @state, :where
        output << "#{_indent}WHERE "
        output << format(node.wheres)
        output << "\n"
        @state = save
      end

      if node.groups
        output << "#{_indent}GROUP BY "
        output << node.groups.map { |c| format(c) }.join(", ")
        output << "\n"
      end

      if node.orders
        output << "#{_indent}ORDER BY "
        output << node.orders.map { |c| format(c) }.join(", ")
        output << "\n"
      end

      @indent -= 2
      @indent = nil if @indent < 0

      output << _indent
    end

    def _format_Expr(node)
      output = format(node.left)
      if node.op
        op = node.op.to_s.upcase

        if @state == :where && %w(AND OR).include?(op)
          output << "\n#{_indent}"
        else
          output << " "
        end

        output << op << " "
        output << format(node.right)
      end
      output
    end

    def _format_Unary(node)
      op = node.op.to_s.upcase
      output = op
      output << " " if op =~ /\w/
      output << format(node.expr)
    end

    def _format_Atom(node)
      output = ""

      case node.type
        when :range
          output << format(node.left) << " AND " << format(node.right)
        when :list
          output << "(" << node.left.map { |c| format(c) }.join(", ") << ")"
        when :func
          output << format(node.left) << "("
          output << node.right.map { |c| format(c) }.join(", ")
          output << ")"
        when :lit
          output << node.left
        when :attr
          output << node.left
          output << "." << node.right if node.right
        when :case
          output << "CASE "
          output << format(node.left) << " " if node.left
          node.right.each do |child|
            if child.is_a?(Array)
              output << "WHEN " << format(child[0]) << " "
              output << "THEN " << format(child[1]) << " "
            else
              output << "ELSE " << format(child) << " "
            end
          end
          output << "END"
        else
          raise ArgumentError, "unknown atom type #{node.type.inspect}"
      end

      output
    end

    def _format_Parens(node)
      "(" + format(node.value) + ")"
    end

    def _format_As(node)
      format(node.expr) + " AS " + format(node.name)
    end

    def _format_Alias(node)
      format(node.expr) + " " + format(node.name)
    end

    def _format_Join(node)
      output = ""

      output << format(node.left)
      output << "\n#{_indent}"
      output << node.type.upcase << " JOIN "
      output << format(node.right)
      output << "\n#{_indent}ON " << format(node.on) if node.on

      output
    end

    def _format_SortKey(node)
      output = ""
      output << format(node.key)

      if node.options.any?
        output << " "
        output << node.options.map { |opt| opt.upcase }.join(", ")
      end

      output
    end

    def _format_String(string)
      string
    end

    def _indent
      " " * (@indent || 0)
    end
  end
end

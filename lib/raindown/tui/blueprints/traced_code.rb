# frozen_string_literal: true

require_relative '../feelings/code_methods'

module Raindown
  module TUI
    # The code a blueprint's box names, found among the project's methods, read once, when they're first needed, and which
    # of it's shown.
    module TracedCode
      # The code the box names, each once, in the order it names it: by a method, like Watcher.listen or
      # Navigator#next_step, or a class, like Workers, whose first method it is, or a method's name alone that only one
      # method has.
      def codes(box)
        (@codes ||= {})[box] ||= box.text.scan(/[A-Z]\w*(?:::\w+)*(?:[.#][a-z_]\w*[?!]?)?|[a-z_]\w*[?!]?/).filter_map { named(it) }.uniq
      end

      # The code shown of what the selected box names, which Space or a click on the box moves on to the next of, or nil.
      def code
        named = codes(boxes[box]) if box
        named[@code % named.length] if named&.any?
      end

      private

      # The box at the index, showing the first code it names, from its first lines.
      def select_box(index)
        @box = index
        @code = 0
        @expanded = false
        follow
        nil
      end

      def next_code
        @code += 1
        @expanded = false
        nil
      end

      # The method a name in a box names, by its owner and name, or its owner's first, or its name if only one has it.
      def named(name)
        owner, method = name.split(/[.#]/, 2)
        owner = owner.split('::').last
        return methods.find { it.owner == owner && it.name == method } if method
        return first_method(owner) if owner.match?(/\A[A-Z]/)

        found = methods.select { it.name == name }
        found.first if found.one?
      end

      def first_method(owner) = methods.select { it.owner == owner }.min_by { [it.path, it.line] }

      def methods = @methods ||= CodeMethods.list(@root)
    end
  end
end

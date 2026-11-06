# frozen_string_literal: true

require 'antlers/api'
require 'nodes/html_node'
require_relative '../raindown/context'
require_relative '../raindown/fragments'
require_relative '../raindown/node_blocks'
require_relative '../raindown/nodes'

module Raindown
  # A write-in node, in <{ }>, which Antlers renders where it is in the template, so its props see loop variables, like
  # <{ Card name=p.name }> in a for: loop. It only renders, with its render, never its rewrite, and the Markdown
  # between its tags, <{ Card: }> to <{ :Card }>, is its slot, rendered to HTML in its scope first.
  # One with a class template, like Raindeer's .rbx components, renders its template, with that HTML as its slot.
  class WriteInNode < Antlers::BranchNode
    DEF_KEY = :node_def
    END_KEY = :node_end

    def initialize(name:, args: '', **)
      super(name:)

      @args = args
    end

    def render(current_binding: nil, context: Context.new, **)
      slot = Raindown.commonmark(super) unless @children.empty?
      props, args = NodeBlocks.args(@args, BoundVariables.new(current_binding))
      node = Nodes.instance(node_class, props, args || [])
      return Fragments.add(template_html(node, props, slot.to_s, current_binding)) if Nodes.template?(node.class)

      Nodes.rendered(node, context, slot: slot.to_s)
    end

    def end_name
      @name
    end

    private

    # A render-only component, like Card, isn't a node Nodes finds, as it has no rewrite, so it's any class of the name.
    def node_class
      klass = Nodes.node_class(@name)
      return klass if klass
      raise NameError, "No node is named #{@name}, for <{ :#{@name} }>" unless @name.match?(/\A[A-Z]/)

      Object.const_get(@name)
    end

    # The node's class template, whose slot is the HTML in place of its children.
    def template_html(node, props, slot, parent_binding)
      children = @children
      @children = [Antlers::HTMLNode.new(html: slot)]
      node.render_template(parent_binding:, slot_node: self, props:)
    ensure
      @children = children
    end

    class << self
      def match?(segment:)
        segment[DEF_KEY]
      end

      def build(segment:, **)
        new(name: segment[DEF_KEY], args: segment[:args])
      end
    end
  end

  # <{ Card }>, or <{ :Card }> when it doesn't end a block, which a lowercase name needs, like <{ :toc }>.
  class SoloWriteInNode < WriteInNode
    END_KEY = nil

    def self.match?(segment:)
      segment[:node_solo] || segment[:node_end]
    end

    def self.build(segment:, **)
      new(name: segment[:node_solo] || segment[:node_end], args: segment[:args])
    end
  end

  # The variables where Antlers renders a node, like a loop's, and then the front matter's, as its props read them.
  class BoundVariables < BasicObject
    def initialize(binding)
      @binding = binding
    end

    # A name that can't be a local, like a-b, is only looked for in the front matter.
    def send(name)
      return @binding.local_variable_get(name) if name.match?(/\A[a-z_]\w*\z/) && @binding.local_variable_defined?(name)

      @binding.receiver.send(name)
    end
  end
end

# frozen_string_literal: true

# A component for the render tree specs, which takes its props and slot as keywords.
class SpecCard
  def initialize(name: nil)
    @name = name
  end

  def render(slot: nil)
    %(<section data-name="#{@name}">#{slot}</section>\n)
  end
end

# A component with only render, which says how long its document is and how many times it has rendered.
class SpecDocumentLength
  def initialize
    @count = 0
  end

  def render(document:)
    @count += 1
    %(<p data-count="#{@count}">#{document.length}</p>)
  end
end

module Quartz
  class DotVisitor
    include Visitor

    def initialize(@root : CoupledModel, @io : IO)
    end

    def to_graph
      @io.puts "digraph"
      @io.puts '{'
      @io.puts "compound = true;"
      @io.puts "rankdir = LR;"
      @io.puts "node [shape = box];"

      @root.accept(self)

      @io.puts '}'
    end

    # Visit multipdevs components so that they appear in the graph
    @[AlwaysInline]
    def visit_children?(model : MultiComponent::Model)
      true
    end

    def visit(model : CoupledModel)
      return if model == @root

      @io.puts "subgraph \"cluster_#{model.name}\""
      @io.puts '{'
      @io.puts "label = \"#{model.name}\";"
    end

    def end_visit(model : CoupledModel)
      if model == @root
        model.find_direct_couplings do |src, dst|
          @io.puts "\"#{src.host.name.to_s}\" -> \"#{dst.host.name.to_s}\" [label=\"#{src.name.to_s} → #{dst.name.to_s}\"];"
        end
      else
        model.each_internal_coupling do |src, dst|
          if src.host.is_a?(AtomicModel) && dst.host.is_a?(AtomicModel)
            @io.puts "\"#{src.host.name.to_s}\" -> \"#{dst.host.name.to_s}\" [label=\"#{src.name.to_s} → #{dst.name.to_s}\"];"
          end
        end
        @io.puts "};"
      end
    end

    def visit(model : MultiComponent::Model)
      @io.puts "subgraph \"cluster_#{model.name}\""
      @io.puts '{'
      @io.puts "label = \"#{model.name}\";"
    end

    def end_visit(model : MultiComponent::Model)
      @io.puts "};"
    end

    def visit(model)
      @io.puts "\"#{model.name}\" [style=filled];"
    end
  end
end

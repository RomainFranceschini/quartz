module DEVS
  abstract class EventSetFactory(T)
    def self.new_event_set(event_set)
      case event_set
      # when :ladder_queue then LadderQueue(T).new
      # when :binary_heap then BinaryHeap(T).new
      # when :minimal_list then MinimalList(T).new
      # when :sorted_list then SortedList(T).new
      # when :splay_tree then SplayTree(T).new
      when :calendar_queue then CalendarQueue(T).new
      else CalendarQueue(T).new
      end
    end
  end
end

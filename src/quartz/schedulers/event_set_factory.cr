module Quartz
  abstract class EventSetFactory(T)
    def self.new_event_set(event_set) : EventSet(T)
      case event_set
      # when :binary_heap then BinaryHeap(T).new
      # when :minimal_list then MinimalList(T).new
      # when :sorted_list then SortedList(T).new
      # when :splay_tree then SplayTree(T).new
      when :ladder_queue   then LadderQueue(T).new
      when :calendar_queue then CalendarQueue(T).new
      else
        if (logger = Quartz.logger?) && logger.warn?
          logger.warn("Unknown event set '#{event_set}', defaults to calendar queue")
        end
        CalendarQueue(T).new
      end
    end
  end
end

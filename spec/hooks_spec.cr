require "./spec_helper"

private class MyNotifiable
  include Hooks::Notifiable

  getter calls : Int32 = 0

  def notify(hook : Symbol)
    @calls += 1
  end
end

describe "Hooks" do
  describe "#subscribe" do
    it "accepts blocks" do
      notifier = Hooks::Notifier.new
      notifier.subscribe(:foo) {}
    end

    it "accepts notifiable" do
      notifier = Hooks::Notifier.new
      notifier.subscribe(:foo, MyNotifiable.new)
    end
  end

  describe "#count_listeners" do
    it "counts listeners for a given hook" do
      notifier = Hooks::Notifier.new
      notifier.subscribe(:foo) {}
      notifier.subscribe(:foo, MyNotifiable.new)
      notifier.count_listeners(:foo).should eq(2)

      myproc = ->(s : Symbol) {}
      mynotifiable = MyNotifiable.new

      notifier.subscribe(:bar, &myproc)
      notifier.subscribe(:bar, mynotifiable)
      notifier.count_listeners(:bar).should eq(2)
      notifier.unsubscribe(:bar, myproc)
      notifier.count_listeners(:bar).should eq(1)
      notifier.unsubscribe(:bar, mynotifiable)
      notifier.count_listeners(:bar).should eq(0)
    end

    it "counts all listeners" do
      notifier = Hooks::Notifier.new
      notifier.subscribe(:foo) {}
      notifier.subscribe(:bar) {}
      notifier.count_listeners.should eq(2)
    end
  end

  describe "#notify" do
    it "notifies right subscribers" do
      notifier = Hooks::Notifier.new
      notifiable = MyNotifiable.new
      notifier.subscribe(:foo, notifiable)
      calls = 0
      block = Proc(Symbol,Nil).new { calls+=1 }
      notifier.subscribe(:bar, &block)

      notifier.notify(:foo)
      notifiable.calls.should eq(1)
      calls.should eq(0)

      notifier.notify(:bar)
      calls.should eq(1)
      notifiable.calls.should eq(1)
    end
  end

  describe "#clear" do
    it "clears all subscribers" do
      notifier = Hooks::Notifier.new
      notifiable = MyNotifiable.new
      notifier.subscribe(:foo, notifiable)
      calls = 0
      block = Proc(Symbol,Nil).new { calls+=1 }
      notifier.subscribe(:bar, &block)

      notifier.clear

      notifier.notify(:foo)
      notifiable.calls.should eq(0)
      notifier.notify(:bar)
      calls.should eq(0)

      notifier.unsubscribe(:foo, notifiable).should be_false
      notifier.unsubscribe(:bar, block).should be_false
    end

    it "clears subscribers of given hook" do
      notifier = Hooks::Notifier.new
      notifiable = MyNotifiable.new
      notifier.subscribe(:foo, notifiable)

      j = 0
      block = Proc(Symbol,Nil).new { j+=1 }
      notifier.subscribe(:bar, &block)

      notifier.clear(:foo)

      notifier.notify(:bar)
      notifier.notify(:foo)

      notifiable.calls.should eq(0)
      j.should eq(1)
      notifier.unsubscribe(:foo, notifiable).should be_false
      notifier.unsubscribe(:bar, block).should be_true
    end
  end

  describe "#unsubscribe" do
    it "is falsey when subscriber doesn't exist" do
      notifier = Hooks::Notifier.new
      notifiable = MyNotifiable.new
      notifiable2 = MyNotifiable.new
      notifier.subscribe(:bar, notifiable)

      notifier.unsubscribe(:foo, notifiable).should be_false
      notifier.unsubscribe(:bar, notifiable2).should be_false
    end

    it "is truthy when successful" do
      notifier = Hooks::Notifier.new
      notifiable = MyNotifiable.new
      notifiable2 = MyNotifiable.new
      calls = 0
      block = Proc(Symbol,Nil).new { calls+=1 }

      notifier.subscribe(:foo, notifiable)
      lost_calls = 0
      notifier.subscribe(:foo) { lost_calls += 1 }
      notifier.subscribe(:bar, notifiable2)
      notifier.subscribe(:bar, &block)

      notifier.unsubscribe(:foo, notifiable).should be_true
      notifier.notify(:foo)
      notifiable.calls.should eq(0)
      lost_calls.should eq(1)
      notifier.clear(:foo)
      notifier.notify(:foo)
      lost_calls.should eq(1)

      notifier.unsubscribe(:bar, notifiable2).should be_true
      notifier.unsubscribe(:bar, block).should be_true
      notifier.notify(:bar)
      notifiable2.calls.should eq(0)
      calls.should eq(0)
    end
  end
end

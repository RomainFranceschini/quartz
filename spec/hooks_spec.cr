require "./spec_helper"

class MyNotifiable
  include Hooks::Notifiable

  getter calls : Int32 = 0

  def notify(hook : Symbol)
    @calls += 1
  end
end

class RaiseNotifiable < MyNotifiable
  def notify(hook : Symbol)
    super(hook)
    raise "ohno"
  end
end

describe "Hooks" do
  describe "implementation" do

    describe "subscribe" do
      it "accepts blocks" do
        notifier = Hooks::Notifier.new
        notifier.subscribe(:foo) {}
      end

      it "accepts notifiable" do
        notifier = Hooks::Notifier.new
        notifier.subscribe(:foo, MyNotifiable.new)
      end
    end

    describe "notify" do
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

      it "doens't fails when a subscriber raises" do
        notifier = Hooks::Notifier.new
        notifier.subscribe(:foo) { raise "ohno" }
        notifier.subscribe(:foo, RaiseNotifiable.new)
        notifier.notify(:foo)
      end

      it "automatically unsubscribes notifiables that raised" do
        notifier = Hooks::Notifier.new
        notifiable = RaiseNotifiable.new
        notifier.subscribe(:foo, notifiable)
        calls = 0
        raiser = Proc(Symbol,Nil).new { calls+=1; raise "ohno" }
        notifier.subscribe(:foo, &raiser)

        notifier.notify(:foo)
        notifier.notify(:foo)

        notifiable.calls.should eq(1)
        calls.should eq(1)

        notifier.unsubscribe(:foo, notifiable).should be_false
        notifier.unsubscribe(:foo, raiser).should be_false
      end
    end

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
      calls = 0
      block = Proc(Symbol,Nil).new { calls+=1 }
      notifier.subscribe(:bar, &block)

      notifier.clear(:bar)

      notifier.notify(:foo)
      notifiable.calls.should eq(1)
      notifier.notify(:bar)
      calls.should eq(0)

      notifier.unsubscribe(:bar, block).should be_false
    end

    describe "unsubscribe" do
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
end

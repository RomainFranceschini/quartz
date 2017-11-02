require "./spec_helper"

private class Foo
  include Observable
end

private class Bar
  include Observer
  getter calls : Int32 = 0

  def update(observer)
    @calls += 1
  end
end

describe "Observable" do
  it "adds observers" do
    f = Foo.new
    f.add_observer(Bar.new)
    f.count_observers.should eq(1)
  end

  it "counts observers" do
    f = Foo.new
    f.add_observer(Bar.new)
    f.add_observer(Bar.new)
    b = Bar.new
    f.add_observer(b)
    f.count_observers.should eq(3)
    f.delete_observer(b)
    f.count_observers.should eq(2)
  end

  describe "delete observers" do
    it "is truthy when successful" do
      f = Foo.new
      b = Bar.new
      f.add_observer(b)
      f.count_observers.should eq(1)
      f.delete_observer(b).should be_true
      f.count_observers.should eq(0)
    end

    it "is falsy when not successful" do
      Foo.new.delete_observer(Bar.new).should be_false
    end
  end

  describe "notify" do
    it "calls #update for each observer" do
      f = Foo.new
      b = Bar.new
      f.add_observer(b)

      f.notify_observers
      b.calls.should eq(1)
      f.notify_observers
      b.calls.should eq(2)
    end
  end
end

describe "Port" do
  describe "Observable" do
    it "adds an observer to attached atomic models when the host is a coupled" do
      atom = AtomicModel.new("am")
      coupled = CoupledModel.new("cm")
      coupled << atom
      aop = OutputPort.new(atom, "aop")
      cop = OutputPort.new(coupled, "cop")
      coupled.attach(aop, cop)

      observer = Bar.new
      cop.add_observer(observer)

      cop.count_observers.should eq(0)
      aop.count_observers.should eq(1)

      cop.notify_observers
      observer.calls.should eq(0)

      aop.notify_observers
      observer.calls.should eq(1)
    end
  end
end

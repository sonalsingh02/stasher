require 'spec_helper'

describe Stasher::CurrentScope do
  describe '.clear!' do
    before :each do
      Stasher::CurrentScope.fields[:foo] = 'bar'
      Stasher::CurrentScope.fields[:baz] = { :bat => "man" }
    end

    it "removes all existing fields" do
      Stasher::CurrentScope.clear!

      Stasher::CurrentScope.fields.should == {}
    end
  end

  describe ".fields" do 
    before :each do
      Stasher::CurrentScope.fields = { :foo => "bar" }
    end

    it "can retrive a value" do
      Stasher::CurrentScope.fields[:foo].should == "bar"
    end
  end

  describe ".fields=" do 
    it "can assign all fields at once" do
      Stasher::CurrentScope.fields = { :foo => "bar" }

      Stasher::CurrentScope.fields[:foo].should == "bar"
    end

    it "overwrites exisitng fields" do
      Stasher::CurrentScope.fields[:baz] = { :bat => "man" }

      Stasher::CurrentScope.fields = { :foo => "bar" }

      Stasher::CurrentScope.fields.should == { :foo => "bar" }
    end
  end
end
# encoding: utf-8
require 'bigdecimal'
require_relative 'normalise_single_cost'

unless String.respond_to?(:blank?)
  class String
    def blank?
      self.strip.length == 0
    end
  end
end

unless NilClass.respond_to?(:blank?)
  class NilClass
    def blank?
      true
    end
  end
end

class Array
  
  def /(other)
    return [self.first/other,self.last/other] unless other.is_a?(Array)
    return [self.first/other.first] if self.size == 1 && other.size == 1
    return [self.first/other.first,self.last/other.first ] if other.size == 1
    return [self.first/other.first,self.first/other.last ] if self.size == 1
    return [self.first/other.last,self.last/other.first ]
  end
end
    
    

class NormaliseCost
  def initialize(original, average_over_peak = nil)
    unless original
      @costs = [NormaliseSingleCost.new(original,average_over_peak)] 
    else
      @costs = original.split(" plus ").map do |c|
        NormaliseSingleCost.new(c.strip,average_over_peak)
      end
    end
  end
  
  def method_missing(method,*args)
    return "?" if @costs.empty?
    @costs.map do |c|
      c.send(method,*args)
    end.inject(nil) do |memo,costs|
      if memo.is_a?(String)
        memo
      elsif costs.is_a?(String)
        costs
      elsif memo
        memo.map.with_index do |sum,i| 
          sum + (costs[i] || costs[0])
        end
      else
        costs
      end
    end
  end
end


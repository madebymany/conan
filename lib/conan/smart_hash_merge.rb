module Conan
  class SmartHashMerge
    def self.merge(lhash, rhash)
      new(lhash, rhash).merge
    end

    def initialize(lhash, rhash)
      @lhash, @rhash = lhash, rhash
    end

    def merge
      lhash = @lhash.dup
      deep_merge(lhash, @rhash)
    end

  private
    def deep_merge(lhash, rhash)
      merged = lhash.dup
      rhash.each do |key, rvalue|
        lvalue = lhash[key]
        if lvalue.is_a?(Hash) and rvalue.is_a?(Hash)
          merged[key] = deep_merge(lhash[key], rhash[key])
        elsif lvalue.is_a?(Array) and rvalue.is_a?(Array)
          merged[key] = lvalue + rvalue
        elsif rvalue.is_a?(Array) && !lvalue.nil?
          merged[key] = [lvalue] + rvalue
        else
          merged[key] = rvalue
        end
      end
      merged
    end
  end
end

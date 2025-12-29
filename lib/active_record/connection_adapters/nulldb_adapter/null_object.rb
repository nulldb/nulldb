class ActiveRecord::ConnectionAdapters::NullDBAdapter
  class NullObject
    def method_missing(*args, &block)
      nil
    end

    def respond_to_missing?(method_name, include_private = false)
      true
    end

    def to_a
      []
    end
  end
end

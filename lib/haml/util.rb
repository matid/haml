require 'erb'
require 'set'
require 'enumerator'
require 'stringio'
require 'haml/root'
require 'haml/util/subset_map'

module Haml
  # A module containing various useful functions.
  module Util
    extend self

    # An array of ints representing the Ruby version number.
    # @api public
    RUBY_VERSION = ::RUBY_VERSION.split(".").map {|s| s.to_i}

    # Returns the path of a file relative to the Haml root directory.
    #
    # @param file [String] The filename relative to the Haml root
    # @return [String] The filename relative to the the working directory
    def scope(file)
      File.join(Haml::ROOT_DIR, file)
    end

    # Converts an array of `[key, value]` pairs to a hash.
    # For example:
    #
    #     to_hash([[:foo, "bar"], [:baz, "bang"]])
    #       #=> {:foo => "bar", :baz => "bang"}
    #
    # @param arr [Array<(Object, Object)>] An array of pairs
    # @return [Hash] A hash
    def to_hash(arr)
      arr.compact.inject({}) {|h, (k, v)| h[k] = v; h}
    end

    # Maps the keys in a hash according to a block.
    # For example:
    #
    #     map_keys({:foo => "bar", :baz => "bang"}) {|k| k.to_s}
    #       #=> {"foo" => "bar", "baz" => "bang"}
    #
    # @param hash [Hash] The hash to map
    # @yield [key] A block in which the keys are transformed
    # @yieldparam key [Object] The key that should be mapped
    # @yieldreturn [Object] The new value for the key
    # @return [Hash] The mapped hash
    # @see #map_vals
    # @see #map_hash
    def map_keys(hash)
      to_hash(hash.map {|k, v| [yield(k), v]})
    end

    # Maps the values in a hash according to a block.
    # For example:
    #
    #     map_values({:foo => "bar", :baz => "bang"}) {|v| v.to_sym}
    #       #=> {:foo => :bar, :baz => :bang}
    #
    # @param hash [Hash] The hash to map
    # @yield [value] A block in which the values are transformed
    # @yieldparam value [Object] The value that should be mapped
    # @yieldreturn [Object] The new value for the value
    # @return [Hash] The mapped hash
    # @see #map_keys
    # @see #map_hash
    def map_vals(hash)
      to_hash(hash.map {|k, v| [k, yield(v)]})
    end

    # Maps the key-value pairs of a hash according to a block.
    # For example:
    #
    #     map_hash({:foo => "bar", :baz => "bang"}) {|k, v| [k.to_s, v.to_sym]}
    #       #=> {"foo" => :bar, "baz" => :bang}
    #
    # @param hash [Hash] The hash to map
    # @yield [key, value] A block in which the key-value pairs are transformed
    # @yieldparam [key] The hash key
    # @yieldparam [value] The hash value
    # @yieldreturn [(Object, Object)] The new value for the `[key, value]` pair
    # @return [Hash] The mapped hash
    # @see #map_keys
    # @see #map_vals
    def map_hash(hash, &block)
      to_hash(hash.map(&block))
    end

    # Computes the powerset of the given array.
    # This is the set of all subsets of the array.
    # For example:
    #
    #     powerset([1, 2, 3]) #=>
    #       Set[Set[], Set[1], Set[2], Set[3], Set[1, 2], Set[2, 3], Set[1, 3], Set[1, 2, 3]]
    #
    # @param arr [Enumerable]
    # @return [Set<Set>] The subsets of `arr`
    def powerset(arr)
      arr.inject([Set.new].to_set) do |powerset, el|
        new_powerset = Set.new
        powerset.each do |subset|
          new_powerset << subset
          new_powerset << subset + [el]
        end
        new_powerset
      end
    end

    # Restricts a number to falling within a given range.
    # Returns the number if it falls within the range,
    # or the closest value in the range if it doesn't.
    #
    # @param value [Numeric]
    # @param range [Range<Numeric>]
    # @return [Numeric]
    def restrict(value, range)
      [[value, range.first].max, range.last].min
    end

    # Concatenates all strings that are adjacent in an array,
    # while leaving other elements as they are.
    # For example:
    #
    #     merge_adjacent_strings([1, "foo", "bar", 2, "baz"])
    #       #=> [1, "foobar", 2, "baz"]
    #
    # @param enum [Enumerable]
    # @return [Array] The enumerable with strings merged
    def merge_adjacent_strings(enum)
      e = enum.inject([]) do |a, e|
        if e.is_a?(String) && a.last.is_a?(String)
          a.last << e
        else
          a << e
        end
        a
      end
    end

    # Intersperses a value in an enumerable, as would be done with `Array#join`
    # but without concatenating the array together afterwards.
    #
    # @param enum [Enumerable]
    # @param val
    # @return [Array]
    def intersperse(enum, val)
      enum.inject([]) {|a, e| a << e << val}[0...-1]
    end

    # Substitutes a sub-array of one array with another sub-array.
    #
    # @param ary [Array] The array in which to make the substitution
    # @param from [Array] The sequence of elements to replace with `to`
    # @param to [Array] The sequence of elements to replace `from` with
    def substitute(ary, from, to)
      res = ary.dup
      i = 0
      while i < res.size
        if res[i...i+from.size] == from
          res[i...i+from.size] = to
        end
        i += 1
      end
      res
    end

    # Destructively strips whitespace from the beginning and end
    # of the first and last elements, respectively,
    # in the array (if those elements are strings).
    #
    # @param arr [Array]
    # @return [Array] `arr`
    def strip_string_array(arr)
      arr.first.lstrip! if arr.first.is_a?(String)
      arr.last.rstrip! if arr.last.is_a?(String)
      arr
    end

    # Return an array of all possible paths through the given arrays.
    #
    # @param arrs [Array<Array>]
    # @return [Array<Arrays>]
    #
    # @example
    # paths([[1, 2], [3, 4], [5]]) #=>
    #   # [[1, 3, 5],
    #   #  [2, 3, 5],
    #   #  [1, 4, 5],
    #   #  [2, 4, 5]]
    def paths(arrs)
      arrs.inject([[]]) do |paths, arr|
        flatten(arr.map {|e| paths.map {|path| path + [e]}}, 1)
      end
    end

    # Computes a single longest common subsequence for `x` and `y`.
    # If there are more than one longest common subsequences,
    # the one returned is that which starts first in `x`.
    #
    # @param x [Array]
    # @param y [Array]
    # @yield [a, b] An optional block to use in place of a check for equality
    #   between elements of `x` and `y`.
    # @yieldreturn [Object, nil] If the two values register as equal,
    #   this will return the value to use in the LCS array.
    # @return [Array] The LCS
    def lcs(x, y, &block)
      x = [nil, *x]
      y = [nil, *y]
      block ||= proc {|a, b| a == b && a}
      lcs_backtrace(lcs_table(x, y, &block), x, y, x.size-1, y.size-1, &block)
    end

    # Returns information about the caller of the previous method.
    #
    # @param entry [String] An entry in the `#caller` list, or a similarly formatted string
    # @return [[String, Fixnum, (String, nil)]] An array containing the filename, line, and method name of the caller.
    #   The method name may be nil
    def caller_info(entry = caller[1])
      info = entry.scan(/^(.*?):(-?.*?)(?::.*`(.+)')?$/).first
      info[1] = info[1].to_i
      # This is added by Rubinius to designate a block, but we don't care about it.
      info[2].sub!(/ \{\}\Z/, '') if info[2]
      info
    end

    # Silence all output to STDERR within a block.
    #
    # @yield A block in which no output will be printed to STDERR
    def silence_warnings
      the_real_stderr, $stderr = $stderr, StringIO.new
      yield
    ensure
      $stderr = the_real_stderr
    end

    @@silence_warnings = false
    # Silences all Haml warnings within a block.
    #
    # @yield A block in which no Haml warnings will be printed
    def silence_haml_warnings
      old_silence_warnings = @@silence_warnings
      @@silence_warnings = true
      yield
    ensure
      @@silence_warnings = old_silence_warnings
    end

    # The same as `Kernel#warn`, but is silenced by \{#silence\_haml\_warnings}.
    #
    # @param msg [String]
    def haml_warn(msg)
      return if @@silence_warnings
      warn(msg)
    end

    ## Cross Rails Version Compatibility

    # Returns the root of the Rails application,
    # if this is running in a Rails context.
    # Returns `nil` if no such root is defined.
    #
    # @return [String, nil]
    def rails_root
      if defined?(Rails.root)
        return Rails.root.to_s if Rails.root
        raise "ERROR: Rails.root is nil!"
      end
      return RAILS_ROOT.to_s if defined?(RAILS_ROOT)
      return nil
    end

    # Returns the environment of the Rails application,
    # if this is running in a Rails context.
    # Returns `nil` if no such environment is defined.
    #
    # @return [String, nil]
    def rails_env
      return Rails.env.to_s if defined?(Rails.root)
      return RAILS_ENV.to_s if defined?(RAILS_ENV)
      return nil
    end

    # Returns whether this environment is using ActionPack
    # version 3.0.0 or greater.
    #
    # @return [Boolean]
    def ap_geq_3?
      # The ActionPack module is always loaded automatically in Rails >= 3
      return false unless defined?(ActionPack) && defined?(ActionPack::VERSION)

      version =
        if defined?(ActionPack::VERSION::MAJOR)
          ActionPack::VERSION::MAJOR
        else
          # Rails 1.2
          ActionPack::VERSION::Major
        end

      version >= 3
    end

    # Returns whether this environment is using ActionPack
    # version 3.0.0.beta.3 or greater.
    #
    # @return [Boolean]
    def ap_geq_3_beta_3?
      # The ActionPack module is always loaded automatically in Rails >= 3
      return false unless defined?(ActionPack) && defined?(ActionPack::VERSION)

      version =
        if defined?(ActionPack::VERSION::MAJOR)
          ActionPack::VERSION::MAJOR
        else
          # Rails 1.2
          ActionPack::VERSION::Major
        end
      version >= 3 &&
        ((defined?(ActionPack::VERSION::TINY) &&
          ActionPack::VERSION::TINY.is_a?(Fixnum) &&
          ActionPack::VERSION::TINY >= 1) ||
         (defined?(ActionPack::VERSION::BUILD) &&
          ActionPack::VERSION::BUILD =~ /beta(\d+)/ &&
          $1.to_i >= 3))
    end

    # Returns whether this environment is using ActionPack
    # version 2.3.6 (or greater, up until 3.0.0).
    #
    # @return [Boolean]
    def ap_2_3_6?
      # Hopefully Rails 2.3.7 will fix the issues that this method hacks around,
      # but for now we'll assume it won't
      require 'action_pack'
      defined?(ActionPack::VERSION::MAJOR) &&
        ActionPack::VERSION::MAJOR == 2 &&
        ActionPack::VERSION::MINOR == 3 &&
        ActionPack::VERSION::TINY >= 6
    end

    # Returns an ActionView::Template* class.
    # In pre-3.0 versions of Rails, most of these classes
    # were of the form `ActionView::TemplateFoo`,
    # while afterwards they were of the form `ActionView;:Template::Foo`.
    #
    # @param name [#to_s] The name of the class to get.
    #   For example, `:Error` will return `ActionView::TemplateError`
    #   or `ActionView::Template::Error`.
    def av_template_class(name)
      return ActionView.const_get("Template#{name}") if ActionView.const_defined?("Template#{name}")
      return ActionView::Template.const_get(name.to_s)
    end

    ## Rails XSS Safety

    # Whether or not ActionView's XSS protection is available and enabled,
    # as is the default for Rails 3.0+, and optional for version 2.3.5+.
    # Overridden in haml/template.rb if this is the case.
    #
    # @return [Boolean]
    def rails_xss_safe?
      false
    end

    # Returns the given text, marked as being HTML-safe.
    # With older versions of the Rails XSS-safety mechanism,
    # this destructively modifies the HTML-safety of `text`.
    #
    # @param text [String, nil]
    # @return [String, nil] `text`, marked as HTML-safe
    def html_safe(text)
      return unless text
      return text.html_safe if defined?(ActiveSupport::SafeBuffer)
      text.html_safe!
    end

    # Assert that a given object (usually a String) is HTML safe
    # according to Rails' XSS handling, if it's loaded.
    #
    # @param text [Object]
    def assert_html_safe!(text)
      return unless rails_xss_safe? && text && !text.to_s.html_safe?
      raise Haml::Error.new("Expected #{text.inspect} to be HTML-safe.")
    end

    # The class for the Rails SafeBuffer XSS protection class.
    # This varies depending on Rails version.
    #
    # @return [Class]
    def rails_safe_buffer_class
      # It's important that we check ActiveSupport first,
      # because in Rails 2.3.6 ActionView::SafeBuffer exists
      # but is a deprecated proxy object.
      return ActiveSupport::SafeBuffer if defined?(ActiveSupport::SafeBuffer)
      return ActionView::SafeBuffer
    end

    ## Cross-Ruby-Version Compatibility

    # Whether or not this is running under Ruby 1.8 or lower.
    #
    # @return [Boolean]
    def ruby1_8?
      Haml::Util::RUBY_VERSION[0] == 1 && Haml::Util::RUBY_VERSION[1] < 9
    end

    # Whether or not this is running under Ruby 1.8.6 or lower.
    # Note that lower versions are not officially supported.
    #
    # @return [Boolean]
    def ruby1_8_6?
      ruby1_8? && Haml::Util::RUBY_VERSION[2] < 7
    end

    # Checks that the encoding of a string is valid in Ruby 1.9
    # and cleans up potential encoding gotchas like the UTF-8 BOM.
    # If it's not, yields an error string describing the invalid character
    # and the line on which it occurrs.
    #
    # @param str [String] The string of which to check the encoding
    # @yield [msg] A block in which an encoding error can be raised.
    #   Only yields if there is an encoding error
    # @yieldparam msg [String] The error message to be raised
    # @return [String] `str`, potentially with encoding gotchas like BOMs removed
    def check_encoding(str)
      if ruby1_8?
        return str.gsub(/\A\xEF\xBB\xBF/, '') # Get rid of the UTF-8 BOM
      elsif str.valid_encoding?
        # Get rid of the Unicode BOM if possible
        if str.encoding.name =~ /^UTF-(8|16|32)(BE|LE)?$/
          return str.gsub(Regexp.new("\\A\uFEFF".encode(str.encoding.name)), '')
        else
          return str
        end
      end

      encoding = str.encoding
      newlines = Regexp.new("\r\n|\r|\n".encode(encoding).force_encoding("binary"))
      str.force_encoding("binary").split(newlines).each_with_index do |line, i|
        begin
          line.encode(encoding)
        rescue Encoding::UndefinedConversionError => e
          yield <<MSG.rstrip, i + 1
Invalid #{encoding.name} character #{e.error_char.dump}
MSG
        end
      end
      return str
    end

    # Checks to see if a class has a given method.
    # For example:
    #
    #     Haml::Util.has?(:public_instance_method, String, :gsub) #=> true
    #
    # Method collections like `Class#instance_methods`
    # return strings in Ruby 1.8 and symbols in Ruby 1.9 and on,
    # so this handles checking for them in a compatible way.
    #
    # @param attr [#to_s] The (singular) name of the method-collection method
    #   (e.g. `:instance_methods`, `:private_methods`)
    # @param klass [Module] The class to check the methods of which to check
    # @param method [String, Symbol] The name of the method do check for
    # @return [Boolean] Whether or not the given collection has the given method
    def has?(attr, klass, method)
      klass.send("#{attr}s").include?(ruby1_8? ? method.to_s : method.to_sym)
    end

    # A version of `Enumerable#enum_with_index` that works in Ruby 1.8 and 1.9.
    #
    # @param enum [Enumerable] The enumerable to get the enumerator for
    # @return [Enumerator] The with-index enumerator
    def enum_with_index(enum)
      ruby1_8? ? enum.enum_with_index : enum.each_with_index
    end

    # A version of `Enumerable#enum_cons` that works in Ruby 1.8 and 1.9.
    #
    # @param enum [Enumerable] The enumerable to get the enumerator for
    # @param n [Fixnum] The size of each cons
    # @return [Enumerator] The consed enumerator
    def enum_cons(enum, n)
      ruby1_8? ? enum.enum_cons(n) : enum.each_cons(n)
    end

    # A version of `Enumerable#enum_slice` that works in Ruby 1.8 and 1.9.
    #
    # @param enum [Enumerable] The enumerable to get the enumerator for
    # @param n [Fixnum] The size of each slice
    # @return [Enumerator] The consed enumerator
    def enum_slice(enum, n)
      ruby1_8? ? enum.enum_slice(n) : enum.each_slice(n)
    end

    # Returns the ASCII code of the given character.
    #
    # @param c [String] All characters but the first are ignored.
    # @return [Fixnum] The ASCII code of `c`.
    def ord(c)
      ruby1_8? ? c[0] : c.ord
    end

    # Flattens the first `n` nested arrays in a cross-version manner.
    #
    # @param arr [Array] The array to flatten
    # @param n [Fixnum] The number of levels to flatten
    # @return [Array] The flattened array
    def flatten(arr, n)
      return arr.flatten(n) unless ruby1_8_6?
      return arr if n == 0
      arr.inject([]) {|res, e| e.is_a?(Array) ? res.concat(flatten(e, n - 1)) : res << e}
    end

    # Returns the hash code for a set in a cross-version manner.
    # Aggravatingly, this is order-dependent in Ruby 1.8.6.
    #
    # @param set [Set]
    # @return [Fixnum] The order-independent hashcode of `set`
    def set_hash(set)
      return set.hash unless ruby1_8_6?
      set.map {|e| e.hash}.uniq.sort.hash
    end

    # Tests the hash-equality of two sets in a cross-version manner.
    # Aggravatingly, this is order-dependent in Ruby 1.8.6.
    #
    # @param set1 [Set]
    # @param set2 [Set]
    # @return [Boolean] Whether or not the sets are hashcode equal
    def set_eql?(set1, set2)
      return set1.eql?(set2) unless ruby1_8_6?
      set1.to_a.uniq.sort_by {|e| e.hash}.eql?(set2.to_a.uniq.sort_by {|e| e.hash})
    end

    ## Static Method Stuff

    # The context in which the ERB for \{#def\_static\_method} will be run.
    class StaticConditionalContext
      # @param set [#include?] The set of variables that are defined for this context.
      def initialize(set)
        @set = set
      end

      # Checks whether or not a variable is defined for this context.
      #
      # @param name [Symbol] The name of the variable
      # @return [Boolean]
      def method_missing(name, *args, &block)
        super unless args.empty? && block.nil?
        @set.include?(name)
      end
    end

    # This is used for methods in {Haml::Buffer} that need to be very fast,
    # and take a lot of boolean parameters
    # that are known at compile-time.
    # Instead of passing the parameters in normally,
    # a separate method is defined for every possible combination of those parameters;
    # these are then called using \{#static\_method\_name}.
    #
    # To define a static method, an ERB template for the method is provided.
    # All conditionals based on the static parameters
    # are done as embedded Ruby within this template.
    # For example:
    #
    #     def_static_method(Foo, :my_static_method, [:foo, :bar], :baz, :bang, <<RUBY)
    #       <% if baz && bang %>
    #         return foo + bar
    #       <% elsif baz || bang %>
    #         return foo - bar
    #       <% else %>
    #         return 17
    #       <% end %>
    #     RUBY
    #
    # \{#static\_method\_name} can be used to call static methods.
    #
    # @overload def_static_method(klass, name, args, *vars, erb)
    # @param klass [Module] The class on which to define the static method
    # @param name [#to_s] The (base) name of the static method
    # @param args [Array<Symbol>] The names of the arguments to the defined methods
    #   (**not** to the ERB template)
    # @param vars [Array<Symbol>] The names of the static boolean variables
    #   to be made available to the ERB template
    # @param erb [String] The template for the method code
    def def_static_method(klass, name, args, *vars)
      erb = vars.pop
      info = caller_info
      powerset(vars).each do |set|
        context = StaticConditionalContext.new(set).instance_eval {binding}
        klass.class_eval(<<METHOD, info[0], info[1])
def #{static_method_name(name, *vars.map {|v| set.include?(v)})}(#{args.join(', ')})
  #{ERB.new(erb).result(context)}
end
METHOD
      end
    end

    # Computes the name for a method defined via \{#def\_static\_method}.
    #
    # @param name [String] The base name of the static method
    # @param vars [Array<Boolean>] The static variable assignment
    # @return [String] The real name of the static method
    def static_method_name(name, *vars)
      "#{name}_#{vars.map {|v| !!v}.join('_')}"
    end

    private

    # Calculates the memoization table for the Least Common Subsequence algorithm.
    # Algorithm from [Wikipedia](http://en.wikipedia.org/wiki/Longest_common_subsequence_problem#Computing_the_length_of_the_LCS)
    def lcs_table(x, y)
      c = Array.new(x.size) {[]}
      x.size.times {|i| c[i][0] = 0}
      y.size.times {|j| c[0][j] = 0}
      (1...x.size).each do |i|
        (1...y.size).each do |j|
          c[i][j] =
            if yield x[i], y[j]
              c[i-1][j-1] + 1
            else
              [c[i][j-1], c[i-1][j]].max
            end
        end
      end
      return c
    end

    # Computes a single longest common subsequence for arrays x and y.
    # Algorithm from [Wikipedia](http://en.wikipedia.org/wiki/Longest_common_subsequence_problem#Reading_out_an_LCS)
    def lcs_backtrace(c, x, y, i, j, &block)
      return [] if i == 0 || j == 0
      if v = yield(x[i], y[j])
        return lcs_backtrace(c, x, y, i-1, j-1, &block) << v
      end

      return lcs_backtrace(c, x, y, i, j-1, &block) if c[i][j-1] > c[i-1][j]
      return lcs_backtrace(c, x, y, i-1, j, &block)
    end
  end
end

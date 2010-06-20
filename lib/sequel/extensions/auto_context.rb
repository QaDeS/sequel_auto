require 'sequel/extensions/auto_assoc'

module Sequel
  
  def self.context(*classes, &block)
    c = Context.new
    c.instance_eval &block
    c.contextualize(classes)
    c
  end

  class Context
    include Sequel::Inflections

    def element(name, cls = nil)
      cls = camelcase(singularize(name.to_s)).to_sym unless cls
      cls = Object.const_get cls unless cls.is_a? Class
      raise "Element #{name} already defined for #{cls}" if ctx.has_key?(cls)

      ctx[cls] = name
      class << self; self; end.class_eval <<-EOF
        attr_reader :#{name}
        def #{name}=(value)
          raise "Wrong type, #{name} is a \#{value.class} instead of a #{cls}" unless value.is_a?(#{cls})
          @#{name} = value
        end
      EOF
    end

    def ctx
      @ctx ||= {}
    end

    def contextualize(classes)
      filter = classes.flatten - ctx.keys

      direct = refs(ctx.keys) & filter
      puts "Direct:", direct.inspect
      contextualize_direct(direct)

      indirect = refs(direct) & filter
      puts "Indirect:", indirect.inspect
      contextualize_indirect(indirect, direct)

      (direct + indirect).uniq
    end

    private
    def contextualize_direct(classes)
      classes.each do |cls|
        filter_exp = ctx.map do |(acls, aname)|
          fk_name = assoc(:key, cls, acls)
          # TODO support combined keys
          # TODO how can the current Context be passed in?
          ":#{fk_name.first} => AppContext.#{aname}.pk" if fk_name
        end.compact.join(', ')
        # TODO choose between .first and .all
        code = <<-EOF
          def_dataset_method :get do
            filter(#{filter_exp}).first
          end
        EOF
        cls.instance_eval code
        puts cls, code
      end
    end

    def contextualize_indirect(classes, targets)
      classes.each do |cls|
        targets.each do |tcls|
          name = assoc(:name, cls, tcls)
          code = <<-EOF
            def #{singularize(name)}
              #{name}_dataset.get
            end
          EOF
          cls.class_eval code
          puts cls, code
        end
      end
    end

    def assoc(key, src, dst)
      result = src.associations.map do |assoc|
        a = src.association_reflection(assoc)
        a[key] if a[:class] == dst
      end.compact
      raise "#{src} has multiple associations to #{dst}: #{result.inspect}" unless result.size == 1
      result.first
    end

    def refs(classes)
      classes.map do |cls|
        cls.associations.map do |assoc|
          c = cls.association_reflection(assoc)
          c[:class]
        end
      end.flatten.compact.uniq
    end

  end
end
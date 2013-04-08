module Mongoblazer
  ##
  # Mongoblazer's ActiveRecord extension.
  #
  module ActiveRecord
    extend ActiveSupport::Concern

    included do
      def mongoblazed
        self.class.recreate_mongoblazer_class!

        self.class.mongoblazer_class.where(ar_id: id, _type: self.class.mongoblazer_class_name).last
      end

      def mongoblaze!(caller=self.class)
        self.class.recreate_mongoblazer_class!

        data = mongoblazer_attributes

        self.class.mongoblazer_options[:embeds_one].each do |em|
          if related = data.delete(em)
            klass = "#{em.to_s.camelize}".constantize
            if klass != caller
              if klass.mongoblazable?
                data[em] = klass.find(related['id']).mongoblazer_attributes(self.class)
              else
                data[em] = related
              end
            end
          end
        end

        self.class.mongoblazer_options[:embeds_many].each do |em|
          if related = data.delete(em)
            klass = "#{em.to_s.singularize.camelize}".constantize
            if klass != caller
              if klass.mongoblazable?
                data[em] = related.map do |r|
                  klass.find(r['id']).mongoblazer_attributes(self.class)
                end
              else
                data[em] = related
              end
            end
          end
        end

        blazed_records = self.class.mongoblazer_class.where(ar_id: id)

        if blazed_records.size > 1
          throw "Multiple Mongoblazed documents found with the same id!
          Set a default scope to filter out unique ones."

        elsif blazed_records.present?
          blazed_record = blazed_records.first
          blazed_record.save!(data)

        else
          blazed_record = self.class.mongoblazer_class.create(data)
        end
      end

      def mongoblaze_relations!(blazed_record, relations)
        if relations.present?
          relations.each do |name, related|
            if related.is_a? Array
              related.each { |r| blazed_record.send(name).build(r) }
            else
              blazed_record.send(name).build(related)
            end
          end

          blazed_record.save
        end
      end

      def mongoblazer_attributes(caller=self.class)
        if self.class.mongoblazable?
          includes = self.class.mongoblazer_options[:includes]

          instance = self.class.includes(includes).find(id)
          data = instance.serializable_hash(:include => includes)

          data[:ar_id] = data.delete('id')

          data.delete(caller.name.underscore.to_sym)
          data.delete(caller.name.pluralize.underscore.to_sym)

          data
        else
          throw "#{self.class.name} is not Mongoblazable!"
        end
      end

      private

        # Add associations specified via the <tt>:include</tt> option.
        #
        # Expects a block that takes as arguments:
        #   +association+ - name of the association
        #   +records+     - the association record(s) to be serialized
        #   +opts+        - options for the association records
        def serializable_add_includes(options = {}) #:nodoc:
          return unless include = options[:include]

          unless include.is_a?(Hash)
            include = Hash[Array.wrap(include).map { |n| n.is_a?(Hash) ? n.to_a.first : [n, {}] }]
          end

          include.each do |association, opts|
            # TODO: This is broken in Rails 3.2.13 it seems, hence this fix.
            opts = {:include => opts} if opts.is_a? Array

            if records = send(association)
              yield association, records, opts
            end
          end
        end
    end

    module ClassMethods
      ##
      # Is this model Mongoblazable?
      #
      def mongoblazable?
        mongoblazer_options.present?
      end

      def belongs_to(name, options={})
        mongoblazer_init embeds_one: name
        super
      end

      def has_one(name, options={})
        mongoblazer_init embeds_one: name
        super
      end

      def has_many(name, options={})
        mongoblazer_init embeds_many: name
        super
      end

      def has_and_belongs_to_many(name, options={})
        mongoblazer_init embeds_many: name
        super
      end

      ##
      # Defines relation includes to be merged
      # in the mongodb document.
      #
      # Syntax same as eager loading syntax in AR:
      #    http://guides.rubyonrails.org/active_record_querying.html#eager-loading-associations
      #
      def mongoblazer_includes(options={})
        mongoblazer_init includes: options
      end

      ##
      # Defines default scope to find the matching mongodb
      # document.
      #
      # Syntax same as where() in AR
      #
      def mongoblazer_default_scope(options={})
        mongoblazer_init default_scope: options
      end

      ##
      # Defines indexes on the blazer model.
      #
      def mongoblazer_index_fields(options={})
        mongoblazer_init indexes: options
      end

      ##
      # Initialize Mongoblazer wit some options:
      #   includes: relations to include
      #   default_scope: the default scope for the blazed model
      #   indexes: fields to index in the blazed model
      #   embeds_one: model to embed one of
      #   embeds_many: model to embed many of
      #
      def mongoblazer_init(options)
        unless @mongoblazer_options
          @mongoblazer_options = {}

          @mongoblazer_options[:indexes] =
            ::ActiveRecord::Base.connection.indexes(self.table_name).map do |ind|
            {ind => 1}
          end

          @mongoblazer_options[:default_scope] = self.default_scopes

          @mongoblazer_options[:embeds_one]  = []
          @mongoblazer_options[:embeds_many] = []
        end

        if options[:embeds_one]
          @mongoblazer_options[:embeds_one] << options.delete(:embeds_one)
        end

        if options[:embeds_many]
          @mongoblazer_options[:embeds_many] << options.delete(:embeds_many)
        end

        @mongoblazer_options.merge! options

        create_mongoblazer_class!
      end

      def mongoblazer_options
        if defined?(@mongoblazer_options)
          @mongoblazer_options
        elsif superclass.respond_to?(:mongoblazer_options)
          superclass.mongoblazer_options || { }
        else
          { }
        end
      end

      def mongoblazer_class
        mongoblazer_class_name.constantize
      end

      def recreate_mongoblazer_class!
        create_mongoblazer_class! unless mongoblazer_class.embedded_relations?
      end

      private # ----------------------------------------------------------------

      def create_mongoblazer_class!
        configuration = mongoblazer_options

        relations  = configure_mongoblazer_relations! configuration[:embeds_one], :embeds_one
        relations += configure_mongoblazer_relations! configuration[:embeds_many], :embeds_many

        klass = Class.new ::Mongoblazer::Document do
          index ar_id: 1

          default_scope configuration[:default_scope] if configuration[:default_scope].present?

          configuration[:indexes].each { |ind| index ind }
        end

        klass.class_eval relations.join("\n")

        Object.const_set mongoblazer_class_name, klass
      end

      def configure_mongoblazer_relations!(relations, embed_type=:embeds_one)
        relations.map do |em|
          class_name = embed_type == :embeds_one ? "#{em.to_s.camelize}Blazer" : "#{em.to_s.singularize.camelize}Blazer"

          if const_defined?(class_name.to_sym)
            <<-CODE
              #{embed_type} :#{em}, class_name: '#{class_name}', inverse_of: '#{mongoblazer_class_name}'
              accepts_nested_attributes_for :#{em}
            CODE
          else
            <<-CODE
              def #{em}=(data)
                write_attribute(:#{em}, data)
              end

              def #{em}
                data = attributes['#{em}']
                if data.is_a? Array
                  data.map{|d| OpenStruct.new(d)}
                elsif data.is_a? Hash
                  OpenStruct.new(data)
                else
                  data
                end
              end
            CODE
          end
        end
      end

      def mongoblazer_class_name
        "#{self.name}Blazer"
      end
    end
  end
end

module Mongoblazer
  ##
  # Mongoblazer's ActiveRecord extension.
  #
  module ActiveRecord
    extend ActiveSupport::Concern
    include Carrierwave

    included do
      def mongoblazed
        @mongoblazed ||= begin
          self.class.recreate_mongoblazer_class!
          self.class.mongoblazer_class.where(id: self.mongoblazer_id).last
        end
      end

      def mongoblazed_add_attribute(name, data={})
        self.class.recreate_mongoblazer_class!
        instance = self.class.mongoblazer_class.where(id: self.mongoblazer_id).last
        instance[name] = data
        instance.save!
        @mongoblazed = instance
      end

      ##
      # Add a relation that is not in the includes options
      #
      # Example:
      # post.mongoblazed.add_include(:comments, post.comments.map(&:attributes))
      #
      # Returns the mongoblazed instance with the new include.
      def mongoblazed_add_include(name, data={})
        self.class.recreate_mongoblazer_class!
        relations = {name => data}
        mongoblaze_relations(mongoblazed, relations)
        mongoblazed.save!
        mongoblazed
      end

      def mongoblaze!(caller=self.class)
        if @mongoblazer_already_blazing
          @mongoblazer_already_blazing = false
          return true
        end

        self.class.recreate_mongoblazer_class!

        data = mongoblazer_attributes
        relations = {}

        self.class.mongoblazer_options[:embeds_one].each do |em, class_name|
          if related = data.delete(em)
            klass = class_name ? class_name.constantize : "#{em.to_s.camelize}".constantize
            if klass != caller
              related_id = related['id'] || data["#{em}_id"]
              if klass.mongoblazable? && related_id
                klass.recreate_mongoblazer_class!
                relations[em] = klass.find(related_id).mongoblazer_attributes(self.class)
              else
                data[em] = related.attributes
              end
            end
          end
        end

        self.class.mongoblazer_options[:embeds_many].each do |em, class_name|
          if related = data.delete(em)
            klass = class_name ? class_name.constantize : "#{em.to_s.singularize.camelize}".constantize
            if klass != caller
              if klass.mongoblazable?
                klass.recreate_mongoblazer_class!
                relations[em] = related.map do |r|
                  related_id = r['id'] || data["#{em.to_s.singularize}_id"]
                  if related_id
                    klass.find(related_id).mongoblazer_attributes(self.class)
                  else
                    r.attributes
                  end
                end
              else
                data[em] = related.map(&:attributes)
              end
            end
          end
        end

        self.class.recreate_mongoblazer_class!

        blazed_record = if self.mongoblazer_id.present?
          self.class.mongoblazer_class
            .where(id: self.mongoblazer_id).first
          else
            nil
          end

        if blazed_record.present?
          blazed_record.save!(data)
        else
          blazed_record = self.class.mongoblazer_class.create(data)
          @mongoblazer_already_blazing = true
          update_attribute :mongoblazer_id, blazed_record.id.to_s
        end

        mongoblaze_relations(blazed_record, relations)

        blazed_record.save!

        blazed_record
      end

      def mongoblaze_relations(blazed_record, relations)
        if relations.present?
          self.class.recreate_mongoblazer_class!

          relations.each do |name, related|
            next if self.class.mongoblazer_options[:uploaders].include? name

            if related.is_a? Array
              blazed_record.send(name).destroy_all

              related.each do |r|
                blazed_record.send(name).build(r)
              end

            else
              blazed_record.send("build_#{name}", related)
            end
          end
        end
      end

      def mongoblazer_attributes(caller=self.class)
        if self.class.mongoblazable?
          self.class.recreate_mongoblazer_class!

          includes = self.class.mongoblazer_options[:includes]

          instance = self.class.includes(includes).find(id)
          data = if includes
            instance.serializable_hash(:include => includes)
          else
            instance.attributes
          end

          if additional = self.class.mongoblazer_options[:additional_attributes]
            additional.each do |attribute|
              next if self.class.mongoblazer_options[:uploaders].include? attribute

              data[attribute] = instance.send(attribute)
            end
          end

          if uploaders = self.class.mongoblazer_options[:uploaders]
            uploaders.each do |uploader|
              data.delete(uploader)
              data.delete(uploader.to_s)
              if instance.send(uploader).present?
                versions = {}
                instance.send(uploader).versions.each do |v,u|
                  versions[v] = u.to_s
                end
                versions.merge({default: instance.send(uploader).to_s})
              end
            end
          end

          data[:ar_id] = data.delete('id')

          data.delete(caller.name.underscore.to_sym)
          data.delete(caller.name.pluralize.underscore.to_sym)

          self.class.recreate_mongoblazer_class!

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
      def find_blazed(id)
        ar_instance = select("#{self.table_name}.mongoblazer_id").find(id)

        recreate_mongoblazer_class!

        mongoblazer_class.find(ar_instance.mongoblazer_id)
      end

      ##
      # Is this model Mongoblazable?
      #
      def mongoblazable?
        mongoblazer_options.present?
      end

      def belongs_to(name, options={})
        mongoblazer_init embeds_one: {name => options[:class_name]}
        super
      end

      def has_one(name, options={})
        mongoblazer_init embeds_one: {name => options[:class_name]}
        super
      end

      def has_many(name, options={})
        mongoblazer_init embeds_many: {name => options[:class_name]}
        super
      end

      def has_and_belongs_to_many(name, options={})
        mongoblazer_init embeds_many: {name => options[:class_name]}
        super
      end

      ##
      # Add a relation that is not in the includes options and not in the
      # ActiveRecord model as a relation.
      #
      # Example:
      # mongoblazer_embeds_one :some_method_returning_ar_results => 'ArModel'
      #
      def mongoblazer_embeds_one(options={})
        options.each do |name, klass_name|
          mongoblazer_init embeds_one: {name => klass_name}
        end
      end

      ##
      # Add a relation that is not in the includes options and not in the
      # ActiveRecord model as a relation.
      #
      # Example:
      # mongoblazer_embeds_many :some_method_returning_ar_results => 'ArModel'
      #
      def mongoblazer_embeds_many(options={})
        options.each do |name, klass_name|
          mongoblazer_init embeds_many: {name => klass_name}
        end
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
      # Defines additional attributes (e.g. not in db) to be merged
      # in the mongodb document.
      #
      def mongoblazer_additional_attributes(options={})
        mongoblazer_init additional_attributes: options
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

          @mongoblazer_options[:uploaders] = []

          @mongoblazer_options[:embeds_one]  = {}
          @mongoblazer_options[:embeds_many] = {}
        end

        if one = options.delete(:embeds_one)
          @mongoblazer_options[:embeds_one][one.keys.first] = one.values.first
        end

        if many = options.delete(:embeds_many)
          @mongoblazer_options[:embeds_many][many.keys.first] = many.values.first
        end

        if uploader = options.delete(:uploaders)
          @mongoblazer_options[:uploaders] << uploader
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

      def mongoblazer_class_name
        "#{self.name}Blazer"
      end

      def recreate_mongoblazer_class!(called_from_parent=false)
        create_mongoblazer_class!

        unless called_from_parent
          begin
            configuration[:embeds_one].each do |rel|
              "#{rel.to_s.camelize}".constantize.recreate_mongoblazer_class!(true)
            end
          rescue NameError
          end
          begin
            configuration[:embeds_many].each do |rel|
              "#{rel.to_s.singularize.camelize}".constantize.recreate_mongoblazer_class!(true)
            end
          rescue NameError
          end
        end
      end

      private # ----------------------------------------------------------------

      def create_mongoblazer_class!
        configuration = mongoblazer_options

        relations  = configure_mongoblazer_relations! configuration[:embeds_one], :embeds_one
        relations += configure_mongoblazer_relations! configuration[:embeds_many], :embeds_many

        uploaders = configure_mongoblazer_uploaders!

        klass = begin
          mongoblazer_class
        rescue NameError
          collection = mongoblazer_class_name.pluralize.underscore

          klass = Class.new do
            include ::Mongoblazer::Document

            # Use one collection to avoid class initialization trouble
            # when guessing the collection to use.
            store_in collection: collection

            index ar_id: 1
            index _type: 1

            default_scope configuration[:default_scope] if configuration[:default_scope].present?

            configuration[:indexes].each { |ind| index ind }
          end

          Object.const_set mongoblazer_class_name, klass

          klass
        end

        klass.module_eval relations.join("\n")
        klass.module_eval uploaders.join("\n")
      end

      def configure_mongoblazer_relations!(relations, embed_type=:embeds_one)
        relations.map do |em, klass_name|
          class_name = if klass_name
            "#{klass_name}Blazer"
          elsif embed_type == :embeds_one
            "#{em.to_s.camelize}Blazer"
          else
            "#{em.to_s.singularize.camelize}Blazer"
          end

          if const_defined?(class_name)
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
    end
  end
end

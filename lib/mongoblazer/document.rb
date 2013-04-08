module Mongoblazer
  class Document
    include Mongoid::Document

    field :ar_id, type: String

    index ar_id: 1

    def is_mongoblazed?
      true
    end
  end
end

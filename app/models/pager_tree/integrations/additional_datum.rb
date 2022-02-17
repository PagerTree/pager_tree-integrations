module PagerTree::Integrations
  class AdditionalDatum
    include ActiveModel::Model
    include ActiveModel::API
    extend ActiveModel::Callbacks

    FORMATS = ["text", "link", "img", "email", "phone", "datetime"]

    attr_accessor :format
    attr_accessor :label
    attr_accessor :value

    validates :format, inclusion: {in: FORMATS}
    validates :label, presence: true
    validates :value, presence: true

    validates :value, url: true, if: proc { |x| x.format == "link" || x.format == "img" }

    define_model_callbacks :initialize

    def initialize(params = {})
      run_callbacks :initialize do
        super(params)
      end
    end

    after_initialize do
      self.format ||= nil
      self.label ||= nil
      self.value ||= nil
    end
  end
end

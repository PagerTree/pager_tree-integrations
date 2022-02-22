require "test_helper"

module PagerTree::Integrations
  class AdditionalDatumTest < ActiveSupport::TestCase
    setup do
      @datum_empty = AdditionalDatum.new
      @datum_filled = AdditionalDatum.new(format: "text", label: "foo", value: "bar")
    end

    test "sanity" do
      assert_nil @datum_empty.format
      assert_nil @datum_empty.label
      assert_nil @datum_empty.value

      assert_equal "text", @datum_filled.format
      assert_equal "foo", @datum_filled.label
      assert_equal "bar", @datum_filled.value

      assert_not @datum_empty.valid?
      assert @datum_filled.valid?

      true_hash = {
        format: "text",
        label: "foo",
        value: "bar"
      }
      assert_equal true_hash, @datum_filled.to_h
    end

    test "url validation" do
      @datum_filled.format = "link"
      assert_not @datum_filled.valid?

      @datum_filled.value = "http://example.com"
      assert @datum_filled.valid?
    end
  end
end

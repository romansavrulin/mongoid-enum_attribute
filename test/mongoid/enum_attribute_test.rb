require "test_helper"

describe Mongoid::EnumAttribute do
  let(:kls) { TestClass }
  let(:instance) { kls.new }

  let(:alias_name) { :status }
  let(:field_name) { "_#{alias_name}" }
  let(:values) { %i(awaiting_approval approved banned) }

  let(:multiple_alias_name) { :roles }
  let(:multiple_field_name) { "_#{multiple_alias_name}" }
  let(:multiple_values) { %i(author editor admin) }

  describe "field" do
    it { kls.fields[field_name].must_be :present? }

    describe "type" do
      describe "multiple: false" do
        it { kls.fields[field_name].options[:type].must_equal Symbol }
        it { kls._validators[field_name.to_sym].first.must_be_kind_of ActiveModel::Validations::InclusionValidator }
      end

      describe "multiple: true" do
        it { kls.fields[multiple_field_name].options[:type].must_equal Array }
        it { kls._validators[multiple_field_name.to_sym].first.must_be_kind_of Mongoid::EnumAttribute::Validators::MultipleValidator }
      end
    end

    describe "required" do
      describe "true" do
        let(:instance) { kls.new(status: nil) }
        it { instance.wont_be :valid? }
      end

      describe "false" do
        let(:instance) { kls.new(roles: nil) }
        it { instance.must_be :valid? }
      end
    end

    describe "aliases" do
      it { instance.must_be :respond_to?, alias_name }
      it { instance.must_be :respond_to?, :"#{alias_name}" }
      it { instance.must_be :respond_to?, :"#{alias_name}=" }

      it { instance.must_be :respond_to?, multiple_alias_name }
      it { instance.must_be :respond_to?, :"#{multiple_alias_name}" }
      it { instance.must_be :respond_to?, :"#{multiple_alias_name}=" }
    end

    describe "accessors" do
      describe "singular" do
        it "accepts strings" do
          instance.status = "banned"
          instance.status.must_equal :banned
        end

        it "accepts symbols" do
          instance.status = :banned
          instance.status.must_equal :banned
        end

        describe "!" do
          before { instance.banned! }
          it { instance.status.must_equal :banned }
        end

        describe "?" do
          before { instance.status = :banned }
          it { instance.must_be :banned? }
          it { instance.wont_be :awaiting_approval? }
          it { instance.wont_be :approved? }
        end
      end

      describe "multiple" do
        it "accepts strings" do
          instance.roles = "author"
          instance.roles.must_equal %i(author)
        end

        it "accepts arrays of strings" do
          instance.roles = %w(author editor)
          instance.roles.must_equal %i(author editor)
        end

        it "accepts symbols" do
          instance.roles = :author
          instance.roles.must_equal %i(author)
        end

        it "accepts arrays of symbols" do
          instance.roles = %i(author editor)
          instance.roles.must_equal %i(author editor)
        end

        describe "!" do
          describe "when field is nil" do
            before do
              instance.roles = nil
              instance.author!
            end
            it { instance.roles.must_equal %i(author) }
          end

          describe "when field is not nil" do
            before do
              instance.author!
              instance.editor!
            end
            it { instance.roles.must_equal %i(author editor) }
          end
        end

        describe "?" do
          before do
            instance.author!
            instance.editor!
          end
          it { instance.must_be :author? }
          it { instance.must_be :editor? }
          it { instance.wont_be :admin? }
        end
      end
    end

    describe "default values" do
      describe "when not specified" do
        it { instance.status.must_equal values.first }
      end

      describe "when specified" do
        it { instance.roles.must_equal [] }
      end
    end
  end

  describe "scopes" do
    describe "when singular" do
      before do
        instance.save!
        instance.banned!
      end
      it { TestClass.banned.must_include instance }
    end

    describe "when multiple" do
      describe "and only one document" do
        before do
          instance.save!
          instance.author!
          instance.editor!
        end
        it { TestClass.author.must_include instance }
        it { TestClass.editor.must_include instance }
      end

      describe "and more than one document" do
        let(:instance_2) { kls.new }

        before do
          instance.save!
          instance.author!
          instance.editor!
          instance_2.save!
          instance_2.author!
        end
        it { TestClass.author.must_include instance }
        it { TestClass.author.must_include instance_2 }
        it { TestClass.editor.must_include instance }
      end
    end
  end

  describe "constant" do
    it { kls::STATUS.must_equal values }
    it { kls::ROLES.must_equal multiple_values }
  end

  describe ".configuration" do
    it { Mongoid::EnumAttribute.configuration.must_be_instance_of Mongoid::EnumAttribute::Configuration }
    it { Mongoid::EnumAttribute.configuration.must_equal Mongoid::EnumAttribute.configuration }
  end

  describe ".configure" do
    before { Mongoid::EnumAttribute.configure { |config| @config = config } }
    it { @config.must_equal Mongoid::EnumAttribute.configuration }
  end

  describe "prefix defined in configuration" do
    let(:field_name_prefix) { "___" }
    let(:old_field_name_prefix) { Mongoid::EnumAttribute.configuration.field_name_prefix }

    before do
      Mongoid::EnumAttribute.configure do |config|
        config.field_name_prefix = field_name_prefix
      end

      TestClassWithPrefix = Class.new do
        include Mongoid::Document
        include Mongoid::EnumAttribute

        enum :status, [:awaiting_approval, :approved, :banned]
      end
    end

    it { TestClassWithPrefix.fields["#{field_name_prefix}status"].must_be :present? }

    after do
      Mongoid::EnumAttribute.configure do |config|
        config.field_name_prefix = old_field_name_prefix
      end
    end
  end
end

require "minitest_helper"

class WannabeAddressable
  extend Cms::Concerns::CanBeAddressable
end

class CouldBeAddressable < ActiveRecord::Base;
end

class HasSelfDefinedPath < ActiveRecord::Base
  is_addressable(no_dynamic_path: true)
  attr_accessible :path
end

class IsAddressable < ActiveRecord::Base;
  is_addressable path: "/widgets"
  attr_accessible :name
end

describe Cms::Concerns::Addressable do

  def create_testing_table(name, &block)
    ActiveRecord::Base.connection.instance_eval do
      drop_table(name) if table_exists?(name)
      create_table(name, &block)
    end
  end

  before :all do
    create_testing_table :is_addressables do |t|
      t.string :name
    end
    create_testing_table :has_self_defined_paths do |t|
      t.string :path
    end
  end

  let(:addressable) { IsAddressable.new }
  describe '#is_addressable' do
    it "should have parent relationship" do
      WannabeAddressable.expects(:attr_accessible).at_least_once
      WannabeAddressable.expects(:has_one)
      WannabeAddressable.is_addressable
      WannabeAddressable.new.must_respond_to :parent
    end

    it "should be added to all ActiveRecord classes" do
      CouldBeAddressable.must_respond_to :is_addressable
    end

    it "provide default path where instances will be placed" do
      IsAddressable.path.must_equal "/widgets"
    end

    it "should allow :path to be ActiveRecord::Base attribute" do
      p = HasSelfDefinedPath.new(path: "/custom")
      p.path.must_equal "/custom"
    end
  end

  describe "#can_have_parent?" do
    it "should be false for non-addressable blocks" do
      WannabeAddressable.can_have_parent?.must_equal false
    end

    it "should be true for addressable block" do
      IsAddressable.can_have_parent?.must_equal true
    end
  end

  describe ".path" do
    it "should join #path and .slug" do
      addressable.expects(:slug).returns("one")
      addressable.path.must_equal "/widgets/one"
    end
  end

  describe ".slug" do
    it "should be nil for new objects" do
      addressable.slug.must_be_nil
    end
  end

  describe "#descendants" do
    it "should return a list of all classes that are Addressable" do
      Cms::Concerns::Addressable.descendants.include?(IsAddressable).must_equal true
    end
  end

  describe "#classes_that_require_custom_routes" do
    it "should include addressable blocks but not pages/links/etc (i.e. already have controllers to display them)" do
      classes = Cms::Concerns::Addressable.classes_that_require_custom_routes
      classes.include?(IsAddressable).must_equal true
      classes.include?(Cms::Page).must_equal false
      classes.include?(Cms::Link).must_equal false
    end
  end

  describe "#with_slug" do

    it "should find content" do
      content = IsAddressable.create(name: "Coke", slug: "coke", parent_id: root_section)
      found = IsAddressable.with_slug("coke")
      found.wont_be_nil
      found.must_equal content
    end

    it "should find correct type" do
      Cms::HtmlBlock.create!(name: "Coke", slug: "coke", parent_id: root_section)
      content = IsAddressable.create(name: "Coke", slug: "coke", parent_id: root_section)
      found = IsAddressable.with_slug("coke")
      found.must_equal content

    end
  end

  describe "#create" do
    it "should allow for both parent and slug to be saved" do
      f = IsAddressable.create(parent_id: root_section.id, slug: "slug")
      f.section_node.slug.must_equal "slug"
    end

    it "should allow for both parent and slug to be saved in any order" do
      f = IsAddressable.create(slug: "slug", parent_id: root_section.id)
      f.section_node.slug.must_equal "slug"
    end
  end

  describe "#calculate_path" do
    it "should generate the correct path given a slug" do
      IsAddressable.calculate_path("slug").must_equal "/widgets/slug"
    end
  end

  describe "#base_path" do
    it "should return base path where new records will be placed" do
      IsAddressable.base_path.must_equal "/widgets/"
    end
  end

  describe ".page_title" do
    it "should default to the name" do
      addressable.name = "Some Name"
      addressable.page_title.must_equal "Some Name"
    end

  end
end

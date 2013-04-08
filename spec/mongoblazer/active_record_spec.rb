require 'spec_helper'

describe Mongoblazer::ActiveRecord do

  describe ".mongoblazable" do
    context "not enabled" do
      subject { NotEnabled }
      it { should_not be_mongoblazable }
    end

    context "enabled" do
      subject { Enabled }
      it { should be_mongoblazable }
    end

    context "enabled in parent" do
      subject { EnabledInParent }
      it { should be_mongoblazable }
    end

    context "options" do
      subject { EnabledInParent.mongoblazer_options }
      it { should eq({:indexes=>[], :default_scope=>[], :embeds_one=>[], :embeds_many=>[:posts], :includes=>{:posts=>[{:comments=>:user}, :tags]}}) }
    end
  end

  describe ".create_mongoblazer_class!" do
    subject { Enabled }

    it "should have defined the EnabledBlazer class" do
      defined?(EnabledBlazer).should eq "constant"
    end
  end

  describe ".mongoblaze!" do
    let(:post) { Post.create(title: "Foo", body: "Bar baz burp", status: 'published')}
    let(:enabled) { Enabled.create(name: "Enabled", posts: [post]) }

    context "after_create" do
      before { Enabled.any_instance.should_receive :mongoblaze! }

      it { enabled }
    end

    context "with relations" do
      subject { enabled.mongoblazed }

      it "should contain a post" do
        subject.posts.size.should eq 1
      end

      context "related data" do
        subject {  enabled.mongoblazed.posts.first }

        its(:title)   { should eq "Foo" }
        its(:body)    { should eq "Bar baz burp" }
        its(:status)  { should eq "published" }
      end
    end

    context "with enabled relations" do
      let(:enabled) { WithEnabledRelation.create(name: "FooBar", related_enableds: [related_enabled]) }
      let(:related_enabled) { RelatedEnabled.create(name: "Related To FooBar") }
      subject { enabled.mongoblazed }

      its(:name) { should eq "FooBar" }

      it "should have embedded related_enableds" do
        subject.related_enableds.size.should be 1
      end

      context "options" do
        subject { WithEnabledRelation.mongoblazer_options }
        it { should eq({:indexes=>[], :default_scope=>[], :embeds_one=>[], :embeds_many=>[:related_enableds], :includes=>:related_enableds}) }
      end

      context "relations" do
        subject {  enabled.mongoblazed.related_enableds.first }

        its(:name) { should eq "Related To FooBar" }
      end
    end

  end
end

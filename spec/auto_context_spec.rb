require 'helpers/connect'

DB.tables.each { |t| puts "dropping #{t}"; DB.drop_table t }

Sequel.extension :auto_context

describe Sequel::Context do
  before(:each) do
  end

  it "should work" do
    DB.create_table :languages do
      primary_key :id
      String :name
      String :iso
    end
    DB.create_table :fields do
      primary_key :id
      String :name
    end
    DB.create_table :descs do
      primary_key :id
      foreign_key :field_id, :fields
      foreign_key :language_id, :languages
      String :txt
    end
    
    classes = Sequel::Model.auto_models
    AppContext = Sequel.context(classes) do
      element :lang, Language
    end

    en = Language.create(:iso => 'en', :name => 'English')
    de = Language.create(:iso => 'de', :name => 'Deutsch')
    field = Field.create(:name => 'firstname')
    Desc.create(:txt => 'First name').update(:language => en, :field => field)
    Desc.create(:txt => 'Vorname').update(:language => de, :field => field)

    AppContext.lang = en
    field.desc.txt.should == 'First name'

    AppContext.lang = de
    field.desc.txt.should == 'Vorname'
  end
end


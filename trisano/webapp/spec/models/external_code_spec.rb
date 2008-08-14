require File.dirname(__FILE__) + '/../spec_helper'

describe ExternalCode do
  before(:each) do
    @external_code = ExternalCode.new
  end

  it "should be valid" do
    @external_code.should be_valid
  end

  describe 'telephone location type ids' do
    
    it 'should be able to provide a list of telephone location type ids' do
      ExternalCode.telephone_location_type_ids.should_not be_empty
    end
    
    it "should only return id codes (which isn't very OO, but there you have it)" do
      result = ExternalCode.telephone_location_type_ids[0].kind_of? Fixnum
      result.should be_true
    end

  end

  describe 'telephone location types' do
    
    it 'should return all telephone location types in sort order' do
      location_types = ExternalCode.telephone_location_types
      location_types.should_not be_empty
      location_types.first.code_description.should == 'Unknown'
    end

  end
  
  describe "find codes for autocomplete" do
    
    before(:each) do
      @external_code_1 = ExternalCode.create(:code_name => "test", :code_description => "ZZAA", :the_code => "ZZAA")
      @external_code_2 = ExternalCode.create(:code_name => "test", :code_description => "ZZAB", :the_code => "ZZAB")
      @external_code_3 = ExternalCode.create(:code_name => "test", :code_description => "XXCC", :the_code => "XXCC")
    end
  
    it "should return all matching codes based on a first letter" do
      codes = ExternalCode.find_codes_for_autocomplete("ZZ")
      codes.size.should eql(2)
      codes[0].is_a?(ExternalCode).should be_true
      
      codes = ExternalCode.find_codes_for_autocomplete("XX")
      codes.size.should eql(1)
      codes[0].is_a?(ExternalCode).should be_true
    end
    
    it "should return no codes if there is no match" do
      codes = ExternalCode.find_codes_for_autocomplete("ZZZZZZ")
      codes.size.should eql(0)
    end
    
    it "should return no codes if nil is provided as a condition" do
      codes = ExternalCode.find_codes_for_autocomplete(nil)
      codes.size.should eql(0)
    end
    
    it "should limit results based on a provided limit" do
      codes = ExternalCode.find_codes_for_autocomplete("ZZ", 1)
      codes.size.should eql(1)
      codes[0].is_a?(ExternalCode).should be_true
    end
    
  end
end

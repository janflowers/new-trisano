# Copyright (C) 2007, 2008, 2009, 2010 The Collaborative Software Foundation
#
# This file is part of TriSano.
#
# TriSano is free software: you can redistribute it and/or modify it under the
# terms of the GNU Affero General Public License as published by the
# Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# TriSano is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with TriSano. If not, see http://www.gnu.org/licenses/agpl-3.0.txt.

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

include HL7

describe Message do
  before :each do
    @hl7 = HL7::Message.parse(hl7_messages[:arup_1])
  end

  it 'should respond to :message_header' do
    @hl7.should respond_to(:message_header)
  end

  it 'should respond to :patient_id' do
    @hl7.should respond_to(:patient_id)
  end

  it 'should respond to :observation_requests' do
    @hl7.should respond_to(:observation_requests)
  end

  it 'should respond to :enhanced_ack_mode?' do
    @hl7.should respond_to(:enhanced_ack_mode?)
  end

  it 'should return a message_header' do
    @hl7.message_header.class.should == StagedMessages::MshWrapper
  end

  it 'should return a patient ID' do
    @hl7.patient_id.class.should == StagedMessages::PidWrapper
  end

  it 'should return an array of observation requests' do
    @hl7.observation_requests.class.should == Array
  end

  it 'should parse the Realm minimal sample message' do
    # Basic sanity check: Pass in an actual 2.5.1 message.
    HL7::Message.parse HL7MESSAGES[:realm_minimal_message]
  end

  describe 'original and enhanced ack modes' do
    it 'should recognize the Realm minimal message as enhanced mode' do
      HL7::Message.parse(HL7MESSAGES[:realm_minimal_message]).should be_enhanced_ack_mode
    end

    it 'should recognize the NIST-1 sample message as original mode' do
      HL7::Message.parse(HL7MESSAGES[:nist_sample_1]).should_not be_enhanced_ack_mode
    end
  end

  describe 'message header' do
    it 'should return the sending facility (without noise)' do
      @hl7.message_header.sending_facility.should == 'ARUP LABORATORIES'
    end
  end

  describe 'patient identifier' do
    # PID|1||17744418^^^^MR||LIN^GENYAO^^^^^L||19840810|M||U^Unknown^HL70005|215 UNIVERSITY VLG^^SALT LAKE CITY^UT^84108^^M||^^PH^^^801^5854967|||||||||U^Unknown^HL70189\rORC||||||||||||^ROSENKOETTER^YUKI^K|||||||||University Hospital UT|50 North Medical Drive^^Salt Lake City^UT^84132^USA^B||^^^^^USA^B

    it 'should return the patient name (formatted)' do
      @hl7.patient_id.patient_name.should == 'Zhang, George'
    end

    it 'should return the patient birth date' do
      @hl7.patient_id.birth_date.should == Date.parse("19830922")
    end

    it 'should return the patient sex ID' do
      @hl7.patient_id.trisano_sex_id.should == external_codes(:gender_male).id
    end

    it 'should return the patient race ID' do
      @hl7.patient_id.trisano_race_id.should == external_codes(:race_unknown).id
    end

    it "should have a non-empty address" do
      @hl7.patient_id.address_empty?.should == false
    end

    it "should have an empty address if there is one" do
      hl7 = HL7::Message.parse(hl7_messages[:arup_simple_pid])
      hl7.patient_id.address_empty?.should == true
    end

    it 'should return the street number' do
      @hl7.patient_id.address_street_no.should == '42'
    end

    it 'should return the unit no' do
      @hl7.patient_id.address_unit_no.should be_blank
    end

    it 'should return the street name' do
      @hl7.patient_id.address_street.should == "Happy Ln"
    end

    it 'should return the city' do
      @hl7.patient_id.address_city.should == "Salt Lake City"
    end

    it 'should return the state ID' do
      @hl7.patient_id.address_trisano_state_id.should == external_codes(:state_utah).id
    end

    it 'should return the zip code' do
      @hl7.patient_id.address_zip.should == "84444"
    end

    it 'should return the country if present' do
      HL7::Message.parse(HL7MESSAGES[:realm_campylobacter_jejuni]).patient_id.address_country.should == "USA"
    end

    it "should have a non-empty telephone" do
      @hl7.patient_id.telephone_empty?.should == false
    end

    it "should have an empty telephone if there is one" do
      hl7 = HL7::Message.parse(hl7_messages[:arup_simple_pid])
      hl7.patient_id.telephone_empty?.should == true
    end

    it "should return the phone number components" do
      a, n, e = @hl7.patient_id.telephone_home
      a.should == "801"
      n.should == "5552346"
      e.should be_blank
    end

    it "should return the phone number components when encoded as a single string" do
      hl7 = HL7::Message.parse(hl7_messages[:ihc_1])
      a, n, e = hl7.patient_id.telephone_home
      a.should == "801"
      n.should == "5554412"
      e.should be_blank
    end

    it 'should return a home telephone type of Home when the HL7 type is PH' do
      hl7 = HL7::Message.parse(hl7_messages[:realm_campylobacter_jejuni])
      hl7.patient_id.telephone_type_home.should == external_codes(:telephonelocationtype_home)
    end

    it 'should return a home telephone type of Mobile when the HL7 type is CP' do
      hl7 = HL7::Message.parse(hl7_messages[:realm_cj_cell_phone])
      hl7.patient_id.telephone_type_home.should == external_codes(:telephonelocationtype_mobile)
    end

    it 'should return a home telephone type of Pager when the HL7 type is BP' do
      hl7 = HL7::Message.parse(hl7_messages[:realm_cj_pager])
      hl7.patient_id.telephone_type_home.should == external_codes(:telephonelocationtype_pager)
    end

    it 'should return a home telephone type of Unknown when the HL7 type is anything else' do
      hl7 = HL7::Message.parse(hl7_messages[:realm_cj_unk_phone])
      hl7.patient_id.telephone_type_home.should == external_codes(:telephonelocationtype_unknown)
    end

    it 'should properly parse a PHIN White race code in an HL7 2.5.1 message' do
      hl7 = HL7::Message.parse HL7MESSAGES[:realm_minimal_message]
      hl7.patient_id.trisano_race_id.should == external_codes(:race_white).id
    end

    it 'should properly parse a PHIN Asian race code in an HL7 2.5.1 message' do
      hl7 = HL7::Message.parse HL7MESSAGES[:realm_campy_jejuni_asian]
      hl7.patient_id.trisano_race_id.should == external_codes(:race_asian).id
    end

    it 'should properly parse a PHIN American Indian or Alaskan Native race code in an HL7 2.5.1 message' do
      hl7 = HL7::Message.parse HL7MESSAGES[:realm_campy_jejuni_ai_or_an]
      hl7.patient_id.trisano_race_id.should include(external_codes(:race_indian).id)
      hl7.patient_id.trisano_race_id.should include(external_codes(:race_alaskan).id)
      hl7.patient_id.trisano_race_id.size.should == 2
    end

    it 'should properly parse a PHIN Black or African American race code in an HL7 2.5.1 message' do
      hl7 = HL7::Message.parse HL7MESSAGES[:realm_campy_jejuni_black]
      hl7.patient_id.trisano_race_id.should == external_codes(:race_black).id
    end

    it 'should properly parse a PHIN Native Hawaiian or Other Pacific Islander race code in an HL7 2.5.1 message' do
      hl7 = HL7::Message.parse HL7MESSAGES[:realm_campy_jejuni_hawaiian]
      hl7.patient_id.trisano_race_id.should == external_codes(:race_hawaiian).id
    end

    it 'should properly parse a PHIN Unknown race code in an HL7 2.5.1 message' do
      hl7 = HL7::Message.parse HL7MESSAGES[:realm_campy_jejuni_unknown]
      hl7.patient_id.trisano_race_id.should == external_codes(:race_unknown).id
    end

    it 'should handle parsing a bad race code in an HL7 2.5.1 message' do
      hl7 = HL7::Message.parse HL7MESSAGES[:realm_campy_jejuni_bad_race_condition]
      hl7.patient_id.trisano_race_id.should == external_codes(:race_unknown).id
    end
  end

  describe 'observation request' do
    it 'should return the test performed (without noise)' do
      @hl7.observation_requests.first.test_performed.should == 'Hepatitis Be Antigen'
    end

    it 'should return the collection date' do
      @hl7.observation_requests.first.collection_date.should == '2009-03-19'
    end

    it 'should return the specimen source' do
      @hl7.observation_requests.first.specimen_source.should == 'BLOOD'
    end

    it 'should return a list of test_results' do
      @hl7.observation_requests.first.tests.should_not be_nil
    end

    it 'should return the filler_order_number (accession number)' do
      HL7::Message.parse(HL7MESSAGES[:realm_campylobacter_jejuni]).observation_requests.first.filler_order_number.should == "9700123"
    end

    it 'should return the specimen ID (when SPM present)' do
      HL7::Message.parse(HL7MESSAGES[:realm_campylobacter_jejuni]).observation_requests.first.specimen_id.should == "23456"
    end

    it 'should return the OBR observation date (as collection date) if present' do
      # this message has an OBR-7
      HL7::Message.parse(HL7MESSAGES[:nist_obr_observation_date]).observation_requests.first.collection_date.should == Date.parse('201007281400').to_s
    end

    it 'should return the OBX observation date (as collection date) if appropriate' do
      # this message has no OBR-7 but an OBX-14
      HL7::Message.parse(HL7MESSAGES[:nist_obx_observation_date]).observation_requests.first.collection_date.should == Date.parse('201007281400').to_s
    end

    it 'should return the SPM collection date if appropriate' do
      # this message has no OBR-7 or OBX-14 but an SPM-17
      HL7::Message.parse(HL7MESSAGES[:nist_spm_collection_date]).observation_requests.first.collection_date.should == Date.parse('201007281359').to_s
    end

    it 'should return the OBR requested date if present' do
      # this message has no OBR-7, OBX-14 or SPM-17 field but has an OBX-6
      HL7::Message.parse(HL7MESSAGES[:nist_obr_requested_date]).observation_requests.first.collection_date.should == Date.parse('201007281358').to_s
    end

    it 'should return nil for observation date if no OBR-7, OBX-14, SPM-17 or OBX-6 present' do
      # this message has no OBR-7, OBX-14, SPM-17 or OBR-6
      HL7::Message.parse(HL7MESSAGES[:nist_no_collection_date]).observation_requests.first.collection_date.should be_nil
    end

    describe 'specimen segment' do
      before :all do
        # This is an OBR segment that should have an SPM segment.
        @arup_3 = HL7::Message.parse(hl7_messages[:arup_3]).observation_requests.first
      end

      it 'should be an SpmWrapper object' do
        @arup_3.specimen.should be_a(StagedMessages::SpmWrapper)
      end

      it 'should have an :spm_segment method returning an SPM object' do
        @arup_3.specimen.spm_segment.should be_an(HL7::Message::Segment::SPM)
      end

      it 'should return \'Whole Blood\' as the specimen source' do
        @arup_3.specimen_source.should == 'Whole Blood'
      end
    end

    describe 'tests' do
      before :each do
        @tests = @hl7.observation_requests.first.tests
      end

      it 'should be a list' do
        @tests.should respond_to(:each)
      end

      it 'should not be an empty list' do
        @tests.should_not be_empty
      end

      it 'should return observation_date' do
        @tests[0].observation_date.should == '2009-03-21'
      end

      it 'should return result' do
        @tests[0].result.should == 'Positive'
      end

      it 'should return a reference range' do
        @tests[0].reference_range.should == 'Negative'
      end

      it 'should return the test type (without the noise)' do
        @tests[0].test_type.should == 'Hepatitis Be Antigen'
      end
    end

    describe 'the ObxWrapper' do
      before :all do
        @realm_min_test =
          HL7::Message.parse(HL7MESSAGES[:realm_minimal_message]).observation_requests.first.all_tests.first
        @realm_cj_test =
          HL7::Message.parse(HL7MESSAGES[:realm_campylobacter_jejuni]).observation_requests.first.all_tests.first
        @realm_ar_test =
          HL7::Message.parse(HL7MESSAGES[:realm_animal_rabies]).observation_requests.first.all_tests.first
      end

      it 'should take :loinc_scale from CWE.2 if present' do
        @realm_cj_test.loinc_scale.should == 'Nom'
      end

      it 'should take :loinc_scale from OBX-2 if not present in CWE.2' do
        @realm_min_test.loinc_scale.should == 'Qn'
      end

      it 'should return a nil :loinc_scale if not present in CWE.2 or OBX-2' do
        @realm_ar_test.loinc_scale.should be_nil
      end

      it 'should take :loinc_common_test_type from CWE.2 if present' do
        @realm_cj_test.loinc_common_test_type.should == 'Culture'
      end

      it 'should return a nil :loinc_common_test_type if not present in CWE.2' do
        @realm_ar_test.loinc_common_test_type.should be_nil
      end

      it 'should parse a CWE result properly' do
        @realm_cj_test.result.should == 'Campylobacter jejuni'
        @realm_ar_test.result.should == 'Detected'
      end

      it 'should parse a Default result properly' do
        @realm_min_test.result.should == '50'
      end

      it 'should return the abnormal flags if set' do
        HL7::Message.parse(HL7MESSAGES[:realm_cj_abnormal_flags]).observation_requests.first.all_tests.first.abnormal_flags.should == "H"
      end

      it 'should return OBX-19 for analysis_date if present' do
        HL7::Message.parse(HL7MESSAGES[:nist_sample_5]).observation_requests.first.all_tests.first.analysis_date.should == '2010-07-30'
      end

      it 'should return OBX-14 for analysis_date if no OBX-19 present' do
        HL7::Message.parse(HL7MESSAGES[:arup_1]).observation_requests.first.all_tests.first.analysis_date.should be_nil
      end
    end
  end

  describe 'batch processing' do
    it 'should have a class method HL7::Message.parse_batch' do
      HL7::Message.should respond_to(:parse_batch)
    end

    it 'should raise an exception when parsing an empty batch' do
      # :empty_batch message contains a valid batch envelope with no
      # contents
      lambda do
        HL7::Message.parse_batch HL7MESSAGES[:empty_batch]
      end.should raise_exception(HL7::ParseError, 'empty_batch_message')
    end

    it 'should raise an exception when parsing a single message as a batch' do
      lambda do
        HL7::Message.parse_batch HL7MESSAGES[:realm_minimal_message]
      end.should raise_exception(HL7::ParseError, 'badly_formed_batch_message')
    end

    it 'should yield multiple messages from a valid batch' do
      count = 0
      HL7::Message.parse_batch(HL7MESSAGES[:realm_batch]) do |m|
        count += 1
      end
      count.should == 2
    end
  end
end

describe 'String extension' do
  before :all do
    @batch_message = HL7MESSAGES[:realm_batch]
    @plain_message = HL7MESSAGES[:realm_minimal_message]
  end

  it 'should respond_to :hl7_batch?' do
    @batch_message.should respond_to(:hl7_batch?)
    @plain_message.should respond_to(:hl7_batch?)
  end

  it 'should return true when passed a batch message' do
    @batch_message.should be_an_hl7_batch
  end

  it 'should return false when passed a plain message' do
    @plain_message.should_not be_an_hl7_batch
  end
end

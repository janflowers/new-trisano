# Copyright (C) 2007, 2008, The Collaborative Software Foundation
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

require 'active_support'
require File.dirname(__FILE__) + '/spec_helper'

# $dont_kill_browser = true

describe 'Soft deleting individual events' do
  
  before(:all) do
    @cmr_last_name = get_unique_name(1) + " sd-uat"
    @contact_last_name = get_unique_name(1) + " sd-uat"
    @place_name = get_unique_name(1) + " sd-uat"
  end

  after(:all) do
    @cmr_last_name = nil
    @contact_last_name = nil
    @place_name = nil
  end
  
  it "should create a CMR with a contact and a place" do
    @browser.open "/trisano/cmrs"
    click_nav_new_cmr(@browser)
    @browser.type "morbidity_event_active_patient__person_last_name", @cmr_last_name

    click_core_tab(@browser, "Contacts")
    @browser.type "//div[@class='contact'][1]//input[contains(@id, 'last_name')]", @contact_last_name
    @browser.type "morbidity_event_new_place_exposure_attributes__name", @place_name
    save_cmr(@browser).should be_true

    @browser.is_text_present('CMR was successfully created.').should be_true
    @browser.is_text_present(@cmr_last_name).should be_true
    @browser.is_text_present(@contact_last_name).should be_true
    @browser.is_text_present(@place_name).should be_true
  end
  
  it "should should soft delete the morbidity event" do
    @browser.click("soft-delete")
    @browser.get_confirmation()   
    @browser.wait_for_page_to_load($load_time)
    @browser.is_text_present("The event was successfully marked as deleted.").should be_true
    @browser.is_text_present("Delete").should be_false
  end
  
  it "should should soft delete the contact event" do
    @browser.click("link=Edit contact event")
    @browser.wait_for_page_to_load($load_time)
    @browser.click("link=Show")
    @browser.wait_for_page_to_load($load_time)
    @browser.click("soft-delete")
    @browser.get_confirmation()   
    @browser.wait_for_page_to_load($load_time)
    @browser.is_text_present("The event was successfully marked as deleted.").should be_true
    @browser.is_text_present("Delete").should be_false
  end
  
    it "should should soft delete the place event" do
    @browser.click("link=#{@cmr_last_name}")
    @browser.wait_for_page_to_load($load_time)
    @browser.click("link=Edit place details")
    @browser.wait_for_page_to_load($load_time)
    @browser.click("link=Show")
    @browser.wait_for_page_to_load($load_time)
    @browser.click("soft-delete")
    @browser.get_confirmation()   
    @browser.wait_for_page_to_load($load_time)
    @browser.is_text_present("The event was successfully marked as deleted.").should be_true
    @browser.is_text_present("Delete").should be_false
  end

end

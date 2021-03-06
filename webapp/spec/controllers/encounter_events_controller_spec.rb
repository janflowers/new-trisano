# Copyright (C) 2007, 2008, 2009, 2010, 2011, 2012, 2013 The Collaborative Software Foundation
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

require File.dirname(__FILE__) + '/../spec_helper'

describe EncounterEventsController do
  
  before(:each) do
    create_user
  end

  describe "handling GET /encounter_events" do

    before(:each) do
      @user.stubs(:can_view?).returns(true)
    end
  
    def do_get
      get :index
    end
  
    it "should return a 405" do
      do_get
      response.code.should == "405"
    end

    describe "handling GET /encounter_events/1 with view entitlement" do

      before(:each) do
        @event = mock_event
        Event.stubs(:find).returns(@event)
        @user.stubs(:is_entitled_to_in?).with(:view_event, 75).returns(true)
        @event.stubs(:read_attribute).returns('EncounterEvent')
      end
  
      def do_get
        get :show, :id => "75"
      end

      it "should be successful" do
        do_get
        response.should be_success
      end
  
      it "should render show template" do
        do_get
        response.should render_template('show')
      end
  
      it "should find the event requested" do
        Event.expects(:find).once().with("75").returns(@event)
        do_get
      end
  
      it "should assign the found event for the view" do
        do_get
        assigns[:event].should equal(@event)
      end
    end
  
    describe "handling GET /encounter_events/1 without view entitlement" do

      before(:each) do
        @event = Factory(:encounter_event)
        @user.stubs(:can_view?).returns(false)
      end
  
      it "should redirect to the new event access view" do
        get :show, :id => @event.id
        response.should redirect_to(new_event_access_record_url(@event))
      end

    end

    describe "handling GETting a real event of the wrong type" do

      before(:each) do
        @event = Factory(:morbidity_event)
        @user.stubs(:can_view?).returns(true)
      end
  
      def do_get
        get :show, :id => @event.id
      end

      it "should return a 404" do
        do_get
        response.response_code.should == 404
      end

      it "should render the public 404 page" do
        do_get
        response.should render_template "shared/_missing_event"
      end

    end

    describe "handling GET /encounter_events/new" do
      before do
        @user.stubs(:can_view?).returns(true)
        @user.stubs(:can_create?).returns(true)
        @user.stubs(:can_update?).returns(true)
      end
  
      it "should return a 405" do
        get :new
        response.code.should == "405"
      end
  
    end

    describe "handling GET /encounter_events/1/edit with update entitlement" do

      before(:each) do
        @event = Factory(:encounter_event)
        @user.stubs(:can_update?).returns(true)
      end
  
      def do_get
        get :edit, :id => @event.id
      end

      it "should be successful" do
        do_get
        response.should be_success
      end
  
      it "should render edit template" do
        do_get
        response.should render_template('edit')
      end
  
      it "should assign the found EncounterEvent for the view" do
        do_get
        assigns[:event].should == @event
      end
    end

  end
  
  describe "handling successful POST /encounter_events/1/soft_delete with update entitlement" do
    
    before(:each) do
      mock_user
      @event = mock_event
      Event.stubs(:find).returns(@event)
      @event.stubs(:read_attribute).returns("EncounterEvent")
      @user.stubs(:is_entitled_to_in?).returns(true)
      @event.stubs(:add_note).returns(true)
    end
    
    def do_post
      request.env['HTTP_REFERER'] = "/some_path"
      post :soft_delete, :id => "1"
    end

    it "should redirect to where the user came from" do
      @event.expects(:soft_delete).returns(true)
      do_post
      response.should redirect_to("http://test.host/some_path")
    end
    
    it "should set the flash notice to a success message" do
      @event.expects(:soft_delete).returns(true)
      do_post
      flash[:notice].should eql("The event was successfully marked as deleted.")
    end
  end
  
  describe "handling failed POST /encounter_events/1/soft_delete with update entitlement" do
    
    before(:each) do
      mock_user
      @event = mock_event
      Event.stubs(:find).returns(@event)
      @event.stubs(:read_attribute).returns("EncounterEvent")
      @user.stubs(:is_entitled_to_in?).returns(true)
      @event.stubs(:add_note).returns(true)
    end
    
    def do_post
      request.env['HTTP_REFERER'] = "/some_path"
      post :soft_delete, :id => "1"
    end

    it "should redirect to where the user came from" do
      @event.expects(:soft_delete).returns(false)
      do_post
      response.should redirect_to("http://test.host/some_path")
    end
    
    it "should set the flash error to an error message" do
      @event.expects(:soft_delete).returns(false)
      do_post
      flash[:error].should eql("An error occurred marking the event as deleted.")
    end

    it "should not add a note" do
      @event.expects(:soft_delete).returns(false)
      @event.expects(:add_note).never
      do_post
    end
  end
  
  describe "handling POST /encounter_events/1/soft_delete without update entitlement" do
    
    before(:each) do
      @event = Factory(:encounter_event)
      @user.stubs(:can_update?).returns(false)
    end
    
    def do_post
      request.env['HTTP_REFERER'] = "/some_path"
      post :soft_delete, :id => @event.id
    end

    it "should be be a 403" do
      do_post
      response.response_code.should == 403
    end

    it "should not add a note" do
      @event.expects(:add_note).never
      do_post
    end
  end
  
end

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

describe CoreFieldElementsController do
  describe "handling GET /core_field_elements" do

    before(:each) do
      mock_user
      @core_field_element = Factory.build(:core_field_element)
      CoreFieldElement.stubs(:find).returns([@core_field_element])
    end
  
    def do_get
      get :index
    end
  
    it "should return a 405" do
      do_get
      response.response_code.should == 405
    end
  end

  describe "handling GET /core_field_elements/1" do

    before(:each) do
      mock_user
      @core_field_element = Factory.build(:core_field_element)
      CoreFieldElement.stubs(:find).returns(@core_field_element)
    end
  
    def do_get
      get :show, :id => "1"
    end

    it "should return a 405" do
      do_get
      response.response_code.should == 405
    end
  end

  describe "handling GET /core_field_elements/new" do

    before(:each) do
      mock_user
      @core_field_element = Factory.build(:core_field_element)
      CoreFieldElement.stubs(:new).returns(@core_field_element)
      @core_field_element.stubs(:available_core_fields).returns([])
    end
  
    def do_get
      get :new
    end

    it "should be successful" do
      do_get
      response.should be_success
    end
  
    it "should render new template" do
      do_get
      response.should render_template('new')
    end
  
    it "should create an new core_field_element" do
      CoreFieldElement.expects(:new).returns(@core_field_element)
      do_get
    end
  
    it "should not save the new core_field_element" do
      @core_field_element.expects(:save).never
      do_get
    end
  
    it "should assign the new core_field_element for the view" do
      do_get
      assigns[:core_field_element].should equal(@core_field_element)
    end
  end

  describe "handling GET /core_field_elements/1/edit" do

    before(:each) do
      mock_user
      @core_field_element = Factory.build(:core_field_element)
      CoreFieldElement.stubs(:find).returns(@core_field_element)
    end
  
    def do_get
      get :edit, :id => "1"
    end

    it "should return a 405" do
      do_get
      response.response_code.should == 405
    end
  end

  describe "handling POST /core_field_elements" do

    before(:each) do
      mock_user
      @core_field_element = Factory.build(:core_field_element)
      @core_field_element.stubs(:form_id).returns(1)
      CoreFieldElement.stubs(:new).returns(@core_field_element)
    end
    
    describe "with successful save" do
  
      def do_post
        @request.env["HTTP_ACCEPT"] = "application/javascript"
        @core_field_element.expects(:save_and_add_to_form).returns(true)
        Form.stubs(:find).with(1).returns(Factory.build(:form))
        post :create, :core_field_element => {}
      end
  
      it "should create a new core_field_element" do
        CoreFieldElement.expects(:new).with({}).returns(@core_field_element)
        do_post
      end

      it "should redirect to the new core_field_element" do
        do_post
        response.should render_template('create')
      end
      
    end
    
    describe "with failed save" do

      def do_post
        @request.env["HTTP_ACCEPT"] = "application/javascript"
        @core_field_element.expects(:save_and_add_to_form).returns(false)
        @core_field_element.stubs(:available_core_fields).returns([])
        @core_field_element.errors.expects(:each)
        post :create, :core_field_element => {}
      end
  
      it "should re-render 'new'" do
        do_post
        response.should render_template('new')
      end
      
    end
  end

  describe "handling PUT /core_field_elements/1" do

    before(:each) do
      mock_user
      @core_field_element = Factory.build(:core_field_element)
      CoreFieldElement.stubs(:find).returns(@core_field_element)
    end
    
    def do_put
      put :update, :id => "1"
    end

    it "should return a 405" do
      do_put
      response.response_code.should == 405
    end
  end

  describe "handling DELETE /core_field_elements/1" do

    before(:each) do
      mock_user
      @core_field_element = Factory.build(:core_field_element)
      CoreFieldElement.stubs(:find).returns(@core_field_element)
    end
  
    def do_delete
      delete :destroy, :id => "1"
    end

    it "should find the core_field_element requested" do
      CoreFieldElement.expects(:find).with("1").returns(@core_field_element)
      do_delete
    end
  
    it "should call destroy on the found core_field_element" do
      @core_field_element.expects(:destroy_and_validate)
      do_delete
    end
  
    it "should redirect to the core_field_elements list" do
      do_delete
      response.should redirect_to(core_field_elements_url)
    end
  end
end

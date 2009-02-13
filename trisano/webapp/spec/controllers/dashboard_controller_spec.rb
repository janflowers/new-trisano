# Copyright (C) 2007, 2008, 2009 The Collaborative Software Foundation
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

describe DashboardController do

  describe "handling GET /dashboard" do
    
    before(:each) do
      mock_user
      @task = mock('a task')
      Task.should_receive(:find_all_by_user_id).with(User.current_user.id).and_return([@task])
    end
    
    def do_get
      get :index
    end
    
    it "should be successful" do
      do_get
      response.should be_success
    end
    
    it "should render index template" do
      do_get
      response.should render_template('index')
    end
    
    it "should assign a user" do
      do_get
      User.current_user.nil?.should be_false
    end

    it "should find user tasks" do
      do_get
    end

    it "should assign tasks" do
      do_get
      assigns[:tasks].should == [@task]
    end
    
  end
 
  describe "handling GET /dashboard with no logged in user" do
    before(:each) do
      controller.session[:user_id] = ''
    end
    
    it "should redirect to 500 error page" do
      get :index
      response.response_code.should == 500
    end
    
  end
  
end

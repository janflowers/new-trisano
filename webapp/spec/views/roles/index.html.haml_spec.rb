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

require File.dirname(__FILE__) + '/../../spec_helper'

describe "/roles/index.html.haml" do
  include RolesHelper
  
  before(:each) do
    role_98 = mock_model(Role)
    role_98.stub!(:find).and_return([@role])
    role_98.stub!(:role_name).and_return("role name")
    role_98.stub!(:description).and_return("role description")
    role_98.stub!(:role_memberships).and_return([])
    role_98.stub!(:privileges_roles).and_return([])

    assigns[:roles] = [role_98, role_98]
  end

  it "should render list of roles" do
    render "/roles/index.html.haml"
  end
end

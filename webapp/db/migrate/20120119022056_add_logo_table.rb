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
class AddLogoTable < ActiveRecord::Migration
  extend MigrationHelpers

  def self.up
    create_table :logos do |t|
      t.integer :size
      t.string :content_type
      t.string :filename
      t.integer :height
      t.integer :width
      t.integer :db_file_id

      t.timestamps
    end

    add_foreign_key :logos, :db_file_id, :db_files

  end

  def self.down
    remove_foreign_key :logos, :db_file_id
    drop_table :logos
  end
end

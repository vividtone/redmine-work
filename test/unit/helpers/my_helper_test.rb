# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../../test_helper', __FILE__)

class MyHelperTest < Redmine::HelperTest
  include ERB::Util
  include MyHelper
  include SortHelper

  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :versions

  def test_timelog_items_should_include_time_entries_without_issue
    User.current = User.find(2)
    entry = TimeEntry.generate!(:spent_on => Date.today, :user_id => 2, :project_id => 1)
    assert_nil entry.issue

    assert_include entry, timelog_items.first
  end

  def test_timelog_items_should_include_time_entries_with_issue
    User.current = User.find(2)
    entry = TimeEntry.generate!(:spent_on => Date.today, :user_id => 2, :project_id => 1, :issue_id => 1)
    assert_not_nil entry.issue

    assert_include entry, timelog_items.first
  end

  def test_issuequery_items_should_return_query_and_ten_sorted_issues
    User.current = User.find(2)
    query, issues = issuequery_items(5)

    assert_equal query.name, "Open issues by priority and tracker"
    assert_equal [7, 9, 10, 14, 2, 1, 3, 4, 5, 6], issues.map(&:id)
  end
end

class AddProjectsDefaultQueryId < ActiveRecord::Migration
  def self.up
    unless column_exists?(:projects, :default_query_id, :integer)
      add_column :projects, :default_query_id, :integer, :default => nil
    end
  end

  def self.down
    remove_column :projects, :default_query_id
  end
end

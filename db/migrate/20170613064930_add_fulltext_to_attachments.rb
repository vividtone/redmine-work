class AddFulltextToAttachments < ActiveRecord::Migration
  def change
    add_column :attachments, :fulltext, :text, :limit => 4.megabytes # room for at least 1 million characters / approx. 80 pages of english text
  end
end

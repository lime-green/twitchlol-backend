class CreateSummoners < ActiveRecord::Migration
  def change
      create_table :summoners do |t|
          t.string :name
          t.string :region
      end
  end
end

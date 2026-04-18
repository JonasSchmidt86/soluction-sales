class AddOrigemToPessoa < ActiveRecord::Migration[7.1]
  def change
    add_reference :pessoa, :origem, foreign_key: true
  end
end
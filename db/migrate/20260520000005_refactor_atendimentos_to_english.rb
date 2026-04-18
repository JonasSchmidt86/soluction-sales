class RefactorAtendimentosToEnglish < ActiveRecord::Migration[7.1]
  def change
    # 🔄 renomear campos
    rename_column :atendimentos, :data_atendimento, :attended_at
    rename_column :atendimentos, :vendeu, :sold
    rename_column :atendimentos, :date_return, :return_at

    # 🔄 alterar tipo (date → datetime)
    change_column :atendimentos, :return_at, :datetime

    # ➕ adicionar status
    add_column :atendimentos, :status, :integer, default: 0, null: false

    # 🚀 índice (opcional mas recomendado)
    add_index :atendimentos, :status
  end
end
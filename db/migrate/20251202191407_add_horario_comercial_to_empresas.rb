class AddHorarioComercialToEmpresas < ActiveRecord::Migration[7.1]
  def change
    add_column :empresa, :horario_comercial_inicio, :time
    add_column :empresa, :horario_comercial_fim, :time
    add_column :empresa, :controlar_horario, :boolean, default: false
  end
end

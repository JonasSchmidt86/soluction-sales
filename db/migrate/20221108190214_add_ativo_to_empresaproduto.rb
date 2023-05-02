class AddAtivoToEmpresaproduto < ActiveRecord::Migration[5.2]
  def change
    add_column :empresaproduto, :ativo, :boolean, default: true
    
    # ALTER TABLE IF EXISTS public.empresaproduto DROP CONSTRAINT IF EXISTS empresaproduto_pkey;

    # ALTER TABLE IF EXISTS public.empresaproduto ADD CONSTRAINT empresaproduto_pkey PRIMARY KEY (id);

  end
end

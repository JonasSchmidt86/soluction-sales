class Lancamentosdiverso < ApplicationRecord
    
    self.table_name = "lancamentosdiversos"
    self.primary_key = "cod_lancamento"

    belongs_to :empresa,     :class_name => 'Empresa',              :foreign_key => 'cod_empresa' #, inverse_of: :lancamentos
    
    belongs_to :funcionario, :class_name => 'Funcionario',          :foreign_key => 'cod_funcionario' #, inverse_of: :lancamentos
    
    belongs_to :historico,   :class_name => 'Tiposhistoricoscaixa', :foreign_key => 'cod_tphitorico', inverse_of: :lancamentos
    
    validates :valor,numericality: { greater_than: 0, message: "Valor tem que ser maior que 0!" }
    validates :descricao, presence: { message: "Descrição não pode estar em branco!" }, length: { maximum: 50, message: "Descrição deve ter no máximo 50 caracteres!" }
    validates :datainicio, presence: { message: "Data de início é obrigatória!" }

    paginates_per 30
    
    def self.ransackable_attributes(auth_object = nil)
      ["cod_empresa", "cod_funcionario", "cod_lancamento", "cod_tphitorico", "datainicio", "datavencimento", "descricao", "entrada", "enumprovisionado", "provisionada", "valor"]
    end

end

# PARA O CADASTROS DOS LANCAMENTOS PROVISIONADOS


# -- Table: public.lancamentosdiversos

# -- DROP TABLE IF EXISTS public.lancamentosdiversos;

# CREATE TABLE IF NOT EXISTS public.lancamentosdiversos
# (
#     cod_empresa bigint NOT NULL,
#     cod_lancamento bigint NOT NULL,
#     datainicio date,
#     datavencimento date,
#     descricao character varying(50) COLLATE pg_catalog."default" NOT NULL,
#     entrada boolean,
#     enumprovisionado integer,
#     provisionada boolean,
#     valor numeric(18,2) NOT NULL DEFAULT 0.00,
#     cod_funcionario bigint,
#     cod_tphitorico bigint,
#     CONSTRAINT lancamentosdiversos_pkey PRIMARY KEY (cod_lancamento),
#     CONSTRAINT fk_empresa FOREIGN KEY (cod_empresa)
#         REFERENCES public.empresa (cod_empresa) MATCH SIMPLE
#         ON UPDATE NO ACTION
#         ON DELETE NO ACTION,
#     CONSTRAINT fk_tphistorico FOREIGN KEY (cod_tphitorico)
#         REFERENCES public.tiposhistoricoscaixa (cod_tphitorico) MATCH SIMPLE
#         ON UPDATE NO ACTION
#         ON DELETE NO ACTION,
#     CONSTRAINT lancamentosdiversos_cod_funcionario_fkey FOREIGN KEY (cod_funcionario)
#         REFERENCES public.funcionario (cod_funcionario) MATCH SIMPLE
#         ON UPDATE NO ACTION
#         ON DELETE NO ACTION
# )

# TABLESPACE pg_default;

# ALTER TABLE IF EXISTS public.lancamentosdiversos
#     OWNER to jonas;
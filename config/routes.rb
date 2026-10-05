Rails.application.routes.draw do
  # Silencia requisições automáticas do Chrome DevTools e sourcemaps ausentes
  # (evitam ActionController::RoutingError no log de desenvolvimento)
  get '/.well-known/appspecific/com.chrome.devtools.json', to: proc { [204, {}, ['']] }
  get '/assets/*path.map', to: proc { [204, {}, ['']] }

  root 'home#index'
  get 'produto/:cod_produto/:cod_cor', to: 'home#produto', as: 'produto'
  get 'portfolio', to: 'home#portfolio'

  # Página pública "link na bio" (Instagram) por empresa
  get 'l/:slug', to: 'link_pages#show', as: :link_page

  match 'orcamentos/:id/:nome_cliente', to: 'orcamentos_publicos#show', via: [:get, :post], as: :orcamento_publico
  post 'orcamentos/:id/:nome_cliente/duration', to: 'orcamentos_publicos#record_duration', as: :orcamento_publico_duration
  get 'orcamentos/:id/pdf', to: 'orcamentos_publicos#pdf', as: :orcamento_publico_pdf

  devise_for :collaborators, skip: [:registrations], controllers: { passwords: 'collaborators/passwords' }
  devise_for :users, skip: [:registrations]

  namespace :users_backoffice do
    get 'welcome/index'
    resources :whatsapp_contacts, only: [:index, :show]
  end

  namespace :collaborators_backoffice do
    get 'grupos/index'
    get 'grupos/new'
    get 'grupos/edit'
    namespace :report do
      get 'rep_dre/index'
      resources :custom_reports, only: [:index, :edit, :update, :new, :create, :show, :destroy] do
        member do
          get :run
        end
      end
    end
    
    get 'welcome/index'
    post 'welcome/index'

    # Troca da própria senha pelo colaborador logado (pede a senha atual)
    get  'change_password', to: 'passwords#edit',   as: :change_password
    patch 'change_password', to: 'passwords#update'

    # Widgets configuráveis do dashboard
    resources :dashboard_widgets, only: [:index, :update] do
      collection do
        patch :reorder
        post  :reset
      end
    end

    get 'search', to: 'produtos/search#produtos'
    get 'check_cpf_cnpj', to: 'check_cpf_cnpj'
    # cria varias rotas possiveis sem precisar criar uma a uma
    resources :collaborators, only: [:index, :edit, :update, :new, :create, :destroy, :check_cpf_cnpj]
    resources :atendimentos, only: [:create, :edit, :update, :destroy]
    
    resources :produtos, only: [:index, :edit, :update, :new, :create, :destroy, :show] do
      member do
        get :estoque
        post :atualizar_estoque
        post :desativar_estoque
        post :ativar_estoque
      end
    end
    resources :produto_imagens, only: [:index, :create, :edit, :destroy] do
      collection do
        get :get_cor_data
        get :biblioteca
        post :salvar_da_orcamento
        get :cadastro_rapido
        post :cadastro_rapido_salvar
        post :cadastro_rapido_linha
        post :cadastro_rapido_verificar
      end
    end
    resources :cores, only: [:index, :edit, :update, :new, :create, :destroy]
    
    resources :marcas
    resources :grupos, param: :cod_grupo

    resources :lembretes, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :funcionarios, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :acertosestoque, only: [:index, :create, :new, :destroy]
    resources :empresa_estoque, only: [:index, :edit, :destroy, :update] do
      collection do
        get 'by_color/:cor_id', to: 'empresa_estoque#by_color', as: :by_color
        patch :update_todos
      end
    end
    
    resources :caixa, only: [:index, :edit, :update, :new, :create, :destroy]
    # resources :contas_pag_rec, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :contas_pag_rec,
              only: [:index, :edit, :update, :new, :create, :destroy] do

      member do
        patch :record_payment
        get :payment_receipt
      end

      get :print_promissory_note, on: :collection
    end

    resources :lancamentoscaixas, only: [:index, :edit, :update, :new, :create, :destroy]
    
    resources :lancamentosdiversos do
      collection do
        get :pagamentos
      end
    end

    resources :orcamentos do
      member do
        post :converter_venda
        get :print
      end

      resource :editor, controller: "orcamento_editor", only: [:show] do
        patch :auto_save, on: :member
        patch :trocar_tema, on: :member
        patch :salvar_link, on: :member
      end

      resources :itens, controller: "orcamento_itens", only: [:create, :update, :destroy] do
        member do
          patch :toggle_posicao_foto
          patch :trocar_tamanho_foto
          patch :remover_foto
        end
        collection do
          patch :reordenar
        end
      end
    end
    
    resources :vendas, only: [:index, :edit, :new, :create, :update, :destroy] do
      patch :atualizar_vendedor, on: :member
      # Emissao fiscal a partir da venda (NF-e modelo 55). Reaproveita o
      # mesmo documento numa reemissao (ver Fiscal::EmissorFiscal).
      resources :documentos_fiscais, only: [:show], controller: "documentos_fiscais" do
        post :emitir, on: :collection
        get :espelho, on: :collection
        get :previsualizar, on: :collection # DANFE de pre-visualizacao (provedor)
        post :cancelar, on: :member
        get :danfe, on: :member
        get :xml, on: :member # baixa o XML (do banco ou do provedor pela chave)
        post :reconciliar, on: :member # consulta a SEFAZ e atualiza o status
        get :evento_arquivo, on: :member # PDF/XML de evento (CC-e/cancelamento)
      end
    end

    namespace :vendas do
      get 'prints/delivery_receipt', to: 'prints#delivery_receipt', as: :print_delivery_receipt
    end
    
    resources :melhorias, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
      member do
        post :comentar
        delete 'remover_anexo/:anexo_id', action: :remover_anexo, as: :remover_anexo
      end
    end

    resources :compras, only: [:index, :edit, :new, :create, :destroy, :show] do
      # Devolucao de compra (NF-e finalidade 4). new = tela de revisao/edicao;
      # create = emite. So super_admin + empresa com modulo fiscal.
      resource :devolucao, only: [:new, :create], controller: "devolucoes_compra" do
        # Pre-visualizacao do DANFE da devolucao (sem transmitir a SEFAZ).
        post :previsualizar
        # Baixa o XML da nota de entrada (compra) pela chave, via provedor.
        get :baixar_xml
        # Resolve o CFOP de um item pela regra fiscal ao trocar a operacao.
        get :resolver_cfop
      end
    end
    resources :pedidos_compras
    resources :produtoxmls, only: [:index, :edit, :new, :create, :destroy]
    resources :pessoas, only: [:index, :edit, :new, :create, :destroy, :update]
    resources :whatsapp_contacts #, only: [:index, :edit, :new, :create, :destroy, :update]
    resources :company_link_pages
    resources :whatsapp_messages, only: [:index, :new, :create, :edit, :update, :destroy]
    resources :xml_files, only: [:index, :edit, :new, :create, :destroy] do
      post 'import/:id', on: :member, to: 'xml_files#import', as: :import
    end
    resources :collaborators do
      post :reset_password, on: :member
    end
    
    resources :cadinternalframes

    # Módulo de Comissões
    resources :commission_rules, except: [:destroy] do
      member do
        delete :destroy
      end
    end
    resources :commission_assignments, only: [:index, :new, :create, :destroy]
    resources :commission_periods, only: [:index, :new, :create, :show, :destroy] do
      member do
        post :calculate
        post :finalize
        post :mark_as_paid
        post :reopen
        patch :update_sale_commission
      end
      collection do
        post :quick_create
      end
    end
    resources :commission_adjustments, only: [:index, :new, :create, :show] do
      member do
        post :cancel
      end
      collection do
        post :detect_cancelled
      end
    end

    # Módulo Fiscal (em desenvolvimento — visível apenas via permissão fiscal_*)
    # Dashboard do modulo fiscal (primeiro link da aba Fiscal).
    get 'fiscal_dashboard', to: 'fiscal_dashboard#index', as: :fiscal_dashboard

    resources :perfis_tributarios do
      resources :regras_fiscais, only: [:new, :create, :edit, :update, :destroy]
    end
    resource :fiscal_config, only: [:show, :edit, :update], controller: :fiscal_config do
      # Status operacional da SEFAZ (JSON) para o modelo informado (55/65).
      get :status_sefaz
      # Consulta de cadastro de contribuinte na SEFAZ (JSON).
      get :consultar_cadastro
      # Exportacao fiscal por periodo (zip XML/PDF ou Excel).
      get :exportar
      post :exportar_download
    end
    get 'fiscal_pendencias', to: 'fiscal_pendencias#index', as: :fiscal_pendencias

    # Emissao AVULSA de NF (sem venda). index=lista; new=form (modelo 55/65);
    # create=emite; show=detalhe; danfe/espelho/cancelar.
    resources :notas_avulsas, only: [:index, :new, :create, :show] do
      member do
        get  :danfe
        post :cancelar
      end
      collection do
        get :cores_produto # cores de um produto (p/ o select de cor)
        post :previsualizar # DANFE/DANFCE de pre-visualizacao (sem SEFAZ)
        get :resolver_cfop # resolve CFOP de um item pela regra (perfil + operacao)
      end
    end

    # Perfil tributario do produto a partir da venda (modal "Sem perfil fiscal").
    # index -> lista de perfis (JSON); show -> status fiscal do produto (JSON);
    # update -> grava cod_perfil_tributario no produto.
    get   'produto_perfil_fiscal',               to: 'produto_perfil_fiscal#index',  as: :produto_perfil_fiscal
    get   'produto_perfil_fiscal/:cod_produto',  to: 'produto_perfil_fiscal#show',   as: :produto_perfil_fiscal_show
    patch 'produto_perfil_fiscal/:cod_produto',  to: 'produto_perfil_fiscal#update', as: :produto_perfil_fiscal_update

    # Módulo de Controle de Acesso
    resources :access_roles do
      member do
        post :assign
        delete :unassign
      end
      collection do
        get :individual_permissions
        post :create_individual_permission
        delete :destroy_individual_permission
      end
    end

    resources :notas_fiscais, only: :index
    root to: 'notas_fiscais#index'
    
    # rotas do javascript - ajax
    post 'vendas/consulta_estoque', to: 'vendas#consulta_estoque'
    post 'compras/consulta_estoque', to: 'compras#consulta_estoque'
    post 'compras/cadastrar_produto', to: 'compras#cadastrar_produto'

    get 'buscas/buscar_pessoas', to: 'buscas#buscar_pessoas'
    get 'buscas/buscar_produtos', to: 'buscas#buscar_produtos'
    get 'buscas/consulta_estoque', to: 'buscas#consulta_estoque'
    get 'buscas/cores_negativas', to: 'buscas#cores_negativas'
    get 'pessoas/check_cpf_cnpj', to: 'pessoas#check_cpf_cnpj'
    get 'pessoas/buscar_cnpj', to: 'pessoas#buscar_cnpj'
    # Complementa o cadastro de PJ com IE/situacao da SEFAZ (modulo fiscal).
    get 'pessoas/consultar_cadastro_sefaz', to: 'pessoas#consultar_cadastro_sefaz'
    get 'vendas/check_cpf_cnpj_venda', to: 'vendas#check_cpf_cnpj_venda'

    get 'report_sales', to: 'report/rep_sales#index'
    get 'report_buy', to: 'report/rep_buy#index'
    get 'report/report_sales/hist_client/:id', to: 'report/rep_sales#hist_client', as: 'report_sales_client'
    get 'sales/index'
    get 'report_put_box', to: 'report/rep_put_box#index', as: 'report_put_box_index'
    delete '/report_put_box/:id', to: 'report/rep_put_box#destroy', as: 'report_put_box_destroy'
    get 'report_stock_min', to: 'report/rep_stock_min#index', as: 'report_stock_min_index'
    get 'report/mais_vendidos', to: 'report/rep_mais_vendidos#index', as: 'report_mais_vendidos'
    post 'report_stock_min/add_to_order', to: 'report/rep_stock_min#add_to_order', as: 'add_to_order_report_rep_stock_min'
    get 'report_atendimentos', to: 'report/rep_atendimentos#index', as: 'report_atendimentos'
    get 'report_aniversariantes', to: 'report/rep_aniversariantes#index', as: 'report_aniversariantes'
    get 'report_sugestao_compra', to: 'report/rep_sugestao_compra#index', as: 'report_sugestao_compra'
    post 'report_sugestao_compra/add_to_order', to: 'report/rep_sugestao_compra#add_to_order', as: 'add_to_order_sugestao_compra'
  end

  resources :produtos do
    resources :produto_imagens, only: [:create, :destroy] do
      member do
        patch :update_ordem
        patch :toggle_principal
      end
    end
  end
end
Rails.application.routes.draw do
  root 'home#index'
  get 'produto/:cod_produto/:cod_cor', to: 'home#produto', as: 'produto'
  get 'portfolio', to: 'home#portfolio'

  devise_for :collaborators, skip: [:registrations]
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
    get 'search', to: 'produtos/search#produtos'
    get 'check_cpf_cnpj', to: 'check_cpf_cnpj'
    # cria varias rotas possiveis sem precisar criar uma a uma
    resources :collaborators, only: [:index, :edit, :update, :new, :create, :destroy, :check_cpf_cnpj]
    
    resources :produtos, only: [:index, :edit, :update, :new, :create, :destroy, :show] do
      member do
        get :estoque
      end
    end
    resources :produto_imagens, only: [:index, :create, :edit, :destroy] do
      collection do
        get :get_cor_data
      end
    end
    resources :cores, only: [:index, :edit, :update, :new, :create, :destroy]
    
    resources :marcas
    resources :grupos, param: :cod_grupo

    resources :lembretes, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :funcionarios, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :empresa_estoque, only: [:index, :edit, :destroy, :update] do
      collection do
        get 'by_color/:cor_id', to: 'empresa_estoque#by_color', as: :by_color
      end
    end
    
    resources :caixa, only: [:index, :edit, :update, :new, :create, :destroy]
    # resources :contas_pag_rec, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :contas_pag_rec, only: [:index, :edit, :update, :new, :create, :destroy] do
      get :print_promissory_note, on: :collection
    end

    resources :lancamentoscaixas, only: [:index, :edit, :update, :new, :create, :destroy]
    
    resources :lancamentosdiversos, only: [:index, :edit, :update, :new, :create, :destroy]

    resources :orcamentos do
      member do
        post :converter_venda
      end
    end
    
    resources :vendas, only: [:index, :edit, :new, :create, :destroy] do
      patch :atualizar_vendedor, on: :member
      get :editar_itens, on: :member
      patch :atualizar_itens, on: :member
    end
    
    resources :compras, only: [:index, :edit, :new, :create, :destroy, :show]
    resources :pedidos_compras
    resources :produtoxmls, only: [:index, :edit, :new, :create, :destroy]
    resources :pessoas, only: [:index, :edit, :new, :create, :destroy, :update]
    resources :whatsapp_contacts #, only: [:index, :edit, :new, :create, :destroy, :update]
    resources :xml_files, only: [:index, :edit, :new, :create, :destroy] do
      post 'import/:id', on: :member, to: 'xml_files#import', as: :import
    end
    resources :collaborators do
      post :reset_password, on: :member
    end
    
    resources :cadinternalframes

    resources :notas_fiscais, only: :index
    root to: 'notas_fiscais#index'
    
    # rotas do javascript - ajax
    post 'vendas/consulta_estoque', to: 'vendas#consulta_estoque'
    post 'compras/consulta_estoque', to: 'compras#consulta_estoque'
    post 'compras/cadastrar_produto', to: 'compras#cadastrar_produto'

    get 'buscas/buscar_pessoas', to: 'buscas#buscar_pessoas'
    get 'buscas/buscar_produtos', to: 'buscas#buscar_produtos'
    get 'pessoas/check_cpf_cnpj', to: 'pessoas#check_cpf_cnpj'
    get 'vendas/check_cpf_cnpj_venda', to: 'vendas#check_cpf_cnpj_venda'

    get 'report_sales', to: 'report/rep_sales#index'
    get 'report_buy', to: 'report/rep_buy#index'
    get 'report/report_sales/hist_client/:id', to: 'report/rep_sales#hist_client', as: 'report_sales_client'
    get 'sales/index'
    get 'report_put_box', to: 'report/rep_put_box#index', as: 'report_put_box_index'
    delete '/report_put_box/:id', to: 'report/rep_put_box#destroy', as: 'report_put_box_destroy'
    get 'report_stock_min', to: 'report/rep_stock_min#index', as: 'report_stock_min_index'
    post 'report_stock_min/add_to_order', to: 'report/rep_stock_min#add_to_order', as: 'add_to_order_report_rep_stock_min'
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
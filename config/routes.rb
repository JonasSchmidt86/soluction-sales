Rails.application.routes.draw do

  # namespace :collaborators_backoffice do
  #   get 'produtoxmls/index'
  #   get 'produtoxmls/edit'
  #   get 'produtoxmls/new'
  # end
  namespace :collaborators_backoffice do
    get 'sales/index'
  end
  devise_for :collaborators, skip: [:registrations]
  devise_for :users, skip: [:registrations]
  
  namespace :site do
    get 'welcome/index'
  end

  namespace :users_backoffice do
    get 'welcome/index'
  end

  namespace :collaborators_backoffice do
    get 'welcome/index'
    post 'welcome/index'
    get 'search', to: 'produtos/search#produtos'

    # cria varias rotas possiveis sem precisar criar uma a uma
    resources :collaborators, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :produtos, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :lembretes, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :funcionarios, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :empresa_estoque, only: [:index, :edit, :destroy]
    resources :caixa, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :contas_pag_rec, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :lancamentoscaixas, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :vendas, only: [:index, :edit, :new, :create, :destroy]
    resources :compras, only: [:index, :edit, :new, :create, :destroy, :show]
    resources :produtoxmls, only: [:index, :edit, :new, :create, :destroy]
    resources :pessoas, only: [:index, :edit, :new, :create, :destroy, :update]
    resources :xml_files, only: [:index, :edit, :new, :create, :destroy] do
      post 'import/:id', on: :member, to: 'xml_files#import', as: :import
    end

    resources :notas_fiscais, only: :index
    root to: 'notas_fiscais#index'
    
    # rotas do javascript - ajax
    post 'vendas/consulta_estoque', to: 'vendas#consulta_estoque'
    get 'buscas/buscar_pessoas', to: 'buscas#buscar_pessoas'
    get 'buscas/buscar_produtos', to: 'buscas#buscar_produtos'
    get 'pessoas/check_cpf_cnpj', to: 'pessoas#check_cpf_cnpj'
    get 'vendas/check_cpf_cnpj_venda', to: 'vendas#check_cpf_cnpj_venda'

    get 'report_sales', to: 'report/rep_sales#index'
    get 'report_buy', to: 'report/rep_buy#index'
    get 'report/report_sales/hist_client/:id', to: 'report/rep_sales#hist_client', as: 'report_sales_client'

    get 'report_put_box', to: 'report/rep_put_box#index', as: 'report_put_box_index'
    delete '/report_put_box/:id', to: 'report/rep_put_box#destroy', as: 'report_put_box_destroy'
    #  get 'collaborator/index'
    #  get 'collaborator/edit:id', to: 'collaborators#edit'
  end

# configurar generate
# não gerar o test, na pasta config/aplication.rb tds configurações

  # get 'welcome/index'
  get 'inicio', to: 'site/welcome#index' # inicio é o nome que vai aparecer www....com/inicio
  
  root to: 'collaborators_backoffice/welcome#index'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end

Rails.application.routes.draw do

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
    resources :empresa_estoque, only: [:index, :destroy]
    resources :caixa, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :contas_pag_rec, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :lancamentoscaixas, only: [:index, :edit, :update, :new, :create, :destroy]
    resources :venda #, only: [:index, :edit, :update, :new, :create, :destroy]

    get 'report_sales', to: 'report/rep_sales#index'
    get 'report_sales/index:id', to: 'report/rep_sales#index', as: 'report_sales_historic'

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

class CollaboratorsBackoffice::ProdutoxmlsController < CollaboratorsBackofficeController

  def index
    @nfe_documents = Produtoxml.all
  end

  def edit
  end

  def new

    puts "-------- NEW PRODUTO XML -----" + params.to_s
    
    @xml_file = XmlFile.find_by(id: params[:format]);

    # xml_content = File.read(ActiveStorage::Blob.service.path_for(@xml_file.file.key), encoding: 'UTF-8')
    # xml_doc = Nokogiri::XML(xml_content)
    return @xml_file

    # det_elements = xml_doc.xpath('//*[local-name()="det"]')
    # @produtos_xml = [];
    
    # det_elements.each do |pr|
    #   codEmissor = pr.at("cProd")&.text if pr.at("cProd")&.text || 0
      
    #   xmlProds = Produtoxml.where(codproemissor: codEmissor, pessoa: @xml_file.pessoa).order(:codigo)
    #   xmlProd = nil

    #   # pode trazer mais de 1 item aqui ele vai verificar se o nome do item é igual
    #   #tbm vai ter o caso do nome ser igual e a cor vem em info adicionais tbm tem que validar
    #   if xmlProds
    #     xmlProds.each do |item|
    #       if item.nome.downcase.gsub(/\s+/, '') == pr.at("xProd")&.text.downcase.gsub(/\s+/, '')
    #         xmlProd = item;
    #         break
    #       end
    #     end
    #   end

    #   if xmlProd.nil?
    #     puts "-------- NEW PRODUTO XML -----"
    #     produto_xml = Produtoxml.new 
    #     produto_xml.pessoa = @xml_file.pessoa
    #     produto_xml.codproemissor = codEmissor

    #   else # atualiza dados
    #     puts "-------- ELSE não é nil PRODUTO XML -----"

    #     if pr.at("xProd")&.text
    #       unless xmlProd.nome.downcase.gsub(/\s+/, '') == pr.at("xProd")&.text.downcase.gsub(/\s+/, '')
    #         puts "-------- ELSE UNLESS  PRODUTO XML -----"
    #         produto_xml = Produtoxml.new 
    #         produto_xml.pessoa = @xml_file.pessoa
    #         produto_xml.codproemissor = codEmissor
    #       else 
    #         produto_xml = xmlProd;
    #       end
    #     end
        
    #   end

    #   produto_xml.nome = pr.at("xProd")&.text.upcase if pr.at("xProd")
    #   produto_xml.infadicionais = pr.at("infAdProd")&.text.upcase if pr.at("infAdProd")&.text || nil
    #   produto_xml.ncm = pr.at("NCM")&.text if pr.at("NCM")&.text || 0
    #   produto_xml.ucom = pr.at("uCom")&.text if pr.at("uCom")&.text || 0
    #   produto_xml.cfop = pr.at("CFOP")&.text if pr.at("CFOP")&.text || 0
    #   produto_xml.cest = pr.at("CEST")&.text if pr.at("CEST")&.text || 0

    #   puts produto_xml

    #   @produtos_xml << produto_xml
    # end
    
    # return @produtos_xml

  end
  
  def destroy
  end
  
  def create
    #Ler o arquivo para atualizar informações como CEST NCM entre outros quando o produtoXML já existir  
    puts "-------- CREATE PRODUTO XML -----" + params.to_s

    produtoXmlSalvar = [];

    # Itera sobre cada produto no hash de produtos
    params[:produtos].each do |produto_id, produto_info|
      # Obtém o ID do produto
      id_do_produto = produto_id

      # Faça algo com o ID, por exemplo, imprimir
      puts "ID do Produto: #{id_do_produto}"

      # Se você quiser acessar outros atributos, pode fazer algo como
      if produto_info && produto_info["produto_xml"].present?
        puts "-------- SE -------------------------"
        produto_xml_string = produto_info["produto_xml"]
        produto_xml_hash = JSON.parse(produto_xml_string)

        puts "COD PROD - " + produto_info["cod_produto"]
        puts "COD PROD - " + produto_info["cod_cor"]


        codigo_do_produtoXML = produto_xml_hash["codigo"]
        puts "Código do ProdutoXML: #{codigo_do_produtoXML}"
        prXML = Produtoxml.find_by(codigo: codigo_do_produtoXML.to_i);

        if !prXML.nil?
          prXML.cod_cor = produto_info["cod_cor"]
          prXML.cod_produto = produto_info["cod_produto"]
          
          # abrir o arquivo e ler para passar as informações atualizadas da nota
          # quando eu crio eu já altero esses valores, aparemtenete
          prXML.nome = produto_xml_hash["nome"]
          prXML.infadicionais = produto_xml_hash["infadicionais"]
          prXML.ncm = produto_xml_hash["ncm"]
          prXML.ucom = produto_xml_hash["ucom"]
          prXML.cfop = produto_xml_hash["cfop"]
          prXML.cest = produto_xml_hash["cest"]

        end
        # Pré-save
        prXML.valid?  # Isso verifica a validade do objeto sem salvar

        # Se houver erros, lide com eles conforme necessário
        if prXML.errors.any?
          flash[:alert] = "Erro ao validar o produto #{prXML.codigo}: #{prXML.errors.full_messages.join(', ')}"
          redirect_to colaboradores_backoffice_xml_files_path
          return  # Retorna para evitar a execução do restante do código
        else
          produtoXmlSalvar << prXML;
        end
        
      else
        puts "---------- ELSE -------- "

        # Certifique-se de verificar se o parâmetro :produto_xml está presente e é um array
        if params[:produtos].present? && params[:produtos].is_a?(Array)

          params[:produtos].each do |produto_params|

            if produto_params[:produto_xml].present?

              produto_json = produto_params[:produto_xml]
              produto_hash = JSON.parse(produto_json)
              
              produto = Produtoxml.new(
                codproemissor: produto_hash["codproemissor"],
                nome: produto_hash["nome"],
                cod_cor: produto_hash["cod_cor"],
                cod_produto: produto_params["cod_produto"],
                infadicionais: produto_hash["infadicionais"],
                ncm: produto_hash["ncm"],
                cod_pessoa: produto_hash["cod_pessoa"],
                ucom: produto_hash["ucom"],
                cfop: produto_hash["cfop"],
                cest: produto_hash["cest"]
              )

              # Agora você pode trabalhar com o objeto Produto recém-criado
              puts "Produto criado:"
              puts produto.inspect
            else
              puts "A chave :produto_xml está vazia, nula ou não está presente como esperado para um produto."
            end
          end
        else
          puts "O parâmetro :produtos está vazio, nulo ou não é um array."
        end

        puts "---------------------------------"
      end 
    end
    produtoXmlSalvar.each do |produto|
      produto.save!
      puts "Salvo " + produto.codigo.to_s
    end
    redirect_to collaborators_backoffice_xml_files_path , notice: "XML Atualizado"
  end

  private

  def det_itens(products)
    lista_produtos = []

    products.each do |pr|
      id = pr.at("cProd")&.text
      nome = pr.at("xProd")&.text
      valor = pr.at("vProd")&.text

      produto = { id: id, nome: nome, valor: valor }
      lista_produtos << produto
    end

    return lista_produtos
  end

  def det_pagto(payments)
    payments.each do |pay|
      puts " Tipo: " + pay.at("tPag")
      puts " desc: " + pay.at("xPag") if pay.at("xPag")
      puts " valr: " + pay.at("vPag")
      
    end
  end

  def charge_pagto(duplicates)
    duplicates.each do |pay|
      puts " nDup: " + pay.at("nDup")
      puts "dVenc: " + pay.at("dVenc") if pay.at("dVenc")
      puts " vDup: " + pay.at("vDup")
    end
  end

end

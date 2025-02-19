class CollaboratorsBackoffice::ProdutoxmlsController < CollaboratorsBackofficeController

  def index
    @nfe_documents = Produtoxml.all
  end

  def edit
  end

  def new

    # puts "-------- NEW PRODUTO XML -----" + params.to_s

    @xml_file = XmlFile.find_by(id: params[:format]);
    # gera o xml_file cria a compra
    # puts "--------------------------"
    # puts @xml_file.name.to_s.upcase

    if @xml_file.compra.nil?
      compra = Compra.new;
      puts "------------ nil compra ---------- "
      
      xml_content = File.read(ActiveStorage::Blob.service.path_for(@xml_file.file.key), encoding: 'UTF-8')
      xml_doc = Nokogiri::XML(xml_content)

      ide_element = xml_doc.xpath('//*[local-name()="ide"]')
      emit_elements = xml_doc.xpath('//*[local-name()="emit"]')
      det_elements = xml_doc.xpath('//*[local-name()="det"]')
      fat_elements = xml_doc.xpath('//*[local-name()="fat"]')
      dup_elements = xml_doc.xpath('//*[local-name()="dup"]')
      icmsTotal_elements = xml_doc.xpath('//*[local-name()="ICMSTot"]')
      
      emitCnpj = emit_elements.at("CNPJ")&.text if emit_elements.at("CNPJ")&.text

      compra.pessoa =  @xml_file.pessoa
      compra.cod_empresa = @xml_file.empresa_id
      compra.cancelada = false;
    #cod_frete bigint,

      compra.datacompra = DateTime.now
      compra.dataemissao = DateTime.iso8601(ide_element.at("dhEmi")&.text) || DateTime.now;
      compra.numeronf = (ide_element.at("nNF")&.text).to_i || 0;
      compra.serienf = (ide_element.at("serie")&.text).to_i || 0;

      # totais
      compra.valorfrete = ((icmsTotal_elements.at("vFrete")&.text).to_f || 0) ;  # vFrete -  Valor do frete que vem na NF
      compra.outrasdespesas = (icmsTotal_elements.at("vOutro")&.text.to_f || 0 ); # vOutro - Outras despesas 
      compra.desconto = (icmsTotal_elements.at("vDesc")&.text.to_f || 0 ); # Desconto da NF
      #compra.tt_prod = (icmsTotal_elements.at("vProd")&.text.to_f || 0 );  # total de produtos
      ######

      compra.valortotal = (fat_elements.at("vLiq")&.text).to_f || 0;
      
      compra.cod_funcionario = current_collaborator.cod_funcionario

      #apenas na hora de gravar
      #compra.cod_compraempresa = (Compra.select(:cod_compraempresa).where("cod_empresa = 2").last).cod_compraempresa + 1;
      
      compra.arquivoxml = @xml_file.file.key.upcase # se eu salvar a key posso encontrar o arquivo novamente - nome do arquivo = @xml_file.file.filename.to_s

      @xml_file.compra = compra;

      compra.itenscompra = det_itens(det_elements)
      compra.contas = dup_contas(dup_elements)

      # se no xml vier com valor total = a zero
      if compra.valortotal == 0 
        # somar o total dos produtos
        valorTotal = 0;
        compra.itenscompra.each do |item|
          valorTotal += item.valorunitario;
        end
        compra.valortotal = valorTotal;
      end

      @xml_file.compra = compra;
    end

    return @xml_file

  end
  
  def destroy
  end
  
  def create
    #Ler o arquivo para atualizar informações como CEST NCM entre outros quando o produtoXML já existir  
    puts "-------- CREATE PRODUTO XML -----" + params.to_s

    puts params
    # break;
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
          prXML.desconto = produto_xml_hash["vDesc"]

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
                desconto: produto_hash["vDesc"],
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
    list_ItensCompra = []

    products.each do |pr|

      codEmissor = pr.at("cProd")&.text if pr.at("cProd")&.text || 0;
      nmXML = pr.at("xProd")&.text if pr.at("xProd")&.text || '';
      nmXML = GenericService.remover_acentos(nmXML); 

      # xmlProds = Produtoxml.where(codproemissor: codEmissor, nome: nmXML, pessoa: @xml_file.pessoa).order(:codigo);
      xmlProds = Produtoxml.where(codproemissor: codEmissor, pessoa: @xml_file.pessoa).where(" nome ilike ? ", nmXML).order(:codigo)

      itemcompra = Itemcompra.new
      produtoXMl = Produtoxml.new
      if xmlProds 
        xmlProds.each do |prXML|

          if GenericService.remover_acentos(prXML.infadicionais.to_s.gsub(/[.,]/, "").strip.upcase) === GenericService.remover_acentos((pr.at("infAdProd")&.text if pr.at("infAdProd")&.text || "").to_s.gsub(/[.,]/, "").strip.upcase)

            prXML.ncm = ( pr.at("NCM")&.text if  pr.at("NCM")&.text || prXML.ncm);
            prXML.produto.ncm = prXML.ncm;

            #atualizar produtoXML e NCM Produto
            if prXML.changed?
              prXML.save!
              puts "Produto XML Atualizado Codigo: #{prXML.codigo}"
            end
            produtoXMl = prXML;
            itemcompra.produto = prXML.produto
            itemcompra.cor = prXML.cor

          end 
        end
      end
      
      if produtoXMl.codigo.blank?
        puts " ---------- new Produtoxml.new ----------"
      end
      produtoXMl.codproemissor = ( pr.at("cProd")&.text if pr.at("cProd")&.text || '')
      produtoXMl.cod_pessoa = @xml_file.pessoa
      produtoXMl.nome = nmXML
      produtoXMl.infadicionais = GenericService.remover_acentos( (pr.at("infAdProd")&.text if pr.at("infAdProd")&.text || '').to_s )
      produtoXMl.ncm = ( pr.at("NCM")&.text if pr.at("NCM")&.text || '')
      produtoXMl.ucom = ( pr.at("uCom")&.text if pr.at("uCom")&.text || '')
      produtoXMl.cfop = ( pr.at("CFOP")&.text if pr.at("CFOP")&.text || '')
      produtoXMl.cest = ( pr.at("CEST")&.text if pr.at("CEST")&.text || '')
        
      produtoXMl.desconto = (pr.at("vDesc")&.text if  pr.at("vDesc")&.text || '0').to_f;

      itemcompra.cod_empresa = @xml_file.empresa_id
      itemcompra.numeronf = @xml_file.compra.numeronf

      # ST
      icms10_elements = pr.xpath('.//*[local-name()="ICMS10"]')

      if icms10_elements.any?
        itemcompra.icms = (icms10_elements.at("vICMSST")&.text if  pr.at("vICMSST")&.text || 0).to_d  #pr.at("vICMS")&.text if  pr.at("vICMS")&.text || 0 # Não compoe o custo do produto
      else
        itemcompra.icms = 0.00
      end
      puts "\n Valor do ICMS #{ itemcompra.icms } \n"
      puts "\n Valor do ICMS #{ icms10_elements.any? } \n"

      itemcompra.quantidade = (pr.at("qCom")&.text if  pr.at("qCom")&.text || 0).to_i
      itemcompra.ipi = ((pr.at("vIPI")&.text if  pr.at("vIPI")&.text || 0).to_f) #(pr.at("pIPI")&.text if  pr.at("pIPI")&.text || 0).to_f
      # vIPI valor do ipi divide pela quantidade + valor unitario
      

      valorUnitario = (pr.at("vUnCom")&.text || '0').gsub(',', '.').to_f

      valorIPI = pr.at("vIPI")&.text
      valorIPI = (valorIPI.gsub(',', '.') if valorIPI).to_f
      itemcompra.valorunitario = valorUnitario.to_f

      vl_frete = pr.at("vFrete")&.text
      vl_frete = (vl_frete.gsub(',', '.') if vl_frete).to_d
      itemcompra.valor_frete = ( vl_frete ).to_d

      itemcompra.pro_xml_temp = produtoXMl

      list_ItensCompra << itemcompra
    end

    return list_ItensCompra
  end


  def dup_contas(duplicates)

    list_contas = []
    nrParcela = 0;
    duplicates.each do |pay|
      nrParcela += 1;
      conta = Contaspagrec.new

      conta.cod_empresa = @xml_file.empresa_id
      conta.ativo = true;
      conta.dtvencimento = (pay.at("dVenc")&.text if  pay.at("dVenc")&.text || 0).to_date
      conta.numeroparcela = nrParcela
      conta.quitada = false;
      conta.valorparcela = (pay.at("vDup")&.text if  pay.at("vDup")&.text || 0).to_f
      conta.cod_tppagamento = 2 # 2 é Parcela de compra

      list_contas << conta;
    end

    return list_contas;
  end
  
end

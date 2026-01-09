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
      
      #service = @xml_file.file.blob.service 
      #file_path = service.path_for(@xml_file.file.key)

      puts "------_>>>>>> #{@xml_file.local_file_path} "
      
      #xml_content = File.read(@xml_file.local_file_path, encoding: 'UTF-8')
      #xml_doc = Nokogiri::XML(xml_content)

      file_path = @xml_file.local_file_path

      if file_path && File.exist?(file_path)
        xml_content = File.read(file_path, encoding: 'UTF-8')
        xml_doc = Nokogiri::XML(xml_content)
      else
        Rails.logger.error "Arquivo não encontrado: #{file_path.inspect}"
        # redirect_to some_path, alert: "Arquivo XML não encontrado."s
      end



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
      next if produto_info["cod_produto"].blank? || produto_info["cod_cor"].blank?
      
      if produto_info && produto_info["produto_xml"].present?
        xml_pro = JSON.parse(produto_info["produto_xml"])
        proXml = nil
        
        # Busca por código existente se presente
        if xml_pro["codigo"].present? && !xml_pro["codigo"].blank?
          candidatos_por_codigo = Produtoxml.where(codigo: xml_pro["codigo"])
          
          # Verifica infadicionais nos candidatos encontrados por código
          candidatos_por_codigo.each do |candidato|
            if candidato.infadicionais.to_s.rstrip.upcase == xml_pro["infadicionais"].to_s.rstrip.upcase
              proXml = candidato
              break
            end
          end
        end
        
        # Se não encontrou por código, busca por produto/cor/emissor/nome
        if proXml.blank?
          proXml = Produtoxml.where(
            cod_cor: produto_info["cod_cor"].to_i,
            cod_produto: produto_info["cod_produto"].to_i,
            codproemissor: xml_pro["codproemissor"]
          ).where(" nome ilike ? ", xml_pro["nome"].to_s.upcase.rstrip).order(:codigo).first
          
          # Verifica infadicionais se encontrou
          if !proXml.blank?
            unless proXml.infadicionais.nil? && (xml_pro["infadicionais"].nil? || xml_pro["infadicionais"].to_s.strip.empty?) ||
              proXml.infadicionais.to_s.rstrip.upcase == xml_pro["infadicionais"].to_s.rstrip.upcase
              proXml = nil
            end
          end
        end
        
        # Se ainda não encontrou, cria novo
        if proXml.blank?
          proXml = Produtoxml.new
          proXml.codproemissor = xml_pro["codproemissor"]
          proXml.infadicionais = xml_pro["infadicionais"].to_s.rstrip.upcase if xml_pro["infadicionais"].present?
          proXml.nome = xml_pro["nome"].to_s.rstrip.upcase if xml_pro["nome"].present?
          proXml.ucom = xml_pro["ucom"]
          proXml.ncm = xml_pro["ncm"]
          proXml.cfop = xml_pro["cfop"]
          proXml.cest = xml_pro["cest"]
        end
        
        # Atualiza dados
        proXml.cod_produto = produto_info["cod_produto"]
        proXml.cod_cor = produto_info["cod_cor"]
        proXml.cod_pessoa = current_collaborator.cod_empresa # Assumindo que é a empresa

        unless proXml.save!
          respond_to do |format|
            format.json { render json: { error: "Erro ao salvar produto #{xml_pro["nome"]}" } }
            format.html { redirect_to collaborators_backoffice_xml_files_path, alert: "Erro ao salvar produto" }
          end
        end
        
        produtoXmlSalvar << proXml
      end
    end

    
    respond_to do |format|
      format.json { render json: { message: "#{produtoXmlSalvar.count} produtos salvos com sucesso!" } }
      format.html { redirect_to collaborators_backoffice_xml_files_path, notice: "XML Atualizado" }
    end
  end

  
  private

  def det_itens(products)
    list_ItensCompra = []

    products.each do |pr|

      codEmissor = pr.at("cProd")&.text if pr.at("cProd")&.text || 0;
      # nmXML = pr.at("xProd")&.text if pr.at("xProd")&.text || '';
      nmXML = pr.at("xProd")&.text || ''
      infXML = pr.at("infAdProd")&.text || ''
      nmXML = GenericService.remover_acentos(nmXML); 
      infXML = GenericService.remover_acentos(infXML); 

      xmlProds = Produtoxml.where(codproemissor: codEmissor, pessoa: @xml_file.pessoa.id).order(:codigo)

      if xmlProds.nil?
        term = nmXML.gsub(/[ \.,]/, '')
        xmlProds = Produtoxml.where("unaccent(replace(replace(replace(nome, ' ', ''), '.', ''), ',', '')) ILIKE unaccent(?)", term)
      end

      itemcompra = Itemcompra.new
      produtoXMl = Produtoxml.new

      if xmlProds 
        puts "\n"
        xmlProds.each do |prXML|
          itemcompra.produto = prXML.produto
          if GenericService.remover_acentos(prXML.infadicionais.to_s.gsub(/[.,]/, "").strip.upcase) === 
            GenericService.remover_acentos((pr.at("infAdProd")&.text || "").to_s.gsub(/[.,]/, "").strip.upcase)

            novo_ncm = pr.at("NCM")&.text

            if novo_ncm.present? && prXML.produto.present? && prXML.produto.ncm != novo_ncm
              prXML.produto.update_column(:ncm, novo_ncm)
            end
            prXML.ncm = novo_ncm if novo_ncm.present?

            #atualizar produtoXML e NCM Produto
            if prXML.cod_produto.present? && prXML.cod_cor.present?
              if prXML.changed?
                begin
                  prXML.save!
                  puts "Produto XML Atualizado Codigo: #{prXML.codigo}"
                rescue ActiveRecord::RecordInvalid => e
                  puts "Erro ao salvar Produtoxml - Produto: #{prXML.nome} (Código: #{prXML.codproemissor}) - #{e.message}"
                  puts "Detalhes dos erros: #{prXML.errors.full_messages.join(', ')}"
                  puts "Erros do produto associado: #{prXML.produto.errors.full_messages.join(', ')}" if prXML.produto&.errors&.any?
                  Rails.logger.error "Erro ao salvar Produtoxml ID #{prXML.id} - Produto: #{prXML.nome}: #{e.message} - Erros: #{prXML.errors.full_messages} - Erros do produto: #{prXML.produto&.errors&.full_messages}"
                end
              end
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
      produtoXMl.codproemissor = pr.at("cProd")&.text || ''
      produtoXMl.cod_pessoa = @xml_file.pessoa
      produtoXMl.nome = nmXML
      produtoXMl.infadicionais = GenericService.remover_acentos((pr.at("infAdProd")&.text || '').to_s)
      produtoXMl.ncm = pr.at("NCM")&.text || ''
      produtoXMl.ucom = pr.at("uCom")&.text || ''
      produtoXMl.cfop = pr.at("CFOP")&.text || ''
      produtoXMl.cest = pr.at("CEST")&.text || ''
      produtoXMl.desconto = (pr.at("vDesc")&.text || '0').to_f

      itemcompra.cod_empresa = @xml_file.empresa_id
      itemcompra.numeronf = @xml_file.compra.numeronf

      # ST
      icms10_elements = pr.xpath('.//*[local-name()="ICMS10"]')

      if icms10_elements.any?
        itemcompra.icms = (icms10_elements.at("vICMSST")&.text if  pr.at("vICMSST")&.text || 0).to_d  #pr.at("vICMS")&.text if  pr.at("vICMS")&.text || 0 # Não compoe o custo do produto
      else
        itemcompra.icms = 0.00
      end
      if pr.at("vOutro")&.text.present?
        itemcompra.icms += (pr.at("vOutro")&.text || '0').to_f;
      end

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

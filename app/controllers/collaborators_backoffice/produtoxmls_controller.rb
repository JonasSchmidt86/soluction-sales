class CollaboratorsBackoffice::ProdutoxmlsController < CollaboratorsBackofficeController

  def index
    @nfe_documents = Produtoxml.all
  end

  def edit
  end

  def new
  end
  
  def destroy
  end
  
  def create
    attributes_xml = [];

    xml_content = File.read(params[:file].path)

    # Use Nokogiri para analisar o XML
    xml_doc = Nokogiri::XML(xml_content)

    # produtos
    det_elements = xml_doc.xpath('//*[local-name()="det"]')

    # tipo de pagamento
    pagto_elements = xml_doc.xpath('//*[local-name()="pag"]')

    # duplicatas
    charge_elements = xml_doc.xpath('//*[local-name()="cobr"]')

    # Iterar sobre cada elemento <det> e imprimir informações do elemento <prod>
    det_elements.each do |det_element|
      attributes_xml = det_itens(det_element.xpath('//*[local-name()="prod"]'))
      # aqui tem que ir tudo que precisa que esta dentro do prod de cada Item(det) do XML
# pegar os impostos
    end

    pagto_elements.each do |pgto_element|
      det_pagto(pgto_element.xpath('//*[local-name()="detPag"]'))
    end

    charge_elements.each do |charge_element|
      charge_pagto(charge_element.xpath('//*[local-name()="dup"]'))
    end

    @xml_nfe = ["1","jonas schmidt"," asdasd "]
    @xml_prod = attributes_xml
    #@xml_dup = dupls
    render :edit

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

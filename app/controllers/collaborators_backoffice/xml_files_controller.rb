# require_relative '/Users/jonas/ProjetosGit/soluction-sales/ProjetosGt/app/services/storage_service.rb'

class CollaboratorsBackoffice::XmlFilesController < CollaboratorsBackofficeController

    before_action :set_xml_file, only: [:show, :destroy, :import]
    before_action :apagar_arquivo, only: [:destroy]
  
    def index

      consulta = " empresa_id = ? ";

      if !params[:term].blank?
          consulta += " and pessoa_id in (select cod_pessoa from pessoa where upper(apelido) ilike upper('%"+ params[:term] +"%')) "
      end

      if !params[:dataInicial].blank? && !params[:dataFinal].blank?
        consulta += " and date(created_at) between to_date('" + params[:dataInicial] +"', 'DD/MM/YYYY') and to_date('" + params[:dataFinal] + "', 'DD/MM/YYYY') ";
      else
          params[:dataInicial] = Date.today.beginning_of_month.strftime("%d/%m/%Y");
          params[:dataFinal] = Date.today.end_of_month.strftime("%d/%m/%Y");
          # consulta += " and date(created_at) between to_date('" + Date.today.beginning_of_month.strftime("%d/%m/%Y") +"', 'DD/MM/YYYY') and to_date('" + Date.today.end_of_month.strftime("%d/%m/%Y") + "', 'DD/MM/YYYY') "
          consulta += " and date(created_at) between to_date('" + params[:dataInicial] +"', 'DD/MM/YYYY') and to_date('" + params[:dataFinal] + "', 'DD/MM/YYYY') "
      end

      @xml_files = XmlFile.where(consulta, current_collaborator.empresa.cod_empresa).page(params[:page])
    end
  
    def show
      # Lógica para exibir ou processar o conteúdo do arquivo XML
    end
  
    def new
        @xml_file = XmlFile.new
    end

    def import
      # criar uma nova compra
      # passar os dados das compra
        # Fornecedor e valores
      # Passar os itens
      # Passar a forma de Pagamento
        puts "Import - --------------"
        puts "Ler arquivo e passar para o produtoXML"
        redirect_to new_collaborators_backoffice_produtoxml_path(@xml_file), notice: "Import XML"
        puts "Import - --------------"
    end
    
    def create

      unless params[:xml_file]
        redirect_to collaborators_backoffice_xml_files_path, notice: 'Selecione um arquivo.'
        return
      end

      @xml_file = XmlFile.new
      
      if xml_file_params[:file].present?

        unless File.extname(xml_file_params[:file]) == ".xml"
          redirect_to collaborators_backoffice_xml_files_path, notice: 'Arquivo não é valido!.'
          return;
        end

        @xml_file.file = xml_file_params[:file] if xml_file_params[:file];
        @xml_file.name = xml_file_params[:name] if xml_file_params[:name];

        # diretorio_destino = File.join(Dir.pwd, "xml", current_collaborator.empresa.nome, "Recebidos")
        # diretorio_destino = File.join("xml",current_collaborator.empresa.nome, "Recebidos")

        # FileUtils.mkdir_p(diretorio_destino) unless File.directory?(diretorio_destino)

        xml_content = File.read(xml_file_params[:file].tempfile, encoding: 'UTF-8')
        xml_doc = Nokogiri::XML(xml_content)
    
        id_nfe = xml_doc.at_xpath('//*[local-name()="infNFe"]')
        cod = id_nfe['Id']
        # @xml_file.file.filename = cod
    
        caminho_do_arquivo = File.join(xml_file_params[:file].original_filename)

        cnpj_val = xml_doc.xpath('//*[local-name()="emit"]').at("CNPJ")&.text
        cnpj_dest = xml_doc.xpath('//*[local-name()="dest"]').at("CNPJ")&.text

        if cnpj_dest == current_collaborator.empresa.cpf_cnpj
          @xml_file.empresa = current_collaborator.empresa
        else 
          redirect_to collaborators_backoffice_xml_files_path, notice: 'Arquivo de Outra empresa.'
          return 
        end

        if cnpj_val
          fornecedor = Pessoa.select(:cod_pessoa, :apelido).where(cpf_cnpj: cnpj_val).limit(1).first
          if fornecedor
            @xml_file.name = fornecedor.apelido
            @xml_file.pessoa = fornecedor
          end
        end
    
        key = StorageService.dynamic_path(caminho_do_arquivo)
        
        blob = ActiveStorage::Blob.find_by(key: key)

        unless blob.nil?
          redirect_to collaborators_backoffice_xml_files_path, notice: 'Arquivo já Existe.'
          return
        end

        @xml_file.file.attach(io: xml_file_params[:file].tempfile,
                              filename: cod,
                              content_type: xml_file_params[:file].content_type,
                              service_name: :local_custom,
                              key: key)
      end
    
      if @xml_file.save
        redirect_to collaborators_backoffice_xml_files_path, notice: 'Arquivo XML enviado com sucesso.'
      else
        redirect_to collaborators_backoffice_xml_files_path, alert: 'Falha ao processar o arquivo XML.'
      end
    end
    
    
    
    def destroy

      if @xml_file.destroy
        redirect_to collaborators_backoffice_xml_files_path, notice: 'Arquivo XML excluído com sucesso.'
      else
        redirect_to collaborators_backoffice_xml_files_path, notice: 'Erro ao excluir.'
      end
    end
  
    private

    def apagar_arquivo
      # Certifique-se de que o xml_file está presente antes de tentar excluir
      if @xml_file.present?
        # Construa o caminho completo do arquivo usando o diretório onde os arquivos estão armazenados
        #caminho_completo = Rails.root.join('public', 'uploads', xml_file)

        puts "0-------------------------"
        puts @xml_file.file.filename
        puts "0-------------------------"

        # Exclua o arquivo se existir
        #File.delete(caminho_completo) if File.exist?(caminho_completo)
      end
    end
    
    def set_xml_file
      @xml_file = XmlFile.find(params[:id])
    end
    
    private

    def xml_file_params
      
      if params[:xml_file]
        params.require(:xml_file).permit(:file)
      end

    end

  end
  
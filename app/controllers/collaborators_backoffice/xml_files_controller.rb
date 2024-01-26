# require_relative '/Users/jonas/ProjetosGit/soluction-sales/ProjetosGt/app/services/storage_service.rb'

class CollaboratorsBackoffice::XmlFilesController < CollaboratorsBackofficeController

    before_action :set_xml_file, only: [:show, :destroy]
    before_action :apagar_arquivo, only: [:destroy]
  
    def index
      @xml_files = XmlFile.where(empresa_id: current_collaborator.empresa.cod_empresa).page(params[:page])
    end
  
    def show
      # Lógica para exibir ou processar o conteúdo do arquivo XML
    end
  
    def new
        @xml_file = XmlFile.new
    end

    def import
        puts "Import - --------------"
        puts "Ler arquivo e passar para o produtoXML"
        puts "Import - --------------"
    end
    
    def create

      unless params[:xml_file]
        redirect_to collaborators_backoffice_xml_files_path, notice: 'Selecione um arqui.'
        return
      end

      @xml_file = XmlFile.new
      

      if xml_file_params[:file].present?
        @xml_file.file = xml_file_params[:file] if xml_file_params[:file];
        @xml_file.name = xml_file_params[:name] if xml_file_params[:name];


        # diretorio_destino = File.join(Dir.pwd, "xml", current_collaborator.empresa.nome, "Recebidos")
        diretorio_destino = File.join("xml",current_collaborator.empresa.nome, "Recebidos")

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
          puts cnpj_dest
          puts " IGUAL -------------------"
          puts current_collaborator.empresa.cpf_cnpj
          @xml_file.empresa = current_collaborator.empresa
        else 
          puts cnpj_dest
          puts " DIFERENTE ================"
          puts current_collaborator.empresa.cpf_cnpj
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
  
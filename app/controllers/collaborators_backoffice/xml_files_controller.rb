# require_relative '/Users/jonas/ProjetosGit/soluction-sales/ProjetosGt/app/services/storage_service.rb'

class CollaboratorsBackoffice::XmlFilesController < CollaboratorsBackofficeController

    before_action :set_xml_file, only: [:show, :destroy, :import]
    before_action :apagar_arquivo, only: [:destroy]
  
    def index

      consulta = " empresa_id = ? ";

      dt_inicial = nil;
      dt_final = nil;

      # criar parametro para ter a opção de ver ou não os processados 
      unless params[:todos].present? && params[:todos] == '1'
       consulta += " and compra_id is null "
      end

      if !params[:term].blank?
          consulta += " and pessoa_id in (select cod_pessoa from pessoa where upper(apelido) ilike upper('%"+ params[:term] +"%')) "
      end

      begin 
        unless params[:dataInicial].blank?
          dt_inicial = Date.parse(params[:dataInicial]).strftime("%d/%m/%Y")
        else
          dt_inicial = (Date.today.beginning_of_month.strftime("%d/%m/%Y"));
        end
        unless params[:dataFinal].blank?
          dt_final = Date.parse(params[:dataFinal]).strftime("%d/%m/%Y")
        else
          dt_final = (Date.today.end_of_month.strftime("%d/%m/%Y"));
        end
      rescue ArgumentError
        dt_inicial = (Date.today.beginning_of_month.strftime("%d/%m/%Y"));
        dt_final = (Date.today.end_of_month.strftime("%d/%m/%Y"));
        params[:dataInicial] = dt_inicial
        params[:dataFinal] = dt_final
        
      end

      # puts "\nInicial: #{dt_inicial} - Final #{dt_final}"
      # puts "Inicial: #{dt_inicial} - Final #{dt_final}\n\n"

      consulta += " and date(created_at) between to_date('" + dt_inicial.to_s + "', 'DD/MM/YYYY') and to_date('" + dt_final.to_s  + "', 'DD/MM/YYYY') ";
    
      @xml_files = XmlFile.where(consulta, current_collaborator.empresa.cod_empresa).page(params[:page]);
      puts @xml_files.size

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
        redirect_to new_collaborators_backoffice_produtoxml_path(@xml_file), notice: "Import XML"
        puts "Import - --------------"
    end
    
    def create
      puts "-------- CREATE XML_FILE -----"
      
      unless params[:xml_file]
        redirect_to collaborators_backoffice_xml_files_path, notice: 'Selecione um arquivo.'
        return
      end
      
      
      
      arquivos = params[:xml_file][:file].reject(&:blank?) # Remove strings vazias
      
      puts "Arquivos: #{arquivos.size }"

      arquivos_salvos = []
      arquivos_erro = []

      if arquivos.size > 0

        #if xml_file_params[:file].present?
        arquivos.map do |arquivo|

          @xml_file = XmlFile.new

          unless File.extname(arquivo.original_filename).upcase == ".XML"
            arquivos_erro << arquivo
            puts " ------------------ ------------------ Arquivo não é XML."
            next;
          end

          @xml_file.file = arquivo;

          # puts "EXISTE = #{File.exist?(arquivo.tempfile)}"

          xml_content = File.read(arquivo.tempfile, encoding: 'UTF-8')
          xml_doc = Nokogiri::XML(xml_content)
      
          cnpj_val = xml_doc.xpath('//*[local-name()="emit"]').at("CNPJ")&.text
          cnpj_dest = xml_doc.xpath('//*[local-name()="dest"]').at("CNPJ")&.text

          if cnpj_dest == current_collaborator.empresa.cpf_cnpj
            @xml_file.empresa = current_collaborator.empresa
          else 
            #redirect_to collaborators_backoffice_xml_files_path, notice: 'Arquivo de Outra empresa.'
            arquivos_erro << arquivo
            puts " ------------------ ------------------ Arquivo de Outra empresa."
            next;
          end
          
          id_nfe = xml_doc.at_xpath('//*[local-name()="infNFe"]')
          @xml_file.name = id_nfe['Id']

          xml_file = XmlFile.joins(file_attachment: :blob).find_by(active_storage_blobs: { filename: id_nfe['Id'] })
          blob = ActiveStorage::Blob.find_by(filename: id_nfe['Id'])
          if blob.present? && xml_file.present?
            arquivos_erro << arquivo
            puts " ------------------ ------------------ Arquivo já foi importado. #{blob.filename}"
            next;
          end

          if cnpj_val
            fornecedor = Pessoa.select(:cod_pessoa, :apelido).where(cpf_cnpj: cnpj_val).limit(1).first
            
            if !fornecedor
              # cadastrar fornecedor novo
              fornecedor = Pessoa.new

              fornecedor.tipo = 'J'; # se for cnpj
              fornecedor.cpf_cnpj = xml_doc.xpath('//*[local-name()="emit"]').at("CNPJ")&.text;
              fornecedor.rg_ie = xml_doc.xpath('//*[local-name()="emit"]').at("IE")&.text;

              fornecedor.nome = xml_doc.xpath('//*[local-name()="emit"]').at("xNome")&.text;
              fornecedor.apelido = xml_doc.xpath('//*[local-name()="emit"]').at("xFant")&.text;
              
              fornecedor.endereco = xml_doc.xpath('//*[local-name()="enderEmit"]').at("xLgr")&.text;
              fornecedor.numero = xml_doc.xpath('//*[local-name()="enderEmit"]').at("cMun")&.text;
              fornecedor.bairro = xml_doc.xpath('//*[local-name()="enderEmit"]').at("xBairro")&.text;
              fornecedor.telefone = xml_doc.xpath('//*[local-name()="enderEmit"]').at("fone")&.text;
              fornecedor.celular = xml_doc.xpath('//*[local-name()="enderEmit"]').at("fone")&.text;

              # buscar pelo cep a cidade 
              fornecedor.cep = xml_doc.xpath('//*[local-name()="emit"]').at("CEP")&.text;

              id_cidade = ViacepService.get_id_cidade(xml_doc.xpath('//*[local-name()="emit"]').at("CEP")&.text)
              fornecedor.cod_cidade = id_cidade.present? ? id_cidade : 1 # se não encontrar a cidade ele vai deixar padrão marechal

            end
            @xml_file.name = fornecedor.apelido
            @xml_file.pessoa = fornecedor
            puts "Fornecedor: #{fornecedor.inspect}"
          end

          file_io = arquivo
          # file_io = @xml_file.file
          company = current_collaborator.empresa 
          puts "----------------- #{company}"
        
          # Associa o arquivo com o serviço personalizado
          @xml_file.attach_file_with_custom_service(file_io, id_nfe['Id'], company)
          numeroNF = xml_doc.xpath('//*[local-name()="ide"]').at("nNF")&.text;
          compra = Compra.select(:cod_compra).where(numeronf: numeroNF, cod_pessoa: fornecedor.cod_pessoa)
          puts "---COMPRA SE EXISTE = -------------- #{compra.size}"
          if compra.size > 0
            @xml_file.compra = compra.first;
          end
puts "----------------- ANTES DE SALVAR -----------------"
          # Se o arquivo XML foi salvo com sucesso, redirecione para a página de listagem
          if @xml_file.save
            arquivos_salvos << @xml_file
          else
              puts "Erro ao salvar XML: #{xml_file.errors.full_messages.join(', ')}"
          end
puts "----------------- depois DE SALVAR ----------------- #{arquivos_salvos.size}"
        end
      end
        if arquivos_salvos.size > 0
          if arquivos_erro.size > 0
            redirect_to collaborators_backoffice_xml_files_path, notice: "#{arquivos_salvos.count} arquivo(s) XML enviado(s) com sucesso. #{arquivos_erro.count} arquivo(s) com erro(s)."
          else
            redirect_to collaborators_backoffice_xml_files_path, notice: "#{arquivos_salvos.count} arquivo(s) XML enviado(s) com sucesso."
          end
        else
          redirect_to collaborators_backoffice_xml_files_path, notice: 'Nenhum XML foi processado com sucesso.'
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
  
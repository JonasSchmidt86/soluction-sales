class CollaboratorsBackoffice::Report::CustomReportsController  < CollaboratorsBackofficeController

    before_action :set_custom_report, only: [:show, :update, :run]
    before_action :custom_report_params, only: [:update]

    def index
      if current_collaborator.cod_funcionario == 1
        @reports = CustomReport.all.order(id: :asc);
      else
        @reports = CustomReport.where("upper(sql_code) NOT LIKE '%UPDATE%'");
      end
    end
    
      def show
        if @report.nil?
          @report = CustomReport.find(params[:id])
        else
          @report = CustomReport.new
        end
      end
    
      def edit
        @custom_report = CustomReport.find(params[:id])
      end

      def update
        if @custom_report.nil? 
          redirect_to :show, status: :unprocessable_entity
          return
        else
          @custom_report.attributes = custom_report_params
          if @custom_report.save
            redirect_to collaborators_backoffice_report_custom_report_path, notice: "Atualizado com sucesso."
          else
            redirect_to :show, status: :unprocessable_entity
        end
        end
      end

      def run
        @report = CustomReport.find(params[:id])
        sql = @report.sql_code.dup

        begin
          # Filtro opcional para a marca
          filtro_marca = ""
          if params[:cod_marca].present?
            filtro_marca = "AND p.marca = #{ActiveRecord::Base.connection.quote(params[:cod_marca])}"
          end
          sql.gsub!("{{filtro_marca}}", filtro_marca)

          # Filtro opcional para a grupo
          filtro_grupo = ""
          if params[:cod_grupo].present?
            filtro_grupo = "AND p.grupo = #{ActiveRecord::Base.connection.quote(params[:cod_grupo])}"
          end
          sql.gsub!("{{filtro_grupo}}", filtro_grupo)

          # Substituição para empresa logada
          sql.gsub!("[[empresa_logada]]", current_collaborator.cod_empresa.to_s)
          
          # Substituições simples para demais placeholders
          params.each do |k, v|
            v = nil if v.blank?
            placeholder = "{{#{k}}}"
            sql.gsub!(placeholder, ActiveRecord::Base.connection.quote(v)) if sql.include?(placeholder)
          end

          # Verificação de SELECT para não permitir comandos perigosos
          unless current_collaborator.cod_funcionario == 1
            raise "Apenas SELECTs são permitidos." unless sql.strip.downcase.start_with?("select")
          end

          # Executa
          @results = ActiveRecord::Base.connection.exec_query(sql)

        rescue => e
          @error = "Erro: #{e.message}"
          render :show
          return
        end

        flash[:notice] = "Relatório executado com sucesso."
        render :show
      end

      
      def new
        @custom_report = CustomReport.new
      end

      # Método para excluir um relatório
      def destroy
        @custom_report = CustomReport.find(params[:id])
        if @custom_report.destroy
          redirect_to collaborators_backoffice_report_custom_reports_path, notice: "Relatório excluído com sucesso."
        else
          redirect_to collaborators_backoffice_report_custom_reports_path, alert: "Erro ao excluir o relatório."
        end
      end

      # Método para criar um novo relatório
      def create
        @custom_report = CustomReport.new(custom_report_params)
        if @custom_report.save
          # Aqui você pode adicionar lógica para criar o relatório
          redirect_to collaborators_backoffice_report_custom_report_path(@custom_report.id), notice: "Relatório criado com sucesso."
        else
          redirect_to :show, status: :unprocessable_entity
        end
      end

      private

    def custom_report_params
      params.require(:custom_report).permit(:title, :description, :sql_code)
    end

    def set_custom_report
      @custom_report = CustomReport.find(params[:id]) # Para show, se necessário
    end

end
      
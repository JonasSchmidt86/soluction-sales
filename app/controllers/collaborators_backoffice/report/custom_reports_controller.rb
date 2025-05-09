class CollaboratorsBackoffice::Report::CustomReportsController  < CollaboratorsBackofficeController

    before_action :set_custom_report, only: [:show, :update, :run]
    before_action :custom_report_params, only: [:update]

    def index
        @reports = CustomReport.all
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
      
        # substitui {{param}} pelos params…
        params.each do |k,v|
          next if v.blank?
          placeholder = "{{#{k}}}"
          sql.gsub!(placeholder, ActiveRecord::Base.connection.quote(v)) if sql.include?(placeholder)
        end
      
        raise "Apenas SELECTs são permitidos." unless sql.strip.downcase.start_with?("select")
      
        results = ActiveRecord::Base.connection.exec_query(sql)
        @results       = results
        @result_columns = results.columns
        @result_rows    = results.rows
      
        respond_to do |format|
          format.html { render :show }   # GET sem format=xlsx
          format.xlsx do                  # GET com format=xlsx
            package = Axlsx::Package.new
            wb = package.workbook

            # 1) Define um estilo para o cabeçalho
            header_style = wb.styles.add_style(
              bg_color: "FFDFDFDF",           # cor de fundo (cinza claro)
              fg_color: "FF000000",           # cor do texto (preto)
              b: true,                        # negrito
              alignment: { horizontal: :center },
              border: { style: :thin, color: "FF000000" }
            )


            wb.add_worksheet(name: "Relatório") do |sheet|
              uppercase_headers = @result_columns.map(&:upcase)
              sheet.add_row uppercase_headers, style: header_style
              
              @result_rows.each { |r| sheet.add_row r }
            end
            send_data package.to_stream.read,
              filename:    "relatorio_#{@report.title.parameterize}.xlsx",
              type:        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
          end
        end
      rescue => e
        @error = "Erro: #{e.message}"
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
      
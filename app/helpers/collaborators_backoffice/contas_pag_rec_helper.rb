module CollaboratorsBackoffice::ContasPagRecHelper

    def tipe_bill( parametros )
        puts "------------------>>>> Paramentro ---->> " + parametros.to_s
        if parametros.blank?
            "Receber" 
        elsif parametros.to_s == "false"
            "Receber"
        else
            "Pagar"
        end
    end

    def status_bill( parametros )
        if parametros.nil?
            "Parcial" 
        else
            "Total"
        end
    end
    
    def tipe_bill_true( parametros )
        parametros = !! parametros
puts "\n Parametros = #{parametros}\n"
        return parametros
        # puts "------------------>>>> Paramentro ---->> " + parametros.to_s
        # if parametros.blank?
        #     false
        # elsif parametros.to_s == "false"
        #     false
        # else
        #     true
        # end
    end
end

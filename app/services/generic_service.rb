class GenericService
  
  def self.remover_acentos(string)
    string.tr(
      "áàãâäéèẽêëíìĩîïóòõôöúùũûüçÁÀÃÂÄÉÈẼÊËÍÌĨÎÏÓÒÕÔÖÚÙŨÛÜÇ",
      "aaaaaeeeeiiiiooooouuuuucAAAAAEEEEIIIIOOOOOUUUUC"
    )

  end
  
end
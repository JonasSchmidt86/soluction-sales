document.addEventListener("DOMContentLoaded", function() {
  // Exportar tabela para Excel
  const exportBtn = document.getElementById("export-excel");
  if (exportBtn) {
    exportBtn.addEventListener("click", function(e) {
      e.preventDefault();
      const table = document.querySelector("table");
      if (!table) {
        alert("Tabela não encontrada!");
        return;
      }

      let filename = this.dataset.filename || "relatorio.xlsx";
      let tableHTML = table.outerHTML.replace(/ /g, '%20');

      const dataType = 'application/vnd.ms-excel';
      const exportFile = `
        <html xmlns:o="urn:schemas-microsoft-com:office:office" 
              xmlns:x="urn:schemas-microsoft-com:office:excel" 
              xmlns="http://www.w3.org/TR/REC-html40">
          <head><!--[if gte mso 9]><xml><x:ExcelWorkbook><x:ExcelWorksheets><x:ExcelWorksheet>
            <x:Name>Sheet1</x:Name>
            <x:WorksheetOptions><x:DisplayGridlines/></x:WorksheetOptions>
          </x:ExcelWorksheet></x:ExcelWorksheets></x:ExcelWorkbook></xml><![endif]-->
            <meta charset="UTF-8">
          </head>
          <body>
            ${tableHTML}
          </body>
        </html>
      `;

      const blob = new Blob([exportFile], { type: dataType });

      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    });
  }

  // Submeter automaticamente se marcar/desmarcar o checkbox "Com Estoque"
  const contemCheckbox = document.getElementById("contem-checkbox");
  if (contemCheckbox) {
    contemCheckbox.addEventListener("change", function() {
      this.form.submit();
    });
  }
});

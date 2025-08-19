$(document).ready(function () {
    $("#btnSubmit").click(function (event) {
        event.preventDefault();

        const damPath = $("#xls").val();
        const destPath = $("#destPath").val();
        const assetsPath = $("#assetsPath").val();
        const templatePath = $("#templatePath").val();

        if (!damPath || damPath.trim().length === 0) {
            alert("Please enter the DAM file path to an Excel file.");
            return;
        }

        const extension = damPath.split('.').pop().toLowerCase();
        if (["json", "xls", "xlsx"].indexOf(extension) === -1) {
            alert("Only .xls, or .xlsx file paths are allowed.");
            return;
        }

        const formData = new FormData();
        formData.append("excelPath", damPath);
        formData.append("pagePath", destPath);
        formData.append("assetsPath", assetsPath);
        formData.append("templatePath", templatePath);

        $("#btnSubmit").prop("disabled", true);
        $(".loading").removeClass("loading--hide").addClass("loading--show");
        $(".result label").hide();
        $("#downloadSection").hide(); // hide before new request

        $.ajax({
            type: "POST",
            url: "/bin/export-pages",
            data: formData,
            processData: false,
            contentType: false,
            cache: false,
            success: function (data) {
                $(".result label").text("Export Completed Successfully.");
                $(".result label").show();
                $(".loading").removeClass("loading--show").addClass("loading--hide");
                $("#btnSubmit").prop("disabled", false);
                $("#downloadSection").show();

                // Prepare Excel data
                const reportData = data;
                const wb = XLSX.utils.book_new();
                const wsData = [["Page Path", "URL", "Status"]];

                reportData.forEach(item => {
                    wsData.push([item.pagePath, item.url, item.status]);
                });

                const ws = XLSX.utils.aoa_to_sheet(wsData);

                // Auto-size column widths
                const colWidths = wsData[0].map((_, colIndex) => {
                    const maxLength = wsData.reduce((max, row) => {
                        const cell = row[colIndex] || '';
                        return Math.max(max, cell.toString().length);
                    }, 10);
                    return { wch: maxLength + 5 }; // Padding
                });
                ws['!cols'] = colWidths;

                XLSX.utils.book_append_sheet(wb, ws, "Export Report");

                // Auto download the Excel file
                XLSX.writeFile(wb, "export-report.xlsx");

                // Optional: bind again to download link if user wants to re-download manually
                $("#downloadReportLink").off("click").on("click", function (e) {
                    e.preventDefault();
                    XLSX.writeFile(wb, "export-report.xlsx");
                });
            },
            error: function (e) {
                $(".result label").text(e.responseText || "Error during import.");
                $(".result label").show();
                $(".loading").removeClass("loading--show").addClass("loading--hide");
                $("#btnSubmit").prop("disabled", false);
            }
        });
    });
});

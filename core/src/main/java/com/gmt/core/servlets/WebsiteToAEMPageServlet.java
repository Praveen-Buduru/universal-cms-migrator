package com.gmt.core.servlets;

import com.day.cq.wcm.api.Page;
import com.day.cq.wcm.api.PageManager;
import com.gmt.core.services.OpenApiConfigurationService;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.apache.sling.api.SlingHttpServletRequest;
import org.apache.sling.api.SlingHttpServletResponse;
import org.apache.sling.api.resource.Resource;
import org.apache.sling.api.resource.ResourceResolver;
import org.apache.sling.api.servlets.SlingAllMethodsServlet;
import org.json.JSONArray;
import org.json.JSONObject;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.osgi.framework.Constants;
import org.osgi.service.component.annotations.Component;
import org.osgi.service.component.annotations.Reference;

import javax.jcr.Node;
import javax.jcr.RepositoryException;
import javax.jcr.Session;
import javax.servlet.Servlet;
import javax.servlet.ServletException;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Objects;

@Component(
        service = Servlet.class,
        property = {
                Constants.SERVICE_DESCRIPTION + "=Creates AEM pages from URLs listed in Excel in DAM",
                "sling.servlet.paths=/bin/export-pages",
                "sling.servlet.methods=POST"
        }
)
public class WebsiteToAEMPageServlet extends SlingAllMethodsServlet {

    @Reference
    private transient OpenApiConfigurationService openApiConfigurationService;

    @Override
    protected void doPost(SlingHttpServletRequest request, SlingHttpServletResponse response)
            throws ServletException, IOException {

        String excelPath = request.getParameter("excelPath");
        String parentPath = request.getParameter("pagePath");
        String assetsPath = request.getParameter("assetsPath");
        String templatePath = request.getParameter("templatePath");

        if (excelPath == null || parentPath == null || templatePath == null) {
            response.setStatus(400);
            response.getWriter().write("Missing required parameters: excelPath, pagePath, templatePath.");
            return;
        }

        ResourceResolver resolver = request.getResourceResolver();
        Resource excelResource = resolver.getResource(excelPath + "/jcr:content/renditions/original/jcr:content");
        if (excelResource == null) {
            response.setStatus(404);
            response.getWriter().write("Excel file not found at: " + excelPath);
            return;
        }

        Node fileNode = excelResource.adaptTo(Node.class);
        try {
            if (fileNode == null || !fileNode.hasProperty("jcr:data")) {
                response.setStatus(500);
                response.getWriter().write("Unable to read Excel binary data.");
                return;
            }
        } catch (RepositoryException e) {
            throw new RuntimeException(e);
        }

        try (Workbook workbook = new XSSFWorkbook(fileNode.getProperty("jcr:data").getBinary().getStream())) {
            Sheet sheet = workbook.getSheetAt(0);
            JSONArray results = new JSONArray();

            for (Row row : sheet) {
                Cell cell = row.getCell(0); // Read column 0
                if (cell == null || cell.getCellType() != CellType.STRING) continue;

                String url = cell.getStringCellValue().trim();
                if (url.isEmpty()) continue;

                JSONObject result = processUrl(url, parentPath, templatePath, resolver, assetsPath);
                results.put(result);
            }

            response.setContentType("application/json");
            response.getWriter().write(results.toString());

        } catch (Exception e) {
            response.setStatus(500);
            response.getWriter().write("Error reading Excel: " + e.getMessage());
        }
    }

    private JSONObject processUrl(String url, String parentPath, String templatePath, ResourceResolver resolver, String assetsPath) {
        JSONObject result = new JSONObject();
        try {
            Document doc = Jsoup.connect(url).get();
            Element content = doc.selectFirst("main");
            if (content == null) content = doc.selectFirst("body");
            if (content == null) {
                return result.put("url", url).put("status", "failed").put("reason", "No <main> or <body> found");
            }

            String html = content.html();
            String prompt = "Convert the following HTML into a JSON array of reusable AEM Core Components. " +
                    "Use keys like 'type', 'text', 'src', 'alt', 'link'. Types should include core/title, core/text, core/image, core/button, etc. " +
                    "Return only a valid JSON array as plain text.\n\n" + html;
            PageManager pageManager = resolver.adaptTo(PageManager.class);
            String pageTitle = getUrlSlug(url);
            String nodeName = pageTitle.toLowerCase().replaceAll("[^a-z0-9]+", "-").replaceAll("(^-+|-+$)", "");
            String newPagePath = parentPath + "/" + nodeName;
            Page existingPage = pageManager.getPage(newPagePath);
            if (Objects.isNull(existingPage)) {
                String jsonString = callOpenAI(prompt);
                JSONObject jsonResponse = new JSONObject(jsonString);
                String contentJson = jsonResponse.getJSONArray("choices")
                        .getJSONObject(0)
                        .getJSONObject("message")
                        .getString("content")
                        .replaceAll("^[^\\[]*", "")
                        .replaceAll("[^\\]]*$", "")
                        .replace("json\\n", "").replace("\\n", "").replace("\\", "").replace("`", "");

                JSONArray components = new JSONArray(contentJson);
                //String pageTitle = components.getJSONObject(0).optString("text", "Untitled");


                Page newPage = pageManager.create(parentPath, nodeName, templatePath, pageTitle);

                if (newPage == null)
                    return result.put("url", url).put("status", "failed").put("reason", "Page creation failed");

                Resource contentResource = resolver.getResource(newPage.getPath() + "/jcr:content/root/container");
                if (contentResource == null)
                    return result.put("url", url).put("status", "failed").put("reason", "Container not found");

                Node contentNode = contentResource.adaptTo(Node.class);
                Session session = resolver.adaptTo(Session.class);
                int index = 1;

                for (int i = 0; i < components.length(); i++) {
                    JSONObject component = components.getJSONObject(i);
                    String type = component.optString("type");
                    if (type == null || type.isEmpty()) continue;

                    Node compNode = contentNode.addNode("component" + index++, "nt:unstructured");
                    compNode.setProperty("sling:resourceType", getResourceType(type));

                    switch (type) {
                        case "core/title":
                            compNode.setProperty("jcr:title", component.optString("text"));
                            compNode.setProperty("type", component.optString("level", "h2"));
                            break;
                        case "core/text":
                            compNode.setProperty("text", component.optString("text"));
                            break;
                        case "core/image":
                            compNode.setProperty("fileReference", assetsPath+"/"+getFileName(component.optString("src")));
                            compNode.setProperty("alt", component.optString("alt"));
                            break;
                        case "core/button":
                            compNode.setProperty("jcr:title", component.optString("text"));
                            compNode.setProperty("linkURL", component.optString("link"));
                            break;
                        case "core/teaser":
                            compNode.setProperty("jcr:title", component.optString("title"));
                            compNode.setProperty("description", component.optString("description"));
                            compNode.setProperty("fileReference", component.optString("image"));
                            compNode.setProperty("linkURL", component.optString("link"));
                            break;
                        default:
                            compNode.setProperty("text", "Unsupported component type: " + type);
                    }
                }

                session.save();
                return result.put("url", url).put("status", "success").put("pagePath", newPage.getPath());
            }else{
                return result.put("url", url).put("status", "failed").put("pagePath", "Page Exists");
            }
        } catch (Exception e) {
            return result.put("url", url).put("status", "error").put("reason", e.getMessage());
        }
    }

    private String callOpenAI(String prompt) throws IOException, InterruptedException {
        HttpClient client = HttpClient.newHttpClient();

        String payload = new JSONObject()
                .put("model", "gpt-4o")
                .put("messages", new JSONArray()
                        .put(new JSONObject().put("role", "system").put("content", "You convert HTML to AEM Core Component JSON."))
                        .put(new JSONObject().put("role", "user").put("content", prompt)))
                .toString();

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(openApiConfigurationService.getEndpoint()))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + openApiConfigurationService.getApiKey())
                .POST(HttpRequest.BodyPublishers.ofString(payload))
                .build();

        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
        return response.body();
    }

    private String getResourceType(String jsonType) {
        switch (jsonType) {
            case "core/title":
                return "core/wcm/components/title/v3/title";
            case "core/text":
                return "core/wcm/components/text/v2/text";
            case "core/image":
                return "core/wcm/components/image/v2/image";
            case "core/button":
                return "core/wcm/components/button/v1/button";
            case "core/teaser":
                return "core/wcm/components/teaser/v1/teaser";
            default:
                return "core/wcm/components/text/v2/text";
        }
    }

    private String getUrlSlug(String url){
        if (url == null || url.isEmpty()) {
            return "";
        }

        if (url.endsWith("/")) {
            url = url.substring(0, url.length() - 1);
        }

        String[] parts = url.split("/");
        String lastPart = parts[parts.length - 1];

        int dotIndex = lastPart.indexOf('.');
        if (dotIndex > 0) {
            lastPart = lastPart.substring(0, dotIndex);
        }

        String[] words = lastPart.split("-");
        StringBuilder title = new StringBuilder();

        for (String word : words) {
            if (!word.isEmpty()) {
                title.append(Character.toUpperCase(word.charAt(0)))
                        .append(word.substring(1).toLowerCase())
                        .append(" ");
            }
        }

        return title.toString().trim();

    }
    private String getFileName(String path){
        String fileName = path.substring(path.lastIndexOf('/') + 1);  // msl-mark_thumbnail_1920x1080.jpg
        return fileName.substring(0, fileName.lastIndexOf('.'))+".jpg";
    }
}